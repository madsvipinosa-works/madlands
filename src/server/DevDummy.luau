-- Dev-only test dummy for trying combat. Only spawns when Config/Dev.luau has DEV_MODE = true.
local Dev = require(game:GetService("ReplicatedStorage").Shared.Config.Dev)

if not Dev.DEV_MODE then
	return true
end

local RESPAWN_SECONDS = 3
local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation")
local base = spawnLocation and spawnLocation.Position or Vector3.new(0, 0, 0)
local position = base + Vector3.new(0, 3, -6) -- default spawn faces -Z, so this is in front

local function spawnDummy()
	local dummy = Instance.new("Model")
	dummy.Name = "DevDummy"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 5, 2)
	root.Position = position
	root.Anchored = true
	root.BrickColor = BrickColor.new("Bright red")
	root.Parent = dummy

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = dummy

	dummy.PrimaryPart = root
	dummy.Parent = workspace
	print(`[DevDummy] spawned with 100 health at {position}`)

	humanoid.Died:Once(function()
		print(`[DevDummy] died, respawning in {RESPAWN_SECONDS}s`)
		task.delay(RESPAWN_SECONDS, function()
			dummy:Destroy()
			spawnDummy()
		end)
	end)
end

spawnDummy()

return true
