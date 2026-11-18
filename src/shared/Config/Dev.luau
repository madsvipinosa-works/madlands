-- Developer switches. Set DEV_MODE to false before release.
return {
	DEV_MODE = true, -- spawns the dev test ground and the dev dummy

	TestGround = {
		Size = 600, -- studs, square
		Depth = 16, -- studs of terrain below the surface (the top surface is at y = 0)
		Material = "Grass", -- any Enum.Material name
		Hills = {
			Count = 8, -- gentle hills spread around the edges
			Height = 12, -- studs above the ground at the top of each hill
			Radius = 100, -- bigger = wider, gentler slopes
			Seed = 7, -- change for a different layout
		},
	},
}
