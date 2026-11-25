-- The health bar floating over a mob. Read-only data; it is only a display (client/MobHealth), the server owns the health.
-- The bar stays hidden at full health and appears when the mob is hurt, then fades again after ShowSeconds without a new hit.
return {
	Width = 170, -- pixels
	BarHeight = 16, -- pixels
	RaiseStuds = 1.6, -- studs above the top of the mob
	MaxDistance = 90, -- studs: not drawn further away than this
	ShowSeconds = 7, -- stays this long after the last hit
	FadeSeconds = 0.35,

	-- The fill color goes from Full (most health) through Half to Low (almost dead).
	Full = Color3.fromRGB(96, 214, 96),
	Half = Color3.fromRGB(240, 196, 64),
	Low = Color3.fromRGB(230, 70, 60),
	Back = Color3.fromRGB(20, 18, 24), -- the dark slot behind
	Trail = Color3.fromRGB(255, 244, 220), -- the pale chip of health just lost; it drains away a moment later
	TrailDelay = 0.45, -- seconds before the chip starts to drain
	TrailSeconds = 0.4, -- how long it takes to drain

	NameColor = Color3.fromRGB(255, 244, 226),
	LevelColor = Color3.fromRGB(255, 214, 120),
	TextSize = 16,
	Font = "GothamBold",
}
