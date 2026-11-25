-- The quick dash every player has, on the E key (no weapon needed). Read-only data; the server checks it all.
return {
	Key = Enum.KeyCode.E,
	Distance = 16, -- studs travelled
	Time = 0.25, -- seconds the dash lasts: it starts very fast and slows to a stop, so it reads as a burst, not a run
	Cooldown = 1.5, -- seconds before the next one
	Sound = "DashStep", -- a cue in Config/Sounds
	Animation = "Dash", -- a pose in Config/SwingAnimations
	-- Looks (your screen only): ghost copies of the body left behind, a dust puff, and a short zoom of the camera.
	GhostEvery = 0.05, -- seconds between ghosts
	GhostSeconds = 0.3, -- how long a ghost takes to fade
	GhostColor = Color3.fromRGB(150, 205, 255),
	FovKick = 10, -- degrees the camera zooms out at the start, then settles back
}
