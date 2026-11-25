-- World zones, as data. Read-only; server/ZoneBuilder turns a zone into terrain, a canyon wall, a trail and trees.
-- Cities are separate places (DESIGN.md section 6), so this place only holds the outside zones. A zone is a circle
-- around the origin, which is also the spawn.
return {
	OutsideZone1 = {
		Name = "Outside Zone 1",
		LevelRange = { 1, 15 }, -- Greenfields in DESIGN.md; the zone level sync (build step 6) will read this

		-- Size: Radius is the zone's size. When you change it, also move Gate.Z (about Radius - 20), the trail's last waypoint (about
		-- 60 studs in front of the gate) and the camps, which are placed in studs from the spawn.
		Radius = 420, -- studs from the spawn to the foot of the canyon wall
		MaxWalkSlope = 50, -- degrees: players cannot walk up anything steeper (hills are gentle; the canyon's ledges are far steeper)
		Depth = 16, -- studs of terrain below the surface (the top surface is at y = 0)
		Material = "Grass", -- any Enum.Material name
		GrassColor = Color3.fromRGB(62, 86, 42), -- Roblox's default grass is 111, 126, 62; lower numbers = darker

		-- The wall around the zone: a dirt canyon that cannot be climbed or jumped: its face wanders in and out, and it rises in
		-- two ledges (each step up is taller than a jump) to a ragged top. Terrain is built from 4-stud cells, so everything is blocky.
		Canyon = {
			Material = "Mud", -- dark packed dirt (the trail uses Ground, and a terrain material has one color for the whole map)
			Color = Color3.fromRGB(98, 72, 50),
			Thickness = 32, -- studs deep, from the face outward
			Ledges = { 12, 24 }, -- heights of the two ledges below the top: steps of 12 are too tall to jump
			Height = 38, -- studs above the ground at the top, on average
			HeightVariation = 8, -- the top rises and falls this many studs...
			MinHeight = 34, -- ...but never below this (keeps every step up taller than a jump)...
			MaxHeight = 44, -- ...or above this: the gate walls (40 x Gate.Scale) are taller than every peak
			EdgeWobble = 22, -- most studs the face moves in or out around the circle
			GateLift = 110, -- the cliff rises to the height of the gate's walls over this many studs beside the gate
			GateCalm = { 0.12, 0.5 }, -- the wobble fades out within this many radians of the gate, so the cliff meets its walls cleanly
			Seed = 11,
			-- Green on the cliff: every ledge and the top are grass, with bushes on the ledges.
			Greenery = {
				Material = "Grass",
				BushChance = 0.04, -- chance that a ledge cell grows a bush
				BushColors = { Color3.fromRGB(70, 118, 52), Color3.fromRGB(88, 134, 58), Color3.fromRGB(58, 100, 50), Color3.fromRGB(110, 140, 62) },
			},
		},

		-- The land beyond the canyon, so the zone is not floating in nothing: rolling hills that rise away from the cliff, cut into
		-- smooth terraces like rice terraces (one step = Terrace studs; the edge of each terrace is bare dirt), alternating two
		-- greens, with big trees, and a haze that fades the far edge. It ends at Radius (a long way out, lost in the haze).
		Surroundings = {
			Radius = 640, -- studs from the spawn to the outer rim of the hills
			StartHeight = 40, -- height of the land right behind the canyon (about the canyon's top)
			Rise = 60, -- how much higher the land is by the end of the ramp
			RampLength = 170, -- studs from the canyon to where it has risen fully
			HillSize = 95, -- bigger = broader hills
			HillHeight = 32, -- how much the hills roll up and down
			Terrace = 4, -- height of one terrace step (4 is the smoothest the terrain can make; 8 gives bolder steps)
			Seed = 17, -- change for different hills
			Grass = "Grass", -- top of every other terrace (its color is the zone's GrassColor)
			AltGrass = "LeafyGrass", -- top of the terraces between
			AltColor = Color3.fromRGB(106, 146, 60),
			EdgeMaterial = "Ground", -- the dirt edge of each terrace and the soil below
			Trees = { Count = 170, Scale = { 2.6, 4.2 }, Edge = 50 }, -- big trees on the far terraces; Edge = studs left bare at the rim
			-- The town you see beyond the gate: a low hill behind its walls with a few rows of houses and a town hall (scenery only).
			Town = {
				Seed = 23,
				Spread = 0.42, -- radians either side of straight behind the gate that the town fills (0.42 = about 24 degrees)
				Bump = 12, -- how much higher than the other hills its hill rises
				Lower = 0.45, -- how much lower than the other land it starts, right behind the gate (0 = not lower)
				Rows = { 500, 538, 576 }, -- distance from the spawn of each row of houses; each row is further up the hill
				Step = 0.075, -- radians between houses along a row (about 40 studs)
				Gaps = 0.42, -- chance that a house is left out
				LaneHalfWidth = 30, -- a street up the middle, from the gate to the hall
				Width = { 18, 26 },
				Depth = { 14, 20 },
				Height = { 14, 22 }, -- wall height, before the roof
				WallColors = { Color3.fromRGB(216, 200, 170), Color3.fromRGB(206, 178, 142), Color3.fromRGB(198, 192, 178) },
				RoofColors = { Color3.fromRGB(152, 68, 52), Color3.fromRGB(104, 78, 58), Color3.fromRGB(88, 94, 106) },
				StoneColor = Color3.fromRGB(150, 146, 138),
				Hall = { Radius = 556, Width = 64, Depth = 30, Height = 24, TowerWidth = 14, TowerHeight = 42 }, -- at the top of the street, straight behind the gate
			},
			Haze = {
				Density = 0.3,
				Offset = 0.15,
				Color = Color3.fromRGB(196, 214, 232),
				Decay = Color3.fromRGB(150, 170, 196),
				Glare = 0,
				Haze = 1.4,
			},
		},

		Hills = {
			Count = 12, -- gentle hills spread near the canyon
			Height = 12, -- studs above the ground at the top of each hill
			Radius = 100, -- bigger = wider, gentler slopes
			Seed = 7, -- change for a different layout
		},

		-- The trail from spawn to the town gate: a winding dirt path. Waypoints are x, z on the ground; the path curves
		-- smoothly through them. The last one is just in front of the gate (see Gate below), on a stone apron.
		Trail = {
			Waypoints = {
				Vector3.new(0, 0, 0),
				Vector3.new(14, 0, 45),
				Vector3.new(-10, 0, 90),
				Vector3.new(10, 0, 135),
				Vector3.new(-6, 0, 168),
				Vector3.new(4, 0, 188),
				Vector3.new(-10, 0, 232),
				Vector3.new(12, 0, 268),
				Vector3.new(-4, 0, 300),
				Vector3.new(0, 0, 296),
			},
			Width = 18, -- studs wide (it varies a little along the way, so the edges look worn)
			Material = "Ground", -- the path
			Color = Color3.fromRGB(122, 98, 66), -- the path's dirt color
			GateMaterial = "Cobblestone", -- the stone apron at the gate site
			GateColor = Color3.fromRGB(110, 108, 104),
			GateRadius = 14, -- studs
			Seed = 3,
		},

		-- The Starter Town gate, on the north edge of the zone. Its curved walls take the canyon's place along that stretch (the
		-- canyon leaves a gap CanyonGap studs either side of the middle) and are as tall as the canyon. The town itself is a
		-- separate place: walking into the gate or pressing F at it opens the gate, fades the screen and teleports the player to
		-- DestinationPlaceId. While that is 0 (no town place yet), the player is put back in front of the gate after the fade.
		Gate = {
			Name = "Starter Town",
			Model = "StarterTownGateCurve", -- ServerStorage.Models.StarterTownGateCurve, from assets/models/StarterTownGateCurve.rbxm
			Scale = 1.5, -- how big the gate is built (1 = as the model was saved). Its walls are 40 x Scale tall (60), and the canyon rises to meet them (Canyon.GateLift)
			Z = 396, -- how far north its middle stands (x = 0); the wall ends (100 x Scale to each side, bending back 32 x Scale) must reach the canyon
			CanyonGap = 130, -- half the width of the stretch of canyon replaced by the gate
			DestinationPlaceId = 0, -- the Roblox place id of the Starter Town; 0 = not connected yet
			AutoOpen = false, -- true: the gate opens by itself when a player is OpenDistance close (false: only when entering)
			OpenDistance = 70,
			OpenSeconds = 2.6, -- how long it takes to open fully
			DoorOpenDegrees = 95,
			PromptKey = Enum.KeyCode.F,
			PromptDistance = 46, -- studs from the gate at which "Enter" shows
			FadeSeconds = 1.2, -- the screen fades to black this fast, then the teleport happens
			ReturnDistance = 70, -- studs in front of the gate where the player is put back if the town is not connected
			-- The hand-made WallPiece (assets/models/WallPiece.rbxm) is tiled along the canyon beside the gate's own walls. HeightShare is
			-- its height as a share of the gate's wall height; Extra is how far past the canyon's rise (GateLift) it keeps going.
			Flank = { Model = "WallPiece", HeightShare = 0.92, Extra = 30 },
		},

		-- Mob camps: where the mobs live. A camp is one kind of mob in one or more groups; each group is a number of mobs
		-- placed at random inside a circle (Radius, and optionally a hole in the middle, MinRadius) around the camp Center plus
		-- the group's Offset (x, z). A second group with
		-- an Offset is the part of the pack standing "beside" the main one. Placement is fixed by the camp's Seed.
		-- The spawn is at 0, 0 and the trail runs north (+z), so camps keep well away from the trail (mobs notice you at about 30 studs).
		Camps = {
			{
				Name = "Goblin Hollow", Mob = "Goblin", Seed = 21,
				Center = Vector3.new(-120, 0, 105),
				Campfire = true, -- a fire at the Center, with the first group gathered around it (MinRadius keeps them off the logs)
				Groups = {
					{ Count = 3, MinRadius = 10, Radius = 15 }, -- three goblins around the fire...
					{ Count = 2, Radius = 6, Offset = Vector3.new(-20, 0, 14) }, -- ...and two more standing nearby
				},
			},
			{
				Name = "Goblin Ridge", Mob = "Goblin", Seed = 22,
				Center = Vector3.new(140, 0, 210),
				Campfire = true,
				Groups = {
					{ Count = 2, MinRadius = 10, Radius = 15 },
					{ Count = 2, Radius = 6, Offset = Vector3.new(18, 0, -18) },
				},
			},
			{
				Name = "Wolf Den", Mob = "Wolf", Seed = 23,
				Center = Vector3.new(165, 0, -147),
				Groups = {
					{ Count = 3, Radius = 7 }, -- a pack of three...
					{ Count = 3, Radius = 8, Offset = Vector3.new(-26, 0, 16) }, -- ...and three more prowling beside it
				},
			},
			{
				Name = "Wolf Hollow", Mob = "Wolf", Seed = 24,
				Center = Vector3.new(-175, 0, 245),
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
				Count = 540, -- how many to try to place (some are skipped where it would be crowded)
				GroveCutoff = -0.05, -- trees only grow where a noise map is above this: raise it for fewer, tighter groves (about -0.4 to 0.3)
				ClearAroundSpawn = 40, -- studs kept open around the spawn
				ClearAroundMobs = 14, -- studs kept open around each mob camp group (on top of its radius)
				ClearAroundCampfires = 18, -- studs kept open around each campfire
				ClearAroundTrail = 20, -- studs kept open beyond the trail's edge
				EdgeMargin = 34, -- studs kept clear in front of the canyon wall (more than its wobble)
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
