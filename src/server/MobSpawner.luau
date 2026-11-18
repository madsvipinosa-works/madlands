-- Spawns mobs from Config/Mobs and runs their AI. Server only.
-- shortcut: mobs walk straight at the target with MoveTo (no pathfinding), so walls block them; upgrade with PathfindingService when zones have terrain.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mobs = require(ReplicatedStorage.Shared.Config.Mobs)
local PlayerData = require(script.Parent.PlayerData)

local rng = Random.new()
local active = {} -- [model] = state

-- A decoration part welded to the body. No collision and no mass, so it never changes how the wolf moves.
local function addPart(model, root, class, name, size, color, offset, tiltDegrees)
	local part = Instance.new(class)
	part.Name = name
	part.Size = size
	part.Color = color
	part.CanCollide = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(offset) * CFrame.Angles(math.rad(tiltDegrees or 0), 0, 0)
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, part
	weld.Parent = part
	return part
end

local function buildModel(name, def, position)
	local look = def.Look
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = look.BodySize
	root.Color = look.BodyColor
	root.Position = position
	root.Parent = model

	addPart(model, root, "Part", "Belly", look.Belly.Size, look.Belly.Color, look.Belly.Offset)
	addPart(model, root, "Part", "Head", look.Head.Size, look.Head.Color, look.Head.Offset)
	addPart(model, root, "Part", "Snout", look.Snout.Size, look.Snout.Color, look.Snout.Offset)
	addPart(model, root, "Part", "Tail", look.Tail.Size, look.Tail.Color, look.Tail.Offset, look.Tail.TiltDegrees)
	for _, side in { -1, 1 } do
		local ear = look.Ear
		local offset = Vector3.new(ear.Offset.X * side, ear.Offset.Y, ear.Offset.Z)
		addPart(model, root, "WedgePart", "Ear", ear.Size, ear.Color, offset)
	end

	-- Legs hang from the bottom of the body on Motor6D hinges; the client swings them (client/MobAnimation).
	-- Phase +1/-1 makes diagonal legs move together, like a trot.
	local leg = look.Leg
	for _, spec in { { "LegFL", -1, -1, 1 }, { "LegFR", 1, -1, -1 }, { "LegBL", -1, 1, -1 }, { "LegBR", 1, 1, 1 } } do
		local hip = Vector3.new(spec[2] * leg.XOffset, -look.BodySize.Y / 2, spec[3] * leg.ZOffset)
		local part = addPart(model, root, "Part", spec[1], leg.Size, leg.Color, hip - Vector3.new(0, leg.Size.Y / 2, 0))
		part:FindFirstChildOfClass("WeldConstraint"):Destroy() -- replaced by the hinge below
		local motor = Instance.new("Motor6D")
		motor.Name = spec[1]
		motor.Part0, motor.Part1 = root, part
		motor.C0 = CFrame.new(hip)
		motor.C1 = CFrame.new(0, leg.Size.Y / 2, 0)
		motor:SetAttribute("Phase", spec[4])
		motor.Parent = root
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false -- keep the body in one piece for CorpseSeconds
	humanoid.HipHeight = leg.Size.Y
	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.DisplayName = name
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = workspace
	CollectionService:AddTag(model, "WalkingMob") -- tells clients to swing its legs
	root:SetNetworkOwner(nil) -- the server moves it, not a player's client
	return model, humanoid, root
end

-- Gives the last player who hit the mob its gold and XP.
local function reward(def, model)
	local userId = model:GetAttribute("LastHitBy")
	local player = userId and Players:GetPlayerByUserId(userId)
	local data = player and PlayerData.Get(player)
	if not data then
		return
	end
	local gold = rng:NextInteger(def.GoldMin, def.GoldMax)
	data.Gold += gold
	data.Xp += def.Xp
	print(`[Mob] {player.Name} killed {model.Name}: +{gold} gold, +{def.Xp} XP (Gold {data.Gold}, XP {data.Xp})`)
end

local function spawnMob(name, def, position)
	local model, humanoid, root = buildModel(name, def, position)
	local state = { def = def, humanoid = humanoid, root = root, home = position, lastAttack = 0, returning = false }
	active[model] = state
	print(`[Mob] {name} spawned at {position}`)

	humanoid.Died:Once(function()
		active[model] = nil
		reward(def, model)
		task.delay(def.CorpseSeconds, model.Destroy, model)
		task.delay(def.RespawnSeconds, spawnMob, name, def, position)
	end)
end

local function step(s)
	local def, humanoid = s.def, s.humanoid
	local pos = s.root.Position
	local homeDistance = (pos - s.home).Magnitude

	-- Too far from home: walk back and ignore players until it arrives.
	if homeDistance > def.LeashRange then
		s.returning = true
	elseif s.returning and homeDistance < 5 then
		s.returning = false
	end
	if s.returning then
		humanoid:MoveTo(s.home)
		return
	end

	local target, targetHumanoid, targetDistance
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		local h = character and character:FindFirstChildOfClass("Humanoid")
		if targetRoot and h and h.Health > 0 then
			local d = (targetRoot.Position - pos).Magnitude
			if d <= def.AggroRange and (not targetDistance or d < targetDistance) then
				target, targetHumanoid, targetDistance = targetRoot, h, d
			end
		end
	end

	if not target then
		humanoid:MoveTo(s.home)
	elseif targetDistance <= def.AttackRange then
		humanoid:MoveTo(pos) -- stand still and bite
		local now = os.clock()
		if now - s.lastAttack >= def.AttackCooldown then
			s.lastAttack = now
			targetHumanoid:TakeDamage(def.Damage)
		end
	else
		humanoid:MoveTo(target.Position)
	end
end

for name, def in Mobs do
	for _, position in def.Spawns do
		spawnMob(name, def, position)
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		for _, state in active do
			step(state)
		end
	end
end)

return true
