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
-- IMPORTANT: the limb travels through every angle between one keyframe and the next, so the numbers must
-- move the way the limb should. A chop winds up BACKWARDS (negative) and then keeps counting down, over the
-- head, to the strike: 0 -> -145 -> -305. Writing the same poses as 0 -> 215 -> 55 looks like a thrust,
-- because the arm then swings forward first to reach 215.
--
-- AssetId: once a move is published from the Animation Editor, paste its id here and Roblox plays it for
-- everyone. The poses below are then only a fallback for moves that have no id yet.
--
-- TrailStart/TrailSeconds: when the blade trail shows, so it marks the cut instead of the whole move.
--
-- Between keyframes the pose eases out. Joints left out of a pose go back to rest. The last keyframe ends the move.
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
	DashSlash = { -- flat sideways cut while rushing through the target: no wind-up over the head
		AssetId = "",
		TrailStart = 0.08, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.26,
		Duration = 0.55,
		Keyframes = {
			{ T = 0.08, Pose = { RightShoulder = V(110, 0, 75), RightElbow = V(50, 0, 0), LeftShoulder = V(12, 0, -12), Waist = V(0, -45, 0), Root = V(-30, 0, 0), RightHip = V(-20, 0, 0) } },
			{ T = 0.20, Pose = { RightShoulder = V(95, 0, -55), RightElbow = V(8, 0, 0), LeftShoulder = V(20, 0, -15), Waist = V(0, 55, 0), Root = V(-38, 0, 0), RightHip = V(25, 0, 0), RightKnee = V(-30, 0, 0) } },
			{ T = 0.32, Pose = { RightShoulder = V(85, 0, -70), RightElbow = V(8, 0, 0), LeftShoulder = V(16, 0, -12), Waist = V(0, 65, 0), Root = V(-28, 0, 0) } },
			{ T = 0.55, Pose = {} },
		},
	},
	Skyfall = { -- crouch, leap, sword high behind the head, then chop straight down as you land
		AssetId = "",
		TrailStart = 0.46, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.25,
		Duration = 0.9,
		Keyframes = {
			{ T = 0.12, Pose = { RightShoulder = V(-25, 0, 12), LeftShoulder = V(-20, 0, -12), Root = V(-12, 0, 0), RightKnee = V(-35, 0, 0), LeftKnee = V(-35, 0, 0) } },
			{ T = 0.34, Pose = { RightShoulder = V(-152, 0, 12), RightElbow = V(35, 0, 0), LeftShoulder = V(-162, 0, -12), Root = V(15, 0, 0), RightKnee = V(-45, 0, 0) } },
			{ T = 0.50, Pose = { RightShoulder = V(-155, 0, 12), RightElbow = V(35, 0, 0), LeftShoulder = V(-165, 0, -12), Root = V(15, 0, 0), RightKnee = V(-45, 0, 0) } },
			{ T = 0.62, Pose = { RightShoulder = V(-322, 0, 5), RightElbow = V(5, 0, 0), LeftShoulder = V(-315, 0, -5), Root = V(-32, 0, 0), RightHip = V(22, 0, 0), RightKnee = V(-30, 0, 0) } }, -- the slam, as you land
			{ T = 0.74, Pose = { RightShoulder = V(-322, 0, 5), RightElbow = V(5, 0, 0), LeftShoulder = V(-315, 0, -5), Root = V(-30, 0, 0), RightHip = V(18, 0, 0) } },
			{ T = 0.90, Pose = { RightShoulder = V(-360, 0, 0), LeftShoulder = V(-360, 0, 0) } },
		},
	},
	WaveSlash = { -- big diagonal cut, from high behind the right shoulder down across to the left
		AssetId = "",
		TrailStart = 0.18, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.26,
		Duration = 0.65,
		Keyframes = {
			{ T = 0.17, Pose = { RightShoulder = V(-160, 0, 55), RightElbow = V(45, 0, 0), LeftShoulder = V(12, 0, -12), Waist = V(0, -50, 0), RightHip = V(-20, 0, 0) } },
			{ T = 0.30, Pose = { RightShoulder = V(-300, 0, -45), RightElbow = V(8, 0, 0), LeftShoulder = V(8, 0, -6), Waist = V(0, 58, 0), Root = V(-14, 12, 0), RightHip = V(22, 0, 0), RightKnee = V(-25, 0, 0) } },
			{ T = 0.40, Pose = { RightShoulder = V(-315, 0, -60), RightElbow = V(8, 0, 0), Waist = V(0, 66, 0), Root = V(-10, 14, 0) } },
			{ T = 0.65, Pose = { RightShoulder = V(-360, 0, 0) } },
		},
	},
	Whirlwind = { -- sword held straight out, two full spins (720 degrees ends facing the same way)
		AssetId = "",
		TrailStart = 0.14, -- seconds into the move when the blade starts cutting
		TrailSeconds = 0.66,
		Duration = 1.0,
		Keyframes = {
			{ T = 0.14, Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-10, 0, 0), RightKnee = V(-25, 0, 0) } },
			{ T = 0.78, Pose = { RightShoulder = V(10, 0, 85), LeftShoulder = V(10, 0, -75), RightElbow = V(5, 0, 0), Root = V(-10, 720, 0) } },
			{ T = 1.0, Pose = { Root = V(0, 720, 0) } },
		},
	},
}
