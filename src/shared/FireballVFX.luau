--[[
	FireballVFX  (Legends of Madlands)
	Fireball skill for the basic wand: a charge-up at the wand tip, a flying fireball with a flame and smoke tail,
	and an explosion where it lands. Everything is built in code from Parts, Trails and ParticleEmitters, so no
	uploads are needed.

	MADLANDS CHANGE: made to match fireball_preview.gif. The charge-up is a warm-white orb gathering sparks (opts.glow
	sets its colour). The flying fireball is the hand-made comet mesh with a flame tail, and the burst is a flash, a
	starburst and the hand-made shockwave ring (opts.color sets the colour of the flames and sparks). The meshes are
	ReplicatedStorage.FireballMeshes, copied there by server/Combat from assets/models/Fireball.rbxm.

	SETUP
	  Put this ModuleScript in ReplicatedStorage. Play the effect on the client so it looks smooth.
	  When a player casts, fire a RemoteEvent so nearby players can play it too. Work out damage on the server.
	  This module only draws the effect. It never damages anything.

	WAND TIP
	  Add an Attachment named "Tip" to the crystal of the wand model (the glowing part at the top).
	  Pass the wand part, or that Attachment, as the source. If you pass a part without a "Tip" attachment,
	  the effect starts at the middle of the part.

	API
	  Fireball.cast(source, direction, opts?)   Charge, then launch. Returns a handle with :Cancel() and .Done.
	  Fireball.charge(source, opts?)            Only the charge-up. Returns a handle with :Release() and :Cancel().
	  Fireball.launch(source, direction, opts?) Only the flight and the explosion (no charge-up).
	  Fireball.explode(position, opts?)         Only the explosion. opts.normal is the surface direction.

	source     BasePart, Attachment, CFrame or Vector3. Where the fireball starts.
	direction  Vector3, or a function that returns a Vector3 when the fireball is released.
	           A function lets the fireball aim at where the camera points at the moment of release.

	OPTIONS (all optional)
	  color         Color3    main flame colour, default orange. Try a light blue for a frost version.
	  scale         number    overall size, default 1
	  speed         number    studs per second, default 75
	  range         number    max distance in studs, default 110
	  chargeTime    number    seconds, default 0.5. Use 0 to skip the charge-up.
	  gravity       number    downward pull in studs/s^2, default 0 (flies straight)
	  ignore        {Instance}  things the fireball flies through. Put the caster's character here.
	  explodeAtRange boolean  explode when the range runs out, default true
	  onHit         function  onHit(position, part, normal) runs on impact. Part is nil at the end of the range.

	WITH AN ANIMATION
	  Add a marker named "Cast" in the wand animation, then:

	  local Fireball = require(game.ReplicatedStorage.FireballVFX)
	  track:GetMarkerReachedSignal("Cast"):Connect(function()
	      Fireball.launch(wandCrystal, function() return mouse.Hit.Position - wandCrystal.Position end,
	          { ignore = { character }, onHit = function(pos, part) print("hit", part) end })
	  end)

	QUICK TEST (LocalScript in StarterPlayerScripts)
	  local F = require(game.ReplicatedStorage.FireballVFX)
	  local char = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
	  local root = char:WaitForChild("HumanoidRootPart")
	  task.wait(3)
	  F.cast(root.CFrame * CFrame.new(1.5, 1, -1.5), root.CFrame.LookVector, { ignore = { char } })
]]

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fireball = {}
Fireball.DefaultColor = Color3.fromRGB(255, 120, 25)

local WHITE = Color3.new(1, 1, 1)
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
Fireball.GlowColor = Color3.fromRGB(255, 228, 170)

-- helpers -------------------------------------------------------------------------------------

local function vfxFolder()
	local f = workspace:FindFirstChild("VFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "VFX"
		f.Parent = workspace
	end
	return f
end

local function newPart(name, size, cf, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = WHITE
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Transparency = transparency
	p.Parent = vfxFolder()
	return p
end

local function glowPart(name, diameter, cf, color, transparency)
	local p = newPart(name, Vector3.new(diameter, diameter, diameter), cf, transparency, Enum.PartType.Ball)
	p.Material = Enum.Material.Neon
	p.Color = color
	return p
end

local function emitterOn(parent, props)
	local e = Instance.new("ParticleEmitter")
	local anyE: any = e
	e.Enabled = false
	e.Rate = 0
	for k, v in props do
		anyE[k] = v
	end
	e.Parent = parent
	return e
end

local function seq(...)
	local pts = { ... }
	local kps = {}
	for i = 1, #pts, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(pts[i], pts[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function fireColors(color)
	-- bright core, then the main colour, then a dark ember red
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 200):Lerp(color, 0.15)),
		ColorSequenceKeypoint.new(0.35, color),
		ColorSequenceKeypoint.new(1, color:Lerp(Color3.fromRGB(70, 10, 5), 0.75)),
	})
end

local function toCFrame(source)
	local t = typeof(source)
	if t == "CFrame" then
		return source
	elseif t == "Vector3" then
		return CFrame.new(source)
	elseif t == "Instance" then
		if source:IsA("Attachment") then
			return source.WorldCFrame
		elseif source:IsA("BasePart") then
			local tip = source:FindFirstChild("Tip")
			if tip and tip:IsA("Attachment") then
				return tip.WorldCFrame
			end
			return source.CFrame
		end
	end
	return CFrame.new()
end

local function resolveDirection(direction, fromPos)
	local d = direction
	if typeof(d) == "function" then
		d = d()
	end
	if typeof(d) ~= "Vector3" or d.Magnitude < 0.001 then
		d = Vector3.new(0, 0, -1)
	end
	return d.Unit
end

-- CFrame at pos whose -Z axis points along dir. Safe when dir is straight up or down.
local function facing(pos, dir)
	local up = if math.abs(dir.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(pos, pos + dir, up)
end

local function fade(part, duration, goal)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, goal):Play()
end

-- the meshes ----------------------------------------------------------------------------------

local MESH_SCALE = 3 -- the flying fireball: about 2.5 studs wide and 7 long at scale 1
local RING_WIDTH = 15.5 -- studs across at scale 1: the shockwave ring of the burst when it has finished spreading

-- A fresh glowing copy of one of the hand-made meshes, `factor` times its saved size, and where it sits from the model's
-- pivot at that size. Nil if the meshes are not there.
local function meshCopy(name, factor)
	local model = ReplicatedStorage:FindFirstChild("FireballMeshes")
	local source = model and model:FindFirstChild(name, true)
	if not source then
		return nil
	end
	local p = source:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Neon
	p.Color = WHITE -- shows the mesh's own colours
	p.Size = source.Size * factor
	p.Parent = vfxFolder()
	return p, (source.Position - model:GetPivot().Position) * factor
end

-- the glow ------------------------------------------------------------------------------------

-- A soft round light drawn facing the camera: circles inside each other, fainter toward the edge, with a solid centre.
local function softGlow(parent, color, diameter, hollow)
	local board = Instance.new("BillboardGui")
	board.Adornee = parent
	board.Size = UDim2.fromScale(diameter, diameter) -- studs
	board.LightInfluence = 0
	for i, ring in { { 1, 0.95 }, { 0.78, 0.91 }, { 0.6, 0.85 }, { 0.45, 0.74 }, { 0.32, 0.5 }, { 0.2, 0 } } do
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(ring[1], ring[1])
		circle.BackgroundColor3 = color:Lerp(WHITE, if i >= 5 then 0.65 else 0.1)
		circle.BackgroundTransparency = ring[2]
		circle.BorderSizePixel = 0
		circle.ZIndex = i
		Instance.new("UICorner", circle).CornerRadius = UDim.new(0.5, 0)
		circle.Parent = if hollow and i >= 5 then nil else board
	end
	board.Parent = parent
	return board
end

-- A bright little centre with a soft halo, and sparks that drift in a cloud `spread` studs wide around it (left behind
-- when it moves). Returns the (unseen) core, the cloud part, the things to switch off at the end, and the halo.
local function glowWithSparks(cf, color, scale, spread, sparkRate, hollow)
	local core = glowPart("FireballCore", 0.4 * scale, cf, color, 1)
	local halo = softGlow(core, color, 2.6 * scale, hollow)
	local cloud = newPart("FireballSparks", Vector3.one * spread * scale, cf, 1, Enum.PartType.Ball)
	local sparks = emitterOn(cloud, {
		Texture = SPARK_TEXTURE,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(color:Lerp(WHITE, 0.5), color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 0.6 * scale), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = seq(0, 0, 0.7, 0.15, 1, 1),
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(0.3, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		Rate = sparkRate,
		LightEmission = 1,
		LightInfluence = 0,
	})
	sparks.Enabled = true
	sparks:Emit(5) -- there from the first frame, even on a very short cast

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10 * scale
	light.Brightness = 2
	light.Shadows = false
	light.Parent = core
	return core, cloud, { halo, sparks }, halo
end

-- charge-up -----------------------------------------------------------------------------------

function Fireball.charge(source, opts)
	local o = opts or {}
	local color = o.glow or Fireball.GlowColor
	local scale = o.scale or 1
	local chargeTime = o.chargeTime or 0.5

	local startCF = toCFrame(source)
	local cfFn = function()
		if typeof(source) == "Instance" and source.Parent then
			return toCFrame(source)
		end
		return startCF
	end

	local core, cloud, emitters, halo = glowWithSparks(startCF, color, scale, 3.2, 70)
	core.Color = color:Lerp(WHITE, 0.6)
	core.Transparency = 0 -- a solid orb grows in the middle of the glow

	local handle = { Done = false }
	local t0 = os.clock()
	local conn
	local function finish()
		if handle.Done then
			return
		end
		handle.Done = true
		conn:Disconnect()
		for _, e in emitters do
			e.Enabled = false
		end
		core.Transparency = 1
		Debris:AddItem(core, 0.6)
		Debris:AddItem(cloud, 0.6)
	end
	conn = RunService.Heartbeat:Connect(function()
		if handle.Done then
			return
		end
		local cf = cfFn()
		local a = if chargeTime > 0 then math.clamp((os.clock() - t0) / chargeTime, 0, 1) else 1
		local pulse = 1 + 0.1 * math.sin((os.clock() - t0) * 40)
		local d = (1.4 + 2.2 * a) * scale * pulse -- the glow swells as it gathers
		halo.Size = UDim2.fromScale(d, d)
		local orb = (0.25 + 0.85 * a) * scale * pulse
		core.Size = Vector3.new(orb, orb, orb)
		core.CFrame = cf
		cloud.CFrame = cf
	end)

	function handle:Release()
		finish()
	end
	function handle:Cancel()
		finish()
	end
	return handle
end

-- explosion -----------------------------------------------------------------------------------

function Fireball.explode(position, opts)
	local o = opts or {}
	local color = o.color or Fireball.DefaultColor
	local scale = o.scale or 1
	local normal = o.normal or Vector3.new(0, 1, 0)
	if normal.Magnitude < 0.001 then
		normal = Vector3.new(0, 1, 0)
	end
	normal = normal.Unit
	local pos = position + normal * 0.2

	-- the hit: a blinding flash that is gone in a blink
	local flashAt = newPart("FireballFlashLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + normal * 1.5), 1)
	local flare = softGlow(flashAt, Color3.fromRGB(255, 205, 120), 6 * scale)
	local quick = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flare, quick, { Size = UDim2.fromScale(17 * scale, 17 * scale) }):Play()
	for _, circle in flare:GetChildren() do
		TweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	end
	Debris:AddItem(flashAt, 0.3)
	local flash = glowPart("FireballFlash", 1.5 * scale, CFrame.new(pos + normal), Color3.fromRGB(255, 250, 230), 0)
	fade(flash, 0.1, { Size = Vector3.new(5 * scale, 5 * scale, 5 * scale), Transparency = 1 })
	Debris:AddItem(flash, 0.3)

	-- a starburst: sharp spikes of light thrown out of the point of the hit, which is what makes it read as an impact (the
	-- dome mesh is not used: even faint and quick it looked like a lump of lava)
	local rng = Random.new()
	for i = 1, 14 do
		local out = (normal * rng:NextNumber(0.1, 1.1) + rng:NextUnitVector()).Unit
		local length = rng:NextNumber(5, 9) * scale
		local from = facing(pos + normal * 0.8, out)
		local spike = newPart("FireballSpike", Vector3.new(0.5 * scale, 0.5 * scale, 1), from * CFrame.new(0, 0, -0.8), 0)
		spike.Material = Enum.Material.Neon
		spike.Color = if i % 2 == 0 then Color3.fromRGB(255, 245, 215) else color:Lerp(WHITE, 0.35)
		-- shoots outward, stretching, then thinning to nothing
		fade(spike, rng:NextNumber(0.13, 0.2), { Size = Vector3.new(0.05, 0.05, length * 0.5), CFrame = from * CFrame.new(0, 0, -length), Transparency = 0.6 })
		Debris:AddItem(spike, 0.22)
	end

	-- and the shockwave ring racing outward over the ground
	local upright = facing(pos, normal) * CFrame.Angles(math.rad(-90), 0, 0) -- its +Y points out of the surface
	local ring = meshCopy("Shockwave_Ring", 1)
	if ring then
		local width = RING_WIDTH * scale
		local full = Vector3.new(width, 0.35, width * ring.Size.Z / ring.Size.X)
		ring.Transparency = 0.15
		ring.Size = full * Vector3.new(0.15, 1, 0.15)
		ring.CFrame = upright * CFrame.new(0, 0.3, 0)
		fade(ring, 0.35, { Size = full, Transparency = 1 })
		Debris:AddItem(ring, 0.5)
	end

	local ringCF = facing(pos, normal) * CFrame.Angles(0, math.rad(90), 0)
	-- scorch mark that stays for a moment
	if normal.Y > 0.6 then
		local scorchCF = ringCF
		local scorch = newPart("FireballScorch", Vector3.new(0.05, 5 * scale, 5 * scale), scorchCF, 0.35, Enum.PartType.Cylinder)
		scorch.Color = Color3.fromRGB(28, 22, 20)
		task.delay(2.2, function()
			if scorch.Parent then
				fade(scorch, 1.2, { Transparency = 1 })
			end
		end)
		Debris:AddItem(scorch, 3.6)
	end

	local holder = newPart("FireballBurst", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), 1)
	Debris:AddItem(holder, 3)
	local att = Instance.new("Attachment")
	att.Parent = holder

	local fire = emitterOn(att, {
		Texture = FIRE_TEXTURE,
		Color = fireColors(color),
		Size = seq(0, 1.6 * scale, 0.35, 3.4 * scale, 1, 0.6 * scale),
		Transparency = seq(0, 0.15, 0.5, 0.55, 1, 1),
		Lifetime = NumberRange.new(0.22, 0.45),
		Speed = NumberRange.new(20 * scale, 38 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 8,
		Acceleration = Vector3.new(0, 6, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 1,
		LightInfluence = 0,
	})
	fire:Emit(24)

	local streaks = emitterOn(att, {
		Texture = SPARK_TEXTURE,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 225), color),
		Size = seq(0, 1.5 * scale, 1, 0.3 * scale),
		Squash = seq(0, 2.4, 1, 2.4), -- long and thin, along the way each one flies
		Transparency = seq(0, 0, 0.7, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.14, 0.28),
		Speed = NumberRange.new(45 * scale, 75 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		LightEmission = 1,
		LightInfluence = 0,
	})
	streaks:Emit(30)

	local sparks = emitterOn(att, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), color),
		Size = seq(0, 0.45 * scale, 1, 0),
		Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new(18 * scale, 42 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -45, 0),
		Drag = 1.5,
		LightEmission = 1,
		LightInfluence = 0,
	})
	sparks:Emit(34)

	local embers = emitterOn(att, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(color),
		Size = seq(0, 0.3 * scale, 1, 0),
		Transparency = seq(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(2, 7),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 7, 0),
		Drag = 1,
		LightEmission = 1,
		LightInfluence = 0,
	})
	embers:Emit(14)

	local smoke = emitterOn(att, {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(70, 62, 58), Color3.fromRGB(40, 36, 34)),
		Size = seq(0, 1.8 * scale, 1, 5.5 * scale),
		Transparency = seq(0, 0.6, 0.5, 0.8, 1, 1),
		Lifetime = NumberRange.new(1.2, 2.0),
		Speed = NumberRange.new(2, 7),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 2,
		Acceleration = Vector3.new(0, 5, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		LightEmission = 0,
		LightInfluence = 1,
	})
	task.delay(0.08, function()
		smoke:Emit(10)
	end)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 26 * scale
	light.Brightness = 7
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
end

-- flight --------------------------------------------------------------------------------------

-- The flying comet: the fireball mesh and the flames licking round it, inside a glow, shedding fire and sparks.
local function buildProjectile(startCF, color, scale)
	local core, cloud, emitters = glowWithSparks(startCF, color, scale * 1.7, 1.4, 80, true)
	local tail = emitterOn(core, {
		Texture = FIRE_TEXTURE,
		Color = fireColors(color),
		Size = seq(0, 2 * scale, 1, 0.2 * scale),
		Transparency = seq(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.1, 0.2),
		Speed = NumberRange.new(0, 2),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-150, 150),
		Rate = 150,
		LightEmission = 1,
		LightInfluence = 0,
	})
	tail.Enabled = true
	table.insert(emitters, tail)

	local head, headAt = meshCopy("Fireball_Core", MESH_SCALE * scale)
	local flames, flamesAt = meshCopy("Fireball_Flames", MESH_SCALE * scale)
	if flames then
		flames.Transparency = 0.3 -- so the bright core shows through
	end
	local t0 = os.clock()

	return {
		move = function(pos, velocity)
			core.CFrame = CFrame.new(pos)
			cloud.CFrame = CFrame.new(pos)
			local back = facing(pos, -velocity) -- the meshes' heads point along +Z, their tails trail along -Z
			if head then
				head.CFrame = back * CFrame.new(headAt)
			end
			if flames then
				flames.CFrame = back * CFrame.Angles(0, 0, (os.clock() - t0) * 14) * CFrame.new(flamesAt)
			end
		end,
		stop = function()
			for _, e in emitters do
				e.Enabled = false
			end
			for _, mesh in { head, flames } do -- fades away rather than blinking out
				fade(mesh, 0.15, { Transparency = 1, Size = mesh.Size * 0.4 })
				Debris:AddItem(mesh, 0.2)
			end
			Debris:AddItem(core, 0.8)
			Debris:AddItem(cloud, 0.8)
		end,
	}
end

function Fireball.launch(source, direction, opts)
	local o = opts or {}
	local color = o.color or Fireball.DefaultColor
	local scale = o.scale or 1
	local speed = o.speed or 75
	local range = o.range or 110
	local gravity = o.gravity or 0
	local explodeAtRange = o.explodeAtRange ~= false

	local startCF = toCFrame(source)
	local dir = resolveDirection(direction, startCF.Position)
	local pos = startCF.Position
	local vel = dir * speed

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignoreList = { vfxFolder() }
	if o.ignore then
		for _, inst in o.ignore do
			table.insert(ignoreList, inst)
		end
	end
	params.FilterDescendantsInstances = ignoreList

	local p = buildProjectile(CFrame.new(pos), color, scale)
	p.move(pos, vel)
	local handle = { Done = false }
	local travelled = 0
	local conn

	local function cleanup()
		if handle.Done then
			return
		end
		handle.Done = true
		conn:Disconnect()
		p.stop()
	end
	local function impact(position, part, normal)
		cleanup()
		Fireball.explode(position, { color = color, scale = scale, normal = normal })
		if o.onHit then
			task.spawn(o.onHit, position, part, normal)
		end
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		if handle.Done then
			return
		end
		vel = vel + Vector3.new(0, -gravity * dt, 0)
		local step = vel * dt
		local from = pos
		local result
		-- skip invisible, non-solid parts such as trigger zones
		for _ = 1, 4 do
			result = workspace:Raycast(from, step, params)
			if result and not result.Instance.CanCollide and result.Instance.Transparency > 0.9 then
				table.insert(ignoreList, result.Instance)
				params.FilterDescendantsInstances = ignoreList
			else
				break
			end
		end
		if result then
			pos = result.Position
			impact(result.Position, result.Instance, result.Normal)
			return
		end

		pos = pos + step
		travelled += step.Magnitude
		p.move(pos, vel)

		if travelled >= range then
			if explodeAtRange then
				impact(pos, nil, -vel.Unit)
			else
				cleanup()
				if o.onHit then
					task.spawn(o.onHit, pos, nil, -vel.Unit)
				end
			end
		end
	end)

	function handle:Cancel()
		cleanup()
	end
	return handle
end

-- charge, then launch -------------------------------------------------------------------------

function Fireball.cast(source, direction, opts)
	local o = opts or {}
	local chargeTime = o.chargeTime or 0.5
	local handle = { Done = false }
	local charge
	local flight
	local cancelled = false

	if chargeTime > 0 then
		charge = Fireball.charge(source, o)
	end
	task.delay(chargeTime, function()
		if cancelled then
			return
		end
		if charge then
			charge:Release()
		end
		-- launch from the wand tip's current position
		local startCF = toCFrame(source)
		flight = Fireball.launch(startCF, direction, o)
		handle.Flight = flight
	end)

	function handle:Cancel()
		cancelled = true
		handle.Done = true
		if charge then
			charge:Cancel()
		end
		if flight then
			flight:Cancel()
		end
	end
	return handle
end

return Fireball
