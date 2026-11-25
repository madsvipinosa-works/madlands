-- Code-made swing animations, keyed by name. Client feedback only; the server decides every hit.
-- Each keyframe: T = seconds from the start, Pose = joint name -> Vector3 of degrees (X, Y, Z).
-- Shift: not a joint, a Vector3 in STUDS that moves the whole body (forward is -Z, up is +Y), for lunges and sinking.
-- Joints: Root (whole body), Waist (torso twist), RightShoulder, LeftShoulder, RightElbow, LeftElbow,
-- RightHip, LeftHip, RightKnee, LeftKnee (the legs, for stepping into a swing).
--
-- For a limb hanging at rest (0 degrees):
--   Shoulder/Hip X: swings the limb forward. 90 = straight forward, 180 = straight up, 270 = straight back.
--     Negative counts the other way: -90 = straight back, -180 = straight up, -270 = straight forward.
--   Shoulder Z: swings the arm out sideways. Right arm: + is out to the right, - crosses the body.
--     Mirror the sign for the left arm. Elbow/Knee X bends the limb.
--   Waist/Root Y: turns the body left (+) or right (-). Root X: - leans forward, + leans back.
--
-- The sword is held pointing FORWARD from the fist when the arm hangs. Raising the arm forward (Shoulder X 90) tips it
-- to point straight UP; swinging the arm out to the side (Shoulder Z 90) keeps it pointing forward and level. So a
-- flat cut keeps the arm out to the side and turns the body (Waist/Root Y); an overhead chop raises the arm.
-- IMPORTANT: the limb travels through every angle between one keyframe and the next, so the numbers must
-- move the way the limb should. A chop winds up BACKWARDS (negative) and then keeps counting down, over the
-- head, to the strike: 0 -> -145 -> -305. Writing the same poses as 0 -> 215 -> 55 looks like a thrust,
-- because the arm then swings forward first to reach 215.
--
-- AssetId: once a move is published from the Animation Editor, paste its id here and Roblox plays it for
-- everyone. The poses below are then only a fallback for moves that have no id yet.
--
-- TrailStart/TrailSeconds: when the blade trail shows, so it marks the cut instead of the whole move.
-- Release (Wave skills only): seconds into the move when the wave leaves the sword. Defaults to TrailStart.
--
-- Between keyframes the pose eases out, unless the keyframe sets Ease = "In" | "InOut" | "Linear" (how the body gets
-- TO that keyframe). Wind-ups use InOut, the strike itself uses In so it speeds up into the cut, follow-through uses Out.
-- Joints left out of a pose go back to rest. The last keyframe ends the move.
local V = Vector3.new

return {
	-- The three basic swings, played in turn: two crossing diagonal cuts, then an overhead finisher.
	-- The weapon lists them in order (Config/Weapons, SwingCombo).
	-- Extra fields for the basic swings:
	--   HitDelay: seconds into the move when the server lands the hit, as the blade crosses in front of you.
	--   Slash: the crescent mesh (same as the Wave Slash) that flashes with the cut. Delay = seconds into the move; Angle = tilt in degrees
	--     (0 flat, 45 diagonal, 90 upright; "/" when positive); Flip = not used; Size = studs wide;
	--     Height = studs above your middle; Ahead = studs in front of you.
	-- The published animations these replace (Animation Editor) were: Swing1 103014564454913, Swing2 111661814697041,
	-- Swing3 110914323852572. Paste an id back into AssetId to use a published version again.
	Swing1 = { -- wide diagonal cut from the upper right, down across to the lower left, lunging in on the left leg
		AssetId = "",
		TrailStart = 0.1, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.2,
		HitDelay = 0.17,
		Slash = { Delay = 0.12, Angle = 28, Flip = true, Size = 12, Height = 1.4, Ahead = 3.6 },
		Duration = 0.5,
		Keyframes = {
			{ T = 0.09, Ease = "InOut", Pose = { RightShoulder = V(40, 0, 98.56), RightElbow = V(20, 0, 0), LeftShoulder = V(15, 0, -35), Waist = V(0, -88.5, 0), Root = V(-6.9, -27.5, 0), Shift = V(0.36, -0.54, 0.9), RightHip = V(-28.6, 0, 13.2), RightKnee = V(-15, 0, 0), LeftHip = V(23.4, 0, -13.2), LeftKnee = V(-31.25, 0, 0) } }, -- wind-up, weight back, body wound right
			{ T = 0.2, Ease = "In", Pose = { RightShoulder = V(-5, 0, 50.4), RightElbow = V(8, 0, 0), LeftShoulder = V(10, 0, -45), Waist = V(0, 92.04, 0), Root = V(-13.8, 32.5, 0), Shift = V(-0.36, -1.26, -1.8), RightHip = V(-32.5, 0, 17.6), RightKnee = V(-25, 0, 0), LeftHip = V(45.5, 0, -17.6), LeftKnee = V(-56.25, 0, 0) } }, -- the cut: lunge onto the left leg, rear leg trailing
			{ T = 0.3, Pose = { RightShoulder = V(-12, 0, 42.56), RightElbow = V(8, 0, 0), LeftShoulder = V(10, 0, -45), Waist = V(0, 103.84, 0), Root = V(-11.5, 37.5, 0), Shift = V(-0.36, -1.35, -1.98), RightHip = V(-32.5, 0, 17.6), RightKnee = V(-25, 0, 0), LeftHip = V(45.5, 0, -17.6), LeftKnee = V(-56.25, 0, 0) } }, -- follow-through, held in the lunge
			{ T = 0.5, Ease = "InOut", Pose = {} },
		},
	},
	Swing2 = { -- the backhand: wide crossing cut from the upper left, down across to the lower right, lunging in on the right leg
		AssetId = "",
		TrailStart = 0.1,
		TrailSeconds = 0.2,
		HitDelay = 0.17,
		Slash = { Delay = 0.12, Angle = -28, Flip = false, Size = 12, Height = 1.4, Ahead = 3.6 },
		Duration = 0.5,
		Keyframes = {
			{ T = 0.09, Ease = "InOut", Pose = { RightShoulder = V(40, 0, -69.44), RightElbow = V(35, 0, 0), LeftShoulder = V(10, 0, -25), Waist = V(0, 88.5, 0), Root = V(-6.9, 27.5, 0), Shift = V(-0.36, -0.54, 0.9), LeftHip = V(-28.6, 0, -13.2), LeftKnee = V(-15, 0, 0), RightHip = V(23.4, 0, 13.2), RightKnee = V(-31.25, 0, 0) } }, -- wind-up, weight back, body wound left
			{ T = 0.2, Ease = "In", Pose = { RightShoulder = V(0, 0, 87.36), RightElbow = V(8, 0, 0), LeftShoulder = V(10, 0, -30), Waist = V(0, -92.04, 0), Root = V(-13.8, -32.5, 0), Shift = V(0.36, -1.26, -1.8), LeftHip = V(-32.5, 0, -17.6), LeftKnee = V(-25, 0, 0), RightHip = V(45.5, 0, 17.6), RightKnee = V(-56.25, 0, 0) } }, -- the cut: lunge onto the right leg
			{ T = 0.3, Pose = { RightShoulder = V(-6, 0, 94.08), RightElbow = V(8, 0, 0), LeftShoulder = V(10, 0, -30), Waist = V(0, -103.84, 0), Root = V(-11.5, -37.5, 0), Shift = V(0.36, -1.35, -1.98), LeftHip = V(-32.5, 0, -17.6), LeftKnee = V(-25, 0, 0), RightHip = V(45.5, 0, 17.6), RightKnee = V(-56.25, 0, 0) } },
			{ T = 0.5, Ease = "InOut", Pose = {} },
		},
	},
	Swing3 = { -- finisher: sword cocked high behind the head, then a one-handed chop straight down in a deep lunge
		AssetId = "",
		TrailStart = 0.16,
		TrailSeconds = 0.22,
		HitDelay = 0.25,
		Slash = { Delay = 0.2, Angle = 90, Flip = true, Size = 13, Height = 1.6, Ahead = 3.8 },
		Duration = 0.62,
		Keyframes = {
			{ T = 0.14, Ease = "InOut", Pose = { RightShoulder = V(-165, 0, 14), RightElbow = V(50, 0, 0), LeftShoulder = V(-35, 0, -60), Waist = V(0, -23.6, 0), Root = V(20.7, 0, 0), Shift = V(0, -0.36, 1.26), RightHip = V(-26, 0, 13.2), LeftHip = V(18.2, 0, -13.2), RightKnee = V(-12.5, 0, 0), LeftKnee = V(-22.5, 0, 0) } }, -- cock the sword back, arched, weight back
			{ T = 0.26, Ease = "In", Pose = { RightShoulder = V(-322, 0, 5), RightElbow = V(5, 0, 0), LeftShoulder = V(-35, 0, -45), Waist = V(0, 14.16, 0), Root = V(-34.5, 0, 0), Shift = V(0, -1.62, -2.7), RightHip = V(54.6, 0, 17.6), RightKnee = V(-65, 0, 0), LeftHip = V(-36.4, 0, -17.6), LeftKnee = V(-27.5, 0, 0) } }, -- the chop, a deep lunge forward on the right leg
			{ T = 0.36, Pose = { RightShoulder = V(-330, 0, 5), LeftShoulder = V(-25, 0, -40), Waist = V(0, 18.88, 0), Root = V(-39.1, 0, 0), Shift = V(0, -1.8, -2.88), RightHip = V(57.2, 0, 17.6), RightKnee = V(-70, 0, 0), LeftHip = V(-39, 0, -17.6), LeftKnee = V(-30, 0, 0) } }, -- sink into it
			{ T = 0.46, Pose = { RightShoulder = V(-328, 0, 5), LeftShoulder = V(-20, 0, -35), Root = V(-29.9, 0, 0), Shift = V(0, -1.62, -2.7), RightHip = V(52, 0, 17.6), RightKnee = V(-62.5, 0, 0), LeftHip = V(-33.8, 0, -17.6), LeftKnee = V(-27.5, 0, 0) } },
			{ T = 0.62, Ease = "InOut", Pose = { RightShoulder = V(-360, 0, 0) } }, -- -360 is rest again, so the arm finishes the circle
		},
	},
	-- The E dash (Config/Dash): a dodge roll. Duck low, tuck into a fast forward somersault through the burst, land in a crouch
	-- and stand up. Root counts down -360 for the full turn (-360 is rest again), like the Whirlwind's spin.
	Dash = {
		AssetId = "",
		Duration = 0.55,
		Keyframes = {
			{ T = 0.05, Ease = "Out", Pose = { Root = V(-50, 0, 0), Shift = V(0, -1.4, -0.6), RightShoulder = V(60, 0, 15), LeftShoulder = V(60, 0, -15), RightElbow = V(70, 0, 0), LeftElbow = V(70, 0, 0), RightHip = V(80, 0, 0), LeftHip = V(80, 0, 0), RightKnee = V(-95, 0, 0), LeftKnee = V(-95, 0, 0) } }, -- duck and tuck
			{ T = 0.15, Ease = "Linear", Pose = { Root = V(-190, 0, 0), Shift = V(0, -1.5, -1), RightShoulder = V(60, 0, 15), LeftShoulder = V(60, 0, -15), RightElbow = V(70, 0, 0), LeftElbow = V(70, 0, 0), RightHip = V(95, 0, 0), LeftHip = V(95, 0, 0), RightKnee = V(-110, 0, 0), LeftKnee = V(-110, 0, 0) } }, -- over the top, tight ball
			{ T = 0.26, Ease = "Linear", Pose = { Root = V(-330, 0, 0), Shift = V(0, -1.4, -0.6), RightShoulder = V(40, 0, 15), LeftShoulder = V(40, 0, -15), RightElbow = V(50, 0, 0), LeftElbow = V(50, 0, 0), RightHip = V(70, 0, 0), LeftHip = V(70, 0, 0), RightKnee = V(-85, 0, 0), LeftKnee = V(-85, 0, 0) } }, -- coming round
			{ T = 0.31, Pose = { Root = V(-360, 0, 0), Shift = V(0, -1.2, -0.4), RightShoulder = V(30, 0, 20), LeftShoulder = V(30, 0, -20), RightElbow = V(30, 0, 0), LeftElbow = V(30, 0, 0), RightHip = V(60, 0, 0), LeftHip = V(45, 0, 0), RightKnee = V(-80, 0, 0), LeftKnee = V(-60, 0, 0) } }, -- land in a crouch
			{ T = 0.55, Ease = "InOut", Pose = { Root = V(-360, 0, 0) } }, -- stand up (-360 is upright: staying at it, not going back to 0, keeps the body from rolling backwards)
		},
	},
	-- The four sword skills. They have no published AssetId yet, so these poses are what plays.
	DashSlash = { -- coil low with the blade level, burst through the target in one flat sideways cut, then slide to a low stop
		AssetId = "",
		TrailStart = 0.04, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.3,
		Duration = 0.7,
		Keyframes = {
			{ T = 0.05, Pose = { RightShoulder = V(12, 0, 85), RightElbow = V(25, 0, 0), LeftShoulder = V(-25, 0, -18), Waist = V(0, -60, 0), Root = V(-22, -12, 0), RightHip = V(-25, 0, 0), RightKnee = V(-15, 0, 0), LeftHip = V(20, 0, 0), LeftKnee = V(-22, 0, 0) } }, -- coil, free arm swung back
			{ T = 0.13, Ease = "In", Pose = { RightShoulder = V(20, 0, 60), RightElbow = V(8, 0, 0), LeftShoulder = V(25, 0, -32), Waist = V(0, 65, 0), Root = V(-26, 14, 0), RightHip = V(28, 0, 0), RightKnee = V(-30, 0, 0), LeftHip = V(-18, 0, 0), LeftKnee = V(-8, 0, 0) } }, -- the cut
			{ T = 0.26, Pose = { RightShoulder = V(24, 0, 48), RightElbow = V(8, 0, 0), LeftShoulder = V(18, 0, -35), Waist = V(0, 78, 0), Root = V(-22, 18, 0), RightHip = V(20, 0, 0), RightKnee = V(-25, 0, 0), LeftHip = V(-10, 0, 0) } }, -- follow-through
			{ T = 0.36, Pose = { RightShoulder = V(22, 0, 50), RightElbow = V(8, 0, 0), LeftShoulder = V(14, 0, -30), Waist = V(0, 70, 0), Root = V(-18, 14, 0), RightHip = V(22, 0, 0), RightKnee = V(-35, 0, 0), LeftHip = V(-14, 0, 0), LeftKnee = V(-30, 0, 0) } }, -- sink into the slide as the rush ends
			{ T = 0.5, Pose = { RightShoulder = V(22, 0, 50), Waist = V(0, 64, 0), Root = V(-12, 10, 0) } }, -- hold the pose a beat
			{ T = 0.7, Ease = "InOut", Pose = {} },
		},
	},
	Skyfall = { -- quick crouch, leap with the sword cocked high behind the head (one-handed, the free arm out for balance), then dive and chop straight down into the ground
		AssetId = "",
		TrailStart = 0.4, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.3,
		Duration = 0.95,
		Keyframes = {
			{ T = 0.06, Ease = "InOut", Pose = { RightShoulder = V(-30, 0, 14), LeftShoulder = V(-25, 0, -14), Root = V(-22, 0, 0), RightHip = V(35, 0, 0), LeftHip = V(35, 0, 0), RightKnee = V(-65, 0, 0), LeftKnee = V(-65, 0, 0) } }, -- crouch, arms swung back (the leap starts here)
			{ T = 0.18, Pose = { RightShoulder = V(-155, 0, 14), RightElbow = V(40, 0, 0), LeftShoulder = V(-35, 0, -60), Root = V(18, 0, 0), RightHip = V(-10, 0, 0), LeftHip = V(10, 0, 0), RightKnee = V(-50, 0, 0), LeftKnee = V(-30, 0, 0) } }, -- launch, sword arm flung up, legs tucked
			{ T = 0.3, Ease = "InOut", Pose = { RightShoulder = V(-168, 0, 14), RightElbow = V(45, 0, 0), LeftShoulder = V(-20, 0, -75), Root = V(22, 0, 0), RightHip = V(-5, 0, 0), RightKnee = V(-40, 0, 0), LeftKnee = V(-25, 0, 0) } }, -- rising to the top
			{ T = 0.42, Ease = "InOut", Pose = { RightShoulder = V(-178, 0, 14), RightElbow = V(55, 0, 0), LeftShoulder = V(-10, 0, -70), Root = V(30, 0, 0), RightHip = V(-12, 0, 0), LeftHip = V(-8, 0, 0), RightKnee = V(-30, 0, 0), LeftKnee = V(-22, 0, 0) } }, -- the top: sword cocked back, body arched, the dive starts
			{ T = 0.55, Ease = "In", Pose = { RightShoulder = V(-322, 0, 5), RightElbow = V(5, 0, 0), LeftShoulder = V(-35, 0, -45), Root = V(-34, 0, 0), RightHip = V(24, 0, 0), LeftHip = V(24, 0, 0), RightKnee = V(-30, 0, 0), LeftKnee = V(-30, 0, 0) } }, -- the chop, landing on it
			{ T = 0.65, Pose = { RightShoulder = V(-330, 0, 5), LeftShoulder = V(-25, 0, -40), Root = V(-38, 0, 0), RightHip = V(34, 0, 0), LeftHip = V(34, 0, 0), RightKnee = V(-52, 0, 0), LeftKnee = V(-52, 0, 0) } }, -- sink into the impact
			{ T = 0.78, Pose = { RightShoulder = V(-328, 0, 5), LeftShoulder = V(-20, 0, -35), Root = V(-30, 0, 0), RightHip = V(28, 0, 0), LeftHip = V(28, 0, 0), RightKnee = V(-42, 0, 0), LeftKnee = V(-42, 0, 0) } }, -- hold
			{ T = 0.95, Ease = "InOut", Pose = { RightShoulder = V(-360, 0, 0) } },
		},
	},
	WaveSlash = { -- sword hand crossed to the left with the blade level, then the whole body turns to sweep it flat across the front to the right
		AssetId = "",
		TrailStart = 0.24, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.2,
		Release = 0.29, -- the wave leaves the sword here; the blade passes straight ahead at about 0.31 on your screen, so this is a hair early to cover the message delay
		Duration = 0.78,
		Keyframes = {
			{ T = 0.22, Ease = "InOut", Pose = { RightShoulder = V(8, 0, -55), RightElbow = V(35, 0, 0), LeftShoulder = V(10, 0, -25), Waist = V(0, 66, 0), Root = V(-6, 20, 0), LeftHip = V(-15, 0, 0), RightHip = V(12, 0, 0), LeftKnee = V(-8, 0, 0) } }, -- wind-up, body turned left
			{ T = 0.34, Ease = "In", Pose = { RightShoulder = V(12, 0, 62), RightElbow = V(8, 0, 0), LeftShoulder = V(10, 0, -30), Waist = V(0, -58, 0), Root = V(-10, -22, 0), LeftHip = V(20, 0, 0), LeftKnee = V(-20, 0, 0), RightHip = V(-12, 0, 0) } }, -- the sweep
			{ T = 0.44, Pose = { RightShoulder = V(14, 0, 66), RightElbow = V(8, 0, 0), Waist = V(0, -64, 0), Root = V(-8, -24, 0) } }, -- follow-through
			{ T = 0.56, Pose = { RightShoulder = V(12, 0, 64), Waist = V(0, -58, 0), Root = V(-6, -20, 0) } },
			{ T = 0.78, Ease = "InOut", Pose = {} },
		},
	},
	Whirlwind = { -- crouch and counter-wind, then three steady full spins, leaning into them, with the sword held straight out
		AssetId = "",
		TrailStart = 0.16, -- seconds into the move when the blade starts cutting
		TrailSeconds = 1.06,
		Duration = 1.5,
		Keyframes = {
			{ T = 0.12, Ease = "InOut", Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-14, -35, 0), RightHip = V(20, 0, 0), LeftHip = V(20, 0, 0), RightKnee = V(-40, 0, 0), LeftKnee = V(-40, 0, 0) } }, -- crouch, wound back
			{ T = 0.66, Ease = "Linear", Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-16, 540, 0), RightKnee = V(-15, 0, 0), LeftKnee = V(-15, 0, 0) } },
			{ T = 1.2, Ease = "Linear", Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-16, 1080, 0), RightKnee = V(-15, 0, 0), LeftKnee = V(-15, 0, 0) } },
			{ T = 1.32, Pose = { RightShoulder = V(30, 0, 40), LeftShoulder = V(30, 0, -35), Root = V(-22, 1080, 0), RightHip = V(18, 0, 0), LeftHip = V(18, 0, 0), RightKnee = V(-35, 0, 0), LeftKnee = V(-35, 0, 0) } }, -- land from the spin
			{ T = 1.5, Ease = "InOut", Pose = { Root = V(0, 1080, 0) } }, -- 1080 is facing the same way again
		},
	},
}
