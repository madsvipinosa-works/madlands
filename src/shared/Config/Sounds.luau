-- Sound effects. Read-only data; the client plays them (client/Sounds.luau). Looks and rules are not affected.
-- A cue is a name for a moment ("Swing1", "SlamLand"). It plays one or more layers at once, like a real mix: a sharp
-- whoosh on top of a warm one, a punch on top of a deep thud. Every play picks a random pitch and a little
-- random volume inside the ranges below, so the same swing never sounds exactly the same twice.
--
-- A layer: Id (the sound), Volume (0 to 1), Speed (pitch and speed: 1 is normal, 0.8 is lower and slower;
--   give { low, high } to vary it every play), Delay (seconds before it starts), Seconds (cut it off after this
--   long, with a short fade), Eq = { Low, Mid, High } in dB (negative turns that part down: High = -6 softens a
--   harsh, hissy sound).
--
-- To change a sound, change its Id (a number from the Creator Store: create.roblox.com/store/audio). In Studio, press
-- [ and ] to step through every cue and hear each one (dev only, see client/Sounds.luau).
local WOOSH_SHORT = "rbxassetid://74248579135630" -- "Short Woosh4": 0.36 s, one sharp swish, a little bright
local WOOSH_HEAVY = "rbxassetid://9120629501" -- Pro Sound Effects "Web Whoosh Fast Heavy Swooshes": 0.85 s, warm and weighty
local WHIRL = "rbxassetid://118431566107728" -- "whirlwind swing": 0.54 s, a double swish
local CLOTH = "rbxassetid://9125441977" -- Pro Sound Effects "Cloth Whooshes Fast": 3 s of swirling passes
local THUD = "rbxassetid://71932753926439" -- "Swift Thud 1": a deep body thud with a short tail
local WHOMP = "rbxassetid://9116907950" -- Pro Sound Effects "Metal Whomps Deep Pounding Impacts": a deep, heavy hit
local PUNCH = "rbxassetid://113727224185057" -- "punch_h_05": 0.44 s, a solid punch
local STAFF = "rbxassetid://87413510107751" -- "Quarterstaff Hit 1": a wooden crack with a tail
local EARTH = "rbxassetid://103626556433205" -- "Earth Impact": a deep ground boom with a long rumble
local DIVE_END = "rbxassetid://85581268010045" -- "dive end": a loud crash landing
local RUBBLE = "rbxassetid://107033324149762" -- "rocks lift 2 sfx": stones and debris

return {
	MasterVolume = 1, -- everything, at once
	NearDistance = 18, -- studs: full volume this close to a sound
	FarDistance = 150, -- studs: silent beyond this

	Cues = {
		-- The three basic swings. The whoosh peaks as the blade crosses in front of you.
		Swing1 = {
			{ Id = WOOSH_SHORT, Volume = 0.5, Speed = { 0.96, 1.08 }, Eq = { High = -4 } },
			{ Id = WOOSH_HEAVY, Volume = 0.2, Speed = { 1.3, 1.45 } },
		},
		Swing2 = { -- the backhand: a touch higher and quicker
			{ Id = WOOSH_SHORT, Volume = 0.5, Speed = { 1.06, 1.18 }, Eq = { High = -4 } },
			{ Id = WOOSH_HEAVY, Volume = 0.2, Speed = { 1.4, 1.55 } },
		},
		Swing3 = { -- the finisher: heavier, lower, with a thump as it lands
			{ Id = WOOSH_HEAVY, Volume = 0.55, Speed = { 0.88, 0.96 } },
			{ Id = WOOSH_SHORT, Volume = 0.35, Speed = { 0.78, 0.86 }, Eq = { High = -5 } },
			{ Id = WHOMP, Volume = 0.3, Speed = { 1.0, 1.1 }, Delay = 0.2 },
		},

		-- A hit landing on something.
		Hit = {
			{ Id = PUNCH, Volume = 0.45, Speed = { 0.95, 1.1 } },
			{ Id = THUD, Volume = 0.35, Speed = { 1.05, 1.2 } },
		},
		HitStrong = { -- a strong hit: lower, heavier, with a crack on top
			{ Id = PUNCH, Volume = 0.6, Speed = { 0.8, 0.9 } },
			{ Id = THUD, Volume = 0.5, Speed = { 0.9, 1.0 } },
			{ Id = STAFF, Volume = 0.22, Speed = { 1.1, 1.2 }, Eq = { High = -4 } },
		},
		PlayerHurt = { -- you taking a hit: a dull thud, not the sharp one
			{ Id = THUD, Volume = 0.5, Speed = { 0.9, 1.0 } },
		},

		-- Skills.
		DashWhoosh = {
			{ Id = WOOSH_HEAVY, Volume = 0.7, Speed = { 1.15, 1.25 } },
			{ Id = WOOSH_SHORT, Volume = 0.4, Speed = { 0.82, 0.9 }, Delay = 0.03, Eq = { High = -4 } },
		},
		LeapWhoosh = {
			{ Id = WOOSH_HEAVY, Volume = 0.45, Speed = { 1.35, 1.5 } },
		},
		DiveWhoosh = {
			{ Id = WOOSH_HEAVY, Volume = 0.6, Speed = { 0.72, 0.8 } },
			{ Id = WHIRL, Volume = 0.25, Speed = { 0.7, 0.8 }, Eq = { High = -3 } },
		},
		SlamLand = { -- the Sky Slam landing: a boom, a deep whomp, a crash and falling stones
			{ Id = EARTH, Volume = 0.9, Speed = { 0.95, 1.05 } },
			{ Id = WHOMP, Volume = 0.7, Speed = { 0.9, 1.0 } },
			{ Id = DIVE_END, Volume = 0.4, Speed = { 0.9, 1.0 }, Eq = { High = -3 } },
			{ Id = RUBBLE, Volume = 0.35, Speed = { 0.9, 1.1 }, Delay = 0.05 },
		},
		WaveRelease = {
			{ Id = WHIRL, Volume = 0.5, Speed = { 0.85, 0.95 } },
			{ Id = WOOSH_HEAVY, Volume = 0.45, Speed = { 0.9, 1.0 } },
		},
		WhirlSpin = { -- the swirl while spinning, cut off when the spin ends
			{ Id = CLOTH, Volume = 0.6, Speed = { 1.5, 1.6 }, Seconds = 0.95 },
		},
		WhirlTick = { -- a quick swish on each cut of the spin
			{ Id = WOOSH_SHORT, Volume = 0.32, Speed = { 1.15, 1.35 }, Eq = { High = -5 } },
		},
	},
}
