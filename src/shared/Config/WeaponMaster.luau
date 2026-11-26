-- The Weapon Master, who gives players their first weapon. Read-only; server/WeaponMaster runs it. Where they stand is in
-- Config/Zones (Village.WeaponMaster).
return {
	Name = "Weapon Master",
	PromptKey = Enum.KeyCode.F,
	TalkDistance = 10, -- studs at which "Talk" shows
	Offers = { "Sword" }, -- weapon ids from Config/Weapons a new player can choose from; add more here as they are made
	-- a plain Roblox character in a leather apron, until there is a model
	Look = {
		Skin = Color3.fromRGB(190, 136, 100),
		Shirt = Color3.fromRGB(70, 78, 88),
		Trousers = Color3.fromRGB(52, 40, 32),
		Apron = Color3.fromRGB(112, 70, 40),
	},
	-- Each entry is one page of the conversation.
	Greeting = {
		"A new face! You will not last long out there with empty hands.",
		"Choose your first weapon, and take good care of it.",
	},
	Chosen = {
		"A fine choice. Click to swing it, and press 1 to 4 for its skills.",
		"Now go and speak with the Village Chief. Follow the arrows.",
	},
	After = { "Keep that blade sharp. The Village Chief always has work for someone who can use it." },
}
