-- Server-side combat. The client only says "I swung" or "I pressed skill N"; the server decides everything else.
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local EffectStyle = require(ReplicatedStorage.Shared.Config.Effects)
local SwingAnimations = require(ReplicatedStorage.Shared.Config.SwingAnimations)
local DashConfig = require(ReplicatedStorage.Shared.Config.Dash)
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
local dashRemote = makeRemote("DashStep") -- client -> server: "I pressed E"
local waveRemote = makeRemote("WaveFired") -- server -> every client: draw a wave (shooter, start, direction, speed, range)
local projectileRemote = makeRemote("Projectile") -- server -> every client: draw arrows, spells and where they land

-- Clients draw the Wave slash themselves, so they need its mesh; ServerStorage is not visible to them.
local waveModel = ServerStorage:FindFirstChild("Models") and ServerStorage.Models:FindFirstChild(EffectStyle.Wave.Model)
if waveModel then
	local copy = waveModel:Clone()
	copy.Name = "WaveSlash"
	copy.Parent = ReplicatedStorage
else
	warn(`[Combat] ServerStorage.Models.{EffectStyle.Wave.Model} not found: Wave Slash will have no visual`)
end

-- The Fireball's meshes too (assets/models/Fireball.rbxm), for shared/FireballVFX.
local fireModel = ServerStorage:FindFirstChild("Models") and ServerStorage.Models:FindFirstChild("Fireball")
if fireModel then
	local copy = fireModel:Clone()
	copy.Name = "FireballMeshes"
	copy.Parent = ReplicatedStorage
else
	warn("[Combat] ServerStorage.Models.Fireball not found: the Fireball will be drawn without its meshes")
end

-- A dashing player passes through mobs ("Mobs" is set on each mob's body in MobSpawner).
PhysicsService:RegisterCollisionGroup("Dashing")
PhysicsService:RegisterCollisionGroup("Mobs")
PhysicsService:CollisionGroupSetCollidable("Dashing", "Mobs", false)

local dashReady = {} -- [player] = os.clock() when the E dash can be used again
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

-- Hits a mob once. Only mobs can be hurt: not villagers, and not players until the PvP rules exist (build step 8).
local function hitModel(player, character, model, damage, seen)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if
		not humanoid
		or seen[model]
		or model == character
		or not CollectionService:HasTag(model, "WalkingMob") -- MobSpawner tags every mob
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

-- Holds the player to a velocity for a short time. `configure(mover)` sets the velocity (built here from config,
-- never from the client).
local function pushWith(root, seconds, configure)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = 1e7
	configure(mover)
	mover.Parent = root
	Debris:AddItem(mover, seconds)
	Debris:AddItem(attachment, seconds)
	return mover
end

local function push(root, velocity, seconds)
	pushWith(root, seconds, function(mover)
		mover.VectorVelocity = velocity
	end)
end

local function flatLook(root)
	return (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
end

-- Which way a ranged attack goes: flat, toward the point the player's mouse is on. The client sends that point, so anything
-- that is not a sensible point falls back to the way they face.
local function aimOf(root, aim)
	if typeof(aim) == "Vector3" then
		local to = (aim - root.Position) * Vector3.new(1, 0, 1)
		if to.Magnitude > 0.5 and to.Magnitude < 10000 then -- (false for NaN and infinity too)
			return to.Unit, aim
		end
	end
	return flatLook(root), nil
end

local function standing(character, root)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0
end

-- Damages every mob within `radius` of a spot on the ground.
local function hitRadius(player, character, position, radius, damage, seen)
	for _, model in CollectionService:GetTagged("WalkingMob") do
		local body = model:FindFirstChild("HumanoidRootPart")
		if body then
			local offset = body.Position - position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + body.Size.X / 2 and math.abs(offset.Y) <= 10 then
				hitModel(player, character, model, damage, seen)
			end
		end
	end
end

-- How far a shot can fly before something solid is in the way (a wall, a trunk, the cliff). Mobs and players do not count.
local function clearDistance(start, direction, range)
	local ignore = CollectionService:GetTagged("WalkingMob")
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(start, direction * range, params)
	return if hit then hit.Distance else range
end

-- The living mob in a box that is closest to where the shot started.
local function firstMob(cframe, size, start, direction)
	local best, bestAlong = nil, math.huge
	for _, part in workspace:GetPartBoundsInBox(cframe, size) do
		local model = part.Parent
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local body = model and model:FindFirstChild("HumanoidRootPart")
		if humanoid and body and humanoid.Health > 0 and CollectionService:HasTag(model, "WalkingMob") then
			local along = (body.Position - start):Dot(direction)
			if along < bestAlong then
				best, bestAlong = model, along
			end
		end
	end
	return best
end

-- An arrow or spell flying straight. The server moves only a hit box; every client draws the shot (client/Projectiles).
-- spec: Speed, Range, Width, Damage, Look; Pierce = goes through mobs; Radius = bursts where it stops.
local shots = 0
local function shoot(player, character, root, direction, spec)
	local start = root.Position + Vector3.new(0, 0.5, 0)
	local range = clearDistance(start, direction, spec.Range)
	local blocked = range < spec.Range -- something solid is in the way, so the shot ends against it
	shots += 1
	local id = shots
	projectileRemote:FireAllClients("Fire", id, spec.Look, start, direction, spec.Speed, range, character)

	local seen, startedAt, last = {}, os.clock(), 0
	local connection
	-- touched: it ran into a mob or something solid. A shot that just reaches the end of its range fades out: no burst.
	local function finish(position, touched)
		connection:Disconnect()
		if touched and spec.Radius then
			hitRadius(player, character, position, spec.Radius, spec.Damage, seen)
		end
		projectileRemote:FireAllClients("Stop", id, position, spec.Radius, touched)
	end
	connection = RunService.Heartbeat:Connect(function()
		local traveled = math.min(spec.Speed * (os.clock() - startedAt), range)
		-- the box covers the whole stretch flown since the last check, so a fast shot cannot jump over a mob
		local middle = start + direction * ((last + traveled) / 2)
		local box = CFrame.lookAt(middle, middle + direction)
		local size = Vector3.new(spec.Width, 7, traveled - last + 1)
		if spec.Pierce then
			hitBox(player, character, box, size, spec.Damage, seen)
		else
			local mob = firstMob(box, size, start, direction)
			if mob then
				local at = mob.HumanoidRootPart.Position
				if not spec.Radius then
					hitModel(player, character, mob, spec.Damage, seen)
				end
				finish(at, true)
				return
			end
		end
		last = traveled
		if traveled >= range then
			finish(start + direction * range, blocked)
		end
	end)
end

local spawnWave -- defined below, after the handlers that use it

-- One handler per skill Type in Config/Skills.
local handlers = {}

-- Dash: rush forward and cut everything in the path.
function handlers.Dash(player, character, root, skill, direction)
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
	if skill.Brake then -- stop where the dash ends, instead of sliding on with its speed
		task.delay(skill.DashTime, function()
			pushWith(root, 0.12, function(mover)
				mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
				mover.PrimaryTangentAxis = Vector3.xAxis
				mover.SecondaryTangentAxis = Vector3.zAxis
				mover.PlaneVelocity = Vector2.zero
			end)
		end)
	end
	task.delay(skill.HitDelay, function()
		local length = skill.DashDistance + 4
		local middle = start + direction * (length / 2)
		hitBox(player, character, CFrame.lookAt(middle, middle + direction), Vector3.new(skill.Width, 7, length), skill.Damage, {})
	end)
end

-- Jump: crouch, leap up and forward, then slam the ground in front of you when you land.
function handlers.Jump(player, character, root, skill)
	local direction = flatLook(root)
	task.delay(skill.JumpDelay or 0, function() -- the crouch before the leap
		if not root.Parent then
			return
		end
		-- Up and forward are pushed separately: the upward push is short, the forward one lasts through the leap,
		-- and neither holds the other back.
		pushWith(root, skill.JumpTime, function(mover)
			mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
			mover.LineDirection = Vector3.yAxis
			mover.LineVelocity = skill.JumpSpeed
		end)
		pushWith(root, skill.ForwardTime, function(mover)
			mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			mover.PrimaryTangentAxis = Vector3.xAxis
			mover.SecondaryTangentAxis = Vector3.zAxis
			mover.PlaneVelocity = Vector2.new(direction.X * skill.Forward, direction.Z * skill.Forward)
		end)
		-- At the top, a short beat, then dive: ordinary gravity makes the way down slow and floaty.
		local gravity = workspace.Gravity
		task.delay(skill.JumpTime + skill.JumpSpeed / gravity + skill.DiveHang, function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not (root.Parent and humanoid) then
				return
			end
			-- A strong extra downward force, like heavy gravity: you drop fast and the ground stops you the normal way.
			-- (Holding a fixed speed instead drives you into the ground and the physics fires you back up.)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -300, 0), params)
			local fall = if hit then hit.Distance - humanoid.HipHeight - root.Size.Y / 2 else 0 -- how far the body still has to drop
			local seconds = math.sqrt(2 * math.max(fall, 0) / (gravity + skill.DiveAccel)) + 0.06 -- the fall, plus a moment
			local attachment = Instance.new("Attachment")
			attachment.Parent = root
			local force = Instance.new("VectorForce")
			force.Attachment0 = attachment
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.ApplyAtCenterOfMass = true
			force.Force = Vector3.new(0, -root.AssemblyMass * skill.DiveAccel, 0)
			force.Parent = root
			Debris:AddItem(force, seconds)
			Debris:AddItem(attachment, seconds)
		end)
	end)
	-- The slam counts when you are back on the ground (when the effect plays), not on a fixed timer alone: a slope or the
	-- network delay moves the landing. Watching starts a little before the flat-ground landing time.
	task.delay(skill.HitDelay - 0.08, function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local deadline = os.clock() + 0.08 + skill.LandWait
		while root.Parent and humanoid and os.clock() < deadline and not workspace:Raycast(root.Position, Vector3.new(0, -(humanoid.HipHeight + root.Size.Y / 2 + 1.5), 0), params) do
			RunService.Heartbeat:Wait()
		end
		if root.Parent and humanoid and humanoid.Health > 0 then
			hitArc(player, character, root, skill.Damage, skill.Range, skill.ArcDegrees)
		end
	end)
end

-- Wave: a slash that flies straight ahead and cuts every mob it passes through.
-- The server only moves an invisible hit box along the path; every client draws the slash itself (client/Effects.Wave).
function handlers.Wave(player, character, root, skill)
	local move = SwingAnimations[skill.Animation]
	task.delay((move.Release or move.TrailStart) / skill.AnimationSpeed, function()
		if root.Parent then
			spawnWave(player, character, root, skill)
		end
	end)
end

function spawnWave(player, character, root, skill)
	local style = EffectStyle.Wave
	local direction = flatLook(root)
	local start = root.Position + direction * style.SpawnForward + Vector3.new(0, style.SpawnHeight, 0)
	waveRemote:FireAllClients(player, start, direction, skill.Speed, skill.Range)

	local seen, startedAt, last = {}, os.clock(), 0
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local traveled = math.min(skill.Speed * (os.clock() - startedAt), skill.Range)
		-- The box covers the whole stretch flown since the last check (plus a little), so a fast wave or a laggy
		-- server frame cannot jump over a mob.
		local middle = start + direction * ((last + traveled) / 2)
		hitBox(player, character, CFrame.lookAt(middle, middle + direction), Vector3.new(skill.Width, 7, traveled - last + 4), skill.Damage, seen)
		last = traveled
		if traveled >= skill.Range then
			connection:Disconnect()
		end
	end)
end

-- Arc: hit everything in a front arc (360 = all around you), after an optional delay. A skill can hit several times
-- (Hits, HitInterval seconds apart), like a spin that cuts every mob around you again and again.
function handlers.Arc(player, character, root, skill)
	for i = 1, skill.Hits or 1 do
		task.delay((skill.HitDelay or 0) + (i - 1) * (skill.HitInterval or 0), function()
			if root.Parent then
				hitArc(player, character, root, skill.Damage, skill.Range, skill.ArcDegrees)
			end
		end)
	end
end

-- Shot: one projectile, or Count of them in a fan Spread degrees wide; Recoil pushes you back as you fire.
function handlers.Shot(player, character, root, skill, direction)
	if skill.Delay then -- every client may draw a wind-up on the weapon while it lasts
		projectileRemote:FireAllClients("Charge", character, skill.Look, skill.Delay)
	end
	task.delay(skill.Delay or 0, function()
		if not standing(character, root) then
			return
		end
		local count = skill.Count or 1
		for i = 1, count do
			local turn = if count > 1 then math.rad(skill.Spread) * ((i - 1) / (count - 1) - 0.5) else 0
			shoot(player, character, root, CFrame.Angles(0, turn, 0):VectorToWorldSpace(direction), skill)
		end
	end)
	if skill.Recoil then
		push(root, -direction * (skill.Recoil.Distance / skill.Recoil.Time), skill.Recoil.Time)
	end
end

-- Rain: strikes a circle where the player points, no farther than CastRange, once or several times.
function handlers.Rain(player, character, root, skill, direction, aim)
	local to = if aim then (aim - root.Position) * Vector3.new(1, 0, 1) else direction * skill.CastRange
	if to.Magnitude > skill.CastRange then
		to = to.Unit * skill.CastRange
	end
	local spot = root.Position + to
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(spot + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	local position = if hit then hit.Position else spot - Vector3.new(0, 3, 0)
	projectileRemote:FireAllClients("Area", skill.Look, position, skill.Radius, skill.Delay, skill.Hits, skill.HitInterval or 0)
	for i = 1, skill.Hits do
		task.delay(skill.Delay + (i - 1) * (skill.HitInterval or 0), function()
			if character.Parent then
				hitRadius(player, character, position, skill.Radius, skill.Damage, {})
			end
		end)
	end
end

handlers.Nova = handlers.Arc
handlers.Blink = handlers.Dash

swingRemote.OnServerEvent:Connect(function(player, aim) -- the point the mouse is on; only aimed weapons use it
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
	-- The hit lands as the blade crosses in front of you (HitDelay), not the instant you click.
	local direction = if weapon.Aimed then aimOf(root, aim) else nil
	task.delay(swing.HitDelay or 0, function()
		if not root.Parent then
			return
		end
		if weapon.Projectile then
			if standing(character, root) then
				local spec = table.clone(weapon.Projectile)
				spec.Damage = weapon.Damage
				shoot(player, character, root, direction, spec)
			end
		else
			hitArc(player, character, root, weapon.Damage, weapon.Range, weapon.ArcDegrees)
		end
	end)
end)

skillRemote.OnServerEvent:Connect(function(player, slot, aim)
	if type(slot) ~= "number" then
		return
	end
	local data, weapon, character, root = getFighter(player)
	local skillId = weapon and weapon.Skills[slot] -- the slot maps to a skill of the equipped weapon only
	local skill = skillId and Skills[skillId]
	local handler = skill and handlers[skill.Type]
	if not (handler and skill.Weapon == data.Weapon and PlayerData.HasSkill(data, skillId)) then
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
	WeaponVisuals.ShowTrail(character, move.TrailStart / skill.AnimationSpeed, move.TrailSeconds / skill.AnimationSpeed, skill.Trail)
	local direction, point = flatLook(root), nil
	if weapon.Aimed then
		direction, point = aimOf(root, aim)
	end
	handler(player, character, root, skill, direction, point)
end)

-- The E dash, for every player: a short burst the way you are moving (or facing, if standing still).
dashRemote.OnServerEvent:Connect(function(player) -- extra arguments are ignored on purpose
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0) then
		return
	end
	local now = os.clock()
	if now < (dashReady[player] or 0) then
		return
	end
	dashReady[player] = now + DashConfig.Cooldown

	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	local direction = if move.Magnitude > 0.1 then move.Unit else flatLook(root)
	-- Speed falls off as 1 - progress^2: quick off the mark but steady through most of the roll, then a short brake. It covers
	-- Distance in Time exactly when it starts at 1.5 x Distance / Time. (A sharper (1 - progress)^2 fall-off put most of the
	-- distance into the first 0.08 s, which looked like a teleport.)
	local startSpeed = 1.5 * DashConfig.Distance / DashConfig.Time
	local mover = pushWith(root, DashConfig.Time, function(m)
		m.VectorVelocity = direction * startSpeed
	end)
	local startedAt = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local progress = (os.clock() - startedAt) / DashConfig.Time
		if progress >= 1 or not mover.Parent then
			connection:Disconnect()
			return
		end
		mover.VectorVelocity = direction * startSpeed * (1 - progress ^ 2)
	end)
	dashRemote:FireClient(player) -- the client draws the dash only when the server accepted it
end)

Players.PlayerRemoving:Connect(function(player)
	dashReady[player] = nil
	lastSwing[player] = nil
	skillReady[player] = nil
	combo[player] = nil
end)

print("[Combat] ready: Swing, UseSkill")

return true
