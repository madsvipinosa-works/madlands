-- Mob definitions, keyed by mob id. Read-only data; the server runs all mob behaviour.
-- Where they live is set by the camps in Config/Zones.
return {
	Wolf = {
		Health = 60,
		Damage = 8, -- per bite
		AttackRange = 6, -- studs, root part to root part (a big wolf bites from further away)
		AttackCooldown = 1.2, -- seconds between bites
		AggroRange = 30, -- starts chasing a player closer than this
		LeashRange = 60, -- gives up and walks home when this far from its spawn
		WalkSpeed = 14, -- walking speed: strolling and heading home
		RunSpeed = 24, -- chasing a player: faster than a walking player (16), and the legs gallop (Look.Swing.Run)
		-- When nobody is near, the wolf strolls around its spawn instead of standing still.
		WanderRadius = 14, -- studs from its spawn it may stroll to
		WanderSpeed = 0.35, -- share of WalkSpeed used for strolling (the legs swing less, so it looks like a stroll)
		WanderPause = { 2, 6 }, -- seconds between choosing a new stroll (it stands still for a moment in between)
		WanderChance = 0.75, -- chance that it strolls instead of standing a while
		GoldMin = 5, -- gold dropped is random between min and max
		GoldMax = 15,
		Xp = 20,
		CorpseSeconds = 2, -- body stays this long after death
		RespawnSeconds = 10, -- a new wolf appears this long after death

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
			Head = { Part = "Neck", Follows = {} }, -- the neck swings from the shoulders...
			-- ...and the skull swings on its own joint at the back of the head (Pivot is in the head's own space; +Z is toward the neck)
			Skull = { Part = "Head", Follows = { "Ear_L", "Ear_R", "Eye_L", "Eye_R", "Nose" }, Pivot = Vector3.new(0, 0, 0.85) },
			-- The bite. Every part of the body has its own curve of { seconds, degrees } rows (studs for Lunge), blended smoothly,
			-- so the neck leads, the head whips a beat later, the legs brace then push, and the tail streams behind.
			-- Positive = nose down / foot forward. The damage, the fang effect's closing and the sound land when the snap ends:
			-- WindSeconds + SnapSeconds. Rear back (to 0.22), snap (to 0.30), hold, recover (to Duration).
			Bite = {
				WindSeconds = 0.22,
				SnapSeconds = 0.08,
				Duration = 0.7,
				Tracks = {
					Body = { { 0, 0 }, { 0.22, -12 }, { 0.30, 16 }, { 0.42, 16 }, { 0.7, 0 } }, -- the whole body rocks back, then pitches into it
					Lunge = { { 0, 0 }, { 0.22, -0.5 }, { 0.30, 1.8 }, { 0.42, 1.8 }, { 0.7, 0 } }, -- studs forward
					Neck = { { 0, 0 }, { 0.12, -8 }, { 0.2, -24 }, { 0.3, 26 }, { 0.44, 24 }, { 0.7, 0 } }, -- arches up, then thrusts first
					Skull = { { 0, 0 }, { 0.14, -6 }, { 0.22, -16 }, { 0.3, 30 }, { 0.35, 44 }, { 0.44, 34 }, { 0.7, 0 } }, -- the head lags, then whips past the neck
					FrontLegs = { { 0, 0 }, { 0.22, -14 }, { 0.3, 24 }, { 0.42, 24 }, { 0.7, 0 } }, -- dig in, then reach
					HindLegs = { { 0, 0 }, { 0.22, 14 }, { 0.3, -20 }, { 0.42, -20 }, { 0.7, 0 } }, -- gather, then push off
					Tail = { { 0, 0 }, { 0.22, 12 }, { 0.32, -24 }, { 0.5, -10 }, { 0.7, 0 } }, -- lifts and streams out behind
				},
				Sound = "WolfBite", -- cue in Config/Sounds, starts with the move
				Color = Color3.fromRGB(255, 200, 200), -- tint of the fang effect (client/WolfAttackVFX)
				EffectScale = 1.3, -- size of the fangs and the lunge streak
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
				-- The gait blends from the walk above to this as the wolf speeds up from WalkSpeed to RunSpeed: long, wide
				-- strides, high lifted feet, a springing body and a forward lean.
				Run = {
					HipDegrees = 58,
					LegLiftStuds = 1,
					RadiansPerStud = 0.55,
					BodyBobStuds = 0.5,
					BodyPitchDegrees = 9,
					LeanDegrees = 7, -- the body leans forward, nose down
				},
				TailDegrees = 20, -- tail wag size
				TailSpeed = 3, -- tail wag speed
			},
		},
	},
	Goblin = {
		Health = 40,
		Damage = 4, -- per ordinary club blow (AttackDamages below can differ per blow)
		AttackRange = 4.5, -- studs, root part to root part
		AttackCooldown = 2.8, -- seconds between combos
		AttackDelays = { 0.40, 0.72, 1.45 }, -- seconds from the start of the combo until each blow lands and counts
		AttackDamages = { 4, 4, 8 }, -- damage of each blow: two swings, then the ground slam
		AggroRange = 28,
		LeashRange = 55,
		WalkSpeed = 12,
		WanderRadius = 9,
		WanderSpeed = 0.4,
		WanderPause = { 2, 7 },
		WanderChance = 0.7,
		GoldMin = 3,
		GoldMax = 10,
		Xp = 12,
		CorpseSeconds = 2,
		RespawnSeconds = 10,

		-- Looks only. The mesh comes from ServerStorage.Models.Goblin, saved from Studio as assets/models/Goblin.rbxm
		-- (import goblin.glb with the 3D Importer first).
		Look = {
			Model = "Goblin",
			TargetHeight = 4.6, -- studs, feet to top of the head; the mesh is scaled to this (the wolf is sized by length instead)
			YawDegrees = 0, -- turns the mesh to face the way the goblin moves. If it faces away from you, set this to 180
			BodySize = Vector3.new(2.2, 4.4, 2), -- the invisible combat hitbox
			Legs = { RightLeg = 1, LeftLeg = -1 }, -- mesh name = swing direction (opposite legs)
			Arms = { LeftArm = 1, RightArm = -1 }, -- each arm swings against the leg on its own side
			ClubArm = "RightArm", -- the arm that holds the club: it swings on the attack
			-- The head turns on the neck (at the bottom of the head) and these pieces ride along with it.
			Head = { Part = "Head", Pivot = "Bottom", Follows = { "InnerEars", "Eyes", "Irises", "Pupils", "Eyelids", "Mouth", "Teeth", "Earrings" } },
			-- Pieces that ride along with a moving piece (they are welded to it).
			Attach = {
				RightArm = { "RightHandClaws", "WristWrap", "Club", "ClubBand" },
				LeftArm = { "LeftHandClaws", "ShoulderPad", "PadStrap" },
				RightLeg = { "RightToeClaws" },
				LeftLeg = { "LeftToeClaws" },
			},
			-- The club swing: wind the arm back and up, bring it over the top and down, then settle.
			-- The attack, a combo: a swing from the right across to the left, a swing back from the left to the right, a jump,
			-- then a chop down into the ground. Each row is a moment (T, seconds into the move) and the pose there; the body
			-- eases between rows.
			-- Roll: body lean to the side. Shoulder: the club shoulder forward (+1) or back (-1). Shrug: shoulders up (+1) or down (-1).
			-- Both are fractions of ShoulderReach, which is small on purpose: the arm has no shoulder piece of its own, so a bigger
			-- move pulls it off the body.
			-- HeadYaw: the head turning on top of the body's turn (it follows the swing). Leaving a field out means 0.
			-- Arm: swing in degrees (-360 is rest; -165 is up behind; -270 is straight out front; -315 is forward and down).
			--   Side: out to the side. Yaw: sweeps the arm level, left (+) or right (-). Twist: torso turn (- right, + left).
			-- Step: leg stride. Lean: body pitch. Lunge and Hop: studs forward and up. Head: head pitch. Off / OffYaw: the off arm.
			Club = {
				Duration = 2.2,
				ShoulderReach = 0.22, -- studs the shoulder may slide forward or back; keep it under about 0.3 or the arm comes off
				ShrugReach = 0.14, -- studs the shoulder may rise or drop
				Keys = {
					{ T = 0.00, Arm = -360 },
					{ T = 0.22, Arm = -270, Yaw = -85, Twist = -55, HeadYaw = -14, Roll = -8, Shoulder = -0.56, Shrug = 0.31, Step = -25, Lean = 6, Lunge = -0.2, Hop = -0.2, Head = -8, Off = -30 }, -- wound out to the right: body turns right, right shoulder drawn back
					{ T = 0.40, Arm = -270, Yaw = 80, Twist = 50, HeadYaw = 13, Roll = 10, Shoulder = 0.75, Shrug = -0.12, Step = 28, Lean = -14, Lunge = 1.2, Hop = 0.1, Head = 25, Off = 40, OffYaw = 25 }, -- blow one, right to left: body turns left, right shoulder driven through
					{ T = 0.54, Arm = -270, Yaw = 95, Twist = 60, HeadYaw = 15, Roll = 8, Shoulder = 0.25, Shrug = 0.12, Step = 10, Lean = 4, Lunge = 0.8, Head = -5, Off = 20, OffYaw = 30 }, -- wound out to the left
					{ T = 0.72, Arm = -270, Yaw = -85, Twist = -55, HeadYaw = -14, Roll = -10, Shoulder = 0.75, Step = -28, Lean = -14, Lunge = 1.6, Hop = 0.1, Head = 28, Off = 90, OffYaw = -35 }, -- blow two, left to right
					{ T = 0.95, Arm = -200, Side = 10, Shoulder = -0.37, Shrug = -0.37, Lean = 14, Lunge = 1.0, Hop = -0.5, Head = -10, Off = -40 }, -- crouch to jump, shoulders hunched
					{ T = 1.20, Arm = -165, Side = 20, Shoulder = -0.62, Shrug = 0.62, Step = -15, Lean = 14, Lunge = 1.6, Hop = 3.0, Head = -15, Off = -60 }, -- the top of the jump, club cocked high behind, shoulder pulled back
					{ T = 1.45, Arm = -315, Shoulder = 1, Shrug = -0.25, Step = 28, Lean = -24, Lunge = 2.2, Head = 35, Off = 80 }, -- the slam: shoulder drives the club into the ground
					{ T = 1.70, Arm = -320, Shoulder = 0.75, Step = 24, Lean = -20, Lunge = 2.0, Hop = -0.15, Head = 20, Off = 60 }, -- hold the club in the ground
					{ T = 2.20, Arm = -360 },
				},
			},
			-- Roblox's importer drops the colors saved in the .glb, so they are set here.
			Colors = {
				Default = { Color = Color3.fromRGB(153, 199, 61), Material = "SmoothPlastic" },
				Torso = { Color = Color3.fromRGB(153, 199, 61), Material = "SmoothPlastic" },
				Head = { Color = Color3.fromRGB(153, 199, 61), Material = "SmoothPlastic" },
				InnerEars = { Color = Color3.fromRGB(184, 92, 84), Material = "SmoothPlastic" },
				Eyes = { Color = Color3.fromRGB(245, 237, 204), Material = "SmoothPlastic" },
				Irises = { Color = Color3.fromRGB(219, 163, 46), Material = "SmoothPlastic" },
				Pupils = { Color = Color3.fromRGB(18, 10, 8), Material = "SmoothPlastic" },
				Eyelids = { Color = Color3.fromRGB(133, 173, 51), Material = "SmoothPlastic" },
				Mouth = { Color = Color3.fromRGB(51, 13, 13), Material = "SmoothPlastic" },
				Teeth = { Color = Color3.fromRGB(245, 240, 214), Material = "SmoothPlastic" },
				Earrings = { Color = Color3.fromRGB(209, 209, 214), Material = "SmoothPlastic" },
				RightArm = { Color = Color3.fromRGB(153, 199, 61), Material = "SmoothPlastic" },
				RightHandClaws = { Color = Color3.fromRGB(128, 133, 117), Material = "Slate" },
				LeftArm = { Color = Color3.fromRGB(153, 199, 61), Material = "SmoothPlastic" },
				LeftHandClaws = { Color = Color3.fromRGB(128, 133, 117), Material = "Slate" },
				WristWrap = { Color = Color3.fromRGB(230, 227, 214), Material = "Fabric" },
				ShoulderPad = { Color = Color3.fromRGB(168, 171, 178), Material = "SmoothPlastic" }, -- Metal reflects the sky as blue, so plain here
				PadStrap = { Color = Color3.fromRGB(92, 56, 31), Material = "Fabric" },
				Club = { Color = Color3.fromRGB(143, 102, 61), Material = "Wood" },
				ClubBand = { Color = Color3.fromRGB(97, 97, 105), Material = "SmoothPlastic" },
				ClothBand = { Color = Color3.fromRGB(153, 74, 38), Material = "Fabric" },
				Loincloth = { Color = Color3.fromRGB(189, 97, 51), Material = "Fabric" },
				ClothPin = { Color = Color3.fromRGB(209, 209, 214), Material = "SmoothPlastic" },
				RightLeg = { Color = Color3.fromRGB(153, 199, 61), Material = "SmoothPlastic" },
				RightToeClaws = { Color = Color3.fromRGB(128, 133, 117), Material = "Slate" },
				LeftLeg = { Color = Color3.fromRGB(153, 199, 61), Material = "SmoothPlastic" },
				LeftToeClaws = { Color = Color3.fromRGB(128, 133, 117), Material = "Slate" },
			},
			Swing = {
				HipDegrees = 42, -- how far each leg swings (big, scrambling strides)
				ArmDegrees = 50, -- how far each arm swings
				LegLiftStuds = 0.3,
				RadiansPerStud = 1.7, -- shorter legs, quick steps
				BodyBobStuds = 0.28, -- a bouncy hop in every stride
				BodyPitchDegrees = 9, -- hunched, rocking forward and back
				TailDegrees = 0,
				TailSpeed = 1,
				IdleBreathStuds = 0.05, -- standing still: a breathing bob...
				IdleHeadDegrees = 18, -- ...the head looking about...
				IdleArmDegrees = 10, -- ...and the arms fidgeting
			},
		},
	},
}
