-- Dev-only flat test ground. Only runs when Config/Dev.luau has DEV_MODE = true. Must load before DevDummy and MobSpawner.
local Dev = require(game:GetService("ReplicatedStorage").Shared.Config.Dev)

if not Dev.DEV_MODE then
	return true
end

local ground = Dev.TestGround
local material = Enum.Material[ground.Material]
local terrain = workspace.Terrain

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
