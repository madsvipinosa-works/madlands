-- Arrows on the ground from you to your next step (client/Quests says where). Near goals are pointed at straight; far
-- ones are led along the village lane and the trail, so the arrows go out through the gap in the fence. Looks only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Style = require(Config:WaitForChild("Guide"))
local zone = require(Config:WaitForChild("Zones")).OutsideZone1

local player = Players.LocalPlayer

-- The way through the zone, from the head of the village lane to the gate.
local spine = {}
for i = #zone.Village.Lane, 1, -1 do
	table.insert(spine, zone.Village.Lane[i])
end
for _, point in zone.Trail.Waypoints do
	table.insert(spine, point)
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function nearest(point)
	local best, bestDistance = 1, math.huge
	for i, p in spine do
		local d = (p - point).Magnitude
		if d < bestDistance then
			best, bestDistance = i, d
		end
	end
	return best
end

local function route(from, to)
	if (to - from).Magnitude <= Style.DirectWithin then
		return { from, to }
	end
	local i, j = nearest(from), nearest(to)
	local step = if j >= i then 1 else -1
	while i ~= j and (spine[i + step] - from).Magnitude < (spine[i + step] - spine[i]).Magnitude do
		i += step -- already past that point: do not walk back to it
	end
	while i ~= j and (spine[j - step] - to).Magnitude < (spine[j - step] - spine[j]).Magnitude do
		j -= step -- no need to walk past the goal and come back
	end
	local points = { from }
	for k = i, j, step do
		table.insert(points, spine[k])
	end
	table.insert(points, to)
	return points
end

local folder = Instance.new("Folder")
folder.Name = "GuideArrows"
folder.Parent = workspace

local arrows = {} -- each: two glowing bars that make a ">" pointing forward
for _ = 1, Style.Count do
	local arrow = {}
	for side = -1, 1, 2 do
		local bar = Instance.new("Part")
		bar.Anchored = true
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.CastShadow = false
		bar.Material = Enum.Material.Neon
		bar.Color = Style.Color
		bar.Size = Vector3.new(0.3, 0.12, 1.25)
		bar.Transparency = 1
		bar.Parent = folder
		table.insert(arrow, { part = bar, offset = CFrame.new(side * 0.42, 0, 0) * CFrame.Angles(0, side * math.rad(45), 0) })
	end
	table.insert(arrows, arrow)
end

local terrain = RaycastParams.new()
terrain.FilterType = Enum.RaycastFilterType.Include
terrain.FilterDescendantsInstances = { workspace.Terrain }

local goal -- function() -> position, hide within this distance; or nil

local Guide = {}

function Guide.SetGoal(fn)
	goal = fn
end

RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local target, hideWithin
	if goal and root then
		target, hideWithin = goal(flat(root.Position))
	end
	local points
	if target and (flat(target) - flat(root.Position)).Magnitude > hideWithin then
		points = route(flat(root.Position), flat(target))
	end

	local used = 0
	if points then
		local total = 0
		for i = 2, #points do
			total += (points[i] - points[i - 1]).Magnitude
		end
		local along = Style.StartAhead + (os.clock() * Style.Speed) % Style.Spacing
		local segment, before = 2, 0
		while used < #arrows and along < total - 3 do
			while along > before + (points[segment] - points[segment - 1]).Magnitude do
				before += (points[segment] - points[segment - 1]).Magnitude
				segment += 1
			end
			local direction = (points[segment] - points[segment - 1]).Unit
			local position = points[segment - 1] + direction * (along - before)
			local hit = workspace:Raycast(Vector3.new(position.X, root.Position.Y + 40, position.Z), Vector3.new(0, -100, 0), terrain)
			if hit then
				used += 1
				local grassy = hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.LeafyGrass
				local base = CFrame.lookAlong(hit.Position + Vector3.new(0, if grassy then Style.HeightOnGrass else Style.HeightOnPath, 0), direction)
				for _, bar in arrows[used] do
					bar.part.CFrame = base * bar.offset
					bar.part.Transparency = 0.1
				end
			end
			along += Style.Spacing
		end
	end
	for i = used + 1, #arrows do
		for _, bar in arrows[i] do
			bar.part.Transparency = 1
		end
	end
end)

return Guide
