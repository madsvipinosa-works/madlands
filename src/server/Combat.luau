-- Server-side combat. The client only says "I swung" or "I pressed skill N"; the server decides everything else.
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
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
function handlers.Wave(player, character, root, skill)
	local direction = flatLook(root)
	local start = root.Position + direction * 2
	local wave = Instance.new("Part")
	wave.Name = "SlashWave"
	wave.Size = Vector3.new(skill.Width, 0.5, 1)
	wave.Color = Color3.fromRGB(225, 228, 238)
	wave.Material = Enum.Material.SmoothPlastic
	wave.Transparency = 0.3
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.Massless = true
	wave.CFrame = CFrame.lookAt(start, start + direction) * CFrame.Angles(0, 0, math.rad(35)) -- tilted, like a diagonal cut
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
	WeaponVisuals.ShowTrail(character, SwingAnimations[weapon.SwingAnimation].Duration)
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
	WeaponVisuals.ShowTrail(character, SwingAnimations[skill.Animation].Duration / skill.AnimationSpeed)
	handler(player, character, root, skill)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
	skillReady[player] = nil
end)

print("[Combat] ready: Swing, UseSkill")

return true
