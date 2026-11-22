-- Sound effects. Read-only data; the client plays them (client/Sounds.luau). Looks and rules are not affected.
-- A cue is a name for a moment ("Swing1", "SlamLand"). It plays one or more layers at once, like a real mix: a sharp
-- whoosh on top of a warm one, a punch on top of a deep thud. Every play picks a random pitch and a little
-- random volume inside the ranges below, so the same swing never sounds exactly the same twice.
--
-- A layer: Id (the sound), Volume (0 to 1), Speed (pitch and speed: 1 is normal, 0.8 is lower and slower;
--   give { low, high } to vary it every play), Delay (seconds before it starts), Seconds (cut it off after this
--   long, with a short fade), Start (skip this many seconds of the clip, to cut a silent lead-in), Eq = { Low, Mid, High } in dB (negative turns that part down: High = -6 softens a
--   harsh, hissy sound).
--
-- To change a sound, change its Id (a number from the Creator Store: create.roblox.com/store/audio). In Studio, press
-- [ and ] to step through every cue and hear each one (dev only, see client/Sounds.luau).
-- The basic swing: assets/audio/sword-swing.mp3, uploaded to Roblox (Creator Hub > Create > Audio). Paste its number here.
-- It is 0.84 s long but the first 0.2 s is silent, so the swings start it at Start = 0.17 to land on time.
local SWORD_SWING = "rbxassetid://129494434245898" -- "rbxassetid://<the number Roblox gives the upload>"
local DASH = "rbxassetid://109570025444455" -- skill 1 sword dash.mp3: 2.19 s, starts at 0.1 s
local WAVE = "rbxassetid://137534802780457" -- wave slash skill 3.mp3: 1.75 s, loud from the start
local WHIRLWIND = "rbxassetid://90083794106814" -- whirlwind skill 4.mp3: 13.4 s, so it is cut short
local HIT_FLESH = "rbxassetid://103504644351165" -- hit-flesh: a blow landing on flesh
local WOLF_BITE = "rbxassetid://103342523319170" -- bite wolf.mp3: 2.1 s, silent until 0.45 s, loudest at 0.65 s
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
		Swing1 = { { Id = SWORD_SWING, Volume = 0.9, Speed = { 0.97, 1.05 }, Start = 0.09 } },
		Swing2 = { { Id = SWORD_SWING, Volume = 0.9, Speed = { 1.03, 1.12 }, Start = 0.09 } }, -- the backhand: a touch higher
		Swing3 = { { Id = SWORD_SWING, Volume = 1, Speed = { 0.85, 0.92 }, Start = 0.05 } }, -- the finisher: lower and heavier

		-- The wolf's bite. The jaws snap shut 0.3 s after it starts, so the clip's silent lead-in is skipped.
		WolfBite = { { Id = WOLF_BITE, Volume = 1, Speed = { 0.95, 1.05 }, Start = 0.4, Seconds = 1.1 } },

		-- A hit landing on something.
		Hit = {
			{ Id = HIT_FLESH, Volume = 0.7, Speed = { 0.95, 1.08 } }, -- one flesh hit, so it never doubles up with a swing
		},
		HitStrong = { -- a strong hit: lower, heavier, with a crack on top
			{ Id = HIT_FLESH, Volume = 1, Speed = { 0.8, 0.9 } }, -- the same blow, lower and louder
		},
		PlayerHurt = { -- you taking a hit: a dull thud, not the sharp one
			{ Id = THUD, Volume = 0.5, Speed = { 0.9, 1.0 } },
		},

		-- Skills.
		DashWhoosh = {
			{ Id = DASH, Volume = 0.8, Start = 0.2, Seconds = 0.9 },
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
			{ Id = WAVE, Volume = 0.8, Seconds = 1.2 },
		},
		WhirlSpin = { -- cut off when the spin ends
			{ Id = WHIRLWIND, Volume = 0.8, Start = 0.9, Seconds = 1.4 },
		},
		WhirlTick = { -- a quick swish on each cut of the spin
			{ Id = WOOSH_SHORT, Volume = 0.32, Speed = { 1.15, 1.35 }, Eq = { High = -5 } },
		},
	},
}
