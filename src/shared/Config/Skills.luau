-- Skill definitions, keyed by skill id. Read-only data.
-- A weapon lists its skills in Config/Weapons.luau (Skills = { ... }); the order is the hotkey order (1, 2, 3, 4).
-- The server checks the equipped weapon, the cooldown and all damage and movement using these values.
-- Type picks how the skill works (see handlers in server/Combat): Dash, Jump, Wave or Arc.
-- Animation is a name in Config/SwingAnimations (client feedback only); AnimationSpeed 2 plays it twice as fast.
-- Sounds = { { Cue, At } }: sound cues from Config/Sounds, each At this many seconds after the key press.
return {
	-- Sword base skills
	DashSlash = {
		Weapon = "Sword",
		Name = "Dash Slash",
		Description = "Rush forward through your enemies in a single, flat cut.", -- shown in the skill's tooltip
		Type = "Dash", -- rush forward through the target and cut everything in the path
		Animation = "DashSlash",
		AnimationSpeed = 1,
		Damage = 35,
		DashDistance = 16, -- studs
		DashTime = 0.22, -- seconds the dash lasts
		HitDelay = 0.1, -- seconds before the cut lands, about halfway through the dash
		Width = 7, -- width of the path that gets cut
		Cooldown = 3, -- seconds
		-- Blade trail while the skill plays. Color and LightEmission tint it; Lifetime (seconds it lingers) and MaxLength
		-- (studs it can stretch) are optional and default to the weapon's. Skills without a Trail use the weapon's plain one.
		Trail = { Color = Color3.fromRGB(170, 215, 255), LightEmission = 0.85, Lifetime = 0.32, MaxLength = 16 },
		Sounds = { { Cue = "DashWhoosh", At = 0 } },
	},
	Skyfall = {
		Weapon = "Sword",
		Name = "Sky Slam",
		Description = "Leap into the air, then dive down and chop the ground, hitting everything around where you land.", -- shown in the skill's tooltip
		Type = "Jump", -- crouch, leap, then dive and chop the sword down into the ground
		Animation = "Skyfall",
		AnimationSpeed = 1,
		Damage = 45,
		JumpDelay = 0.06, -- seconds of crouch before the leap
		JumpSpeed = 38, -- studs per second upward at the start
		JumpTime = 0.12, -- seconds that upward push lasts, then gravity takes over
		DiveHang = 0.05, -- seconds at the top before the dive starts
		DiveAccel = 700, -- extra downward acceleration in the dive, on top of gravity (196): gravity alone is slow and floaty
		Forward = 20, -- studs per second forward
		ForwardTime = 0.45, -- seconds the forward push lasts, so you travel Forward x ForwardTime studs through the air
		HitDelay = 0.54, -- seconds until the slam lands: must match when you touch down (measure it if you change the numbers above)
		Range = 10,
		ArcDegrees = 180,
		Cooldown = 6,
		Trail = { Color = Color3.fromRGB(255, 190, 110), LightEmission = 0.85, Lifetime = 0.3, MaxLength = 14 },
		Sounds = { { Cue = "LeapWhoosh", At = 0.06 }, { Cue = "DiveWhoosh", At = 0.38 } },
	},
	WaveSlash = {
		Weapon = "Sword",
		Name = "Wave Slash",
		Description = "Cut the air and send a wave of force flying forward, slicing through every enemy in its path.", -- shown in the skill's tooltip
		Type = "Wave", -- a slash that flies straight ahead
		Animation = "WaveSlash",
		AnimationSpeed = 1,
		Damage = 45,
		Range = 45, -- how far the wave travels
		Speed = 95, -- studs per second
		Width = 6, -- width of the wave
		Cooldown = 8,
		Trail = { Color = Color3.fromRGB(190, 225, 255), LightEmission = 0.7 },
		Sounds = { { Cue = "WaveRelease", At = 0.26 } },
	},
	Whirlwind = {
		Weapon = "Sword",
		Name = "Whirlwind",
		Description = "Spin with your blade out and cut everything around you, again and again.", -- shown in the skill's tooltip
		Type = "Arc", -- spin with the sword and cut everything around you, again and again
		Animation = "Whirlwind",
		AnimationSpeed = 1,
		Damage = 12, -- per hit
		Hits = 4, -- the spin cuts this many times (every half turn), so 4 x Damage in total
		HitDelay = 0.2, -- seconds until the first cut
		HitInterval = 0.17, -- seconds between cuts
		Range = 10,
		ArcDegrees = 360,
		Cooldown = 12,
		Trail = { Color = Color3.fromRGB(225, 240, 255), LightEmission = 0.9, Lifetime = 0.28, MaxLength = 30 }, -- long enough to draw the whole circle
		Sounds = { { Cue = "WhirlSpin", At = 0.1 }, { Cue = "WhirlTick", At = 0.2 }, { Cue = "WhirlTick", At = 0.37 }, { Cue = "WhirlTick", At = 0.54 }, { Cue = "WhirlTick", At = 0.71 } },
	},
}
