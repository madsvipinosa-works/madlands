-- Player data. Server only. Saves with ProfileStore, never raw DataStore calls.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileStore = require(script.Parent.ProfileStore)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)

local TEMPLATE = {
	Level = 1,
	Xp = 0,
	Weapon = "Sword", -- equipped weapon id, a key in Config/Weapons
	Gold = 0, -- carried gold, can drop on death
	BankGold = 0, -- safe gold
	Inventory = {}, -- [itemId] = count
	Quests = {}, -- [questId] = { Progress = n } while taken, { Done = true } once rewarded (Config/Quests)
}

-- Change the name only to wipe all data (new store). Add new fields to TEMPLATE; Reconcile fills them in.
local store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local profiles = {}

local PlayerData = {}

-- XP needed to climb from `level` to the next one (0 at the top level).
function PlayerData.XpNeeded(level)
	if level >= Leveling.MaxLevel then
		return 0
	end
	return math.floor(Leveling.BaseXp * level ^ Leveling.Power)
end

-- Copies the numbers the HUD shows onto the player as attributes, which Roblox replicates to that client.
-- The client only reads them; every change happens on the server.
function PlayerData.Sync(player)
	local d = PlayerData.Get(player)
	if not d then
		return
	end
	player:SetAttribute("Level", d.Level)
	player:SetAttribute("Xp", d.Xp)
	player:SetAttribute("XpNeeded", PlayerData.XpNeeded(d.Level))
	player:SetAttribute("Gold", d.Gold)
	player:SetAttribute("BankGold", d.BankGold)
	player:SetAttribute("Weapon", d.Weapon)
	player:SetAttribute("Inventory", HttpService:JSONEncode(d.Inventory)) -- the bag as text; the menu decodes it
	player:SetAttribute("Quests", HttpService:JSONEncode(d.Quests))
end

-- Adds XP and levels the player up as many times as it pays for. Returns how many levels were gained.
function PlayerData.AddXp(player, amount)
	local d = PlayerData.Get(player)
	if not d or amount <= 0 then
		return 0
	end
	d.Xp += amount
	local gained = 0
	while d.Level < Leveling.MaxLevel and d.Xp >= PlayerData.XpNeeded(d.Level) do
		d.Xp -= PlayerData.XpNeeded(d.Level)
		d.Level += 1
		gained += 1
	end
	if d.Level >= Leveling.MaxLevel then
		d.Xp = 0
	end
	if gained > 0 and Leveling.HealOnLevelUp then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
	end
	PlayerData.Sync(player)
	return gained
end

function PlayerData.AddGold(player, amount)
	local d = PlayerData.Get(player)
	if d and amount > 0 then
		d.Gold += amount
		PlayerData.Sync(player)
	end
end

-- Returns the player's live data table, or nil if not loaded yet / already left.
function PlayerData.Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

local function onJoin(player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end
	profiles[player] = profile
	PlayerData.Sync(player)
	local d = profile.Data
	print(`[PlayerData] {player.Name}: Level {d.Level}, Gold {d.Gold}, Bank {d.BankGold}`)end

Players.PlayerAdded:Connect(onJoin)
for _, player in Players:GetPlayers() do
	task.spawn(onJoin, player)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
		profiles[player] = nil
	end
end)

return PlayerData
