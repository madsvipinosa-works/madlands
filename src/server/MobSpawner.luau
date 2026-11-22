-- Spawns mobs from Config/Mobs and runs their AI. Server only.
-- shortcut: mobs walk straight at the target with MoveTo (no pathfinding), so walls block them; upgrade with PathfindingService when zones have terrain.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mobs = require(ReplicatedStorage.Shared.Config.Mobs)
local PlayerData = require(script.Parent.PlayerData)

local rng = Random.new()
local active = {} -- [model] = state

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- A hinge the client can swing (client/MobAnimation). Phase +1/-1 makes diagonal legs move together, like a trot.
local function hinge(part0, part1, c0, c1, name, role, phase)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0, motor.Part1 = part0, part1
	motor.C0, motor.C1 = c0, c1
	motor:SetAttribute("Role", role)
	motor:SetAttribute("Phase", phase)
	motor.Parent = part0
end

-- Builds the mob from the imported mesh model in ServerStorage.Models (saved from Studio as assets/models/<Look.Model>.rbxm).
-- Returns nil if that model has not been added yet.
local function buildModel(name, def, position)
	local look = def.Look
	local models = ServerStorage:FindFirstChild("Models")
	local template = models and models:FindFirstChild(look.Model)
	if not (template and template:IsA("Model")) then
		warn(`[Mob] ServerStorage.Models.{look.Model} not found: import the mesh and save it as assets/models/{look.Model}.rbxm`)
		return nil
	end

	local meshes = template:Clone()
	local extents = meshes:GetExtentsSize()
	-- The importer's scale is unknown, so size it: by height for upright mobs, by length for animals.
	meshes:ScaleTo(if look.TargetHeight then look.TargetHeight / extents.Y else look.TargetLength / math.max(extents.X, extents.Z))
	meshes.PrimaryPart = meshes:FindFirstChild("Torso", true)
	local boxCFrame, boxSize = meshes:GetBoundingBox()

	local model = Instance.new("Model")
	model.Name = name

	-- The root is the invisible combat hitbox, at the center of the mesh box.
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = look.BodySize
	root.Transparency = 1
	root.CollisionGroup = "Mobs" -- dashing players pass through it
	root.Position = position
	root.Parent = model

	local yaw = CFrame.Angles(0, math.rad(look.YawDegrees), 0)
	local byName = {}
	for _, part in meshes:GetDescendants() do
		if part:IsA("MeshPart") then
			part.CFrame = root.CFrame * yaw * boxCFrame:ToObjectSpace(part.CFrame)
			part.Anchored = false
			part.CanCollide = false -- no collision and no mass, so it never changes how the mob moves
			part.Massless = true
			local style = look.Colors[part.Name] or look.Colors.Default
			part.Color = style.Color
			part.Material = Enum.Material[style.Material]
			part.Parent = model
			byName[part.Name] = part
		end
	end
	meshes:Destroy()

	-- The torso hangs on a "Body" hinge so the whole upper body can bob and rock while walking.
	-- Legs hang from the top of their mesh and the tail from its top, both attached to the torso. Everything else is rigid.
	local torso = byName.Torso
	hinge(root, torso, root.CFrame:ToObjectSpace(torso.CFrame), CFrame.new(), "Torso_Body", "Body", 1)
	local moving = { [torso] = true }
	local function addHinge(partName, role, phase, pivot)
		local part = byName[partName]
		if part then
			local c1 = CFrame.new(0, (if pivot == "Bottom" then -1 else 1) * part.Size.Y / 2, 0) -- hung from its top, or its bottom (a head)
			hinge(torso, part, torso.CFrame:ToObjectSpace(part.CFrame * c1), c1, partName .. "_" .. role, role, phase)
			moving[part] = true
		end
	end
	for legName, phase in look.Legs do
		addHinge(legName, "Hip", phase)
	end
	for armName, phase in look.Arms or {} do
		addHinge(armName, if armName == look.ClubArm then "ClubArm" else "Arm", phase)
	end
	if look.Tail then
		addHinge(look.Tail, "Tail", 1)
	end
	if look.Head then
		addHinge(look.Head.Part, "Neck", 1, look.Head.Pivot)
	end

	-- Pieces that ride along with a moving one are welded to it; everything else is fixed to the torso.
	local function attach(carrierName, followerNames)
		local carrier = byName[carrierName]
		for _, partName in followerNames do
			local part = byName[partName]
			if part and carrier then
				weld(carrier, part)
				moving[part] = true -- already joined, so the torso loop below skips it
			end
		end
	end
	if look.Head then
		attach(look.Head.Part, look.Head.Follows) -- the head group rides on the neck
		local skull = look.Skull and byName[look.Skull.Part]
		if skull then -- the head has its own joint on the neck, so it can move separately
			local joint = skull.CFrame * CFrame.new(look.Skull.Pivot)
			hinge(byName[look.Head.Part], skull, byName[look.Head.Part].CFrame:ToObjectSpace(joint), skull.CFrame:ToObjectSpace(joint), "Skull", "Skull", 1)
			moving[skull] = true
			attach(look.Skull.Part, look.Skull.Follows)
		end
	end
	for carrierName, followerNames in look.Attach or {} do
		attach(carrierName, followerNames)
	end
	for _, part in byName do
		if not moving[part] then
			weld(torso, part)
		end
	end
	local motorCount = 0
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") then
			motorCount += 1
		end
	end
	model:SetAttribute("MotorCount", motorCount) -- the client waits for this many hinges before animating

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false -- keep the body in one piece for CorpseSeconds
	humanoid.HipHeight = math.max(0, boxSize.Y / 2 - look.BodySize.Y / 2) -- feet touch the ground
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
	PlayerData.AddGold(player, gold)
	local levels = PlayerData.AddXp(player, def.Xp)
	print(`[Mob] {player.Name} killed {model.Name}: +{gold} gold, +{def.Xp} XP (Gold {data.Gold}, Level {data.Level}, XP {data.Xp}){levels > 0 and " LEVEL UP" or ""}`)
end

local function spawnMob(name, def, position)
	local model, humanoid, root = buildModel(name, def, position)
	if not model then
		return
	end
	local state = { def = def, humanoid = humanoid, root = root, home = position, lastAttack = 0, returning = false }
	active[model] = state
	print(`[Mob] {name} spawned at {position}, size {model:GetExtentsSize()}, yaw {def.Look.YawDegrees}`)

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
			s.root.Parent:SetAttribute("BiteAt", workspace:GetServerTimeNow()) -- clients animate the bite or club swing
			local function strike(damage)
				targetHumanoid:TakeDamage(damage or def.Damage)
			end
			if def.AttackDelays then -- a flurry: each blow counts when its club lands, if the target is still close
				for blow, delay in def.AttackDelays do
					task.delay(delay, function()
						if humanoid.Health > 0 and targetHumanoid.Health > 0 and (target.Position - s.root.Position).Magnitude <= def.AttackRange + 2 then
							strike(def.AttackDamages and def.AttackDamages[blow])
						end
					end)
				end
			else
				local bite = def.Look.Bite
				task.delay(if bite then bite.WindSeconds + bite.SnapSeconds else 0, function() -- the bite lands when the jaws snap shut
					if humanoid.Health > 0 and targetHumanoid.Health > 0 and (target.Position - s.root.Position).Magnitude <= def.AttackRange + 2 then
						strike()
					end
				end)
			end
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
