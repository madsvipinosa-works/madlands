-- Mob definitions, keyed by mob id. Read-only data; the server runs all mob behaviour.
return {
	Wolf = {
		Health = 60,
		Damage = 8, -- per bite
		AttackRange = 5, -- studs, root part to root part
		AttackCooldown = 1.2, -- seconds between bites
		AggroRange = 30, -- starts chasing a player closer than this
		LeashRange = 60, -- gives up and walks home when this far from its spawn
		WalkSpeed = 14,
		GoldMin = 5, -- gold dropped is random between min and max
		GoldMax = 15,
		Xp = 20,
		CorpseSeconds = 2, -- body stays this long after death
		RespawnSeconds = 10, -- a new wolf appears this long after death
		Spawns = { Vector3.new(30, 3, -30) }, -- one wolf per position

		-- Looks only. Offsets are studs from the body's center; the wolf faces -Z (head at negative Z).
		-- BodySize is the combat hitbox. Keep it the same unless you want to change how the wolf is hit.
		Look = {
			BodySize = Vector3.new(2, 2, 4),
			BodyColor = Color3.fromRGB(105, 105, 110),
			Belly = { Size = Vector3.new(1.7, 0.6, 3.4), Offset = Vector3.new(0, -0.8, 0), Color = Color3.fromRGB(190, 190, 185) },
			Head = { Size = Vector3.new(1.5, 1.4, 1.5), Offset = Vector3.new(0, 0.5, -2.6), Color = Color3.fromRGB(120, 120, 125) },
			Snout = { Size = Vector3.new(0.7, 0.6, 1), Offset = Vector3.new(0, 0.2, -3.7), Color = Color3.fromRGB(170, 165, 160) },
			Ear = { Size = Vector3.new(0.3, 0.8, 0.5), Offset = Vector3.new(0.45, 1.5, -2.3), Color = Color3.fromRGB(80, 80, 85) }, -- one per side
			Tail = { Size = Vector3.new(0.5, 0.5, 2), Offset = Vector3.new(0, 0.9, 2.8), TiltDegrees = -35, Color = Color3.fromRGB(95, 95, 100) },
			Leg = {
				Size = Vector3.new(0.5, 1.5, 0.5), -- the height also lifts the body off the ground
				XOffset = 0.7, -- left/right from the center
				ZOffset = 1.4, -- front/back from the center
				Color = Color3.fromRGB(85, 85, 90),
			},
			Swing = { AngleDegrees = 35, RadiansPerStud = 1.2 }, -- leg swing size, and how fast legs cycle per stud walked
		},
	},
}
