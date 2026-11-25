-- World zones, as data. Read-only; server/ZoneBuilder turns a zone into terrain, a canyon wall, a trail and trees.
-- Cities are separate places (DESIGN.md section 6), so this place only holds the outside zones. A zone is a circle
-- around the origin, which is also the spawn.
return {
	OutsideZone1 = {
		Name = "Outside Zone 1",
		LevelRange = { 1, 15 }, -- Greenfields in DESIGN.md; the zone level sync (build step 6) will read this

		Radius = 300, -- studs from the spawn to the foot of the canyon wall
		Depth = 16, -- studs of terrain below the surface (the top surface is at y = 0)
		Material = "Grass", -- any Enum.Material name
		GrassColor = Color3.fromRGB(62, 86, 42), -- Roblox's default grass is 111, 126, 62; lower numbers = darker

		-- The wall around the zone: a dirt canyon with a vertical face that cannot be climbed or jumped. Terrain is built
		-- from 4-stud cells, so the face is a little ragged, which suits a canyon.
		Canyon = {
			Material = "Mud", -- dark packed dirt (the trail uses Ground, and a terrain material has one color for the whole map)
			Color = Color3.fromRGB(98, 72, 50),
			Thickness = 32, -- studs deep, from the face outward
			Height = 70, -- studs above the ground at its average
			HeightVariation = 0.3, -- 0.3 = the top varies up to 30% higher or lower
			EdgeWobble = 12, -- studs the face moves in and out around the circle
			Seed = 11,
		},

		Hills = {
			Count = 8, -- gentle hills spread near the canyon
			Height = 12, -- studs above the ground at the top of each hill
			Radius = 100, -- bigger = wider, gentler slopes
			Seed = 7, -- change for a different layout
		},

		-- The trail from spawn to the town gate: a winding dirt path. Waypoints are x, z on the ground; the path curves
		-- smoothly through them. The last one is the gate site: a stone apron where the way to the Starter Town (a separate
		-- place, build step 7) will stand.
		Trail = {
			Waypoints = {
				Vector3.new(0, 0, 0),
				Vector3.new(14, 0, 45),
				Vector3.new(-10, 0, 90),
				Vector3.new(10, 0, 135),
				Vector3.new(-6, 0, 180),
				Vector3.new(8, 0, 225),
				Vector3.new(0, 0, 262),
			},
			Width = 18, -- studs wide (it varies a little along the way, so the edges look worn)
			Material = "Ground", -- the path
			Color = Color3.fromRGB(122, 98, 66), -- the path's dirt color
			GateMaterial = "Cobblestone", -- the stone apron at the gate site
			GateColor = Color3.fromRGB(110, 108, 104),
			GateRadius = 14, -- studs
			Seed = 3,
		},

		-- Trees: a row on each side of the trail, then scattered clumps over the rest of the zone.
		Trees = {
			Seed = 5,
			AlongTrail = {
				Every = 14, -- studs of trail between trees on each side
				Chance = 0.6, -- chance that a spot gets a tree
				MinOffset = 18, -- studs from the trail's edge...
				MaxOffset = 36, -- ...to this far out
			},
			Scattered = {
				Count = 260, -- how many to try to place (some are skipped where it would be crowded)
				GroveCutoff = -0.05, -- trees only grow where a noise map is above this: raise it for fewer, tighter groves (about -0.4 to 0.3)
				ClearAroundSpawn = 40, -- studs kept open around the spawn
				ClearAroundMobs = 14, -- studs kept open around each mob spawn
				ClearAroundTrail = 20, -- studs kept open beyond the trail's edge
				EdgeMargin = 12, -- studs kept clear in front of the canyon wall
			},
			-- The tree is the model in assets/models/Tree.rbxm. It is about 13 studs tall at scale 1.
			Scale = { 1.6, 2.6 }, -- every tree is randomly scaled between these (so about 21 to 35 studs tall)
			TrunkColor = Color3.fromRGB(96, 68, 44),
			TrunkMaterial = "Wood",
			LeafMaterial = "Grass",
			Leaves = {
				Color3.fromRGB(58, 102, 48),
				Color3.fromRGB(72, 120, 54),
				Color3.fromRGB(50, 90, 52),
				Color3.fromRGB(96, 128, 56),
			},
		},
	},
}
