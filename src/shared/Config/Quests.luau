-- Quests, as data. Read-only. The server (server/Quests) gives them out, counts kills and pays the rewards; the client
-- only shows them. Where the chief stands is in Config/Zones (Village.Chief).
return {
	Chief = {
		Name = "Village Chief",
		PromptKey = Enum.KeyCode.F,
		TalkDistance = 10, -- studs at which "Talk" shows
		Cooldown = 1, -- seconds between two talks
		NoMoreQuests = "You have done all I asked, friend. The Starter Town gate lies at the north end of the trail.",
		Model = "VillageChief", -- assets/models/VillageChief.rbxm; parts named "Head...", "LeftArm" (free hand), "...Leg" and "Staff" move
		Scale = 1, -- size of the model (1 = as saved)
		LookDistance = 18, -- studs within which the chief watches you
	},

	-- Given one at a time, in this order. Mob = a key in Config/Mobs. Reminder takes the kills so far and the number needed.
	List = {
		{
			Id = "GoblinTrouble", -- saved in player data: do not rename a quest that has been released
			Title = "Goblin Trouble",
			Mob = "Goblin",
			Count = 5,
			Objective = "Goblins defeated",
			Reward = { Gold = 40, Xp = 60 },
			Offer = "Goblins have made camp up the trail and they raid our stores. Look for their campfires and defeat 5 of them.",
			Reminder = "The goblins still trouble us: %d of %d so far. Look for their campfires off the trail.",
			Thanks = "You drove them off! Take this, with the village's thanks.",
		},
	},
}
