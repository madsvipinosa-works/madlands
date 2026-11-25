-- Dev-only flat test ground. Only runs when Config/Dev.luau has DEV_MODE = true. Must load before DevDummy and MobSpawner.
local Dev = require(game:GetService("ReplicatedStorage").Shared.Config.Dev)

if not Dev.DEV_MODE then
	return true
end

local ground = Dev.TestGround
local material = Enum.Material[ground.Material]
local terrain = workspace.Terrain

-- Grass length is a Terrain property a game script is not allowed to change; it is set on the place in Studio instead.
terrain:SetMaterialColor(Enum.Material.Grass, ground.GrassColor)

-- Flat slab with its top surface at y = 0.
terrain:FillBlock(CFrame.new(0, -ground.Depth / 2, 0), Vector3.new(ground.Size, ground.Depth, ground.Size), material)

-- Hills: the top of a big ball poking out of the ground. The ball sits below ground, so only a gentle dome shows.
local hills = ground.Hills
local rng = Random.new(hills.Seed)
local half = ground.Size / 2
for i = 1, hills.Count do
	local angle = (i + rng:NextNumber(-0.3, 0.3)) / hills.Count * math.pi * 2
	local distance = half - rng:NextNumber(10, 60) -- near the edge, so the middle stays flat
	local height = hills.Height * rng:NextNumber(0.6, 1)
	local center = Vector3.new(math.cos(angle) * distance, height - hills.Radius, math.sin(angle) * distance)
	terrain:FillBall(center, hills.Radius, material)
end

-- The trail to the town: a smooth curve through the waypoints (a Catmull-Rom spline). Terrain is made of 4-stud cells and
-- only a fully covered cell changes its material, so the path is painted cell by cell: every cell whose middle is within
-- half the (slightly varying) width of the curve becomes dirt. A stone plaza closes the town end.
local trail = ground.Trail
if trail then
	local points = trail.Waypoints
	local trailMaterial = Enum.Material[trail.Material]
	terrain:SetMaterialColor(trailMaterial, trail.Color)
	local wobble = Random.new(trail.Seed)
	local function point(i)
		return points[math.clamp(i, 1, #points)]
	end
	local CELL = 4 -- studs; the terrain's cell size
	local painted = {} -- ["x,z"] = true, so a cell is only filled once
	local last
	for i = 1, #points - 1 do
		local p0, p1, p2, p3 = point(i - 1), point(i), point(i + 1), point(i + 2)
		local steps = math.ceil((p2 - p1).Magnitude / (CELL / 2))
		for s = 0, steps do
			local t = s / steps
			local position = 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ^ 2 + (3 * p1 - p0 - 3 * p2 + p3) * t ^ 3)
			local reach = trail.Width / 2 * wobble:NextNumber(0.8, 1.2)
			local cells = math.ceil(reach / CELL) + 1
			local cx, cz = math.floor(position.X / CELL), math.floor(position.Z / CELL)
			for dx = -cells, cells do
				for dz = -cells, cells do
					local x, z = (cx + dx) * CELL + CELL / 2, (cz + dz) * CELL + CELL / 2
					local key = x .. "," .. z
					if not painted[key] and (Vector3.new(x, 0, z) - position).Magnitude <= reach then
						painted[key] = true
						terrain:FillBlock(CFrame.new(x, -CELL / 2, z), Vector3.one * CELL, trailMaterial)
					end
				end
			end
			last = position
		end
	end
	local plazaMaterial = Enum.Material[trail.PlazaMaterial]
	terrain:SetMaterialColor(plazaMaterial, trail.PlazaColor)
	terrain:FillCylinder(CFrame.new(last.X, -CELL / 2, last.Z), CELL, trail.PlazaRadius, plazaMaterial)
end

-- The flat baseplate would hide the grass.
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

-- Invisible spawn at 0, 3, 0, still the spawn point.
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

print(`[DevGround] {ground.Size}x{ground.Size} {ground.Material} ground, {hills.Count} hills, spawn at {spawn.Position}`)

return true
