-- Look of the floating damage numbers. Client feedback only, changes no rules. Tweak freely.
return {
	Font = "LuckiestGuy", -- any Enum.Font name, e.g. "GothamBlack"
	StrongThreshold = 30, -- damage at or above this counts as a strong hit (Sword does 20, so lower it to test)

	Normal = { TextSize = 30, Color = Color3.fromRGB(255, 255, 255) },
	Strong = { TextSize = 48, Color = Color3.fromRGB(255, 215, 0) },

	OutlineColor = Color3.fromRGB(25, 12, 12),
	OutlineThickness = 3, -- pixels

	StartScale = 0.3, -- pop starts at this fraction of full size
	PopTime = 0.15, -- seconds to scale up (overshoots slightly, then settles)
	Lifetime = 0.7, -- total seconds on screen
	FadeStart = 0.35, -- seconds after spawn when the fade begins

	StartHeight = 3, -- studs above the target's root part
	RiseStuds = 2.5, -- how far it drifts up
	SideStuds = 1, -- random sideways drift, left or right up to this far
}
