-- Look of combat effects. Client feedback only, changes no rules. Tweak freely.
return {
	HitSpark = { -- little chips that fly off a target when it is hit
		Count = 14,
		Color = Color3.fromRGB(235, 235, 240),
		Size = 0.4, -- studs, shrinks to nothing
		Lifetime = 0.4, -- seconds
		Speed = 20, -- studs per second
	},
	Dust = { -- ground puff and expanding ring (dashes, landings, spins)
		Color = Color3.fromRGB(170, 160, 140),
		Lifetime = 0.7,
	},
	-- The flying slash of a Wave skill. Every client draws it itself (client/Effects.Wave); the server only moves the
	-- hit box, so the slash is smooth from its first frame and everyone sees it.
	Wave = {
		Color = Color3.fromRGB(235, 240, 250), -- the pop of light and sparks where it is released
		-- The slash's look: a single Part with a SpecialMesh in ServerStorage.Models (saved as assets/models/<Model>.rbxm).
		-- The server copies it to ReplicatedStorage.WaveSlash on start so clients can draw it.
		Model = "Slash",
		ModelScale = 2.2, -- multiplies the effect's own size (the imported slash is 6 studs wide at 1, so about 13 studs now)
		-- The mesh's color multiplier. 1, 1, 1 shows its texture as is; bigger numbers glow brighter; uneven ones tint it
		-- (the premade slash was 2, 1, 5: purple). 2, 2, 2 is a bright white.
		Tint = Vector3.new(2, 2, 2),
		-- Where the slash is released: on your aim line, in front of your chest, at the moment the cut passes
		-- forward (the move's Release time in Config/SwingAnimations).
		SpawnForward = 3, -- studs in front
		SpawnHeight = 0.5, -- studs up or down from your root part
		GrowFrom = 0.35, -- it is released at this fraction of its size...
		GrowSeconds = 0.12, -- ...and swells to full size over this long, so it is cut out of the air, not placed
		FadeFrom = 0.65, -- fraction of the flight after which it fades out, instead of blinking away
		ModelOffset = Vector3.new(0, 0, 0), -- nudge it if the effect sits off to one side of the wave
		ModelRotation = Vector3.new(0, 0, 0), -- lies flat, like a sweep of the sword; Y turns it about the vertical. 0 = curved back toward you, tips pointing the way it flies; 180 flips it so the curved edge leads
		TiltDegrees = 0, -- leaned over (positive: right end higher); 0 keeps it level
	},
	-- The glowing tail of a flying Wave: sparks shed behind it and a light that travels with it.
	WaveGlow = {
		Color = Color3.fromRGB(240, 245, 255),
		LightRange = 14,
		LightBrightness = 2,
		SparkRate = 90, -- sparks per second shed along the flight
		SparkSize = 0.5,
	},
	-- A strong hit (damage at or above DamageNumbers.StrongThreshold): a bright pop and a slash line across the target.
	Impact = {
		Color = Color3.fromRGB(255, 240, 200),
		FlashSize = 6,
		MarkLength = 9, -- studs, the slash line
		SparkCount = 18,
		ShakeAmplitude = 0.15,
		ShakeSeconds = 0.12,
	},
	-- Per skill Type (see Config/Skills). Sizes are studs; Shake is camera shake strength and seconds.
	-- FovKick widens the camera for a moment (degrees) so a rush feels fast.
	Types = {
		Dash = {
			StartDustSize = 5,
			EndDustSize = 4, -- dust where the rush ends
			StreakSeconds = 0.4, -- a speed streak behind the body while rushing
			StreakColor = Color3.fromRGB(205, 225, 255),
			StreakHeight = 4, -- studs tall, roughly head to knee
			StreakSpread = 1.4, -- studs between the three ribbons, so the streak is a wide band
			TrailDustSize = 2.5, -- a small puff of dust on the ground this often along the rush
			TrailDustEvery = 0.04, -- seconds
			-- The crescent that flashes where the cut lands (the same mesh as the Wave Slash).
			CutMarkScale = 1.7, -- times its native size (6 studs wide), so about 10 studs against the 7 stud wide cut
			CutMarkAhead = 4, -- studs in front of you when it lands
			CutMarkTurn = 180, -- 180: curved edge leads, like a blade swept across; 0: curved edge trails
			CutMarkSeconds = 0.3,
			FlashColor = Color3.fromRGB(190, 220, 255),
			FovKick = 9,
		},
		Jump = {
			UseSkySlam = true, -- take-off, dive trail and landing slam come from the SkySlamVFX module
			SkySlamScale = 1, -- overall size of the module's effects
			MinAirTime = 0.3, -- seconds in the air before the module starts watching for the ground
			StreakSeconds = 0.45, -- ribbons behind the body through the whole leap
			StreakColor = Color3.fromRGB(255, 225, 180),
			StreakHeight = 4,
			StreakSpread = 1.2,
			-- The downward chop: the crescent stood upright in front of you, just before you land.
			ChopMarkScale = 2.2, -- times its native size (6 studs wide)
			ChopMarkAhead = 5, -- studs in front of you
			ChopMarkLead = 0.07, -- seconds before the landing
			-- On landing, besides the module's slam:
			CrackCount = 9, -- glowing cracks running out from the impact
			CrackLength = 13, -- studs
			CrackColor = Color3.fromRGB(255, 120, 40), -- glowing orange
			LandingFovKick = 8, -- degrees the camera widens for a moment
			ShakeAmplitude = 1.1,
			ShakeSeconds = 0.45,
			FlashColor = Color3.fromRGB(255, 185, 110), -- the colour of the module's effects
		},
		Arc = {
			StartDustSize = 8,
			-- On every hit of the spin: a ring on the ground, the crescent flashing where the blade is, and a jolt.
			SpinRingSize = 11,
			TickMarkScale = 1.4, -- the crescent, times its native size (6 studs wide). It lies along the blade, from you outward
			TickMarkRadius = 5.2, -- studs out from you: its middle, so it spans about 1 to 9 studs from you
			TickMarkSeconds = 0.3,
			SpinDustSize = 3, -- a puff of dust at your feet every 0.08 s through the spin
			ShakeAmplitude = 0.25,
			ShakeSeconds = 0.5,
			WhirlDelay = 0.12, -- seconds after the key press, when the spin itself starts
			WhirlSeconds = 0.7, -- how long the crescents of wind circle you
			WhirlBlades = 3, -- how many crescents
			WhirlScale = 1.4, -- each, times its native size (6 studs wide). Each lies from you outward, like a blade
			WhirlRadius = 5.2, -- studs out from you: its middle, so it spans about 1 to 9 studs from you
			WhirlHeights = { -0.2, 0.7, 1.6 }, -- height of each crescent, from your middle
		},
		Wave = {},
	},
}
