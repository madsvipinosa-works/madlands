-- Weapon definitions, keyed by weapon id (e.g. Weapons.Sword = { ... }).
-- Read-only data. The server decides all damage using these values.
return {
	Sword = {
		Damage = 20,
		Range = 7, -- studs, measured from the player's root part
		ArcDegrees = 120, -- total width of the swing in front of the player
		Cooldown = 0.6, -- seconds between swings
		SwingAnimation = "Swing", -- a name in Config/SwingAnimations; client feedback only
		Skills = { "DashSlash", "Skyfall", "WaveSlash", "Whirlwind" }, -- base skills, in hotkey order (1 to 4); see Config/Skills
		SwingSound = "rbxasset://sounds/swordslash.wav", -- client feedback only
		-- Model held in the right hand. The first part is the handle; Offset is from the handle, blade along -Z (forward).
		Visual = {
			GripOffset = Vector3.new(0, -0.2, 0),
			GripAngleDegrees = 35, -- blade tilts up this much from straight ahead
			TrailPart = "Blade", -- the part that leaves a trail during swings and skills
			Trail = { Color = Color3.fromRGB(235, 235, 240), Lifetime = 0.3 }, -- Lifetime = how long the trail lingers
			Parts = {
				{ Name = "Handle", Size = Vector3.new(0.25, 0.25, 0.9), Offset = Vector3.zero, Color = Color3.fromRGB(70, 45, 25), Material = "Wood" },
				{ Name = "Guard", Size = Vector3.new(1.2, 0.25, 0.25), Offset = Vector3.new(0, 0, -0.55), Color = Color3.fromRGB(160, 130, 60), Material = "Metal" },
				{ Name = "Blade", Size = Vector3.new(0.45, 0.12, 3.2), Offset = Vector3.new(0, 0, -2.3), Color = Color3.fromRGB(200, 205, 215), Material = "Metal" },
			},
		},
	},
}
