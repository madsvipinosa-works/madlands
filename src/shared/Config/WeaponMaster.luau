-- The Weapon Master, who gives players their first weapon. Read-only; server/WeaponMaster runs it. Where they stand is in
-- Config/Zones (Village.WeaponMaster).
return {
	Name = "Weapon Master",
	PromptKey = Enum.KeyCode.F,
	TalkDistance = 10, -- studs at which "Talk" shows
	Offers = { "Sword", "Bow", "Wand" }, -- weapon ids from Config/Weapons a new player can choose from
	Model = "WeaponMaster", -- assets/models/WeaponMaster.rbxm; parts named "Head...", "LeftArm" (free hand), "...Leg" and "Sword" move
	Scale = 1, -- size of the model (1 = as saved)
	LookDistance = 18, -- studs within which they watch you
	-- Each entry is one page of the conversation.
	Greeting = {
		"A new face! You will not last long out there with empty hands.",
		"Choose your first weapon, and take good care of it.",
	},
	Chosen = {
		"A fine choice. Click to attack, and press 1 for your first skill. You will learn the other three on your journey.",
		"Now go and speak with the Village Chief. Follow the arrows.",
	},
	After = { "Keep that blade sharp. The Village Chief always has work for someone who can use it." },
}
