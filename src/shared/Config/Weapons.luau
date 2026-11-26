-- Weapon definitions, keyed by weapon id (e.g. Weapons.Sword = { ... }).
-- Read-only data. The server decides all damage using these values.
return {
	Sword = {
		Name = "Sword", -- shown in the profile screen
		Description = "A balanced blade: quick swings, and four skills of its own.",
		Rarity = "Common", -- Common, Uncommon, Rare, Epic or Legendary: the colour of its card
		Kind = "Melee", -- shown in the profile screen
		Damage = 20,
		Range = 7, -- studs, measured from the player's root part
		ArcDegrees = 120, -- total width of the swing in front of the player
		Cooldown = 0.6, -- seconds between swings
		-- Basic swings, played in turn: click again within ComboResetSeconds to continue the combo.
		SwingCombo = { "Swing1", "Swing2", "Swing3" }, -- names in Config/SwingAnimations
		ComboResetSeconds = 1.4,
		Skills = { "DashSlash", "Skyfall", "WaveSlash", "Whirlwind" }, -- base skills, in hotkey order (1 to 4); see Config/Skills
		StarterSkill = "DashSlash", -- the only one open at the start; the others are locked until the player obtains them
		-- Model held in the right hand. The mesh comes from ServerStorage.Models.<Model>, saved from Studio as
		-- assets/models/<Model>.rbxm (import assets/models/sword.glb first). Until then, plain Parts below are used.
		Visual = {
			Model = "Sword",
			Length = 4.2, -- studs, pommel to tip; the mesh is scaled to this
			HandlePart = "Grip", -- the part held in the fist; the rest follow it
			-- How the blade sits in the fist.
			-- X: where it points. 0 = straight up, -90 = straight forward, -125 = forward and angled down, 180 = down.
			-- Y: rolls the blade around its own length. 0 = flat side up, 90 = edge down (how a sword is held).
			-- Z: tilts it away from the leg.
			MeshRotation = Vector3.new(-125, 90, 8),
			GripOffset = Vector3.new(0, -0.2, 0),
			GripAngleDegrees = 0, -- extra tilt on top of MeshRotation
			StandFlip = true, StandSink = 0.9, -- how it stands in the Weapon Master's stump: upside down, this deep
			TrailPart = "Blade", -- the part that leaves a trail during swings and skills
			TrailAxis = Vector3.new(0, 1, 0), -- direction from the blade's base to its tip, in the blade's own space
			Trail = {
				Color = Color3.fromRGB(235, 235, 240),
				Lifetime = 0.12, -- how long the ribbon lingers
				MaxLength = 5, -- how far it stretches behind the blade
				FromBladeFraction = 0.5, -- the ribbon covers only the outer half of the blade, so it reads as an edge, not a sheet
			},
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
	-- Ranged weapons: Aimed = they attack toward the mouse. Projectile = the basic attack is a shot (Damage per hit); Look is
	-- a name in Config/Projectiles. Visual.Hand = which hand holds it (RightHand if left out).
	Bow = {
		Name = "Bow",
		Description = "Shoots arrows from far away, wherever you point.",
		Rarity = "Common",
		Kind = "Ranged",
		Aimed = true,
		Damage = 16,
		Range = 60,
		ArcDegrees = 0,
		Cooldown = 0.75,
		SwingCombo = { "BowShot" },
		ComboResetSeconds = 1,
		Projectile = { Speed = 130, Range = 60, Width = 2.5, Look = "Arrow" },
		Skills = { "PowerShot", "Volley", "RetreatShot", "ArrowRain" },
		StarterSkill = "PowerShot", -- the only one open at the start; the others are locked until the player obtains them
		Visual = {
			Model = "BasicBow",
			Length = 4.2,
			Hand = "LeftHand",
			HandlePart = "Bow_Body_1",
			MeshRotation = Vector3.new(-90, 0, 0), -- upright when the arm is held out to shoot
			GripOffset = Vector3.new(0, -0.15, 0.31),
			GripAngleDegrees = 0,
			StandSink = 0.2,
			Colors = { Default = { Color = Color3.new(1, 1, 1), Material = "SmoothPlastic" } }, -- white shows the model's own colors
		},
	},
	Wand = {
		Name = "Wand",
		Description = "Magic bolts wherever you point, with fire, frost and meteors.",
		Rarity = "Common",
		Kind = "Magic",
		Aimed = true,
		Damage = 18,
		Range = 50,
		ArcDegrees = 0,
		Cooldown = 0.8,
		SwingCombo = { "WandCast" },
		ComboResetSeconds = 1,
		Projectile = { Speed = 90, Range = 50, Width = 3, Look = "Bolt" },
		Skills = { "Fireball", "FrostNova", "ArcaneStep", "Meteor" },
		StarterSkill = "Fireball", -- the only one open at the start; the others are locked until the player obtains them
		Visual = {
			Model = "BasicWand",
			Length = 2.6,
			HandlePart = "Wand_Body",
			MeshRotation = Vector3.new(-115, 0, 0),
			GripOffset = Vector3.new(0, -0.4, -0.6),
			GripAngleDegrees = 0,
			StandSink = 0.5,
			Colors = { Default = { Color = Color3.new(1, 1, 1), Material = "SmoothPlastic" } },
		},
	},
}
