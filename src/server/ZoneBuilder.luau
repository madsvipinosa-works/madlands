-- Builds the outside zones from Config/Zones: round grass ground, a dirt canyon wall around it, hills, a trail to the
-- gate site, and trees. Server only. Must load before the dummy and the mobs, which stand on the ground.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Mobs = require(ReplicatedStorage.Shared.Config.Mobs)

local terrain = workspace.Terrain
local CELL = 4 -- terrain cell size in studs: only a fully covered cell changes material, so everything is laid cell by cell

-- A smooth curve through the waypoints (a Catmull-Rom spline), as a list of points about CELL / 2 studs apart.
local function trailPoints(waypoints)
	local function point(i)
		return waypoints[math.clamp(i, 1, #waypoints)]
	end
	local points = {}
	for i = 1, #waypoints - 1 do
		local p0, p1, p2, p3 = point(i - 1), point(i), point(i + 1), point(i + 2)
		local steps = math.ceil((p2 - p1).Magnitude / (CELL / 2))
		for s = (if i == 1 then 0 else 1), steps do
			local t = s / steps
			table.insert(points, 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ^ 2 + (3 * p1 - p0 - 3 * p2 + p3) * t ^ 3))
		end
	end
	return points
end

-- Distance on the ground plane from a point to the nearest of a list of points.
local function nearest(position, points)
	local best = math.huge
	for _, p in points do
		best = math.min(best, math.sqrt((position.X - p.X) ^ 2 + (position.Z - p.Z) ^ 2))
	end
	return best
end

local function buildGround(zone)
	local material = Enum.Material[zone.Material]
	terrain:SetMaterialColor(material, zone.GrassColor)
	-- A little wider than the zone, so no gap is left where the canyon face wobbles outward; the canyon columns cover the rest.
	terrain:FillCylinder(CFrame.new(0, -zone.Depth / 2, 0), zone.Depth, zone.Radius + zone.Canyon.EdgeWobble + CELL, material)
end

-- Hills: the top of a big ball poking out of the ground. They keep clear of the trail, which would be buried under one.
local function buildHills(zone, trail)
	local hills = zone.Hills
	local material = Enum.Material[zone.Material]
	local rng = Random.new(hills.Seed)
	for i = 1, hills.Count do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) / hills.Count * math.pi * 2
		local distance = zone.Radius - rng:NextNumber(10, 60)
		local height = hills.Height * rng:NextNumber(0.6, 1)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		local reach = math.sqrt(hills.Radius ^ 2 - (hills.Radius - height) ^ 2) -- how far out the dome meets the ground
		if nearest(Vector3.new(x, 0, z), trail) > reach + zone.Trail.Width then
			terrain:FillBall(Vector3.new(x, height - hills.Radius, z), hills.Radius, material)
		end
	end
end

-- The canyon: every cell of a ring outside the zone gets a full-height column of dirt. The inner face is vertical,
-- wobbles in and out around the circle, and the top rises and falls, so it reads as a canyon and cannot be climbed.
local function buildCanyon(zone)
	local c = zone.Canyon
	local material = Enum.Material[c.Material]
	terrain:SetMaterialColor(material, c.Color)
	local outer = zone.Radius + c.Thickness + c.EdgeWobble
	local cells = math.ceil(outer / CELL)
	local work = 0
	for i = -cells, cells do
		for j = -cells, cells do
			local x, z = (i + 0.5) * CELL, (j + 0.5) * CELL
			local distance = math.sqrt(x * x + z * z)
			local angle = math.atan2(z, x)
			local wobble = math.noise(math.cos(angle) * 3 + c.Seed, math.sin(angle) * 3 + c.Seed, 0.5) * c.EdgeWobble * 2
			local face = zone.Radius + wobble
			if distance >= face and distance <= zone.Radius + c.Thickness + wobble then
				local variation = 1 + math.noise(x / 40 + c.Seed, z / 40 + c.Seed, 1.5) * c.HeightVariation * 2
				local height = math.max(math.floor(c.Height * variation / CELL) * CELL, 3 * CELL)
				terrain:FillBlock(CFrame.new(x, (height - zone.Depth) / 2, z), Vector3.new(CELL, height + zone.Depth, CELL), material)
				work += 1
				if work % 400 == 0 then
					task.wait() -- spread the work over a few frames; the middle of the zone is already solid
				end
			end
		end
	end
end

-- The trail: every cell whose middle is within about half the (slightly varying) width of the curve becomes dirt, and
-- the last waypoint gets a round stone apron.
local function paintTrail(zone, points)
	local t = zone.Trail
	local material = Enum.Material[t.Material]
	terrain:SetMaterialColor(material, t.Color)
	local wobble = Random.new(t.Seed)
	local painted = {}
	for _, position in points do
		local reach = t.Width / 2 * wobble:NextNumber(0.8, 1.2)
		local cells = math.ceil(reach / CELL) + 1
		local cx, cz = math.floor(position.X / CELL), math.floor(position.Z / CELL)
		for dx = -cells, cells do
			for dz = -cells, cells do
				local x, z = (cx + dx) * CELL + CELL / 2, (cz + dz) * CELL + CELL / 2
				local key = x .. "," .. z
				if not painted[key] and (Vector3.new(x, 0, z) - position).Magnitude <= reach then
					painted[key] = true
					terrain:FillBlock(CFrame.new(x, -CELL / 2, z), Vector3.one * CELL, material)
				end
			end
		end
	end
	local gate = Enum.Material[t.GateMaterial]
	terrain:SetMaterialColor(gate, t.GateColor)
	local last = points[#points]
	terrain:FillCylinder(CFrame.new(last.X, -CELL / 2, last.Z), CELL, t.GateRadius, gate)
end

-- Trees ---------------------------------------------------------------------------------------------------------

local treeRay = RaycastParams.new()
treeRay.FilterType = Enum.RaycastFilterType.Exclude

local function groundHeight(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), treeRay)
	return hit and hit.Position.Y
end

-- The tree is a model made by hand (assets/models/Tree.rbxm, served as ServerStorage.Models.Tree). Every tree is a clone,
-- scaled, turned a random way and tinted: the trunk and branches brown, the foliage one of a few greens. Only the trunk
-- blocks you; the foliage can be walked and fought through, and ignores raycasts.
local treeModel = ServerStorage:WaitForChild("Models"):WaitForChild("Tree")

local function tree(parent, x, y, z, rng, trees)
	local model = treeModel:Clone()
	model.Name = "Tree"
	local leaves = trees.Leaves[rng:NextInteger(1, #trees.Leaves)]
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local isFoliage = string.find(descendant.Name, "Foliage") ~= nil
			descendant.Anchored = true
			descendant.CanTouch = false
			descendant.CanCollide = descendant.Name == "Trunk"
			descendant.CanQuery = descendant.Name == "Trunk"
			descendant.Material = Enum.Material[if isFoliage then trees.LeafMaterial else trees.TrunkMaterial]
			descendant.Color = if isFoliage then leaves else trees.TrunkColor
		end
	end
	model:ScaleTo(rng:NextNumber(trees.Scale[1], trees.Scale[2]))
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-2, 2)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-2, 2)))
	model:PivotTo(CFrame.new(x, y, z) * lean)
	model.Parent = parent
end

local function buildTrees(zone, points)
	local trees = zone.Trees
	local rng = Random.new(trees.Seed)
	local folder = Instance.new("Folder")
	folder.Name = "Trees"
	folder.Parent = workspace
	treeRay.FilterDescendantsInstances = { folder } -- a new tree must not count as ground
	local placed = 0
	local function plant(x, z)
		local y = groundHeight(x, z)
		if y and y > -1 and y < 30 then -- on the grass, not in a canyon column
			tree(folder, x, y, z, rng, trees)
			placed += 1
		end
	end

	-- Along the trail: walk it and plant on both sides.
	local a = trees.AlongTrail
	local sinceTree = 0
	for i = 2, #points do
		sinceTree += (points[i] - points[i - 1]).Magnitude
		if sinceTree >= a.Every then
			sinceTree = 0
			local forward = (points[i] - points[i - 1]).Unit
			local side = Vector3.new(-forward.Z, 0, forward.X)
			for sign = -1, 1, 2 do
				if rng:NextNumber() < a.Chance then
					local offset = zone.Trail.Width / 2 + rng:NextNumber(a.MinOffset, a.MaxOffset)
					local spot = points[i] + side * sign * offset + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
					if i < #points - 4 then -- none on the stone apron at the end
						plant(spot.X, spot.Z)
					end
				end
			end
		end
	end

	-- Scattered: random spots in groves, away from the spawn, the mobs, the trail and the canyon.
	local s = trees.Scattered
	local mobSpots = {}
	for _, def in Mobs do
		for _, position in def.Spawns do
			table.insert(mobSpots, position)
		end
	end
	for _ = 1, s.Count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber()) * (zone.Radius - s.EdgeMargin)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		local position = Vector3.new(x, 0, z)
		local grove = math.noise(x / 55 + trees.Seed, z / 55 + trees.Seed, 2.5) -- -1..1: positive in groves, negative in clearings
		if
			grove > s.GroveCutoff
			and distance > s.ClearAroundSpawn
			and nearest(position, points) > zone.Trail.Width / 2 + s.ClearAroundTrail
			and nearest(position, mobSpots) > s.ClearAroundMobs
		then
			plant(x, z)
		end
	end
	print(`[Zone] {placed} trees planted`)
end

-- The spawn: a hidden SpawnLocation at the middle of the zone, and no flat baseplate to hide the grass.
local function placeSpawn()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation") or Instance.new("SpawnLocation")
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy() -- the sun decal
		end
	end
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.Position = Vector3.new(0, 3, 0)
	spawn.Parent = workspace
end

local zone = Zones.OutsideZone1
-- Grass length is a Terrain property a game script is not allowed to change; it is set on the place in Studio instead.
buildGround(zone)
placeSpawn()
local points = trailPoints(zone.Trail.Waypoints)
buildHills(zone, points)
paintTrail(zone, points)
task.wait(1) -- new terrain cannot be raycast for a moment; the trees look for the ground with a raycast
buildTrees(zone, points)
buildCanyon(zone) -- last and slowest; it waits between batches, but everything the player stands on is already built

print(`[Zone] {zone.Name} (levels {zone.LevelRange[1]}-{zone.LevelRange[2]}): radius {zone.Radius}, canyon wall built`)

return true
