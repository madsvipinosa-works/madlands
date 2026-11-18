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
		if #s.motors < 4 then -- legs may arrive a moment after the model
			s.motors = {}
			for _, child in s.root:GetChildren() do
				if child:IsA("Motor6D") and child:GetAttribute("Phase") then
					table.insert(s.motors, child)
				end
			end
		end

		local velocity = s.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local swing = s.def.Look.Swing
		s.phase += speed * dt * swing.RadiansPerStud
		local angle = math.rad(swing.AngleDegrees) * math.min(speed / s.def.WalkSpeed, 1)
		for _, motor in s.motors do
			motor.Transform = CFrame.Angles(math.sin(s.phase) * angle * motor:GetAttribute("Phase"), 0, 0)
		end
	end
end)

CollectionService:GetInstanceAddedSignal("WalkingMob"):Connect(add)
for _, model in CollectionService:GetTagged("WalkingMob") do
	task.spawn(add, model)
end

return true
