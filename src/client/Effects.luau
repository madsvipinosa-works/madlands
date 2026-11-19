-- Hit sparks, ground dust, flashes, whirl ribbons and camera shake. Looks only; runs on your screen.
-- shortcut: skill effects (dust, shake) are only shown to the player using the skill; fix when PvP needs it (build step 8).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Effects"))
local player = Players.LocalPlayer

local Effects = {}

-- An invisible anchored part that effects hang their emitters and lights on.
local function anchorAt(cframe)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = cframe
	anchor.Parent = workspace
	return anchor
end

local function tween(instance, seconds, goal, style)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- A burst of chips at a target's body. `big` (a strong hit) throws more of them.
function Effects.HitSpark(root, big)
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
	emitter:Emit(if big then c.Count * 2 else c.Count)
	Debris:AddItem(attachment, c.Lifetime + 0.2)
end

-- A puff of dust, no ring (cheap enough to drop along a whole dash).
function Effects.Puff(position, size)
	local c = Config.Dust
	local anchor = anchorAt(CFrame.new(position))
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
	Debris:AddItem(anchor, c.Lifetime + 0.3)
end

-- A puff of dust and an expanding ring on the ground.
function Effects.Dust(position, size)
	local c = Config.Dust
	Effects.Puff(position, size)

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
	tween(ring, c.Lifetime * 0.6, { Size = Vector3.new(0.2, size * 2, size * 2), Transparency = 1 })
	Debris:AddItem(ring, c.Lifetime)
end

-- A flat ring on the ground that grows and fades. `seconds` is how long it takes.
function Effects.Ring(position, size, seconds)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Color = Config.Dust.Color
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.5
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	tween(ring, seconds, { Size = Vector3.new(0.2, size, size), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(ring, seconds + 0.1)
end

-- A bright ball that swells and fades, with a flash of light: the pop of an impact.
function Effects.Flash(position, size, color)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Transparency = 0.25
	ball.Size = Vector3.one * size * 0.3
	ball.Position = position
	ball.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 2
	light.Brightness = 3
	light.Parent = ball

	tween(ball, 0.22, { Size = Vector3.one * size, Transparency = 1 })
	tween(light, 0.22, { Brightness = 0 })
	Debris:AddItem(ball, 0.3)
end

-- Glowing chips thrown from a point along `direction`. spec: Count, Color, Speed, Size, Lifetime, Spread (degrees), Gravity.
function Effects.Sparks(position, direction, spec)
	local anchor = anchorAt(CFrame.lookAt(position, position + direction))
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Front -- along the way the part faces
	emitter.Color = ColorSequence.new(spec.Color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(spec.Lifetime * 0.6, spec.Lifetime)
	emitter.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed)
	emitter.SpreadAngle = Vector2.new(spec.Spread, spec.Spread)
	emitter.Acceleration = Vector3.new(0, -spec.Gravity, 0)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(spec.Count)
	Debris:AddItem(anchor, spec.Lifetime + 0.2)
end

-- A thin bright line facing the camera that stretches out and fades, like the cut mark in an anime fight.
function Effects.SlashMark(position, length, color, degrees)
	local mark = Instance.new("Part")
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Material = Enum.Material.Neon
	mark.Color = color
	mark.Size = Vector3.new(length * 0.4, 0.5, 0.05)
	mark.CFrame = CFrame.new(position) * workspace.CurrentCamera.CFrame.Rotation * CFrame.Angles(0, 0, math.rad(degrees))
	mark.Parent = workspace
	tween(mark, 0.2, { Size = Vector3.new(length, 0.05, 0.05), Transparency = 1 })
	Debris:AddItem(mark, 0.3)
end

-- Ribbons that circle you while you spin, so the whole turn leaves a visible wind.
function Effects.Whirl(root, style)
	local orbiters = {}
	for i = 1, 3 do
		local part = anchorAt(root.CFrame)
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 0.7, 0)
		top.Parent = part
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -0.7, 0)
		bottom.Parent = part
		local ribbon = Instance.new("Trail")
		ribbon.Attachment0, ribbon.Attachment1 = top, bottom
		ribbon.Color = ColorSequence.new(style.WhirlColor)
		ribbon.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		ribbon.Lifetime = 0.3
		ribbon.LightEmission = 0.7
		ribbon.FaceCamera = false
		ribbon.Parent = part
		orbiters[i] = { part = part, height = (i - 2) * 1.7, phase = (i - 1) * math.pi * 2 / 3 }
		Debris:AddItem(part, style.WhirlSeconds + 0.5) -- stays a moment after, so the ribbon fades instead of vanishing
	end

	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= style.WhirlSeconds or not root.Parent then
			connection:Disconnect()
			return
		end
		local angle = t * math.rad(1100) -- about the speed of the spin animation
		for _, o in orbiters do
			o.part.CFrame = CFrame.new(root.Position + Vector3.new(0, o.height, 0))
				* CFrame.Angles(0, angle + o.phase, 0)
				* CFrame.new(0, 0, style.WhirlRadius)
		end
	end)
end

-- A fresh, white, anchored copy of the crescent mesh, and how to resize it: slash, the thing to resize, its
-- property ("Scale" or "Size") and the full size it comes at. Nil if the mesh is not there.
local function newSlash()
	local template = ReplicatedStorage:WaitForChild("WaveSlash", 5)
	-- Either the old premade Part with a SpecialMesh, or an imported Model whose MeshPart is the slash.
	local source = template and (if template:IsA("BasePart") then template else template:FindFirstChildWhichIsA("BasePart", true))
	if not source then
		return nil
	end
	local slash = source:Clone()
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanQuery = false
	slash.CanTouch = false
	slash.CastShadow = false
	for _, item in slash:GetDescendants() do
		if item:IsA("WeldConstraint") then
			item:Destroy() -- joins nothing here
		end
	end
	-- The old premade slash is sized and colored through its SpecialMesh; an imported MeshPart through itself.
	local mesh = slash:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.VertexColor = Config.Wave.Tint
	else
		slash.Material = Enum.Material.Neon -- glows pure white
	end
	slash.Color = Color3.new(1, 1, 1)
	local sized, property = mesh or slash, if mesh then "Scale" else "Size"
	return slash, sized, property, sized[property]
end

-- The crescent flashing where a cut lands (a Dash): swells to `scale` times its native size and fades.
-- `cframe` is where it sits; turn it about Y by 180 to make its curved edge lead instead of trail.
function Effects.CutMark(cframe, scale, seconds)
	local slash, sized, property, native = newSlash()
	if not slash then
		return
	end
	slash.CFrame = cframe
	sized[property] = native * scale * 0.5
	slash.Parent = workspace
	tween(sized, seconds * 0.5, { [property] = native * scale }, Enum.EasingStyle.Back)
	tween(slash, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(slash, seconds + 0.1)
end

-- The flying slash of a Wave skill, drawn here on every client. The server sends where it starts and how it
-- moves and only moves the hit box itself, so this runs smoothly from the first frame. It swells out of a small
-- size and fades before it ends. (Fading copies left behind it were tried and looked like separate frames.)
function Effects.Wave(shooter, start, direction, speed, range)
	local c = Config.Wave
	local glow = Config.WaveGlow
	local slash, sized, property, native = newSlash()
	if not slash then
		return
	end

	local rotation = c.ModelRotation
	local aim = CFrame.lookAt(start, start + direction)
		* CFrame.Angles(0, 0, math.rad(c.TiltDegrees))
		* CFrame.new(c.ModelOffset)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	local facing = aim.Rotation
	local origin = aim.Position

	local fullScale = native * c.ModelScale
	sized[property] = fullScale * c.GrowFrom
	slash.CFrame = CFrame.new(origin) * facing
	slash.Parent = workspace
	tween(sized, c.GrowSeconds, { [property] = fullScale }, Enum.EasingStyle.Back)

	local sparks = Instance.new("ParticleEmitter") -- shed along the flight
	sparks.Color = ColorSequence.new(glow.Color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, glow.SparkSize), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.25, 0.5)
	sparks.Speed = NumberRange.new(0, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = glow.SparkRate
	sparks.Parent = slash
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Range = glow.LightRange
	light.Brightness = glow.LightBrightness
	light.Parent = slash

	-- The pop where it leaves the sword; whoever swung also feels it.
	Effects.Flash(start, 5, c.Color)
	Effects.Sparks(start, direction, { Count = 14, Color = c.Color, Speed = 45, Size = 0.5, Lifetime = 0.35, Spread = 35, Gravity = 10 })
	if shooter == player then
		Effects.Shake(0.2, 0.15)
		Effects.FovKick(4, 0.3)
	end

	local baseTransparency = slash.Transparency
	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startedAt
		local traveled = speed * t
		if traveled >= range then
			connection:Disconnect()
			slash:Destroy()
			return
		end
		slash.CFrame = CFrame.new(origin + direction * traveled) * facing
		local gone = math.clamp((traveled / range - c.FadeFrom) / (1 - c.FadeFrom), 0, 1)
		slash.Transparency = baseTransparency + (1 - baseTransparency) * gone
	end)
end

-- A strong hit: a pop of light, a slash line across the target and a spray of sparks.
function Effects.Impact(position)
	local c = Config.Impact
	Effects.Flash(position, c.FlashSize, c.Color)
	Effects.SlashMark(position, c.MarkLength, c.Color, math.random(-60, 60))
	Effects.Sparks(position, Vector3.yAxis, { Count = c.SparkCount, Color = c.Color, Speed = 35, Size = 0.5, Lifetime = 0.45, Spread = 180, Gravity = 60 })
	Effects.Shake(c.ShakeAmplitude, c.ShakeSeconds)
end

-- Streaks behind the body, for a rush that is over too fast to read on its own. A few ribbons side by side make a band.
function Effects.Streak(root, style)
	local spread = style.StreakSpread or 0
	for _, x in (if spread > 0 then { -spread, 0, spread } else { 0 }) do
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(x, style.StreakHeight / 2, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(x, -style.StreakHeight / 2, 0)
		bottom.Parent = root

		local streak = Instance.new("Trail")
		streak.Attachment0, streak.Attachment1 = top, bottom
		streak.Color = ColorSequence.new(style.StreakColor)
		streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		streak.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		streak.Lifetime = style.StreakSeconds
		streak.LightEmission = 0.4
		streak.FaceCamera = true
		streak.Parent = root

		Debris:AddItem(streak, style.StreakSeconds * 2)
		Debris:AddItem(top, style.StreakSeconds * 2)
		Debris:AddItem(bottom, style.StreakSeconds * 2)
	end
end

-- Shakes the camera for a moment, fading out. A weaker shake never cuts off a stronger one that is still going.
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
	local now = os.clock()
	if now < shakeUntil and strength < shakeStrength * (shakeUntil - now) / (shakeUntil - shakeStart) then
		return
	end
	shakeStart = now
	shakeUntil = now + seconds
	shakeStrength = strength
end

-- Widens the camera for a moment and eases back, so a rush feels fast.
local restFov, kicking = nil, false
function Effects.FovKick(degrees, seconds)
	local camera = workspace.CurrentCamera
	if not kicking then
		restFov = camera.FieldOfView
	end
	kicking = true
	camera.FieldOfView = restFov + degrees
	tween(camera, seconds, { FieldOfView = restFov })
	task.delay(seconds, function()
		kicking = false
	end)
end

local function groundBelow(root)
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0))
	return hit and hit.Position or root.Position - Vector3.new(0, 3, 0)
end

-- Runs act(root) after `seconds`, if your character is still there.
local function later(seconds, act)
	task.delay(seconds, function()
		local now = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if now then
			act(now)
		end
	end)
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
	if e.StreakSeconds then
		Effects.Streak(root, e)
	end
	if e.FovKick then
		Effects.FovKick(e.FovKick, 0.4)
	end
	if e.CutMarkScale then -- where the server's cut lands: the crescent flashes across the path, with a pop of light
		later(skill.HitDelay, function(now)
			local look = now.CFrame.LookVector
			local at = now.Position + look * e.CutMarkAhead
			Effects.CutMark(CFrame.lookAt(at, at + look) * CFrame.Angles(0, math.rad(e.CutMarkTurn), 0), e.CutMarkScale, e.CutMarkSeconds)
			Effects.Flash(at, 4, e.FlashColor)
		end)
	end
	if e.TrailDustSize then -- a line of dust along the ground the whole way
		for i = 1, math.floor(skill.DashTime / e.TrailDustEvery) do
			later(i * e.TrailDustEvery, function(now)
				Effects.Puff(groundBelow(now), e.TrailDustSize)
			end)
		end
	end
	if e.EndDustSize then
		later(skill.DashTime, function(now)
			Effects.Dust(groundBelow(now), e.EndDustSize)
		end)
	end
	if e.WhirlSeconds then
		later(e.WhirlDelay, function(now)
			Effects.Whirl(now, e)
		end)
	end
	if e.SpinRingSize then -- a ring sweeping out around the spin
		later(skill.HitDelay or 0, function(now)
			Effects.Ring(groundBelow(now), e.SpinRingSize, 0.45)
		end)
	end
	if e.ShakeAmplitude and not e.LandingDustSize then
		Effects.Shake(e.ShakeAmplitude, e.ShakeSeconds)
	end
	if e.LandingDustSize then
		later(skill.HitDelay, function(now)
			local ground = groundBelow(now)
			Effects.Dust(ground, e.LandingDustSize)
			Effects.Ring(ground, e.ShockwaveSize, 0.35) -- the slam snaps out faster than the dust
			task.delay(0.08, Effects.Ring, ground, e.SecondRingSize, 0.6)
			Effects.Flash(ground + Vector3.new(0, 1, 0), e.FlashSize, e.FlashColor)
			Effects.Sparks(ground, Vector3.yAxis, { Count = e.EmberCount, Color = e.FlashColor, Speed = 40, Size = 0.7, Lifetime = 0.9, Spread = 55, Gravity = 70 })
			Effects.Shake(e.ShakeAmplitude, e.ShakeSeconds)
		end)
	end
end

return Effects
