-- You come back where you logged out. While you play, your position is noted in your saved data (ProfileStore, through
-- PlayerData); when you join again you are put back there. If you died (or never played), you start at the spawn.
-- Server only. A spot only counts in the place it was saved in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CanyonShape = require(ReplicatedStorage.Shared.CanyonShape)
local zone = require(ReplicatedStorage.Shared.Config.Zones).OutsideZone1
local PlayerData = require(script.Parent.PlayerData)

local NOTE_EVERY = 1 -- seconds between notes of your position

-- Where to put a returning player, or nil to leave them at the spawn. The saved spot is checked again because the client
-- moves its own character, and the map can change between visits.
local function placeFor(saved)
	if type(saved) ~= "table" or saved.Place ~= game.PlaceId then
		return nil
	end
	local x, z = saved.X, saved.Z
	local edge = zone.Radius + CanyonShape.faceOffset(zone, math.atan2(z, x)) - 6
	if math.sqrt(x * x + z * z) > edge then
		return nil -- in or beyond the canyon
	end
	if math.abs(x) < zone.Gate.CanyonGap then
		z = math.min(z, zone.Gate.Z - zone.Gate.ReturnDistance) -- not inside the gate: you would "enter the town" at once
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local ground = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return ground and ground.Position + Vector3.new(0, 4, 0)
end

local function follow(player)
	local data = PlayerData.Get(player)
	while not data do -- still loading, or the player left
		if player.Parent ~= Players then
			return
		end
		task.wait(0.2)
		data = PlayerData.Get(player)
	end
	while not workspace:GetAttribute("ZoneReady") do -- set by init.server once the ground is built
		task.wait(0.2)
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local spot = placeFor(data.Position)
	if root and spot then
		pcall(player.RequestStreamAroundAsync, player, spot) -- so the ground there has loaded for the player
		task.wait(0.2) -- after Roblox has finished putting the new character at the spawn
		character:PivotTo(CFrame.new(spot))
		task.wait(0.5)
	end

	-- Only now start noting positions, so the spawn never overwrites the saved spot.
	while player.Parent == Players do
		local live = PlayerData.Get(player)
		local current = player.Character
		local currentRoot = current and current:FindFirstChild("HumanoidRootPart")
		local humanoid = current and current:FindFirstChildOfClass("Humanoid")
		if live and currentRoot and humanoid then
			local p = currentRoot.Position
			-- dead: forget the spot, so you start at the spawn
			live.Position = if humanoid.Health > 0 then { X = p.X, Y = p.Y, Z = p.Z, Place = game.PlaceId } else nil
		end
		task.wait(NOTE_EVERY)
	end
end

Players.PlayerAdded:Connect(follow)
for _, player in Players:GetPlayers() do
	task.spawn(follow, player)
end

return true
