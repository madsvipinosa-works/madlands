-- Skill definitions, keyed by skill id. Read-only data.
-- A weapon lists its skills in Config/Weapons.luau (Skills = { ... }); the order is the hotkey order (1, 2, 3, 4).
-- The server checks the equipped weapon, the cooldown and all damage and movement using these values.
-- Type picks how the skill works (see handlers in server/Combat): Dash, Jump, Wave or Arc.
-- Animation is a name in Config/SwingAnimations (client feedback only); AnimationSpeed 2 plays it twice as fast.
return {
	-- Sword base skills
	DashSlash = {
		Weapon = "Sword",
		Name = "Dash Slash",
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
	},
	Skyfall = {
		Weapon = "Sword",
		Name = "Sky Slam",
		Type = "Jump", -- leap up and forward, slam the sword down on landing
		Animation = "Skyfall",
		AnimationSpeed = 1,
		Damage = 45,
		JumpSpeed = 32, -- studs per second upward at the start
		JumpTime = 0.15, -- seconds that upward push lasts, then gravity takes over
		Forward = 10, -- studs per second forward during the push
		HitDelay = 0.62, -- seconds until the slam lands, about when you touch down
		Range = 10,
		ArcDegrees = 180,
		Cooldown = 6,
		Trail = { Color = Color3.fromRGB(255, 190, 110), LightEmission = 0.6 },
	},
	WaveSlash = {
		Weapon = "Sword",
		Name = "Wave Slash",
		Type = "Wave", -- a slash that flies straight ahead
		Animation = "WaveSlash",
		AnimationSpeed = 1,
		Damage = 45,
		Range = 45, -- how far the wave travels
		Speed = 95, -- studs per second
		Width = 6, -- width of the wave
		Cooldown = 8,
		Trail = { Color = Color3.fromRGB(190, 225, 255), LightEmission = 0.7 },
	},
	Whirlwind = {
		Weapon = "Sword",
		Name = "Whirlwind",
		Type = "Arc", -- spin with the sword and cut everything around you
		Animation = "Whirlwind",
		AnimationSpeed = 1,
		Damage = 40,
		HitDelay = 0.35,
		Range = 10,
		ArcDegrees = 360,
		Cooldown = 12,
		Trail = { Color = Color3.fromRGB(215, 235, 255), LightEmission = 0.7 },
	},
}
