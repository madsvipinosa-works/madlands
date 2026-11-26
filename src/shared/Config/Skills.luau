-- Skill definitions, keyed by skill id. Read-only data.
-- A weapon lists its skills in Config/Weapons.luau (Skills = { ... }); the order is the hotkey order (1, 2, 3, 4).
-- The server checks the equipped weapon, the cooldown and all damage and movement using these values.
-- Type picks how the skill works (see handlers in server/Combat): Dash, Jump, Wave, Arc, Shot (one or more projectiles),
-- Rain (strikes where you point), Nova (an Arc with its own look) or Blink (a Dash with its own look).
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
		HitDelay = 0.54, -- seconds until the slam lands on flat ground (times the effects): measure it if you change the numbers above
		LandWait = 0.7, -- the server may wait this much longer for you to touch down (slopes, lag) before it counts the hit anyway
		Range = 16, -- studs all around where you land; the slam's shock ring spreads to about 17
		ArcDegrees = 360,
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
		Sounds = { { Cue = "WaveRelease", At = 0.2 } },
	},
	Whirlwind = {
		Weapon = "Sword",
		Name = "Whirlwind",
		Description = "Spin with your blade out and cut everything around you, again and again.", -- shown in the skill's tooltip
		Type = "Arc", -- spin with the sword and cut everything around you, again and again
		Animation = "Whirlwind",
		AnimationSpeed = 1,
		Damage = 8, -- per hit
		Hits = 6, -- the spin cuts this many times (every half turn), so 6 x Damage in total
		HitDelay = 0.2, -- seconds until the first cut
		HitInterval = 0.18, -- seconds between cuts
		Range = 10,
		ArcDegrees = 360,
		Cooldown = 12,
		Trail = { Color = Color3.fromRGB(225, 240, 255), LightEmission = 0.9, Lifetime = 0.28, MaxLength = 30 }, -- long enough to draw the whole circle
		Sounds = { { Cue = "WhirlSpin", At = 0 } },
	},

	-- Bow base skills
	PowerShot = {
		Weapon = "Bow",
		Name = "Power Shot",
		Description = "Draw the bow to its limit and loose a heavy arrow that goes through every enemy in its line.",
		Type = "Shot",
		Animation = "BowPower",
		AnimationSpeed = 1,
		Delay = 0.4, -- seconds until the arrow leaves
		Damage = 45,
		Speed = 170,
		Range = 75,
		Width = 3.5,
		Pierce = true, -- flies on through what it hits
		Look = "PowerArrow", -- Config/Projectiles
		Cooldown = 5,
		Sounds = { { Cue = "BowPower", At = 0.38 } },
	},
	Volley = {
		Weapon = "Bow",
		Name = "Volley",
		Description = "Loose five arrows at once in a wide fan.",
		Type = "Shot",
		Animation = "BowShot",
		AnimationSpeed = 1,
		Delay = 0.24,
		Count = 5, -- arrows
		Spread = 40, -- degrees from the first to the last
		Damage = 16, -- per arrow
		Speed = 130,
		Range = 45,
		Width = 2.5,
		Look = "Arrow",
		Cooldown = 7,
		Sounds = { { Cue = "BowShot", At = 0 }, { Cue = "BowPower", At = 0.24 } },
	},
	RetreatShot = {
		Weapon = "Bow",
		Name = "Retreat Shot",
		Description = "Spring backwards away from danger, firing a piercing arrow as you go.",
		Type = "Shot",
		Animation = "BowLeap",
		AnimationSpeed = 1,
		Delay = 0.12,
		Damage = 25,
		Speed = 140,
		Range = 55,
		Width = 3,
		Pierce = true,
		Look = "Arrow",
		Recoil = { Distance = 18, Time = 0.28 }, -- you are pushed back this far, over this long
		Cooldown = 8,
		Sounds = { { Cue = "Blink", At = 0.1 }, { Cue = "BowShot", At = 0 } },
	},
	ArrowRain = {
		Weapon = "Bow",
		Name = "Arrow Rain",
		Description = "Fire into the sky; arrows pour down where you point, again and again.",
		Type = "Rain",
		Animation = "BowRain",
		AnimationSpeed = 1,
		CastRange = 45, -- farthest from you it can land
		Radius = 11,
		Delay = 0.8, -- seconds until the first arrows land
		Hits = 6,
		HitInterval = 0.25,
		Damage = 10, -- per hit
		Look = "Rain",
		Cooldown = 14,
		Sounds = { { Cue = "BowPower", At = 0.3 } },
	},

	-- Wand base skills
	Fireball = {
		Weapon = "Wand",
		Name = "Fireball",
		Description = "Hurl a ball of fire that bursts on whatever it meets, burning everything nearby.",
		Type = "Shot",
		Animation = "WandFireball",
		AnimationSpeed = 1.8, -- the throw in the animation is at 0.45 s at speed 1: keep Delay = 0.45 / this
		Delay = 0.25, -- the charge-up at the wand tip, then it is thrown
		Damage = 40,
		Speed = 140,
		Range = 90, -- keep below every mob's ChaseRange (Config/Mobs), so what you hit can come after you
		Width = 3,
		Radius = 9, -- the burst, only when it touches a mob or something solid
		Look = "Fireball",
		Cooldown = 5,
		Sounds = { { Cue = "FireCast", At = 0.2 } },
	},
	FrostNova = {
		Weapon = "Wand",
		Name = "Frost Nova",
		Description = "Strike the ground with cold: a ring of ice bursts out and hits everything around you.",
		Type = "Nova",
		Animation = "WandNova",
		AnimationSpeed = 1,
		HitDelay = 0.32,
		Damage = 30,
		Range = 15,
		ArcDegrees = 360,
		Cooldown = 8,
		Sounds = { { Cue = "FrostNova", At = 0.28 } },
	},
	ArcaneStep = {
		Weapon = "Wand",
		Name = "Arcane Step",
		Description = "Flash forward toward where you point, scorching whatever you pass through.",
		Type = "Blink",
		Animation = "WandBlink",
		AnimationSpeed = 1,
		Damage = 20,
		DashDistance = 22,
		DashTime = 0.15,
		Brake = true, -- no sliding past the end
		HitDelay = 0.07,
		Width = 6,
		Cooldown = 7,
		Sounds = { { Cue = "Blink", At = 0 } },
	},
	Meteor = {
		Weapon = "Wand",
		Name = "Meteor",
		Description = "Call a burning rock down from the sky. Slow to land, and it hits very hard.",
		Type = "Rain",
		Animation = "WandMeteor",
		AnimationSpeed = 1,
		CastRange = 45,
		Radius = 13,
		Delay = 1.1,
		Hits = 1,
		Damage = 75,
		Look = "Meteor",
		Cooldown = 15,
		Sounds = { { Cue = "FireCast", At = 0.25 } },
	},
}
