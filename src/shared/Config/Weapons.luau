-- Weapon definitions, keyed by weapon id (e.g. Weapons.Sword = { ... }).
-- Read-only data. The server decides all damage using these values.
return {
	Sword = {
		Damage = 20,
		Range = 7, -- studs, measured from the player's root part
		ArcDegrees = 120, -- total width of the swing in front of the player
		Cooldown = 0.6, -- seconds between swings
		-- Basic swings, played in turn: click again within ComboResetSeconds to continue the combo.
		SwingCombo = { "Swing1", "Swing2", "Swing3" }, -- names in Config/SwingAnimations
		ComboResetSeconds = 1.4,
		Skills = { "DashSlash", "Skyfall", "WaveSlash", "Whirlwind" }, -- base skills, in hotkey order (1 to 4); see Config/Skills
		SwingSound = "rbxasset://sounds/swordslash.wav", -- client feedback only
		-- Model held in the right hand. The mesh comes from ServerStorage.Models.<Model>, saved from Studio as
		-- assets/models/<Model>.rbxm (import assets/models/sword.glb first). Until then, plain Parts below are used.
		Visual = {
			Model = "Sword",
			Length = 4.2, -- studs, pommel to tip; the mesh is scaled to this
			HandlePart = "Grip", -- the part held in the fist; the rest follow it
			MeshRotation = Vector3.new(-90, 0, 0), -- the mesh points its blade along +Y; this turns it to point forward
			GripOffset = Vector3.new(0, -0.2, 0),
			GripAngleDegrees = 35, -- blade tilts up this much from straight ahead
			TrailPart = "Blade", -- the part that leaves a trail during swings and skills
			TrailAxis = Vector3.new(0, 1, 0), -- direction from the blade's base to its tip, in the blade's own space
			Trail = { Color = Color3.fromRGB(235, 235, 240), Lifetime = 0.3 }, -- Lifetime = how long the trail lingers
			-- Roblox's importer drops the colors saved in the .glb, so they are set here. Default is used for any part not listed.
			Colors = {
				Default = { Color = Color3.fromRGB(184, 191, 204), Material = "Metal" },
				Blade = { Color = Color3.fromRGB(190, 196, 208), Material = "Metal" },
				Guard = { Color = Color3.fromRGB(199, 153, 51), Material = "Metal" },
				Pommel = { Color = Color3.fromRGB(199, 153, 51), Material = "Metal" },
				Grip = { Color = Color3.fromRGB(69, 43, 26), Material = "Fabric" },
				Gem_Front = { Color = Color3.fromRGB(204, 13, 20), Material = "SmoothPlastic" },
				Gem_Back = { Color = Color3.fromRGB(204, 13, 20), Material = "SmoothPlastic" },
			},
			-- Plain stand-in used only while the mesh is missing. Offsets are from the handle.
			Parts = {
				{ Name = "Grip", Size = Vector3.new(0.25, 0.9, 0.25), Offset = Vector3.zero },
				{ Name = "Guard", Size = Vector3.new(1.2, 0.25, 0.25), Offset = Vector3.new(0, 0.55, 0) },
				{ Name = "Blade", Size = Vector3.new(0.45, 3.2, 0.12), Offset = Vector3.new(0, 2.3, 0) },
			},
		},
	},
}
