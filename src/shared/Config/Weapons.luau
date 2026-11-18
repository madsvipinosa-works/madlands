-- Weapon definitions, keyed by weapon id (e.g. Weapons.Sword = { ... }).
-- Read-only data. The server decides all damage using these values.
return {
	Sword = {
		Damage = 20,
		Range = 7, -- studs, measured from the player's root part
		ArcDegrees = 120, -- total width of the swing in front of the player
		Cooldown = 0.6, -- seconds between swings
		SwingSound = "rbxasset://sounds/swordslash.wav", -- client feedback only
	},
}
