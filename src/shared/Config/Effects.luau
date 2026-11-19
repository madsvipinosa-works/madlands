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
	-- Per skill Type (see Config/Skills). Sizes are studs; Shake is camera shake strength and seconds.
	Types = {
		Dash = { StartDustSize = 5 },
		Jump = { LandingDustSize = 12, ShakeAmplitude = 0.6, ShakeSeconds = 0.3 }, -- happens at the skill's HitDelay
		Arc = { StartDustSize = 8, ShakeAmplitude = 0.25, ShakeSeconds = 0.5 },
		Wave = {},
	},
}
