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
local waveRemote = makeRemote("WaveFired") -- server -> every client: draw a wave (shooter, start, direction, speed, range)

-- Clients draw the Wave slash themselves, so they need its mesh; ServerStorage is not visible to them.
local waveModel = ServerStorage:FindFirstChild("Models") and ServerStorage.Models:FindFirstChild(EffectStyle.Wave.Model)
if waveModel then
	local copy = waveModel:Clone()
	copy.Name = "WaveSlash"
	copy.Parent = ReplicatedStorage
else
	warn(`[Combat] ServerStorage.Models.{EffectStyle.Wave.Model} not found: Wave Slash will have no visual`)
end

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
	task.delay(skill.HitDelay, function()
		if root.Parent then
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
	-- The hit lands as the blade crosses in front of you (HitDelay), not the instant you click.
	task.delay(swing.HitDelay or 0, function()
		if root.Parent then
			hitArc(player, character, root, weapon.Damage, weapon.Range, weapon.ArcDegrees)
		end
	end)
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
	WeaponVisuals.ShowTrail(character, move.TrailStart / skill.AnimationSpeed, move.TrailSeconds / skill.AnimationSpeed, skill.Trail)
	handler(player, character, root, skill)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
	skillReady[player] = nil
	combo[player] = nil
end)

print("[Combat] ready: Swing, UseSkill")

return true
