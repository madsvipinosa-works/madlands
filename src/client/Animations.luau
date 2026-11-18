-- Plays the code-made swing animations (Config/SwingAnimations) on the local character by turning its joints.
-- shortcut: only you see your own swing, because joint turns are not sent to other players; fix when PvP needs it (build step 8).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Defs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SwingAnimations"))
local player = Players.LocalPlayer
local ZERO = Vector3.zero

local active -- { def, joints, start, speed }

local function setPose(joints, from, to, alpha)
	for name, joint in joints do
		local v = (from[name] or ZERO):Lerp(to[name] or ZERO, alpha)
		local x, y, z = math.rad(v.X), math.rad(v.Y), math.rad(v.Z)
		if name == "Root" then
			-- R15's Root joint is turned: its X is the body's -X, its Y is the body's Z and its Z is the body's up.
			-- This maps the config's pose (lean X, turn Y, roll Z) onto it, so Y really spins the body.
			joint.Transform = CFrame.Angles(-x, z, y)
		else
			joint.Transform = CFrame.Angles(x, y, z)
		end
	end
end

local function update()
	if not active then
		return
	end
	local t = (os.clock() - active.start) * active.speed
	local def = active.def
	if t >= def.Duration then
		for _, joint in active.joints do
			joint.Transform = CFrame.new()
		end
		active = nil
		return
	end
	local from, fromT = {}, 0
	for _, key in def.Keyframes do
		if t <= key.T then
			local a = (t - fromT) / (key.T - fromT)
			setPose(active.joints, from, key.Pose, 1 - (1 - a) * (1 - a)) -- ease out
			return
		end
		from, fromT = key.Pose, key.T
	end
end

-- Written after the game's own animations each frame, so ours wins.
RunService.Heartbeat:Connect(update)
RunService.RenderStepped:Connect(update)

local Animations = {}

function Animations.Play(name, speed)
	local def = Defs[name]
	local character = player.Character
	if not (def and character) then
		return
	end
	local joints = {}
	for _, key in def.Keyframes do
		for jointName in key.Pose do
			local joint = joints[jointName] or character:FindFirstChild(jointName, true)
			if joint and joint:IsA("Motor6D") then
				joints[jointName] = joint
			end
		end
	end
	active = { def = def, joints = joints, start = os.clock(), speed = speed or 1 }
end

return Animations
