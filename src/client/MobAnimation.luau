-- Swings the legs of mobs tagged "WalkingMob" while they move. Looks only; runs on each client.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Mobs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mobs"))

local animated = {} -- [model] = { root, def, phase, motors }

local function add(model)
	local def = Mobs[model.Name]
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if def and root then
		animated[model] = { root = root, def = def, phase = 0, motors = {} }
	end
end

RunService.RenderStepped:Connect(function(dt)
	for model, s in animated do
		if not model.Parent then
			animated[model] = nil
			continue
		end
		if #s.motors < (model:GetAttribute("MotorCount") or 1) then -- hinges may arrive a moment after the model
			s.motors = {}
			for _, child in model:GetDescendants() do
				if child:IsA("Motor6D") and child:GetAttribute("Phase") then
					table.insert(s.motors, child)
				end
			end
		end

		local velocity = s.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local swing = s.def.Look.Swing
		s.phase += speed * dt * swing.RadiansPerStud
		local power = math.min(speed / s.def.WalkSpeed, 1)

		-- The bite runs on top of the walk: wind up, snap forward, recover.
		local bite = s.def.Look.Bite
		local since = workspace:GetServerTimeNow() - (model:GetAttribute("BiteAt") or -99)
		local bitePitch, biteLunge, headAngle = 0, 0, 0
		if since >= 0 and since < bite.Duration then
			local p = since / bite.Duration
			if p < 0.3 then -- wind up
				local a = p / 0.3
				bitePitch = -math.rad(bite.RearDegrees) * a
				headAngle = -math.rad(bite.HeadUpDegrees) * a
			elseif p < 0.55 then -- snap
				local a = (p - 0.3) / 0.25
				bitePitch = -math.rad(bite.RearDegrees) + (math.rad(bite.RearDegrees + bite.PitchDegrees)) * a
				headAngle = -math.rad(bite.HeadUpDegrees) + (math.rad(bite.HeadUpDegrees + bite.HeadDropDegrees)) * a
				biteLunge = math.sin(a * math.pi) * bite.LungeStuds
			else -- recover
				local a = 1 - (p - 0.55) / 0.45
				bitePitch = math.rad(bite.PitchDegrees) * a
				headAngle = math.rad(bite.HeadDropDegrees) * a
				biteLunge = 0
			end
		end
		for _, motor in s.motors do
			local role = motor:GetAttribute("Role")
			if role == "Tail" then -- wags side to side, a little even when standing
				local wag = math.sin(os.clock() * swing.TailSpeed) * math.rad(swing.TailDegrees)
				motor.Transform = CFrame.Angles(0, wag * (0.4 + 0.6 * power), 0)
			elseif role == "Neck" then -- head dips into the bite
				motor.Transform = CFrame.Angles(headAngle, 0, 0)
			elseif role == "Body" then -- bobs twice and rocks once per stride, plus the bite lunge
				local bob = math.sin(s.phase * 2) * swing.BodyBobStuds * power
				local pitch = math.sin(s.phase) * math.rad(swing.BodyPitchDegrees) * power
				local forward = -math.cos(math.rad(s.def.Look.YawDegrees)) * biteLunge
				motor.Transform = CFrame.new(0, bob, forward) * CFrame.Angles(pitch + bitePitch, 0, 0)
			else -- Hip
				local p = s.phase + (if motor:GetAttribute("Phase") == 1 then 0 else math.pi) -- diagonal legs move together
				-- The hinge is turned by YawDegrees, so this sign says which swing direction is "forward".
				local forward = math.cos(math.rad(s.def.Look.YawDegrees))
				local lift = math.max(0, math.cos(p) * forward) * swing.LegLiftStuds * power
				motor.Transform = CFrame.new(0, lift, 0) * CFrame.Angles(math.sin(p) * math.rad(swing.HipDegrees) * power, 0, 0)
			end
		end
	end
end)

CollectionService:GetInstanceAddedSignal("WalkingMob"):Connect(add)
for _, model in CollectionService:GetTagged("WalkingMob") do
	task.spawn(add, model)
end

return true
