-- Code-made swing animations, keyed by name. Client feedback only; the server decides every hit.
-- Each keyframe: T = seconds from the start, Pose = joint name -> Vector3 of degrees (X, Y, Z).
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
	-- The three basic swings, played in turn: right to left, back again, then an overhead finisher.
	-- The weapon lists them in order (Config/Weapons, SwingCombo).
	Swing1 = { -- flat cut from the right, stepping in
		AssetId = "rbxassetid://103014564454913",
		TrailStart = 0.1, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.25,
		Duration = 0.5,
		Keyframes = {
			{ T = 0.10, Pose = { RightShoulder = V(85, 0, 70), RightElbow = V(35, 0, 0), LeftShoulder = V(12, 0, -12), Waist = V(0, -55, 0), Root = V(-10, -12, 0), RightHip = V(-15, 0, 0), LeftHip = V(10, 0, 0) } },
			{ T = 0.22, Pose = { RightShoulder = V(92, 0, -55), RightElbow = V(8, 0, 0), LeftShoulder = V(8, 0, -6), Waist = V(0, 55, 0), Root = V(-16, 15, 0), RightHip = V(18, 0, 0), RightKnee = V(-20, 0, 0), LeftHip = V(-12, 0, 0) } },
			{ T = 0.30, Pose = { RightShoulder = V(88, 0, -72), RightElbow = V(8, 0, 0), Waist = V(0, 65, 0), Root = V(-12, 18, 0) } },
			{ T = 0.50, Pose = {} },
		},
	},
	Swing2 = { -- the backhand: the same cut coming back from the left
		AssetId = "rbxassetid://111661814697041",
		TrailStart = 0.1, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.25,
		Duration = 0.5,
		Keyframes = {
			{ T = 0.10, Pose = { RightShoulder = V(80, 0, -60), RightElbow = V(40, 0, 0), LeftShoulder = V(8, 0, -6), Waist = V(0, 50, 0), Root = V(-10, 12, 0), LeftHip = V(-15, 0, 0) } },
			{ T = 0.22, Pose = { RightShoulder = V(95, 0, 65), RightElbow = V(8, 0, 0), LeftShoulder = V(14, 0, -14), Waist = V(0, -55, 0), Root = V(-16, -15, 0), LeftHip = V(18, 0, 0), LeftKnee = V(-20, 0, 0) } },
			{ T = 0.30, Pose = { RightShoulder = V(90, 0, 78), RightElbow = V(8, 0, 0), Waist = V(0, -62, 0), Root = V(-12, -18, 0) } },
			{ T = 0.50, Pose = {} },
		},
	},
	Swing3 = { -- finisher: wind up behind the shoulder, chop down with the whole body
		AssetId = "rbxassetid://110914323852572",
		TrailStart = 0.14, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.25,
		Duration = 0.55,
		Keyframes = {
			{ T = 0.12, Pose = { RightShoulder = V(-145, 0, 20), RightElbow = V(45, 0, 0), LeftShoulder = V(10, 0, -8), Waist = V(0, -30, 0), Root = V(8, 0, 0), RightHip = V(-18, 0, 0) } },
			{ T = 0.24, Pose = { RightShoulder = V(-305, 0, -15), RightElbow = V(10, 0, 0), LeftShoulder = V(10, 0, -5), Waist = V(0, 35, 0), Root = V(-22, 0, 0), RightHip = V(20, 0, 0), RightKnee = V(-25, 0, 0) } },
			{ T = 0.33, Pose = { RightShoulder = V(-325, 0, -25), RightElbow = V(8, 0, 0), Waist = V(0, 42, 0), Root = V(-18, 0, 0) } },
			{ T = 0.55, Pose = { RightShoulder = V(-360, 0, 0) } }, -- -360 is rest again, so the arm finishes the circle
		},
	},
	-- The four sword skills. They have no published AssetId yet, so these poses are what plays.
	DashSlash = { -- coil low with the blade level, then rush through the target in one flat sideways cut and follow it through
		AssetId = "",
		TrailStart = 0.06, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.3,
		Duration = 0.6,
		Keyframes = {
			{ T = 0.05, Pose = { RightShoulder = V(12, 0, 85), RightElbow = V(25, 0, 0), LeftShoulder = V(14, 0, -25), Waist = V(0, -60, 0), Root = V(-22, -12, 0), RightHip = V(-25, 0, 0), RightKnee = V(-15, 0, 0), LeftHip = V(20, 0, 0), LeftKnee = V(-10, 0, 0) } }, -- coil
			{ T = 0.13, Ease = "In", Pose = { RightShoulder = V(20, 0, 60), RightElbow = V(8, 0, 0), LeftShoulder = V(18, 0, -40), Waist = V(0, 65, 0), Root = V(-26, 14, 0), RightHip = V(28, 0, 0), RightKnee = V(-30, 0, 0), LeftHip = V(-18, 0, 0) } }, -- the cut
			{ T = 0.26, Pose = { RightShoulder = V(24, 0, 48), RightElbow = V(8, 0, 0), LeftShoulder = V(18, 0, -35), Waist = V(0, 78, 0), Root = V(-22, 18, 0), RightHip = V(20, 0, 0), RightKnee = V(-25, 0, 0), LeftHip = V(-10, 0, 0) } }, -- follow-through
			{ T = 0.4, Pose = { RightShoulder = V(22, 0, 50), Waist = V(0, 64, 0), Root = V(-14, 12, 0) } }, -- hold the pose a beat
			{ T = 0.6, Ease = "InOut", Pose = {} },
		},
	},
	Skyfall = { -- crouch, launch with the sword high behind the head, hang, then chop straight down as you land
		AssetId = "",
		TrailStart = 0.48,
		TrailSeconds = 0.25,
		Duration = 1.0,
		Keyframes = {
			{ T = 0.1, Ease = "InOut", Pose = { RightShoulder = V(-20, 0, 14), LeftShoulder = V(-15, 0, -14), Root = V(-18, 0, 0), RightHip = V(28, 0, 0), LeftHip = V(28, 0, 0), RightKnee = V(-55, 0, 0), LeftKnee = V(-55, 0, 0) } }, -- crouch
			{ T = 0.3, Pose = { RightShoulder = V(-155, 0, 14), RightElbow = V(40, 0, 0), LeftShoulder = V(-165, 0, -14), Root = V(18, 0, 0), RightHip = V(-10, 0, 0), LeftHip = V(10, 0, 0), RightKnee = V(-50, 0, 0), LeftKnee = V(-30, 0, 0) } }, -- launch, legs tucked
			{ T = 0.5, Ease = "InOut", Pose = { RightShoulder = V(-168, 0, 14), RightElbow = V(45, 0, 0), LeftShoulder = V(-170, 0, -14), Root = V(22, 0, 0), RightHip = V(-5, 0, 0), RightKnee = V(-40, 0, 0), LeftKnee = V(-25, 0, 0) } }, -- hang at the top
			{ T = 0.6, Ease = "In", Pose = { RightShoulder = V(-322, 0, 5), RightElbow = V(5, 0, 0), LeftShoulder = V(-315, 0, -5), Root = V(-32, 0, 0), RightHip = V(22, 0, 0), LeftHip = V(22, 0, 0), RightKnee = V(-30, 0, 0), LeftKnee = V(-30, 0, 0) } }, -- the slam, as you land
			{ T = 0.72, Pose = { RightShoulder = V(-330, 0, 5), LeftShoulder = V(-325, 0, -5), Root = V(-36, 0, 0), RightHip = V(32, 0, 0), LeftHip = V(32, 0, 0), RightKnee = V(-48, 0, 0), LeftKnee = V(-48, 0, 0) } }, -- sink into the impact
			{ T = 1.0, Ease = "InOut", Pose = { RightShoulder = V(-360, 0, 0), LeftShoulder = V(-360, 0, 0) } },
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
	Whirlwind = { -- crouch and counter-wind, then two steady full spins with the sword held straight out
		AssetId = "",
		TrailStart = 0.2, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.62,
		Duration = 1.1,
		Keyframes = {
			{ T = 0.12, Ease = "InOut", Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-14, -35, 0), RightHip = V(20, 0, 0), LeftHip = V(20, 0, 0), RightKnee = V(-40, 0, 0), LeftKnee = V(-40, 0, 0) } }, -- crouch, wound back
			{ T = 0.46, Ease = "Linear", Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-8, 330, 0), RightKnee = V(-15, 0, 0), LeftKnee = V(-15, 0, 0) } },
			{ T = 0.8, Ease = "Linear", Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-8, 720, 0), RightKnee = V(-15, 0, 0), LeftKnee = V(-15, 0, 0) } },
			{ T = 0.92, Pose = { RightShoulder = V(30, 0, 40), LeftShoulder = V(30, 0, -35), Root = V(-22, 720, 0), RightHip = V(18, 0, 0), LeftHip = V(18, 0, 0), RightKnee = V(-35, 0, 0), LeftKnee = V(-35, 0, 0) } }, -- land from the spin
			{ T = 1.1, Ease = "InOut", Pose = { Root = V(0, 720, 0) } }, -- 720 is facing the same way again
		},
	},
}
