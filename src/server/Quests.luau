-- Quests (Config/Quests): the Village Chief who gives them, the kill count and the rewards. Server only: the client is only
-- told what to show. Progress is kept in the player's saved data (ProfileStore, through PlayerData). A player needs a weapon
-- (from the Weapon Master) before the chief will give them anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config.Quests)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local village = require(ReplicatedStorage.Shared.Config.Zones).OutsideZone1.Village
local Dialogue = require(script.Parent.Dialogue)
local PlayerData = require(script.Parent.PlayerData)

local chief = Config.Chief

local Quests = {}

-- The first quest the player has not finished, and their state in it (nil = not taken yet).
local function nextQuest(data)
	for _, quest in Config.List do
		local state = data.Quests[quest.Id]
		if not (state and state.Done) then
			return quest, state
		end
	end
	return nil
end

local function talk(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	if not Weapons[data.Weapon] then
		return { Lines = chief.NoWeapon }
	end
	local quest, state = nextQuest(data)
	if not quest then
		return { Lines = chief.NoMoreQuests }
	elseif not state then
		local lines = table.clone(quest.Offer)
		lines[#lines] ..= `\nReward: {quest.Reward.Gold} gold, {quest.Reward.Xp} XP`
		return { Lines = lines, Choices = { { Label = "Accept quest", Action = "Accept", Arg = quest.Id }, { Label = "Not now" } } }
	elseif state.Progress < quest.Count then
		return { Lines = { string.format(quest.Reminder, state.Progress, quest.Count) } }
	end
	return { Lines = quest.Ready, Choices = { { Label = "Claim reward", Action = "Claim", Arg = quest.Id } } }
end

local function accept(player, id)
	local data = PlayerData.Get(player)
	if not data or not Weapons[data.Weapon] then
		return nil
	end
	local quest, state = nextQuest(data)
	if not quest or quest.Id ~= id or state then
		return nil
	end
	data.Quests[quest.Id] = { Progress = 0 }
	PlayerData.Sync(player)
	return { Lines = quest.Accepted }
end

local function claim(player, id)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local quest, state = nextQuest(data)
	if not quest or quest.Id ~= id or not state or state.Progress < quest.Count then
		return nil
	end
	data.Quests[quest.Id] = { Done = true } -- marked before paying, so it can never pay twice
	PlayerData.AddGold(player, quest.Reward.Gold)
	PlayerData.AddXp(player, quest.Reward.Xp)
	PlayerData.Sync(player)
	print(`[Quest] {player.Name} finished {quest.Id}`)
	local lines = table.clone(quest.Thanks)
	lines[#lines] ..= `\nYou got {quest.Reward.Gold} gold and {quest.Reward.Xp} XP.`
	return { Lines = lines }
end

-- Called by MobSpawner for the player who gets the kill.
function Quests.MobKilled(player, mobName)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local quest, state = nextQuest(data)
	if quest and state and quest.Mob == mobName and state.Progress < quest.Count then
		state.Progress += 1
		PlayerData.Sync(player)
	end
end

-- The chief is the hand-made model, anchored. Its idle movement is only a look, so client/Quests does it.
local function buildChief()
	local model = ServerStorage:WaitForChild("Models"):WaitForChild(chief.Model):Clone()
	model.Name = chief.Name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- reaches a client all at once
	model:ScaleTo(model:GetScale() * chief.Scale)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.Color = Color3.new(1, 1, 1) -- white shows the model's own colors
		end
	end

	local spot, faces = village.Chief.Position, village.Chief.Faces
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(spot.X, 120, spot.Z), Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position.Y else 0
	-- the model's face is toward -Z, which lookAlong turns toward the spot
	model:PivotTo(CFrame.lookAlong(model:GetPivot().Position, Vector3.new(faces.X - spot.X, 0, faces.Z - spot.Z)))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(spot.X - box.X, ground - (box.Y - size.Y / 2), spot.Z - box.Z))

	-- an invisible post: players cannot walk through it, and the prompt and the name hang on it
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(2, size.Y, 2)
	root.CFrame = CFrame.lookAlong(Vector3.new(spot.X, ground + size.Y / 2, spot.Z), Vector3.new(faces.X - spot.X, 0, faces.Z - spot.Z)) -- the client reads which way is forward
	root.Parent = model
	model.PrimaryPart = root

	model.Parent = workspace

	Dialogue.Add({
		Id = "VillageChief",
		Name = chief.Name,
		Model = model,
		PromptKey = chief.PromptKey,
		TalkDistance = chief.TalkDistance,
		Talk = talk,
		Actions = { Accept = accept, Claim = claim },
	})
end

task.spawn(function()
	while not workspace:GetAttribute("ZoneReady") do -- set by init.server once the ground is built
		task.wait(0.2)
	end
	buildChief()
end)

return Quests
