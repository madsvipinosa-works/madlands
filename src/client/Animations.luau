-- Plays a move from Config/SwingAnimations: the published animation when it has an AssetId, otherwise by turning the character's joints.
-- Characters come in two rig types: old ones joined by Motor6D, new ones by AnimationConstraint. Both are handled.
-- It turns the joint's resting pose, not the pose Roblox's own animations write every frame, so ours is not erased.
-- shortcut: only you see your own swing, because joint turns are not sent to other players; fix when PvP needs it (build step 8).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Defs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SwingAnimations"))
local player = Players.LocalPlayer
local ZERO = Vector3.zero

-- Older R6 characters name their joints differently.
local ALIASES = {
	Root = "RootJoint",
	RightShoulder = "Right Shoulder",
	LeftShoulder = "Left Shoulder",
	Waist = "RootJoint",
}

local active -- { def, joints, start, speed }; joints[name] = { object, property, rest }

-- The thing to turn for this joint, and which of its properties holds the resting pose.
local function targetOf(joint)
	if joint:IsA("Motor6D") then
		return joint, "C0"
	end
	local attachment = joint.Attachment0 -- AnimationConstraint: its first attachment holds the resting pose
	if attachment then
		return attachment, "CFrame"
	end
end

local function setPose(joints, from, to, alpha)
	for name, j in joints do
		local v = (from[name] or ZERO):Lerp(to[name] or ZERO, alpha)
		local turn = CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
		-- Turned around the joint but along the body part it hangs from, not along the joint's own tilted axes.
		-- That way X always swings forward, Y always turns and Z always moves out to the side, on every rig.
		j.object[j.property] = CFrame.new(j.rest.Position) * turn * j.rest.Rotation
	end
end

local function finish()
	for _, j in active.joints do
		j.object[j.property] = j.rest
	end
	active = nil
end

local function update()
	if not active then
		return
	end
	local t = (os.clock() - active.start) * active.speed
	local def = active.def
	if t >= def.Duration then
		finish()
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

RunService.RenderStepped:Connect(update)

local tracks = {} -- [assetId] = { animator, track }; reloaded after a respawn

-- A move published from the Animation Editor. Roblox plays it, so other players see it too.
local function playPublished(def, speed)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	local entry = tracks[def.AssetId]
	if not entry or entry.animator ~= animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = def.AssetId
		entry = { animator = animator, track = animator:LoadAnimation(animation) }
		entry.track.Priority = Enum.AnimationPriority.Action
		tracks[def.AssetId] = entry
	end
	entry.track:Play(0.05)
	entry.track:AdjustSpeed(speed or 1)
	return true
end

local Animations = {}

function Animations.Play(name, speed)
	local def = Defs[name]
	local character = player.Character
	if not (def and character) then
		return
	end
	if def.AssetId ~= "" and playPublished(def, speed) then
		return
	end
	if active then
		finish() -- a new move cuts off the old one
	end

	local rig = {} -- every joint in the character, by name
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") or item.ClassName == "AnimationConstraint" then
			rig[item.Name] = item
		end
	end

	local joints = {}
	for _, key in def.Keyframes do
		for jointName in key.Pose do
			local joint = rig[jointName] or rig[ALIASES[jointName]]
			if joint and not joints[jointName] then
				local object, property = targetOf(joint)
				if object then
					joints[jointName] = { object = object, property = property, rest = object[property] }
				end
			end
		end
	end

	active = { def = def, joints = joints, start = os.clock(), speed = speed or 1 }
end

return Animations
