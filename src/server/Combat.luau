-- Server-side combat. The client only says "I swung" or "I pressed skill N"; the server decides everything else.
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local EffectStyle = require(ReplicatedStorage.Shared.Config.Effects)
local SwingAnimations = require(ReplicatedStorage.Shared.Config.SwingAnimations)
local PlayerData = require(script.Parent.PlayerData)
local WeaponVisuals = require(script.Parent.WeaponVisuals)

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end
local swingRemote = makeRemote("Swing")
local skillRemote = makeRemote("UseSkill") -- client -> server: skill slot number
local skillUsedRemote = makeRemote("SkillUsed") -- server -> client: slot and cooldown, so the bar shows the real cooldown

-- A dashing player passes through mobs ("Mobs" is set on each mob's body in MobSpawner).
PhysicsService:RegisterCollisionGroup("Dashing")
PhysicsService:RegisterCollisionGroup("Mobs")
PhysicsService:CollisionGroupSetCollidable("Dashing", "Mobs", false)

local lastSwing = {} -- [player] = os.clock() of last accepted swing
local combo = {} -- [player] = { index, expires }: which basic swing comes next
local skillReady = {} -- [player][skillId] = os.clock() when that skill can be used again

-- Returns the player's saved data, weapon, character and root part, or nil if they can't fight right now.
local function getFighter(player)
	local data = PlayerData.Get(player)
	local weapon = data and Weapons[data.Weapon] -- weapon comes from saved data, never from the client
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if weapon and root and humanoid and humanoid.Health > 0 then
		return data, weapon, character, root
	end
end

-- Hits a mob once. Players are skipped until the PvP rules exist (build step 8).
local function hitModel(player, character, model, damage, seen)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if
		not humanoid
		or seen[model]
		or model == character
		or Players:GetPlayerFromCharacter(model)
		or humanoid.Health <= 0
		or not model:FindFirstChild("HumanoidRootPart")
	then
		return false
	end
	seen[model] = true
	model:SetAttribute("LastHitBy", player.UserId) -- lets mobs reward the killer
	humanoid:TakeDamage(damage)
	print(`[Combat] {player.Name} hit {model.Name} for {damage}, health now {humanoid.Health}`)
	return true
end

-- Damages every mob inside a range and a front arc of the player.
local function hitArc(player, character, root, damage, range, arcDegrees)
	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local minDot = math.cos(math.rad(arcDegrees / 2))
	local seen = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, range) do
		local model = part.Parent
		local targetRoot = model and model:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local offset = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			if offset.Magnitude < 0.01 or forward:Dot(offset.Unit) >= minDot then
				hitModel(player, character, model, damage, seen)
			end
		end
	end
end

-- Damages every mob touching a box. `seen` lets a moving hit (a dash or a wave) hit each mob only once.
local function hitBox(player, character, cframe, size, damage, seen)
	for _, part in workspace:GetPartBoundsInBox(cframe, size) do
		hitModel(player, character, part.Parent, damage, seen)
	end
end

-- Pushes the player at a fixed velocity for a short time. The velocity is built here from config, not from the client.
local function push(root, velocity, seconds)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = 1e7
	mover.VectorVelocity = velocity
	mover.Parent = root
	Debris:AddItem(mover, seconds)
	Debris:AddItem(attachment, seconds)
end

local function flatLook(root)
	return (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
end

local spawnWave -- defined below, after the handlers that use it

-- One handler per skill Type in Config/Skills.
local handlers = {}

-- Dash: rush forward and cut everything in the path.
function handlers.Dash(player, character, root, skill)
	local direction = flatLook(root)
	local start = root.Position
	push(root, direction * (skill.DashDistance / skill.DashTime), skill.DashTime)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Dashing"
		end
	end
	task.delay(skill.DashTime, function()
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Default"
			end
		end
	end)
	task.delay(skill.HitDelay, function()
		local length = skill.DashDistance + 4
		local middle = start + direction * (length / 2)
		hitBox(player, character, CFrame.lookAt(middle, middle + direction), Vector3.new(skill.Width, 7, length), skill.Damage, {})
	end)
end

-- Jump: leap up and forward, then slam the ground in front of you when you land.
function handlers.Jump(player, character, root, skill)
	local direction = flatLook(root)
	push(root, Vector3.new(direction.X * skill.Forward, skill.JumpSpeed, direction.Z * skill.Forward), skill.JumpTime)
	task.delay(skill.HitDelay, function()
		if root.Parent then
			hitArc(player, character, root, skill.Damage, skill.Range, skill.ArcDegrees)
		end
	end)
end

-- Wave: a slash that flies straight ahead and cuts every mob it passes through.
-- The slash leaves the blade partway through the swing, so it looks cut out of the air, not thrown.
function handlers.Wave(player, character, root, skill)
	local style = EffectStyle.Wave
	task.delay(SwingAnimations[skill.Animation].TrailStart / skill.AnimationSpeed, function()
		if root.Parent then
			spawnWave(player, character, root, skill, style)
		end
	end)
end

function spawnWave(player, character, root, skill, style)
	local direction = flatLook(root)
	local start = root.Position + direction * style.SpawnForward + Vector3.new(0, style.SpawnHeight, 0)
	local wave = Instance.new("Part")
	wave.Name = "SlashWave"
	wave.Size = Vector3.new(0.2, 0.2, 0.2)
	wave.Transparency = 1 -- the crescent slices below do the showing; this part just carries them
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.Massless = true
	wave.CFrame = CFrame.lookAt(start, start + direction) * CFrame.Angles(0, 0, math.rad(style.TiltDegrees))

	-- A ready-made effect, if one is set up. It is welded on and flies with the wave.
	local models = ServerStorage:FindFirstChild("Models")
	local template = style.Model ~= "" and models and models:FindFirstChild(style.Model)
	if template then
		local visual = template:Clone()
		local rotation = style.ModelRotation
		local turn = CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		for _, item in visual:GetDescendants() do
			if item:IsA("WeldConstraint") or item:IsA("JointInstance") then
				item:Destroy() -- joints to parts that are not coming along
			elseif item:IsA("SpecialMesh") then
				item.Scale *= style.ModelScale
			end
		end
		for _, part in (if visual:IsA("BasePart") then { visual } else visual:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
				part.CFrame = wave.CFrame * CFrame.new(style.ModelOffset) * turn
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = wave, part
				weld.Parent = part
			end
		end
		visual.Parent = wave
	end

	-- Otherwise: thin slices laid along an arc. Each one is turned around a point behind the wave, so
	-- together they curve like a sword stroke, tallest in the middle and tapering to nothing at the tips.
	local halfArc = math.rad(style.ArcDegrees) / 2
	local sliceLength = (style.Radius * halfArc * 2 / style.Slices) * 1.2 -- a little overlap, so there are no gaps
	for i = 1, (if template then 0 else style.Slices) do
		local along = (i - 0.5) / style.Slices * 2 - 1 -- -1 at one tip, 1 at the other
		local taper = math.cos(along * math.pi / 2)
		local slice = Instance.new("Part")
		slice.Name = "WaveSlice"
		-- Upright: the slice spans sideways and the arc climbs. Flat: the slice stands up and the arc sweeps wide.
		slice.Size = if style.Upright
			then Vector3.new(style.Height * taper, style.Thickness, sliceLength)
			else Vector3.new(style.Thickness, style.Height * taper, sliceLength)
		slice.Color = style.Color
		slice.Material = Enum.Material.SmoothPlastic
		slice.Transparency = style.Transparency
		slice.CanCollide = false
		slice.CanQuery = false
		slice.CanTouch = false
		slice.Massless = true
		local turn = if style.Upright then CFrame.Angles(along * halfArc, 0, 0) else CFrame.Angles(0, along * halfArc, 0)
		slice.CFrame = wave.CFrame * CFrame.new(0, 0, style.Radius) * turn * CFrame.new(0, 0, -style.Radius)
		slice.Parent = wave
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = wave, slice
		weld.Parent = slice

		if i == 1 or i == style.Slices then -- the tips smear as the crescent flies
			local across = if style.Upright then Vector3.new(slice.Size.X / 2, 0, 0) else Vector3.new(0, slice.Size.Y / 2, 0)
			local top = Instance.new("Attachment")
			top.Position = across
			top.Parent = slice
			local bottom = Instance.new("Attachment")
			bottom.Position = -across
			bottom.Parent = slice
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = top, bottom
			trail.Color = ColorSequence.new(style.Color)
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
			trail.Lifetime = style.TrailLifetime
			trail.LightEmission = 0
			trail.FaceCamera = false
			trail.Parent = slice
		end
	end

	local attachment = Instance.new("Attachment")
	attachment.Parent = wave
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = 1e7
	mover.VectorVelocity = direction * skill.Speed
	mover.Parent = wave
	wave.Parent = workspace
	wave:SetNetworkOwner(nil)

	local seen, traveled = {}, 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		traveled += skill.Speed * dt
		if traveled >= skill.Range or not wave.Parent then
			connection:Disconnect()
			wave:Destroy()
			return
		end
		hitBox(player, character, CFrame.lookAt(wave.Position, wave.Position + direction), Vector3.new(skill.Width, 7, 4), skill.Damage, seen)
	end)
end

-- Arc: hit everything in a front arc (360 = all around you), after an optional delay.
function handlers.Arc(player, character, root, skill)
	task.delay(skill.HitDelay or 0, function()
		if root.Parent then
			hitArc(player, character, root, skill.Damage, skill.Range, skill.ArcDegrees)
		end
	end)
end

swingRemote.OnServerEvent:Connect(function(player) -- extra arguments are ignored on purpose
	local _, weapon, character, root = getFighter(player)
	if not weapon then
		return
	end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < weapon.Cooldown then
		return
	end
	lastSwing[player] = now

	-- Swings chain while you keep attacking, then start over.
	local chain = combo[player]
	local index = if chain and now < chain.expires then chain.index % #weapon.SwingCombo + 1 else 1
	combo[player] = { index = index, expires = now + weapon.ComboResetSeconds }

	swingRemote:FireClient(player, index) -- the client animates only what the server accepted
	local swing = SwingAnimations[weapon.SwingCombo[index]]
	WeaponVisuals.ShowTrail(character, swing.TrailStart, swing.TrailSeconds)
	hitArc(player, character, root, weapon.Damage, weapon.Range, weapon.ArcDegrees)
end)

skillRemote.OnServerEvent:Connect(function(player, slot)
	if type(slot) ~= "number" then
		return
	end
	local data, weapon, character, root = getFighter(player)
	local skillId = weapon and weapon.Skills[slot] -- the slot maps to a skill of the equipped weapon only
	local skill = skillId and Skills[skillId]
	local handler = skill and handlers[skill.Type]
	if not (handler and skill.Weapon == data.Weapon) then
		return
	end

	local now = os.clock()
	local ready = skillReady[player]
	if not ready then
		ready = {}
		skillReady[player] = ready
	end
	if now < (ready[skillId] or 0) then
		return
	end
	ready[skillId] = now + skill.Cooldown

	skillUsedRemote:FireClient(player, slot, skill.Cooldown)
	local move = SwingAnimations[skill.Animation]
	WeaponVisuals.ShowTrail(character, move.TrailStart / skill.AnimationSpeed, move.TrailSeconds / skill.AnimationSpeed)
	handler(player, character, root, skill)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
	skillReady[player] = nil
	combo[player] = nil
end)

print("[Combat] ready: Swing, UseSkill")

return true
