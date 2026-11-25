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

		-- Mob camps: where the mobs live. A camp is one kind of mob in one or more groups; each group is a number of mobs
		-- placed at random inside a circle (Radius, and optionally a hole in the middle, MinRadius) around the camp Center plus
		-- the group's Offset (x, z). A second group with
		-- an Offset is the part of the pack standing "beside" the main one. Placement is fixed by the camp's Seed.
		-- The spawn is at 0, 0 and the trail runs north (+z), so camps keep well away from the trail (mobs notice you at about 30 studs).
		Camps = {
			{
				Name = "Goblin Hollow", Mob = "Goblin", Seed = 21,
				Center = Vector3.new(-85, 0, 75),
				Campfire = true, -- a fire at the Center, with the first group gathered around it (MinRadius keeps them off the logs)
				Groups = {
					{ Count = 3, MinRadius = 10, Radius = 15 }, -- three goblins around the fire...
					{ Count = 2, Radius = 6, Offset = Vector3.new(-20, 0, 14) }, -- ...and two more standing nearby
				},
			},
			{
				Name = "Goblin Ridge", Mob = "Goblin", Seed = 22,
				Center = Vector3.new(100, 0, 150),
				Campfire = true,
				Groups = {
					{ Count = 2, MinRadius = 10, Radius = 15 },
					{ Count = 2, Radius = 6, Offset = Vector3.new(18, 0, -18) },
				},
			},
			{
				Name = "Wolf Den", Mob = "Wolf", Seed = 23,
				Center = Vector3.new(115, 0, -105),
				Groups = {
					{ Count = 3, Radius = 7 }, -- a pack of three...
					{ Count = 3, Radius = 8, Offset = Vector3.new(-26, 0, 16) }, -- ...and three more prowling beside it
				},
			},
			{
				Name = "Wolf Hollow", Mob = "Wolf", Seed = 24,
				Center = Vector3.new(-125, 0, 175),
				Groups = {
					{ Count = 3, Radius = 7 },
					{ Count = 3, Radius = 8, Offset = Vector3.new(24, 0, -20) },
				},
			},
		},

		-- Campfires beside the trail: a ring of stones, logs, a fire and log seats. Along = how far along the trail each one
		-- stands (0 = spawn, 1 = the gate); they alternate sides, starting on the left.
		Campfires = {
			Along = { 0.47 },
			Stones = 7, -- stones in the ring around the fire
			StoneRing = 3.8, -- studs from the fire to the ring (the bigger, the more space between the stones)
			Offset = 16, -- studs from the trail's edge to the fire
			BareRadius = 10, -- studs of bare dirt around the fire (the tall grass would hide it)
			BareMaterial = "Ground",
			StoneColor = Color3.fromRGB(112, 110, 106),
			LogColor = Color3.fromRGB(88, 62, 42),
			Light = { Color = Color3.fromRGB(255, 170, 90), Range = 34, Brightness = 2 }, -- the glow the fire throws
		},

		-- Rocks beside the trail, alone or in small groups; now and then a big boulder.
		Rocks = {
			Seed = 9,
			Every = { 9, 22 }, -- studs of trail between one group and the next (random in this range)
			ClearAroundCampfires = 22, -- studs kept free of rocks around each campfire (trail ones and camp ones)
			MinOffset = 3, -- studs from the trail's edge...
			MaxOffset = 10, -- ...to this far out
			Group = { 1, 3 }, -- rocks per group
			Size = { 2.5, 6 }, -- studs across
			BoulderChance = 0.12, -- chance that a group is one big boulder instead
			BoulderSize = { 9, 14 },
			Colors = { Color3.fromRGB(86, 84, 82), Color3.fromRGB(72, 72, 76), Color3.fromRGB(96, 90, 84), Color3.fromRGB(66, 68, 70) },
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
				ClearAroundMobs = 14, -- studs kept open around each mob camp group (on top of its radius)
				ClearAroundCampfires = 18, -- studs kept open around each campfire
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
