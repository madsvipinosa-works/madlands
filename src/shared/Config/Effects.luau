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
		ModelScale = 1.5, -- multiplies the effect's own size (the imported slash is 6 studs wide at 1)
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
			StreakSeconds = 0.3, -- a speed streak behind the body while rushing
			StreakColor = Color3.fromRGB(205, 225, 255),
			StreakHeight = 4, -- studs tall, roughly head to knee
			StreakSpread = 1.4, -- studs between the three ribbons, so the streak is a wide band
			CutMarkLength = 12, -- the slash line that flashes where the cut lands
			FlashColor = Color3.fromRGB(190, 220, 255),
			FovKick = 9,
		},
		Jump = {
			StartDustSize = 6,
			LandingDustSize = 12,
			ShockwaveSize = 22,
			SecondRingSize = 32, -- a slower, wider ring right behind the first
			ShakeAmplitude = 0.9,
			ShakeSeconds = 0.4, -- happens at the skill's HitDelay
			FlashColor = Color3.fromRGB(255, 185, 110),
			FlashSize = 14,
			EmberCount = 26, -- glowing chips thrown up from the ground
		},
		Arc = {
			StartDustSize = 8,
			SpinRingSize = 11,
			ShakeAmplitude = 0.25,
			ShakeSeconds = 0.5,
			WhirlDelay = 0.12, -- seconds after the key press, when the spin itself starts
			WhirlSeconds = 0.7, -- how long the wind ribbons spin around you
			WhirlRadius = 5.5,
			WhirlColor = Color3.fromRGB(215, 235, 255),
		},
		Wave = {},
	},
}
