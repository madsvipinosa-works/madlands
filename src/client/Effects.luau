-- Hit sparks, ground dust and camera shake. Looks only; runs on your screen.
-- shortcut: skill effects (dust, shake) are only shown to the player using the skill; fix when PvP needs it (build step 8).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Effects"))
local player = Players.LocalPlayer

local Effects = {}

-- A burst of chips at a target's body.
function Effects.HitSpark(root)
	local c = Config.HitSpark
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(c.Color)
	emitter.LightEmission = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, c.Size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(c.Lifetime * 0.6, c.Lifetime)
	emitter.Speed = NumberRange.new(c.Speed * 0.6, c.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(c.Count)
	Debris:AddItem(attachment, c.Lifetime + 0.2)
end

-- A puff of dust and an expanding ring on the ground.
function Effects.Dust(position, size)
	local c = Config.Dust
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(c.Color)
	emitter.LightEmission = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.3), NumberSequenceKeypoint.new(1, size * 0.8) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(c.Lifetime * 0.6, c.Lifetime)
	emitter.Speed = NumberRange.new(size * 0.8, size * 1.6)
	emitter.SpreadAngle = Vector2.new(85, 85)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(math.floor(size * 2))

	local ring = Instance.new("Part") -- flat ring that grows and fades
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Color = c.Color
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.4
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(
		ring,
		TweenInfo.new(c.Lifetime * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, size * 2, size * 2), Transparency = 1 }
	):Play()

	Debris:AddItem(anchor, c.Lifetime + 0.3)
	Debris:AddItem(ring, c.Lifetime)
end

-- Shakes the camera for a moment, fading out.
local shakeUntil, shakeStart, shakeStrength = 0, 0, 0
RunService.RenderStepped:Connect(function()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local now = os.clock()
	if now < shakeUntil then
		local fade = (shakeUntil - now) / (shakeUntil - shakeStart)
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 2 * shakeStrength * fade
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
	end
end)

function Effects.Shake(strength, seconds)
	shakeStart = os.clock()
	shakeUntil = shakeStart + seconds
	shakeStrength = strength
end

local function groundBelow(root)
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0))
	return hit and hit.Position or root.Position - Vector3.new(0, 3, 0)
end

-- Called when the server accepts a skill; picks the effects for its Type.
function Effects.SkillStarted(skill)
	local e = Config.Types[skill.Type]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (e and root) then
		return
	end
	if e.StartDustSize then
		Effects.Dust(groundBelow(root), e.StartDustSize)
	end
	if e.ShakeAmplitude and not e.LandingDustSize then
		Effects.Shake(e.ShakeAmplitude, e.ShakeSeconds)
	end
	if e.LandingDustSize then
		task.delay(skill.HitDelay, function()
			local now = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if now then
				Effects.Dust(groundBelow(now), e.LandingDustSize)
				Effects.Shake(e.ShakeAmplitude, e.ShakeSeconds)
			end
		end)
	end
end

return Effects
