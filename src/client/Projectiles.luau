-- Draws arrows, spells and their landings for everyone's attacks, as the server announces them. Looks only.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Projectiles"))
local Effects = require(script.Parent.Effects)
local FireballVFX = require(ReplicatedStorage.Shared:WaitForChild("FireballVFX"))
local Sounds = require(script.Parent.Sounds)

local rng = Random.new()
local flying = {} -- [shot id] = { model, look, connection }

local function part(parent, size, color, material, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

local function trail(on, width, color, seconds)
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Position, b.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
	a.Parent, b.Parent = on, on
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a, b
	t.Color = ColorSequence.new(color)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime = seconds
	t.LightEmission = 0.8
	t.FaceCamera = true
	t.Parent = on
end

-- A model whose pivot points along -Z: a shaft, a head and two feathers.
local function arrow(look)
	local model = Instance.new("Model")
	local glow = if look.Glow then Enum.Material.Neon else Enum.Material.Wood
	local shaft = part(model, Vector3.new(0.16, 0.16, look.Length), look.Color, glow)
	local head = part(model, Vector3.new(0.34, 0.34, 0.55), Color3.fromRGB(190, 196, 208), Enum.Material.Metal)
	head.CFrame = CFrame.new(0, 0, -look.Length / 2 - 0.2) * CFrame.Angles(0, 0, math.pi / 4)
	for turn = 0, 1 do
		local feather = part(model, Vector3.new(0.55, 0.05, 0.7), Color3.fromRGB(236, 232, 220), Enum.Material.SmoothPlastic)
		feather.CFrame = CFrame.new(0, 0, look.Length / 2 - 0.35) * CFrame.Angles(0, 0, turn * math.pi / 2)
	end
	model.PrimaryPart = shaft
	trail(shaft, if look.Glow then 0.9 else 0.3, look.Trail, if look.Glow then 0.3 else 0.14)
	return model
end

local function orb(look)
	local model = Instance.new("Model")
	local ball = part(model, Vector3.one * look.Size, look.Color, Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = look.Color
	light.Range = look.Size * 8
	light.Brightness = 2
	light.Parent = ball
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(look.Color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, look.Size * 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(0, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 60
	sparks.Parent = ball
	model.PrimaryPart = ball
	trail(ball, look.Size * 0.8, look.Color, 0.2)
	return model
end

-- The glowing part at the top of the shooter's wand, if they hold one.
local function wandTip(character)
	local weapon = character and character:FindFirstChild("WeaponVisual")
	return weapon and weapon:FindFirstChild("Wand_Crystal")
end

local function charge(shooter, lookName, seconds)
	local look = Config[lookName]
	local tip = wandTip(shooter)
	if look and look.Kind == "Fireball" and tip then
		local gathering = FireballVFX.charge(tip, { glow = look.Glow, scale = look.Scale, chargeTime = seconds })
		task.delay(seconds, gathering.Release, gathering)
	end
end

local function fire(id, lookName, start, direction, speed, range, shooter)
	local look = Config[lookName]
	if not look then
		return
	end
	if look.Kind == "Fireball" then
		-- thrown from the wand tip toward where the server's shot ends; the server alone decides what it hits, so the effect
		-- is told to ignore everything and is stopped by the "Stop" message
		local tip = wandTip(shooter)
		local from = if tip then tip.Position else start + direction * 2
		local to = start + direction * range
		flying[id] = {
			look = look,
			flight = FireballVFX.launch(from, to - from, {
				color = look.Color,
				glow = look.Glow,
				scale = look.Scale,
				speed = speed,
				range = (to - from).Magnitude,
				ignore = { workspace },
				explodeAtRange = false,
			}),
		}
		return
	end
	local model = if look.Kind == "Orb" then orb(look) else arrow(look)
	local from = CFrame.lookAlong(start + direction * 2, direction)
	model:PivotTo(from)
	model.Parent = workspace
	local startedAt = os.clock()
	local shot = { model = model, look = look }
	flying[id] = shot
	shot.connection = RunService.RenderStepped:Connect(function()
		local traveled = math.min(speed * (os.clock() - startedAt), math.max(range - 2, 0))
		model:PivotTo(from + direction * traveled)
		if speed * (os.clock() - startedAt) > range + speed then -- the stop message never came
			shot.connection:Disconnect()
			model:Destroy()
			flying[id] = nil
		end
	end)
end

-- A burst of light, sparks and a ring.
local function burst(position, radius, color)
	Effects.Flash(position, radius * 1.5, color)
	Effects.Ring(position - Vector3.new(0, 2, 0), radius * 2, 0.45)
	Effects.Sparks(position, Vector3.yAxis, { Count = math.floor(radius * 4), Color = color, Speed = radius * 4, Size = 0.7, Lifetime = 0.5, Spread = 180, Gravity = 50 })
end

-- A sound at a spot in the world.
local function soundAt(cue, position)
	local anchor = part(workspace, Vector3.one, Color3.new(), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.Position = position
	Sounds.Play(cue, anchor)
	Debris:AddItem(anchor, 3)
end

local function stop(id, position, radius, touched)
	local shot = flying[id]
	if not shot then
		return
	end
	flying[id] = nil
	local look = shot.look
	if shot.flight then
		shot.flight:Cancel()
	else
		shot.connection:Disconnect()
		shot.model:Destroy()
	end
	if not touched then
		return -- it ran out of range in the open air
	end
	if shot.flight then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local ground = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -9, 0), params)
		FireballVFX.explode(if ground then ground.Position else position, { color = look.Color, scale = look.BlastScale })
		if (workspace.CurrentCamera.CFrame.Position - position).Magnitude < 80 then
			Effects.Shake(0.5, 0.2) -- the jolt of the hit
		end
	elseif radius or look.Burst then
		burst(position, radius or look.Burst, look.Color)
	end
	if look.Cue then
		soundAt(look.Cue, position)
	end
end

local function area(lookName, position, radius, delay, hits, interval)
	local look = Config[lookName]
	if not look then
		return
	end
	-- a faint circle on the ground shows where it will land
	local disc = part(workspace, Vector3.new(0.15, radius * 2, radius * 2), look.Color, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Transparency = 1
	TweenService:Create(disc, TweenInfo.new(0.25), { Transparency = 0.75 }):Play()
	local ends = delay + (hits - 1) * interval + 0.1
	task.delay(ends, function()
		TweenService:Create(disc, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(disc, ends + 0.4)

	if look.Kind == "Meteor" then
		task.delay(math.max(delay - look.FallSeconds, 0), function()
			local rock = part(workspace, Vector3.one * look.Size, look.Color, Enum.Material.Neon, Enum.PartType.Ball)
			rock.Position = position + Vector3.new(look.Height * 0.4, look.Height, 0)
			local flames = Instance.new("ParticleEmitter")
			flames.Texture = "rbxasset://textures/particles/fire_main.dds"
			flames.Color = ColorSequence.new(look.Color)
			flames.LightEmission = 1
			flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, look.Size), NumberSequenceKeypoint.new(1, 0) })
			flames.Lifetime = NumberRange.new(0.3, 0.6)
			flames.Speed = NumberRange.new(1, 4)
			flames.Rate = 80
			flames.Parent = rock
			trail(rock, look.Size * 0.9, look.Color, 0.35)
			TweenService:Create(rock, TweenInfo.new(look.FallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = position + Vector3.new(0, look.Size * 0.3, 0) }):Play()
			task.delay(look.FallSeconds, function()
				burst(rock.Position, radius, look.Color)
				Effects.Cracks(position, 12, radius, look.Color)
				local camera = workspace.CurrentCamera
				if (camera.CFrame.Position - position).Magnitude < 90 then
					Effects.Shake(0.9, 0.4)
				end
				Sounds.Play(look.Cue, rock)
				rock.Transparency = 1
				flames.Enabled = false
				Debris:AddItem(rock, 3)
			end)
		end)
		return
	end

	for i = 1, hits do -- a shower of arrows landing with each hit
		task.delay(math.max(delay + (i - 1) * interval - look.FallSeconds, 0), function()
			for n = 1, look.PerHit do
				local angle, distance = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * radius
				local landing = position + Vector3.new(math.cos(angle) * distance, 0.8, math.sin(angle) * distance)
				local shaft = part(workspace, Vector3.new(0.14, 2.6, 0.14), look.Color, Enum.Material.Neon)
				local lean = Vector3.new(0.25, 1, 0).Unit
				shaft.CFrame = CFrame.fromMatrix(landing + lean * look.Height, lean:Cross(Vector3.zAxis).Unit, lean)
				local fall = TweenService:Create(shaft, TweenInfo.new(look.FallSeconds * rng:NextNumber(0.85, 1.15), Enum.EasingStyle.Linear), { CFrame = shaft.CFrame - lean * look.Height })
				fall:Play()
				fall.Completed:Once(function()
					if n % 4 == 0 then
						Effects.Puff(landing, 1.5)
					end
					TweenService:Create(shaft, TweenInfo.new(0.35), { Transparency = 1 }):Play()
				end)
				Debris:AddItem(shaft, 1.2)
			end
			task.delay(look.FallSeconds, Sounds.Play, look.Cue, disc)
		end)
	end
end

task.spawn(function()
	ReplicatedStorage:WaitForChild("Projectile", math.huge).OnClientEvent:Connect(function(what, ...)
		if what == "Charge" then
			charge(...)
		elseif what == "Fire" then
			fire(...)
		elseif what == "Stop" then
			stop(...)
		elseif what == "Area" then
			area(...)
		end
	end)
end)

return true
