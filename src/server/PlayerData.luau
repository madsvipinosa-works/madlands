-- Player data. Server only. Saves with ProfileStore, never raw DataStore calls.
local Players = game:GetService("Players")
local ProfileStore = require(script.Parent.ProfileStore)

local TEMPLATE = {
	Level = 1,
	Xp = 0,
	Weapon = "Sword", -- equipped weapon id, a key in Config/Weapons
	Gold = 0, -- carried gold, can drop on death
	BankGold = 0, -- safe gold
	Inventory = {}, -- [itemId] = count
}

-- Change the name only to wipe all data (new store). Add new fields to TEMPLATE; Reconcile fills them in.
local store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local profiles = {}

local PlayerData = {}

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
