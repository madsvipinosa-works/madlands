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

-- The pose of an attack at `t` seconds: the fields of the two rows around it, eased between.
local FIELDS = { "Arm", "Side", "Yaw", "Twist", "Step", "Lean", "Lunge", "Hop", "Head", "Off", "OffYaw", "Roll", "Shoulder", "Shrug", "HeadYaw" }
local function sample(keys, t)
	local out = {}
	local before, after = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].T and t <= keys[i + 1].T then
			before, after = keys[i], keys[i + 1]
			break
		end
	end
	local a = if after.T > before.T then math.clamp((t - before.T) / (after.T - before.T), 0, 1) else 1
	a = a * a * (3 - 2 * a) -- smoothstep: eases in and out
	for _, f in FIELDS do
		local from, to = before[f] or 0, after[f] or 0 -- a row can leave a field out: that means 0
		out[f] = from + (to - from) * a
	end
	return out
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
		local bite = s.def.Look.Bite or { Duration = 0 }
		local since = workspace:GetServerTimeNow() - (model:GetAttribute("BiteAt") or -99)
		local bitePitch, biteLunge, headAngle = 0, 0, 0
		local forward = math.cos(math.rad(s.def.Look.YawDegrees)) -- +1 or -1: which way "forward" is for the hinges
		-- The club flurry (mobs with a Club): rows of poses in Config/Mobs, eased between. Every part of the body moves.
		local club = s.def.Look.Club
		local attacking = club and since >= 0 and since < club.Duration
		local armAngle, armSide, armYaw, twist, legStep, hop, offArm, offYaw = 0, 0, 0, 0, 0, 0, 0, 0
		local roll, shoulder, shrug, headYaw = 0, 0, 0, 0
		if attacking then
			local k = sample(club.Keys, since)
			armAngle, armSide, armYaw = math.rad(k.Arm), math.rad(k.Side), math.rad(k.Yaw)
			twist, legStep, hop = math.rad(k.Twist), math.rad(k.Step), k.Hop
			offArm, offYaw = math.rad(k.Off), math.rad(k.OffYaw)
			bitePitch, biteLunge, headAngle = math.rad(k.Lean), k.Lunge, math.rad(k.Head)
			roll, headYaw = math.rad(k.Roll), math.rad(k.HeadYaw)
			shoulder, shrug = math.clamp(k.Shoulder, -1, 1) * club.ShoulderReach, math.clamp(k.Shrug, -1, 1) * club.ShrugReach -- small: the arm must stay on the body
		end
		if not club and since >= 0 and since < bite.Duration then
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
				local look = math.sin(os.clock() * 0.9) * math.rad(swing.IdleHeadDegrees or 0) * (1 - power)
				motor.Transform = CFrame.Angles(headAngle, headYaw + look, 0) -- the head turns with the swing, on top of the torso's turn
			elseif role == "Arm" or role == "ClubArm" then -- arms swing against the legs; in the attack they follow the rows
				if attacking then
					if role == "ClubArm" then
						-- the shoulder moves too: forward as the club comes through, back on the wind-up, up in a shrug
						motor.Transform = CFrame.new(0, shrug, -forward * shoulder) * CFrame.Angles(0, armYaw, 0) * CFrame.Angles(armAngle * forward, 0, armSide)
					else
						motor.Transform = CFrame.new(0, shrug * 0.5, forward * shoulder * 0.7) * CFrame.Angles(0, offYaw, 0) * CFrame.Angles(offArm * forward, 0, 0) -- the off shoulder counter-moves
					end
				else
					local p = s.phase + (if motor:GetAttribute("Phase") == 1 then 0 else math.pi)
					local fidget = math.sin(os.clock() * 1.9 + (motor:GetAttribute("Phase") or 0) * 2) * math.rad(swing.IdleArmDegrees or 0) * (1 - power)
					motor.Transform = CFrame.Angles((math.sin(p) * math.rad(swing.ArmDegrees) * power + fidget) * forward, 0, 0)
				end
			elseif role == "Body" then -- bobs twice and rocks once per stride; breathes when still; hops and lunges in the attack
				local bob = math.sin(s.phase * 2) * swing.BodyBobStuds * power + math.sin(os.clock() * 2.4) * (swing.IdleBreathStuds or 0) * (1 - power)
				local pitch = math.sin(s.phase) * math.rad(swing.BodyPitchDegrees) * power
				motor.Transform = CFrame.new(0, bob + hop, -forward * biteLunge) * CFrame.Angles(pitch + bitePitch * (if club then forward else 1), twist, roll)
			else -- Hip
				local p = s.phase + (if motor:GetAttribute("Phase") == 1 then 0 else math.pi) -- diagonal legs move together
				-- The hinge is turned by YawDegrees, so `forward` (above) says which swing direction is "forward".
				local lift = math.max(0, math.cos(p) * forward) * swing.LegLiftStuds * power
				motor.Transform = CFrame.new(0, lift, 0) * CFrame.Angles(0, -twist * 0.8, 0) * CFrame.Angles(math.sin(p) * math.rad(swing.HipDegrees) * power + legStep * forward * motor:GetAttribute("Phase"), 0, 0)
			end
		end
	end
end)

CollectionService:GetInstanceAddedSignal("WalkingMob"):Connect(add)
for _, model in CollectionService:GetTagged("WalkingMob") do
	task.spawn(add, model)
end

return true
