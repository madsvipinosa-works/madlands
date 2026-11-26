-- Builds the outside zones from Config/Zones: round grass ground, a dirt canyon wall around it, hills, a trail to the
-- gate site, and trees. Server only. Must load before the mobs, which stand on the ground.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Camps = require(ReplicatedStorage.Shared.Camps)
local CanyonShape = require(ReplicatedStorage.Shared.CanyonShape)

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
		-- not on the trail, not on the village, and not at the gate, which is built over it
		local fromVillage = (Vector3.new(x, 0, z) - zone.Village.Center).Magnitude
		if nearest(Vector3.new(x, 0, z), trail) > reach + zone.Trail.Width and fromVillage > reach + zone.Village.Radius and z + reach < zone.Gate.Z - 70 then
			terrain:FillBall(Vector3.new(x, height - hills.Radius, z), hills.Radius, material)
		end
	end
end

local smooth, faceOffset = CanyonShape.smooth, CanyonShape.faceOffset -- shared/CanyonShape: the gate's flank walls follow the same face

-- The canyon: every cell of a ring outside the zone gets a column of dirt. Seen from inside it is not one straight wall but
-- a rough cliff: the face wanders in and out (three scales of noise, so there are bays and headlands as well as crags), the
-- ground rises in two ledges and then a ragged top, and the ledges change width along the way. Each step up is taller than a
-- player can jump (and an invisible barrier, buildBarrier, keeps fast runners off it). Near the gate the wandering fades out, so the cliff meets the gate's walls
-- cleanly, and the cut where the gate takes over is ragged.
local function buildCanyon(zone)
	local c = zone.Canyon
	local material = Enum.Material[c.Material]
	terrain:SetMaterialColor(material, c.Color)
	local seed = c.Seed

	-- The height of the top of the cliff at a spot: broad swells plus small bumps, and now and then a crag one step higher.
	local function topAt(x, z)
		local n = math.noise(x / 70 + seed, z / 70 + seed, 4.5) + 0.5 * math.noise(x / 20 + seed, z / 20 + seed, 6.5)
		local top = c.Height + n * c.HeightVariation
		local crag = 4 * math.max(0, math.floor(math.noise(x / 7 + seed, z / 7 + seed, 7.5) * 2 + 0.5))
		top = math.clamp(top + crag, c.MinHeight, c.MaxHeight)
		-- Next to the gate the cliff rises to meet its walls, so the walls do not stand up out of a much lower cliff.
		local beyondGap = math.abs(x) - zone.Gate.CanyonGap
		if z > 0 and beyondGap < c.GateLift then
			top += (c.GateHeight - top) * (1 - smooth(beyondGap / c.GateLift))
		end
		return top
	end

	local green = c.Greenery
	local grassMaterial = Enum.Material[green.Material]
	local bushRng = Random.new(seed + 5)
	local bushes = {} -- where bushes grow: on the ledges
	local outer = zone.Radius + c.Thickness + c.EdgeWobble
	local cells = math.ceil(outer / CELL)
	local work = 0
	for i = -cells, cells do
		for j = -cells, cells do
			local x, z = (i + 0.5) * CELL, (j + 0.5) * CELL
			local distance = math.sqrt(x * x + z * z)
			local angle = math.atan2(z, x)
			local depth = distance - (zone.Radius + faceOffset(zone, angle)) -- how far in from the face this cell is
			-- Along the north edge the gate's walls take the canyon's place (Gate.CanyonGap = half the width of that stretch).
			local gapEdge = zone.Gate.CanyonGap + 8 * math.noise(z / 14 + seed, 0.5, 3.5)
			local underGate = z > 0 and math.abs(x) < gapEdge
			if depth >= 0 and depth <= c.Thickness and not underGate then
				local ux, uy = math.cos(angle), math.sin(angle)
				local w1 = 4 + 5 * (math.noise(ux * 6 + seed, uy * 6 + seed, 8.5) + 0.5) -- width of the first and second ledge
				local w2 = 4 + 5 * (math.noise(ux * 8 + seed, uy * 8 + seed, 9.5) + 0.5)
				local height
				if depth < w1 then
					height = c.Ledges[1]
				elseif depth < w1 + w2 then
					height = c.Ledges[2]
				else
					height = topAt(x, z)
				end
				height = math.max(math.floor(height / CELL) * CELL, CELL)
				terrain:FillBlock(CFrame.new(x, (height - zone.Depth) / 2, z), Vector3.new(CELL, height + zone.Depth, CELL), material)
				terrain:FillBlock(CFrame.new(x, height - CELL / 2, z), Vector3.new(CELL, CELL, CELL), grassMaterial) -- grass on every ledge and on top
				if depth < w1 + w2 and bushRng:NextNumber() < green.BushChance then
					table.insert(bushes, Vector3.new(x + bushRng:NextNumber(-1.5, 1.5), height + 1, z + bushRng:NextNumber(-1.5, 1.5)))
				end
				work += 1
				if work % 400 == 0 then
					task.wait() -- spread the work over a few frames; the middle of the zone is already solid
				end
			end
		end
	end

	-- Bushes on the ledges: a few leafy lumps, so the cliff is green and lived-in, not bare rock.
	local folder = Instance.new("Folder")
	folder.Name = "CanyonBushes"
	folder.Parent = workspace
	for _, position in bushes do
		local color = green.BushColors[bushRng:NextInteger(1, #green.BushColors)]
		for _ = 1, bushRng:NextInteger(2, 4) do
			local size = bushRng:NextNumber(3, 6)
			local lump = Instance.new("Part")
			lump.Shape = Enum.PartType.Ball
			lump.Anchored = true
			lump.CanCollide = false
			lump.CanQuery = false
			lump.CanTouch = false
			lump.Material = Enum.Material.LeafyGrass
			lump.Color = color
			lump.Size = Vector3.new(size, size * 0.75, size)
			lump.CFrame = CFrame.new(position + Vector3.new(bushRng:NextNumber(-2, 2), size * 0.25, bushRng:NextNumber(-2, 2)))
			lump.Parent = folder
		end
	end
end

-- Smooth terrain turns the steps of the canyon into slopes a player can run up at speed, so an invisible wall stands along
-- its face: short straight pieces, each just in front of the rock where it is, tall enough to stop any jump. Nothing is
-- needed where the gate's walls take the canyon's place.
local function buildBarrier(zone)
	local folder = Instance.new("Folder")
	folder.Name = "CanyonBarrier"
	folder.Parent = workspace
	local count = 240
	local step = math.pi * 2 / count
	for i = 0, count - 1 do
		local angle = i * step
		local radius = zone.Radius + faceOffset(zone, angle) - 1.5
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if not (z > 0 and math.abs(x) < zone.Gate.CanyonGap - 8) then -- the barrier starts inside the gate wall, which covers the join
			local piece = Instance.new("Part")
			piece.Name = "Barrier"
			piece.Anchored = true
			piece.CanQuery = false
			piece.CanTouch = false
			piece.CastShadow = false
			piece.Transparency = 1
			piece.Size = Vector3.new(2, 90, radius * step + 2) -- long enough to overlap its neighbours
			piece.CFrame = CFrame.new(x, 40, z) * CFrame.Angles(0, -angle, 0) -- its long side runs around the circle
			piece.Parent = folder
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

	-- The forecourt: paved from the end of the trail to the gate's doors, so no grass grows there. It widens from the stone
	-- apron to the full width (Gate.Forecourt) over the first Flare studs.
	local f = zone.Gate.Forecourt
	for z = math.floor(last.Z / CELL) * CELL + CELL / 2, zone.Gate.Z, CELL do
		local half = t.GateRadius + (f.HalfWidth - t.GateRadius) * math.clamp((z - last.Z) / f.Flare, 0, 1)
		local width = math.floor(half / CELL) * CELL * 2 -- whole cells: a partly covered cell would keep its grass
		terrain:FillBlock(CFrame.new(0, -CELL / 2, z), Vector3.new(width, CELL, CELL), gate)
	end
end

-- Beyond the canyon -------------------------------------------------------------------------------------------------------
-- Past the canyon the land goes on: rolling hills cut into smooth terraces, like rice terraces. The ground is one height per
-- 4-stud cell (the terraces are one cell high, so they stay gentle), the cells at the edge of each terrace are bare dirt like
-- the little walls round a paddy, and the terraces alternate between two greens. A haze in the air fades the far edge away.

-- 1 right behind the gate, fading to 0 off to either side: where the hill of the town stands.
local function townFactor(zone, angle)
	local fromNorth = math.abs((angle - math.pi / 2 + math.pi) % (2 * math.pi) - math.pi)
	return smooth(1 - fromNorth / (zone.Surroundings.Town.Spread + 0.15))
end

-- The surface height at a spot, before it is cut into terraces.
local function outsideHeight(zone, x, z)
	local s = zone.Surroundings
	local r = math.sqrt(x * x + z * z)
	local angle = math.atan2(z, x)
	local start = zone.Radius + faceOffset(zone, angle) + zone.Canyon.Thickness -- the canyon's back edge
	local t = smooth((r - start) / s.RampLength)
	local town = townFactor(zone, angle)
	local hills = (math.noise(x / s.HillSize + s.Seed, z / s.HillSize + s.Seed, 0.5) * s.HillHeight + math.noise(x / 35 + s.Seed, z / 35 + s.Seed, 1.5) * 8) * t * (1 - 0.7 * town)
	-- Right behind the gate the land starts lower and rises less (Town.Lower), so the gate's walls are not dwarfed by high ground.
	local h = s.StartHeight * (1 - s.Town.Lower * town) + s.Rise * t * (1 - 0.65 * town) + hills + s.Town.Bump * town * smooth((r - start) / 120)
	return h * (1 - 0.45 * (1 - 0.8 * town) * smooth((r - (s.Radius - 120)) / 120)) -- a little lower toward the rim, so it sinks into the haze
end

local function terraceHeight(zone, x, z)
	local step = zone.Surroundings.Terrace
	return math.max(math.floor(outsideHeight(zone, x, z) / step + 0.5) * step, 24)
end

local function inSurroundings(zone, x, z)
	local r = math.sqrt(x * x + z * z)
	local start = zone.Radius + faceOffset(zone, math.atan2(z, x)) + zone.Canyon.Thickness - 8 -- overlaps the canyon a little, so no gap
	return r >= start and r <= zone.Surroundings.Radius
end

local function buildSurroundings(zone)
	local s = zone.Surroundings
	terrain:SetMaterialColor(Enum.Material[s.AltGrass], s.AltColor)
	local body = Enum.Material[s.EdgeMaterial]
	local grass, alt = Enum.Material[s.Grass], Enum.Material[s.AltGrass]
	local cells = math.ceil(s.Radius / CELL)
	local work = 0
	for j = -cells, cells do
		local z = (j + 0.5) * CELL
		local runStart, runHeight, runTop -- the run of cells in this row that share one height and one top material
		local function flush(xEnd)
			if runStart then
				local length = xEnd - runStart
				local middle = runStart + length / 2
				terrain:FillBlock(CFrame.new(middle, runHeight - 14, z), Vector3.new(length, 20, CELL), body) -- dirt below the top cell
				terrain:FillBlock(CFrame.new(middle, runHeight - CELL / 2, z), Vector3.new(length, CELL, CELL), runTop)
				runStart = nil
				work += 1
				if work % 300 == 0 then
					task.wait()
				end
			end
		end
		for i = -cells, cells do
			local x = (i + 0.5) * CELL
			local height, top
			if inSurroundings(zone, x, z) then
				height = terraceHeight(zone, x, z)
				-- the cells along a terrace's edge are dirt; the rest of the terrace is grass, one of two greens by level
				if
					terraceHeight(zone, x + CELL, z) < height
					or terraceHeight(zone, x - CELL, z) < height
					or terraceHeight(zone, x, z + CELL) < height
					or terraceHeight(zone, x, z - CELL) < height
				then
					top = body
				else
					top = if (height / s.Terrace) % 2 == 0 then grass else alt
				end
			end
			if height and runStart and height == runHeight and top == runTop then
				-- the run goes on
			else
				flush(x - CELL / 2)
				if height then
					runStart, runHeight, runTop = x - CELL / 2, height, top
				end
			end
		end
		flush((cells + 1) * CELL)
	end
end

-- A haze in the air, so the far hills fade out instead of ending in nothing.
local function buildAtmosphere(zone)
	local h = zone.Surroundings.Haze
	local lighting = game:GetService("Lighting")
	local atmosphere = lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = h.Density
	atmosphere.Offset = h.Offset
	atmosphere.Color = h.Color
	atmosphere.Decay = h.Decay
	atmosphere.Glare = h.Glare
	atmosphere.Haze = h.Haze
	atmosphere.Parent = lighting
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

-- A rock: one of the hand-made models (assets/models/rocks), scaled so its longest side is `size` studs, turned any way,
-- tilted a touch and sunk into the ground. `look` is Config/Zones Rocks (Sink, Material, Tint).
local rockModels = ServerStorage:WaitForChild("Models"):WaitForChild("rocks")

local function rock(parent, x, y, z, kind, size, rng, look, solid)
	local model = rockModels:WaitForChild(kind):Clone()
	model.Name = "Rock"
	local _, native = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * size / math.max(native.X, native.Y, native.Z))
	local tilt = math.rad(look.Tilt)
	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(rng:NextNumber(-tilt, tilt), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-tilt, tilt)))
	local box, extent = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(x - box.X, y - extent.Y * look.Sink - (box.Y - extent.Y / 2), z - box.Z))
	local shade = look.Tint:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = solid
			part.CanTouch = false
			part.Material = Enum.Material[look.Material]
			part.Color = shade
		end
	end
	model.Parent = parent
end

-- A campfire: a ring of stones, three logs, ash, a fire with smoke and sparks that lights up the ground, and three log seats.
local function campfire(parent, x, y, z, rng, c, rocks)
	local model = Instance.new("Model")
	model.Name = "Campfire"
	local base = CFrame.new(x, y, z)
	local block, cylinder = Enum.PartType.Block, Enum.PartType.Cylinder
	local flat = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder Part lies along X; this stands it up

	for i = 0, c.Stones - 1 do -- the stone ring, spaced out
		local angle = i / c.Stones * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local spot = (base * CFrame.Angles(0, angle, 0) * CFrame.new(c.StoneRing, 0, 0)).Position
		rock(model, spot.X, y, spot.Z, c.StoneKinds[rng:NextInteger(1, #c.StoneKinds)], rng:NextNumber(c.StoneSize[1], c.StoneSize[2]), rng, rocks, true)
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

-- Bare ground round a fire, so the tall grass does not hide it. Painted in whole cells, like the trail: a partly covered cell
-- keeps its grass.
local function bareGround(center, radius, material)
	local cells = math.ceil(radius / CELL)
	local cx, cz = math.floor(center.X / CELL), math.floor(center.Z / CELL)
	for dx = -cells, cells do
		for dz = -cells, cells do
			local x, z = (cx + dx) * CELL + CELL / 2, (cz + dz) * CELL + CELL / 2
			if (x - center.X) ^ 2 + (z - center.Z) ^ 2 <= radius ^ 2 then
				terrain:FillBlock(CFrame.new(x, -CELL / 2, z), Vector3.one * CELL, material)
			end
		end
	end
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
			bareGround(spot, fires.BareRadius, Enum.Material[fires.BareMaterial])
			campfire(propsFolder, spot.X, y, spot.Z, fireRng, fires, zone.Rocks)
			table.insert(clear, { Position = spot, Radius = zone.Trees.Scattered.ClearAroundCampfires })
		end
	end

	-- Camp fires: the middle of a camp that asks for one.
	for _, camp in zone.Camps or {} do
		if camp.Campfire then
			local y = groundHeight(camp.Center.X, camp.Center.Z)
			if y then
				bareGround(camp.Center, fires.BareRadius, Enum.Material[fires.BareMaterial])
				campfire(propsFolder, camp.Center.X, y, camp.Center.Z, fireRng, fires, zone.Rocks)
				table.insert(clear, { Position = camp.Center, Radius = zone.Trees.Scattered.ClearAroundCampfires })
			end
		end
	end

	local r = zone.Rocks
	local rng = Random.new(r.Seed)
	local noRocks = { { Position = zone.Village.Center, Radius = zone.Village.Radius } } -- circles rocks must stay out of: the village and every fire
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
				-- which rocks stand here depends on how far along the trail this is (Rocks.Areas)
				local area = r.Areas[#r.Areas]
				for _, candidate in r.Areas do
					if along[i] / total <= candidate.Until then
						area = candidate
						break
					end
				end
				local rocksInGroup = if boulder then 1 else rng:NextInteger(r.Group[1], r.Group[2])
				for n = 1, rocksInGroup do
					local spot = center + Vector3.new(rng:NextNumber(-3.5, 3.5), 0, rng:NextNumber(-3.5, 3.5))
					local y = groundHeight(spot.X, spot.Z)
					if y then
						local kinds = if boulder then area.Boulder elseif n == 1 then area.Main else area.Small
						local kind = kinds[rng:NextInteger(1, #kinds)]
						local size = if boulder then rng:NextNumber(r.BoulderSize[1], r.BoulderSize[2]) else rng:NextNumber(r.Size[1], r.Size[2])
						rock(propsFolder, spot.X, y, spot.Z, kind, size, rng, r, kind ~= "RockPebbles") -- pebbles are walked over
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

	-- Scattered: random spots in groves, away from the village, the mobs, the trail and the canyon.
	local s = trees.Scattered
	for _ = 1, s.Count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber()) * (zone.Radius - s.EdgeMargin)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		local position = Vector3.new(x, 0, z)
		local grove = math.noise(x / 55 + trees.Seed, z / 55 + trees.Seed, 2.5) -- -1..1: positive in groves, negative in clearings
		if
			grove > s.GroveCutoff
			and nearest(position, points) > zone.Trail.Width / 2 + s.ClearAroundTrail
			and clearOf(position, keepClear)
		then
			plant(x, z)
		end
	end
	print(`[Zone] {placed} trees planted`)
end

-- The village where players start ---------------------------------------------------------------------------------

-- A rustic fence along a smooth line through Fence.Path: slightly crooked timber posts with two rails, a stone pillar every
-- few posts (a copy of a house chimney, so the stonework matches), and taller pillars with a lantern at the two ends, the way in.
local function fence(parent, f)
	local rng = Random.new(f.Seed)
	local points = trailPoints(f.Path)
	local spots, run = { points[1] }, 0
	for i = 2, #points do
		run += (points[i] - points[i - 1]).Magnitude
		if run >= f.PostEvery then
			run = 0
			table.insert(spots, points[i])
		end
	end
	if (points[#points] - spots[#spots]).Magnitude < f.PostEvery / 2 then
		spots[#spots] = points[#points]
	else
		table.insert(spots, points[#points])
	end

	local model = Instance.new("Model")
	model.Name = "Fence"
	model.Parent = parent
	local function part(cframe, size, color)
		return prop(model, Enum.PartType.Block, cframe, size, Enum.Material.SmoothPlastic, color, true)
	end
	local chimney = ServerStorage.Models.houses[f.Stone.Model]:FindFirstChild(f.Stone.Part, true)

	local previous -- the ground under the post before this one
	for i, spot in spots do
		local y = groundHeight(spot.X, spot.Z)
		if not y then
			previous = nil
			continue
		end
		local ground = Vector3.new(spot.X, y, spot.Z)
		local base = CFrame.lookAlong(ground, spots[math.min(i + 1, #spots)] - spots[math.max(i - 1, 1)])
		local entrance = i == 1 or i == #spots
		if entrance or (i % f.PillarEvery == 1 and i < #spots - 2) then
			local height = if entrance then f.EntranceHeight else f.PillarHeight
			if chimney then
				local pillar = chimney:Clone()
				local width = if entrance then f.EntranceWidth else f.PillarWidth
				pillar.Size = chimney.Size * (width / chimney.Size.X) -- the same shape, smaller; the part not needed sits in the ground
				pillar.CFrame = base * CFrame.new(0, height - pillar.Size.Y / 2, 0) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
				pillar.Anchored = true
				pillar.CanTouch = false
				pillar.Color = Color3.new(1, 1, 1)
				pillar.Parent = model
			end
			if entrance then
				local top = base * CFrame.new(0, height - 0.1, 0)
				local glass = part(top * CFrame.new(0, 0.75, 0), Vector3.new(1, 1.2, 1), f.LanternColor)
				glass.Material = Enum.Material.Neon
				for x = -1, 1, 2 do
					for z = -1, 1, 2 do
						part(top * CFrame.new(x * 0.55, 0.75, z * 0.55), Vector3.new(0.22, 1.5, 0.22), f.PostColor)
					end
				end
				part(top * CFrame.new(0, 1.6, 0), Vector3.new(1.7, 0.35, 1.7), f.PostColor)
				local light = Instance.new("PointLight")
				light.Color = f.LanternColor
				light.Range = 18
				light.Brightness = 1.5
				light.Shadows = false
				light.Parent = glass
			end
		else
			local height = f.PostHeight * rng:NextNumber(0.9, 1.1)
			local post = base * CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(-4, 4)))
			part(post * CFrame.new(0, height / 2 - 0.3, 0), Vector3.new(0.85, height + 0.6, 0.85), f.PostColor)
			part(post * CFrame.new(0, height + 0.15, 0) * CFrame.Angles(0, math.pi / 4, 0), Vector3.new(0.7, 0.45, 0.7), f.RailColor)
		end
		if previous then
			for _, share in { 0.38, 0.72 } do -- two rails, at these shares of the post height
				local from = previous + Vector3.new(0, f.PostHeight * share + rng:NextNumber(-0.18, 0.18), 0)
				local to = ground + Vector3.new(0, f.PostHeight * share + rng:NextNumber(-0.18, 0.18), 0)
				part(CFrame.lookAt((from + to) / 2, to), Vector3.new(0.35, 0.55, (to - from).Magnitude), f.RailColor)
			end
		end
		previous = ground
	end
end

-- The village (Config/Zones Village): the hand-made houses (assets/models/houses) along a winding dirt lane, each facing
-- its own spot with a path to it, a campfire in the square, a few trees and a fence round it all.
local function buildVillage(zone)
	local v = zone.Village
	local models = ServerStorage:WaitForChild("Models"):WaitForChild("houses")
	local rng = Random.new(v.Fence.Seed + 1)
	local folder = Instance.new("Folder")
	folder.Name = "Village"
	folder.Parent = propsFolder -- so nothing in it counts as ground

	-- Everything is stood on the ground first and the dirt painted last: terrain that was just repainted may not answer a
	-- raycast for a moment.
	local yards = {}
	for _, house in v.Houses do
		local y = groundHeight(house.Position.X, house.Position.Z)
		if y then
			local model = models:WaitForChild(house.Model):Clone()
			model:ScaleTo(model:GetScale() * v.Scale[house.Model])
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanTouch = false
					part.Color = Color3.new(1, 1, 1) -- white shows the model's own colors
				end
			end
			-- the models' doors face -Z, which lookAlong turns toward the spot the house faces
			model:PivotTo(CFrame.lookAlong(model:GetPivot().Position, house.Faces - house.Position))
			local box, extent = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + Vector3.new(house.Position.X - box.X, y - v.Sink - (box.Y - extent.Y / 2), house.Position.Z - box.Z))
			model.Parent = folder
			table.insert(yards, { At = house.Position, Radius = math.min(extent.X, extent.Z) / 2 + 1 })
		end
	end
	local fireY = groundHeight(v.Campfire.X, v.Campfire.Z)
	if fireY then
		campfire(folder, v.Campfire.X, fireY, v.Campfire.Z, Random.new(zone.Trees.Seed + 2), zone.Campfires, zone.Rocks)
	end
	fence(folder, v.Fence)
	local settings = table.clone(zone.Trees)
	settings.Scale = v.Trees.Scale
	for _, spot in v.Trees.Spots do
		local y = groundHeight(spot.X, spot.Z)
		if y then
			tree(folder, spot.X, y, spot.Z, rng, settings)
		end
	end

	local dirt = Enum.Material[zone.Trail.Material]
	for _, patches in { v.Dirt, yards } do -- the square, and a yard under each house so no tall grass covers the doorstep
		for _, patch in patches do
			bareGround(patch.At, patch.Radius, dirt)
		end
	end
	for _, point in trailPoints(v.Lane) do
		bareGround(point, v.LaneWidth / 2 * rng:NextNumber(0.8, 1.15), dirt)
	end
	for _, house in v.Houses do -- the path to each door, with a slight bend in it
		local along = house.Faces - house.Position
		local bend = Vector3.new(-along.Z, 0, along.X).Unit * rng:NextNumber(-5, 5)
		for _, point in trailPoints({ house.Position, house.Position + along * 0.55 + bend, house.Faces }) do
			bareGround(point, v.PathWidth / 2 * rng:NextNumber(0.85, 1.15), dirt)
		end
	end
	print(`[Zone] village built: {#v.Houses} houses`)
end

-- The town beyond the gate ------------------------------------------------------------------------------------------------
-- The Starter Town itself is a separate place, but from the gate it should look like a town lies behind: a hill rises behind the
-- gate's walls, and on it stand a few rows of houses and a town hall with a clock tower, lit by warm windows.
-- This is scenery only; nobody can go there (the walls and the canyon close it off).

local function townPart(parent, cframe, size, material, color, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = material
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function smoke(part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 148, 146))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Rate = 2
	emitter.Parent = part
end

-- A house: plastered walls on a stone foot, a long pitched roof along the row, warm windows, a chimney. `base` stands on the ground
-- and faces the way the front (-Z) points.
local function townHouse(parent, base, w, d, h, rng, t)
	local model = Instance.new("Model")
	model.Name = "House"
	model.Parent = parent
	local wall = t.WallColors[rng:NextInteger(1, #t.WallColors)]
	local roof = t.RoofColors[rng:NextInteger(1, #t.RoofColors)]
	townPart(model, base * CFrame.new(0, -3, 0), Vector3.new(w + 1, 8, d + 1), Enum.Material.Cobblestone, Color3.fromRGB(112, 108, 102)) -- foot, deep enough for uneven ground
	townPart(model, base * CFrame.new(0, h / 2, 0), Vector3.new(w, h, d), Enum.Material.Concrete, wall)
	townPart(model, base * CFrame.new(0, h - 0.7, 0), Vector3.new(w + 0.6, 1.4, d + 0.6), Enum.Material.Wood, Color3.fromRGB(92, 66, 44))
	local rise = d * 0.62
	local half = d / 2 + 1.5
	local tilt = math.atan2(rise, half)
	local slab = math.sqrt(half ^ 2 + rise ^ 2) + 0.4
	for side = -1, 1, 2 do
		townPart(model, base * CFrame.new(0, h + rise / 2, side * half / 2) * CFrame.Angles(side * tilt, 0, 0), Vector3.new(w + 3, 1.2, slab), Enum.Material.Slate, roof)
	end
	local chimney = townPart(model, base * CFrame.new(w * 0.28, h + rise + 3, d * 0.12), Vector3.new(3, 9, 3), Enum.Material.Cobblestone, Color3.fromRGB(104, 100, 96))
	smoke(chimney)
	for i = 1, math.max(math.floor(w / 7), 2) do
		local x = -w / 2 + (i - 0.5) * w / math.max(math.floor(w / 7), 2)
		townPart(model, base * CFrame.new(x, h * 0.58, -d / 2 - 0.15), Vector3.new(2.6, 3.6, 0.3), Enum.Material.Neon, Color3.fromRGB(255, 196, 110))
	end
	townPart(model, base * CFrame.new(0, 4.5, -d / 2 - 0.2), Vector3.new(4.5, 9, 0.4), Enum.Material.Wood, Color3.fromRGB(84, 58, 38)) -- door
end

local function buildTownBackdrop(zone)
	local t = zone.Surroundings.Town
	local rng = Random.new(t.Seed)
	local folder = Instance.new("Folder")
	folder.Name = "TownBackdrop"
	folder.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local function ground(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -800, 0), params)
		return hit and hit.Position.Y
	end
	local count = 0

	-- The town wall: the hand-made WallPiece tiled along a curve (Town.Wall.Path) that starts at the ends of the gate's walls and
	-- bends round behind the town, so the houses stand inside a walled enclosure on the terraces beyond the canyon.
	local wall = t.Wall
	local wallPoints = trailPoints(wall.Path)
	local piece = ServerStorage.Models:FindFirstChild(wall.Model)
	local function inside(x, z, margin)
		-- even-odd test against the wall's outline, closed across the gate side
		local isIn = false
		local n = #wallPoints
		for i = 1, n do
			local a, b = wallPoints[i], wallPoints[i % n + 1]
			if (a.Z > z) ~= (b.Z > z) and x < a.X + (z - a.Z) / (b.Z - a.Z) * (b.X - a.X) then
				isIn = not isIn
			end
		end
		return isIn and nearest(Vector3.new(x, 0, z), wallPoints) > margin
	end
	local wallPieces = 0
	if piece then
		local wallFolder = Instance.new("Folder")
		wallFolder.Name = "TownWall"
		wallFolder.Parent = folder
		local base = piece:GetPivot()
		local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
		for _, part in piece:GetDescendants() do
			if part:IsA("MeshPart") then
				local cf = base:Inverse() * part.CFrame
				local half = part.Size / 2
				local r = cf:VectorToWorldSpace(Vector3.new(half.X, 0, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, half.Y, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, 0, half.Z)):Abs()
				lo = Vector3.new(math.min(lo.X, cf.X - r.X), math.min(lo.Y, cf.Y - r.Y), math.min(lo.Z, cf.Z - r.Z))
				hi = Vector3.new(math.max(hi.X, cf.X + r.X), math.max(hi.Y, cf.Y + r.Y), math.max(hi.Z, cf.Z + r.Z))
			end
		end
		local scale = wall.Scale
		local length = (hi.X - lo.X) * scale
		local travelled = length -- so the first piece goes right at the start
		for i = 1, #wallPoints - 1 do
			travelled += (wallPoints[i + 1] - wallPoints[i]).Magnitude
			if travelled >= length * 0.78 then -- plenty of overlap, so the outside of a curve has no cracks between pieces
				travelled = 0
				local a, b = wallPoints[i], wallPoints[math.min(i + 4, #wallPoints)]
				local tangent = (b - a).Unit
				local middle = (a + b) / 2
				local normal = Vector3.new(-tangent.Z, 0, tangent.X)
				local lowest = math.huge
				for _, offset in { -0.5, 0, 0.5 } do -- the lowest ground under it, so the terraces never leave a gap beneath
					lowest = math.min(lowest, ground(middle.X + tangent.X * length * offset, middle.Z + tangent.Z * length * offset) or lowest)
				end
				if lowest < math.huge then
					local copy = piece:Clone()
					copy:ScaleTo(copy:GetScale() * scale)
					local y = lowest - wall.Sink - lo.Y * scale
					copy:PivotTo(CFrame.lookAt(Vector3.new(middle.X, y, middle.Z), Vector3.new(middle.X, y, middle.Z) + normal))
					for _, part in copy:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored = true
							part.CanCollide = false -- beyond the canyon, where nobody goes
							part.CanQuery = false
							part.CanTouch = false
							part.Material = Enum.Material.Slate
							part.Color = Color3.new(1, 1, 1)
						end
					end
					copy.Parent = wallFolder
					wallPieces += 1
				end
			end
		end
	else
		warn(`[Zone] ServerStorage.Models.{wall.Model} not found: save it as assets/models/{wall.Model}.rbxm`)
	end

	-- Rows of houses inside the wall, facing the gate.
	for _, z in t.RowsZ do
		local x = -t.HalfWidth
		while x <= t.HalfWidth do
			local w, d, h = rng:NextNumber(t.Width[1], t.Width[2]), rng:NextNumber(t.Depth[1], t.Depth[2]), rng:NextNumber(t.Height[1], t.Height[2])
			local px, pz = x + rng:NextNumber(-4, 4), z + rng:NextNumber(-5, 5)
			local y = ground(px, pz)
			if y and math.abs(px) > t.LaneHalfWidth + w / 2 and rng:NextNumber() > t.Gaps and inside(px, pz, t.WallMargin + w / 2) then
				townHouse(folder, CFrame.new(px, y - 1, pz), w, d, h, rng, t)
				count += 1
			end
			x += w + rng:NextNumber(t.Gap[1], t.Gap[2])
		end
	end

	-- The town hall at the top of the street, straight behind the gate: a long hall with a pitched roof, columns and steps along the
	-- front, and a clock tower rising from the middle.
	local hall = t.Hall
	local hy = ground(0, hall.Z)
	local base = hy and CFrame.new(0, hy - 1, hall.Z)
	if base then
		local model = Instance.new("Model")
		model.Name = "TownHall"
		model.Parent = folder
		local stone = t.StoneColor
		townPart(model, base * CFrame.new(0, -4, 0), Vector3.new(hall.Width + 10, 10, hall.Depth + 10), Enum.Material.Cobblestone, stone) -- the foot
		townPart(model, base * CFrame.new(0, hall.Height / 2, 0), Vector3.new(hall.Width, hall.Height, hall.Depth), Enum.Material.Concrete, Color3.fromRGB(214, 200, 176))
		townPart(model, base * CFrame.new(0, hall.Height - 0.8, 0), Vector3.new(hall.Width + 1, 1.6, hall.Depth + 1), Enum.Material.Wood, Color3.fromRGB(92, 66, 44))
		local rise = hall.Depth * 0.5
		local half = hall.Depth / 2 + 2
		local tilt = math.atan2(rise, half)
		local slab = math.sqrt(half ^ 2 + rise ^ 2) + 0.5
		for side = -1, 1, 2 do
			townPart(model, base * CFrame.new(0, hall.Height + rise / 2, side * half / 2) * CFrame.Angles(side * tilt, 0, 0), Vector3.new(hall.Width + 4, 1.4, slab), Enum.Material.Slate, Color3.fromRGB(88, 94, 106))
		end
		for i = -3, 3 do -- columns along the front
			townPart(model, base * CFrame.new(i * hall.Width / 7.5, hall.Height * 0.4, -hall.Depth / 2 - 2), Vector3.new(3, hall.Height * 0.8, 3), Enum.Material.Marble, Color3.fromRGB(226, 222, 212))
		end
		townPart(model, base * CFrame.new(0, hall.Height * 0.82, -hall.Depth / 2 - 2), Vector3.new(hall.Width * 0.9, 2.4, 4), Enum.Material.Marble, Color3.fromRGB(226, 222, 212)) -- the beam over them
		for step = 0, 3 do
			townPart(model, base * CFrame.new(0, step * 1.2 - 3, -hall.Depth / 2 - 6 - (3 - step) * 2), Vector3.new(hall.Width * 0.5, 2.4, 4), Enum.Material.Cobblestone, stone)
		end
		for i = -2, 2 do
			if i ~= 0 then
				local window = townPart(model, base * CFrame.new(i * hall.Width / 6, hall.Height * 0.5, -hall.Depth / 2 - 0.2), Vector3.new(4, 8, 0.4), Enum.Material.Neon, Color3.fromRGB(255, 196, 110))
				window.Transparency = 0.15
			end
		end
		townPart(model, base * CFrame.new(0, 6, -hall.Depth / 2 - 0.3), Vector3.new(9, 12, 0.5), Enum.Material.Wood, Color3.fromRGB(84, 58, 38)) -- the great door
		-- the clock tower
		local tw = hall.TowerWidth
		townPart(model, base * CFrame.new(0, hall.Height + hall.TowerHeight / 2 - 4, 0), Vector3.new(tw, hall.TowerHeight, tw), Enum.Material.Cobblestone, stone)
		townPart(model, base * CFrame.new(0, hall.Height + hall.TowerHeight - 2, 0), Vector3.new(tw + 4, 4, tw + 4), Enum.Material.Cobblestone, stone)
		for i = 0, 5 do -- a stepped pyramid roof
			local width = (tw + 4) * (1 - i / 6)
			townPart(model, base * CFrame.new(0, hall.Height + hall.TowerHeight + 2 + i * 4, 0), Vector3.new(width, 4, width), Enum.Material.Slate, Color3.fromRGB(150, 62, 50))
		end
		local clock = townPart(model, base * CFrame.new(0, hall.Height + hall.TowerHeight * 0.7, -tw / 2 - 0.3), Vector3.new(tw * 0.6, tw * 0.6, 0.5), Enum.Material.Neon, Color3.fromRGB(255, 240, 200), Enum.PartType.Cylinder)
		clock.CFrame = base * CFrame.new(0, hall.Height + hall.TowerHeight * 0.7, -tw / 2 - 0.3) * CFrame.Angles(0, math.pi / 2, 0)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Range = 50
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = clock
		count += 1
	end
	print(`[Zone] town backdrop: {count} buildings inside {wallPieces} wall pieces`)
end

-- Trees on the far terraces, big enough to read from inside the zone. Their heights come from a raycast onto the new terrain.
local function buildFarTrees(zone)
	local s = zone.Surroundings
	local rng = Random.new(s.Seed + 3)
	local folder = Instance.new("Folder")
	folder.Name = "FarTrees"
	folder.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local settings = table.clone(zone.Trees)
	settings.Scale = s.Trees.Scale
	local placed = 0
	for _ = 1, s.Trees.Count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = zone.Radius + zone.Canyon.Thickness + 40 + rng:NextNumber(0, 1) * (s.Radius - s.Trees.Edge - (zone.Radius + zone.Canyon.Thickness + 40))
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local hit = townFactor(zone, angle) < 0.05 and workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params) -- none on the town's hill
		-- only on the grass of a terrace, not on the dirt edge
		if hit and hit.Position.Y > 30 and (hit.Material == Enum.Material[s.Grass] or hit.Material == Enum.Material[s.AltGrass]) then
			tree(folder, x, hit.Position.Y, z, rng, settings)
			placed += 1
		end
	end
	print(`[Zone] {placed} trees on the far terraces`)
end

-- The spawn: a hidden SpawnLocation in the village, facing north, and no flat baseplate to hide the grass.
local function placeSpawn(zone)
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
	spawn.CFrame = CFrame.lookAlong(zone.Village.Spawn, Vector3.zAxis)
	spawn.Parent = workspace
end

local zone = Zones.OutsideZone1

-- The client waits for this remote from the moment it joins, and the zone takes a while to build, so it is made first.
-- (GateBuilder uses it for the "entering the town" fade.)
local gateRemote = Instance.new("RemoteEvent")
gateRemote.Name = "GateEnter"
gateRemote.Parent = ReplicatedStorage

-- Smooth terrain turns the step between two ledges into a steep slope, and a Humanoid walks up any slope below its MaxSlopeAngle
-- (89 degrees by default), which would let players walk up the canyon. So players are limited to zone.MaxWalkSlope, set as soon
-- as they spawn (the zone takes a while to build, and people can join before it is done).
local function limitSlope(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.MaxSlopeAngle = zone.MaxWalkSlope
	end
end
local function watch(player)
	player.CharacterAdded:Connect(limitSlope)
	if player.Character then
		task.spawn(limitSlope, player.Character)
	end
end
game:GetService("Players").PlayerAdded:Connect(watch)
for _, player in game:GetService("Players"):GetPlayers() do
	watch(player)
end
-- Grass length is a Terrain property a game script is not allowed to change; it is set on the place in Studio instead.
buildGround(zone)
placeSpawn(zone)
local points = trailPoints(zone.Trail.Waypoints)
buildHills(zone, points)
paintTrail(zone, points)
buildSurroundings(zone)
buildAtmosphere(zone)
task.wait(1) -- new terrain cannot be raycast for a moment; the props and trees look for the ground with a raycast
treeRay.FilterDescendantsInstances = { propsFolder }
local keepClear = buildProps(zone, points)
buildVillage(zone)
table.insert(keepClear, { Position = zone.Village.Center, Radius = zone.Village.Radius })
for _, area in Camps.Areas(zone) do -- the mobs' ground stays open: no trees where they walk and fight
	table.insert(keepClear, { Position = area.Position, Radius = area.Radius + zone.Trees.Scattered.ClearAroundMobs })
end
for x = -300, 300, 20 do -- the gate and its walls: no trees on them
	table.insert(keepClear, { Position = Vector3.new(x, 0, zone.Gate.Z), Radius = 16 * zone.Gate.Scale })
end
table.insert(keepClear, { Position = Vector3.new(0, 0, zone.Gate.Z - 40 * zone.Gate.Scale), Radius = 44 * zone.Gate.Scale }) -- the gate's forecourt
buildTrees(zone, points, keepClear)
buildFarTrees(zone)
buildTownBackdrop(zone)
buildCanyon(zone)
buildBarrier(zone)
-- (the canyon is the last and slowest step; it waits between batches, but everything the player stands on is already built)

print(`[Zone] {zone.Name} (levels {zone.LevelRange[1]}-{zone.LevelRange[2]}): radius {zone.Radius}, canyon wall built`)

return true
