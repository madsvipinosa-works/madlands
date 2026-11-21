-- How levelling works. Read-only data; the server applies it (PlayerData.AddXp).
-- XP needed to go from level L to L+1 is floor(BaseXp * L ^ Power).
-- With these numbers: level 1 -> 2 takes 30 XP, 2 -> 3 takes 84, 5 -> 6 takes 335, 10 -> 11 takes 948.
return {
	BaseXp = 30,
	Power = 1.5, -- bigger = later levels take much longer
	MaxLevel = 50, -- placeholder: the real cap is still an open question in DESIGN.md
	HealOnLevelUp = true, -- a level-up restores the player's health
}
