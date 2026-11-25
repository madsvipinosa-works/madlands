-- Builds the outside zones from Config/Zones: round grass ground, a dirt canyon wall around it, hills, a trail to the
-- gate site, and trees. Server only. Must load before the dummy and the mobs, which stand on the ground.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Camps = require(ReplicatedStorage.Shared.Camps)

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
local propsFolder = Instance.new("Folder") -- campfires and rocks; they must not count as ground either
propsFolder.Name = "Props"
propsFolder.Parent = workspace

local function groundHeight(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), treeRay)
	return hit and hit.Position.Y
end

-- True if the point is outside every { Position, Radius } circle in the list.
local function clearOf(position, circles)
	for _, circle in circles do
		if (Vector3.new(position.X, 0, position.Z) - Vector3.new(circle.Position.X, 0, circle.Position.Z)).Magnitude < circle.Radius then
			return false
		end
	end
	return true
end

-- Campfires and rocks ---------------------------------------------------------------------------------------------

local function prop(parent, shape, cframe, size, material, color, solid)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = solid
	p.CanTouch = false
	p.Material = material
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- A rock: a chunky tilted block with one or two smaller ones leaning against it, sunk a little into the ground.
local function rock(parent, x, y, z, size, rng, rocks)
	local model = Instance.new("Model")
	model.Name = "Rock"
	local color = rocks.Colors[rng:NextInteger(1, #rocks.Colors)]
	for i = 1, rng:NextInteger(2, 3) do
		local scale = if i == 1 then 1 else rng:NextNumber(0.4, 0.65)
		local w, h, d = size * scale * rng:NextNumber(0.8, 1.2), size * scale * rng:NextNumber(0.55, 0.85), size * scale * rng:NextNumber(0.8, 1.2)
		local offset = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-0.4, 0.4) * size, 0, rng:NextNumber(-0.4, 0.4) * size)
		local turn = CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-22, 22)))
		prop(model, Enum.PartType.Block, CFrame.new(x + offset.X, y + h * 0.3, z + offset.Z) * turn, Vector3.new(w, h, d), Enum.Material.Slate, color:Lerp(Color3.new(0.3, 0.3, 0.3), rng:NextNumber(0, 0.2)), true)
	end
	model.Parent = parent
end

-- A campfire: a ring of stones, three logs, ash, a fire with smoke and sparks that lights up the ground, and three log seats.
local function campfire(parent, x, y, z, rng, c)
	local model = Instance.new("Model")
	model.Name = "Campfire"
	local base = CFrame.new(x, y, z)
	local block, cylinder = Enum.PartType.Block, Enum.PartType.Cylinder
	local flat = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder Part lies along X; this stands it up

	for i = 0, c.Stones - 1 do -- the stone ring, spaced out
		local angle = i / c.Stones * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local size = Vector3.new(rng:NextNumber(1.4, 2), rng:NextNumber(0.9, 1.3), rng:NextNumber(1.2, 1.7))
		prop(model, block, base * CFrame.Angles(0, angle, 0) * CFrame.new(c.StoneRing, size.Y / 2 - 0.2, 0) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), size, Enum.Material.Rock, c.StoneColor:Lerp(Color3.new(0.4, 0.4, 0.4), rng:NextNumber(0, 0.25)), true)
	end
	prop(model, cylinder, base * CFrame.new(0, 0.05, 0) * flat, Vector3.new(0.2, 5.2, 5.2), Enum.Material.Slate, Color3.fromRGB(40, 36, 34), false) -- the ash and embers bed
	for i = 0, 2 do -- three logs, crossing like spokes
		prop(model, cylinder, base * CFrame.Angles(0, i / 3 * math.pi + 0.3, 0) * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(8)), Vector3.new(4.2, 0.9, 0.9), Enum.Material.Wood, c.LogColor, false)
	end
	for i = 0, 2 do -- log seats around it, a bit apart
		local angle = i / 3 * math.pi * 2 + 0.9
		local seat = base * CFrame.Angles(0, angle, 0) * CFrame.new(7.2, 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0)
		prop(model, cylinder, seat, Vector3.new(5, 1.3, 1.3), Enum.Material.Wood, c.LogColor:Lerp(Color3.new(0.5, 0.4, 0.3), 0.15), true)
	end

	local flame = prop(model, block, base * CFrame.new(0, 1.4, 0), Vector3.one, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), false)
	flame.Transparency = 1
	flame.CanQuery = false
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(230, 70, 20))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.6), NumberSequenceKeypoint.new(1, 0.6) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.6, 1.1)
	fire.Speed = NumberRange.new(3, 5)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.Rate = 30
	fire.Rotation = NumberRange.new(-20, 20)
	fire.Parent = flame
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 88, 86))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2.5, 4)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Rate = 4
	smoke.Parent = flame
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 110))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25)
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(5, 9)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Rate = 5
	sparks.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = c.Light.Color
	light.Range = c.Light.Range
	light.Brightness = c.Light.Brightness
	light.Shadows = false
	light.Parent = flame
	model.Parent = parent
end

-- Puts campfires (along the trail, and at the camps that have one) and rocks along the trail. Returns the circles trees
-- must stay out of.
local function buildProps(zone, points)
	local clear = {}
	local halfWidth = zone.Trail.Width / 2 * 1.2 -- the trail's widest edge
	local function sideOf(i)
		local forward = (points[math.min(i + 1, #points)] - points[math.max(i - 1, 1)]).Unit
		return Vector3.new(-forward.Z, 0, forward.X)
	end

	-- How far along the trail each point is, in studs.
	local along, total = { 0 }, 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
		along[i] = total
	end

	local fires = zone.Campfires
	local fireRng = Random.new(zone.Trees.Seed + 1)
	for n, fraction in fires.Along do
		local i = 1
		while along[i] < total * fraction and i < #points do
			i += 1
		end
		local side = if n % 2 == 1 then 1 else -1
		local spot = points[i] + sideOf(i) * side * (halfWidth + fires.Offset)
		local y = groundHeight(spot.X, spot.Z)
		if y then
			terrain:FillCylinder(CFrame.new(spot.X, -CELL / 2, spot.Z), CELL, fires.BareRadius, Enum.Material[fires.BareMaterial]) -- bare ground: no tall grass
			campfire(propsFolder, spot.X, y, spot.Z, fireRng, fires)
			table.insert(clear, { Position = spot, Radius = zone.Trees.Scattered.ClearAroundCampfires })
		end
	end

	-- Camp fires: the middle of a camp that asks for one.
	for _, camp in zone.Camps or {} do
		if camp.Campfire then
			local y = groundHeight(camp.Center.X, camp.Center.Z)
			if y then
				terrain:FillCylinder(CFrame.new(camp.Center.X, -CELL / 2, camp.Center.Z), CELL, fires.BareRadius, Enum.Material[fires.BareMaterial])
				campfire(propsFolder, camp.Center.X, y, camp.Center.Z, fireRng, fires)
				table.insert(clear, { Position = camp.Center, Radius = zone.Trees.Scattered.ClearAroundCampfires })
			end
		end
	end

	local r = zone.Rocks
	local rng = Random.new(r.Seed)
	local noRocks = {} -- circles rocks must stay out of: around every fire
	for _, circle in clear do
		table.insert(noRocks, { Position = circle.Position, Radius = r.ClearAroundCampfires })
	end
	local distance, count = rng:NextNumber(r.Every[1], r.Every[2]), 0
	for i = 1, #points do
		if along[i] >= distance and along[i] < total - zone.Trail.GateRadius - 4 then
			distance = along[i] + rng:NextNumber(r.Every[1], r.Every[2])
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			local boulder = rng:NextNumber() < r.BoulderChance
			local reach = halfWidth + rng:NextNumber(r.MinOffset, r.MaxOffset) + (if boulder then r.BoulderSize[2] / 2 else 0)
			local center = points[i] + sideOf(i) * side * reach
			if clearOf(center, noRocks) then
				local rocksInGroup = if boulder then 1 else rng:NextInteger(r.Group[1], r.Group[2])
				for _ = 1, rocksInGroup do
					local spot = center + Vector3.new(rng:NextNumber(-3.5, 3.5), 0, rng:NextNumber(-3.5, 3.5))
					local y = groundHeight(spot.X, spot.Z)
					if y then
						local size = if boulder then rng:NextNumber(r.BoulderSize[1], r.BoulderSize[2]) else rng:NextNumber(r.Size[1], r.Size[2])
						rock(propsFolder, spot.X, y, spot.Z, size, rng, r)
						count += 1
					end
				end
			end
		end
	end
	print(`[Zone] {#fires.Along} campfires and {count} rocks placed`)
	return clear
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

local function buildTrees(zone, points, keepClear)
	local trees = zone.Trees
	local rng = Random.new(trees.Seed)
	local folder = Instance.new("Folder")
	folder.Name = "Trees"
	folder.Parent = workspace
	treeRay.FilterDescendantsInstances = { folder, propsFolder } -- a new tree or prop must not count as ground
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
					if i < #points - 4 and clearOf(spot, keepClear) then -- none on the stone apron at the end, or near a camp or fire
						plant(spot.X, spot.Z)
					end
				end
			end
		end
	end

	-- Scattered: random spots in groves, away from the spawn, the mobs, the trail and the canyon.
	local s = trees.Scattered
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
			and clearOf(position, keepClear)
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
task.wait(1) -- new terrain cannot be raycast for a moment; the props and trees look for the ground with a raycast
treeRay.FilterDescendantsInstances = { propsFolder }
local keepClear = buildProps(zone, points)
for _, area in Camps.Areas(zone) do -- the mobs' ground stays open: no trees where they walk and fight
	table.insert(keepClear, { Position = area.Position, Radius = area.Radius + zone.Trees.Scattered.ClearAroundMobs })
end
for x = -160, 160, 22 do -- the gate, its walls and the town behind them: no trees there
	table.insert(keepClear, { Position = Vector3.new(x, 0, zone.Gate.Z + 6), Radius = 36 })
end
buildTrees(zone, points, keepClear)
buildCanyon(zone) -- last and slowest; it waits between batches, but everything the player stands on is already built

print(`[Zone] {zone.Name} (levels {zone.LevelRange[1]}-{zone.LevelRange[2]}): radius {zone.Radius}, canyon wall built`)

return true
