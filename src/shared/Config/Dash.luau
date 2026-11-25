-- The quick dash every player has, on the E key (no weapon needed). Read-only data; the server checks it all.
return {
	Key = Enum.KeyCode.E,
	Distance = 16, -- studs travelled
	Time = 0.35, -- seconds the dash lasts: about as long as the roll animation, so the body and the movement finish together
	Cooldown = 1.5, -- seconds before the next one
	Sound = "DashStep", -- a cue in Config/Sounds
	Animation = "Dash", -- a pose in Config/SwingAnimations
	-- Looks (your screen only): a faint white streak behind you, a dust puff, and a small camera zoom.
	StreakColor = Color3.new(1, 1, 1),
	StreakStart = 0.6, -- how see-through the streak is next to your body (1 = invisible)
	StreakSeconds = 0.25, -- how long the streak takes to fade
	FovKick = 4, -- degrees the camera zooms out at the start, then settles back
}
