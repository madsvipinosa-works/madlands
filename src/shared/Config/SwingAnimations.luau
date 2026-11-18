-- Code-made swing animations, keyed by name. Client feedback only; the server decides every hit.
-- Each keyframe: T = seconds from the start, Pose = joint name -> Vector3 of degrees (X, Y, Z).
-- Joints: Root (whole body), Waist (torso twist), RightShoulder, LeftShoulder, RightElbow, LeftElbow.
-- Shoulder X raises the arm forward, Z moves it out to the side. Waist/Root Y turns left (+) or right (-). Root X leans.
-- Between keyframes the pose eases out. Joints left out of a pose go back to rest. The last keyframe ends the animation.
local V = Vector3.new

return {
	Swing = { -- the basic click swing
		Duration = 0.35,
		Keyframes = {
			{ T = 0.10, Pose = { RightShoulder = V(130, 0, 30), RightElbow = V(40, 0, 0), Waist = V(0, -25, 0) } },
			{ T = 0.20, Pose = { RightShoulder = V(55, 0, -15), RightElbow = V(15, 0, 0), Waist = V(0, 30, 0) } },
			{ T = 0.35, Pose = {} },
		},
	},
	DashSlash = { -- lean forward and cut across while rushing through
		Duration = 0.45,
		Keyframes = {
			{ T = 0.06, Pose = { RightShoulder = V(100, 0, 55), RightElbow = V(40, 0, 0), Waist = V(0, -40, 0), Root = V(-25, 0, 0) } },
			{ T = 0.18, Pose = { RightShoulder = V(80, 0, -45), RightElbow = V(10, 0, 0), Waist = V(0, 55, 0), Root = V(-30, 0, 0) } },
			{ T = 0.45, Pose = {} },
		},
	},
	Skyfall = { -- sword raised overhead while in the air, then chopped down to the ground
		Duration = 0.8,
		Keyframes = {
			{ T = 0.30, Pose = { RightShoulder = V(175, 0, 10), RightElbow = V(35, 0, 0), LeftShoulder = V(150, 0, -10), Root = V(12, 0, 0) } },
			{ T = 0.58, Pose = { RightShoulder = V(25, 0, 0), RightElbow = V(5, 0, 0), LeftShoulder = V(40, 0, 0), Root = V(-28, 0, 0) } },
			{ T = 0.80, Pose = {} },
		},
	},
	WaveSlash = { -- a big sideways-to-diagonal cut that sends out the wave
		Duration = 0.55,
		Keyframes = {
			{ T = 0.14, Pose = { RightShoulder = V(120, 0, 65), RightElbow = V(45, 0, 0), Waist = V(0, -50, 0) } },
			{ T = 0.26, Pose = { RightShoulder = V(85, 0, -45), RightElbow = V(8, 0, 0), Waist = V(0, 60, 0), Root = V(0, 10, 0) } },
			{ T = 0.55, Pose = {} },
		},
	},
	Whirlwind = { -- arms out, two full spins (720 degrees looks the same as standing still)
		Duration = 0.9,
		Keyframes = {
			{ T = 0.10, Pose = { RightShoulder = V(90, 0, 80), LeftShoulder = V(90, 0, -80), RightElbow = V(10, 0, 0) } },
			{ T = 0.70, Pose = { RightShoulder = V(90, 0, 80), LeftShoulder = V(90, 0, -80), RightElbow = V(10, 0, 0), Root = V(0, 720, 0) } },
			{ T = 0.90, Pose = { Root = V(0, 720, 0) } },
		},
	},
}
