-- Plays a move from Config/SwingAnimations: the published animation when it has an AssetId, otherwise an animation
-- built on the spot from the move's poses and played by Roblox's own Animator (R15 characters).
-- shortcut: a built animation is registered for this client only, so only you see your own skills, not other
-- players; publish the move from the Animation Editor and paste its AssetId, or fix when PvP needs it (build step 8).
-- (Turning the joints' resting pose from a script does not work: the body hardly follows, which looked like a thrust.)
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Defs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SwingAnimations"))
local player = Players.LocalPlayer
local ZERO = Vector3.zero

-- Seconds between built keyframes. Small, so no joint turns more than about 45 degrees between two of them:
-- Roblox turns a limb the shortest way between two poses, so a bigger step would go the wrong way round.
local STEP = 0.025

-- Joint name in the config -> the body part that joint moves (what an animation stores poses for).
local PART_OF = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm",
	RightElbow = "RightLowerArm",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
}
local JOINT_OF = {}
for joint, part in PART_OF do
	JOINT_OF[part] = joint
end

local function node(name, ...)
	return { name = name, children = { ... } }
end
-- An animation stores poses in the same nesting as the rig.
local TREE = node(
	"HumanoidRootPart",
	node(
		"LowerTorso",
		node("UpperTorso", node("LeftUpperArm", node("LeftLowerArm")), node("RightUpperArm", node("RightLowerArm"))),
		node("LeftUpperLeg", node("LeftLowerLeg")),
		node("RightUpperLeg", node("RightLowerLeg"))
	)
)

-- The pose (joint -> Vector3 degrees) the move is in at time t, easing between its keyframes.
local function poseAt(def, t)
	local from, fromT = {}, 0
	for _, key in def.Keyframes do
		if t <= key.T then
			local a = (t - fromT) / (key.T - fromT)
			-- Ease says how the body gets here: "In" speeds up into a strike, "InOut" is a slow wind-up,
			-- "Linear" is a steady spin, "Out" (the default) is a quick snap that settles.
			if key.Ease ~= "Linear" then
				a = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection[key.Ease or "Out"])
			end
			local pose = {}
			for joint in PART_OF do
				pose[joint] = (from[joint] or ZERO):Lerp(key.Pose[joint] or ZERO, a) -- joints left out go back to rest
			end
			return pose
		end
		from, fromT = key.Pose, key.T
	end
	return from
end

local function buildSequence(def)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action
	for i = 0, math.ceil(def.Duration / STEP) do
		local t = math.min(i * STEP, def.Duration)
		local pose = poseAt(def, t)
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = t
		local function add(item, parent)
			local p = Instance.new("Pose")
			p.Name = item.name
			local v = pose[JOINT_OF[item.name]]
			if v then
				p.CFrame = CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
			end
			p.Parent = parent
			for _, child in item.children do
				add(child, p)
			end
		end
		add(TREE, keyframe)
		keyframe.Parent = sequence
	end
	return sequence
end

local ids = {} -- [move name] = the id of its built animation, made once
local tracks = {} -- [key] = { animator, track }; reloaded after a respawn

local Animations = {}

function Animations.Play(name, speed)
	local def = Defs[name]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not (def and animator) then
		return
	end

	local published = def.AssetId ~= ""
	local key = if published then def.AssetId else name
	local entry = tracks[key]
	if not entry or entry.animator ~= animator then
		if not published and not ids[name] then
			ids[name] = KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence(def))
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = if published then def.AssetId else ids[name]
		entry = { animator = animator, track = animator:LoadAnimation(animation) }
		entry.track.Priority = Enum.AnimationPriority.Action
		tracks[key] = entry
	end
	entry.track:Play(0.05)
	entry.track:AdjustSpeed(speed or 1)
end

return Animations
