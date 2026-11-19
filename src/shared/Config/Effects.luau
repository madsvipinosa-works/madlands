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
	-- The flying slash of a Wave skill: a crescent built from thin slices along an arc, so it curves
	-- like a sword stroke instead of flying flat like a card. Built on the server, so everyone sees it.
	Wave = {
		Color = Color3.fromRGB(235, 240, 250),
		-- A ready-made effect from ServerStorage.Models (saved as assets/models/<Model>.rbxm).
		-- Leave Model empty to use the plain crescent built from the numbers below instead.
		Model = "Slash",
		ModelScale = 0.5, -- multiplies the effect's own size
		-- Where the slash is born. It starts at the sword blade itself as the swing cuts (the animation's
		-- TrailStart), not at the moment the key is pressed. The numbers below are the fallback for a
		-- character with no weapon model.
		SpawnForward = 2.5, -- studs in front
		SpawnHeight = -0.4, -- studs up or down
		FadeFrom = 0.65, -- fraction of the flight after which it fades out, instead of blinking away
		ModelOffset = Vector3.new(0, 0, 0), -- nudge it if the effect sits off to one side of the wave
		ModelRotation = Vector3.new(0, 90, 0), -- lies flat, like a sweep of the sword; Y turns which way its curve opens (0, 90, 180 or 270)
		Upright = true, -- true: a C standing on end, facing the way it flies. false: a curve lying flat.
		Radius = 6, -- how tightly the crescent curves; bigger = flatter
		ArcDegrees = 125, -- how far around the crescent sweeps
		Slices = 15, -- more slices = smoother curve
		Height = 4.5, -- how far the blade reaches across at the middle, tapering to nothing at the tips
		Thickness = 0.3,
		TiltDegrees = 20, -- leaned over, like a diagonal cut
		Transparency = 0.3,
		TrailLifetime = 0.2, -- smear behind the tips
	},
	-- Per skill Type (see Config/Skills). Sizes are studs; Shake is camera shake strength and seconds.
	Types = {
		Dash = {
			StartDustSize = 5,
			StreakSeconds = 0.3, -- a speed streak behind the body while rushing
			StreakColor = Color3.fromRGB(225, 230, 245),
			StreakHeight = 4, -- studs tall, roughly head to knee
		},
		Jump = { LandingDustSize = 12, ShockwaveSize = 22, ShakeAmplitude = 0.6, ShakeSeconds = 0.3 }, -- happens at the skill's HitDelay
		Arc = { StartDustSize = 8, SpinRingSize = 11, ShakeAmplitude = 0.25, ShakeSeconds = 0.5 },
		Wave = {},
	},
}
