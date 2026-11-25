-- Developer switches. Set DEV_MODE to false before release.
return {
	DEV_MODE = true, -- spawns the dev test ground and the dev dummy

	TestGround = {
		Size = 600, -- studs, square
		Depth = 16, -- studs of terrain below the surface (the top surface is at y = 0)
		Material = "Grass", -- any Enum.Material name
		GrassColor = Color3.fromRGB(62, 86, 42), -- the ground's grass color (Roblox's default is 111, 126, 62); lower numbers = darker
		-- The trail from spawn to the starter town's gate: a winding dirt path with a stone plaza where the gate will stand
		-- (the town itself is a separate place, build step 7). Waypoints are x, z on the ground; the path curves smoothly through them.
		Trail = {
			Waypoints = { Vector3.new(0, 0, 0), Vector3.new(14, 0, 45), Vector3.new(-10, 0, 90), Vector3.new(10, 0, 135), Vector3.new(-4, 0, 172) },
			Width = 12, -- studs wide (it varies a little along the way, so the edges look worn). Terrain cells are 4 studs, so edges are blocky
			Material = "Ground", -- the path
			Color = Color3.fromRGB(122, 98, 66), -- the path's dirt color
			PlazaMaterial = "Cobblestone", -- the stone circle at the town end
			PlazaColor = Color3.fromRGB(110, 108, 104),
			PlazaRadius = 16, -- studs
			Seed = 3,
		},
		Hills = {
			Count = 8, -- gentle hills spread around the edges
			Height = 12, -- studs above the ground at the top of each hill
			Radius = 100, -- bigger = wider, gentler slopes
			Seed = 7, -- change for a different layout
		},
	},
}
