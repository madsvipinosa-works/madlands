-- Quests (Config/Quests): the Village Chief who gives them, the kill count and the rewards. Server only: the client is only
-- told what to show. Progress is kept in the player's saved data (ProfileStore, through PlayerData). A player needs a weapon
-- (from the Weapon Master) before the chief will give them anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function buildChief()
	local model = Dialogue.Place(chief, village.Chief)

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
