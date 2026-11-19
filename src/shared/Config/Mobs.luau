-- Mob definitions, keyed by mob id. Read-only data; the server runs all mob behaviour.
return {
	Wolf = {
		Health = 60,
		Damage = 8, -- per bite
		AttackRange = 6, -- studs, root part to root part (a big wolf bites from further away)
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

		-- Looks only. The mesh comes from ServerStorage.Models.<Model>, saved from Studio as assets/models/<Model>.rbxm
		-- (import assets/models/wolf.glb with the 3D Importer first).
		-- BodySize is the invisible combat hitbox. Keep it the same unless you want to change how the wolf is hit.
		Look = {
			Model = "Wolf",
			TargetLength = 9, -- studs, nose to tail; the mesh is scaled to this
			YawDegrees = 0, -- turns the mesh to face the way the wolf moves. If it faces away from you, set this to 180
			BodySize = Vector3.new(3.6, 3.8, 7.2), -- about 0.4 x 0.42 x 0.8 of TargetLength; resize it when you change TargetLength
			Legs = { FrontLeg_L = 1, HindLeg_R = 1, FrontLeg_R = -1, HindLeg_L = -1 }, -- mesh name = swing direction (diagonals match)
			Tail = "Tail",
			-- The head swings on the neck, and these parts ride along with it.
			Head = { Part = "Neck", Follows = { "Head", "Ear_L", "Ear_R", "Eye_L", "Eye_R", "Nose" } },
			-- The bite: rear back, snap the head down and forward, then recover.
			Bite = {
				Duration = 0.55, -- seconds for the whole move
				RearDegrees = 14, -- how far the body pulls back first
				PitchDegrees = 22, -- how far it drops into the bite
				HeadUpDegrees = 12, -- head lifts during the wind-up
				HeadDropDegrees = 32, -- head snaps down this far
				LungeStuds = 1, -- how far the body shoves forward on the bite
			},
			-- Roblox's importer drops the colors saved in the .glb, so they are set here. Default is used for any piece not listed.
			Colors = {
				Default = { Color = Color3.fromRGB(80, 80, 86), Material = "SmoothPlastic" }, -- grey fur
				Torso = { Color = Color3.fromRGB(72, 72, 78), Material = "SmoothPlastic" },
				Neck = { Color = Color3.fromRGB(95, 95, 101), Material = "SmoothPlastic" }, -- lighter ruff
				Head = { Color = Color3.fromRGB(100, 100, 106), Material = "SmoothPlastic" },
				Tail = { Color = Color3.fromRGB(92, 92, 98), Material = "SmoothPlastic" },
				Ear_L = { Color = Color3.fromRGB(50, 50, 55), Material = "SmoothPlastic" }, -- darker ears
				Ear_R = { Color = Color3.fromRGB(50, 50, 55), Material = "SmoothPlastic" },
				Eye_L = { Color = Color3.fromRGB(255, 184, 20), Material = "Neon" },
				Eye_R = { Color = Color3.fromRGB(255, 184, 20), Material = "Neon" },
				Nose = { Color = Color3.fromRGB(30, 30, 34), Material = "SmoothPlastic" },
			},
			Swing = {
				HipDegrees = 28, -- how far each leg swings
				LegLiftStuds = 0.45, -- the leg lifts this much while swinging forward, so feet clear the ground
				RadiansPerStud = 0.9, -- how fast the legs cycle per stud walked; lower = longer strides
				BodyBobStuds = 0.17, -- body moves up and down twice per stride
				BodyPitchDegrees = 3, -- body rocks forward and back once per stride
				TailDegrees = 20, -- tail wag size
				TailSpeed = 3, -- tail wag speed
			},
		},
	},
}
