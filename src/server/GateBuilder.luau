-- Builds the Starter Town gate at the end of the trail (Config/Zones: Gate): the hand-made gate model, stone walls running
-- from its towers to the canyon on both sides, a row of town buildings standing behind the wall, and the way in. The gate
-- opens when a player comes near. Walking into the passage or pressing F at the gate "enters the town": the screen fades
-- to black and the player is teleported to the town's place (Gate.DestinationPlaceId). Server only; runs after ZoneBuilder
-- (it needs the canyon wall).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local zone = Zones.OutsideZone1
local config = zone.Gate

local enterRemote = Instance.new("RemoteEvent") -- server -> client: fade the screen for "entering the town"
enterRemote.Name = "GateEnter"
enterRemote.Parent = ReplicatedStorage

-- Measured from the imported model (assets/models/StarterTownGate.rbxm), in studs from the gate's middle (its pivot).
-- The model is mirrored by the importer: the front, where players arrive, is -Z, so with no rotation it faces the spawn.
local K = config.Scale -- how much bigger than the imported model the gate is built (Config/Zones)
local SCALE = 1.714 * K -- the importer already made the model this much bigger than the original design
local WALL_LENGTH = 46.1 * K -- one stone wall piece, tower to far end
local WALL_END = 69.8 * K -- where the model's own walls stop, on each side
local WALL_HEIGHT, WALL_THICKNESS = 27.8 * K, 11 * K
local PORTCULLIS_DROP = 9 * SCALE
local DOOR_HINGE_X, DOOR_Z = 8.4 * K, -3.15 * K
local PASSAGE_HALF_WIDTH = 8.5 * K
local LANTERNS = {
	Vector3.new(11.8, 12.9, 10.8) * K, Vector3.new(-11.8, 12.9, 10.8) * K, Vector3.new(11.8, 12.9, -10.8) * K, Vector3.new(-11.8, 12.9, -10.8) * K,
}

local template = ServerStorage:WaitForChild("Models"):WaitForChild(config.Model)
local folder = Instance.new("Folder")
folder.Name = "TownGate"
folder.Parent = workspace

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -300, 0), terrainOnly)
	return hit and hit.Position.Y or 0
end

local function invisible(name, cframe, size, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = canCollide
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cframe
	p.Parent = folder
	return p
end

-- The gate model ------------------------------------------------------------------------------------------------

local groundY = groundAt(0, config.Z)
local gateModel = template:Clone():FindFirstChild("Gate", true)
gateModel.Name = "Gate"
gateModel:ScaleTo(gateModel:GetScale() * K) -- ScaleTo is absolute, and the imported model already carries its own scale
gateModel:PivotTo(CFrame.new(0, groundY - 0.4, config.Z)) -- the road sits a hair into the ground
gateModel.Parent = folder
local origin = gateModel:GetPivot()

local MATERIALS = {
	Stone = Enum.Material.Slate, Roof = Enum.Material.Slate, Road = Enum.Material.Cobblestone, Door_Iron = Enum.Material.Metal,
	Door = Enum.Material.Wood, Sign = Enum.Material.Wood, Cloth = Enum.Material.Fabric, Lantern = Enum.Material.Neon,
	Iron = Enum.Material.Metal, Portcullis = Enum.Material.Metal,
}
local function materialFor(group)
	if string.find(group, "^Door_[LR]_Iron") then
		return MATERIALS.Door_Iron
	end
	for prefix, material in MATERIALS do
		if string.find(group, "^" .. prefix) then
			return material
		end
	end
	return Enum.Material.Slate
end

local groups = {} -- group name -> list of its parts
for _, part in gateModel:GetDescendants() do
	if part:IsA("MeshPart") then
		local group = string.gsub(part.Name, "_H%d+$", "")
		part.Anchored = true
		part.CanCollide = false -- the invisible blocks below do the colliding
		part.CanQuery = false
		part.CanTouch = false
		part.Material = materialFor(group)
		part.Color = Color3.new(1, 1, 1) -- the meshes carry their own colors
		groups[group] = groups[group] or {}
		table.insert(groups[group], part)
	end
end

-- Stone walls from the towers out to the canyon, on both sides. The model's wall pieces are copied, end to end, until a
-- ray from the wall's end hits the canyon; the last piece reaches into the rock, so nothing can be seen or walked around.
local wallPieces = 0
for _, side in { { Group = "Stone_Wall_L", Sign = 1 }, { Group = "Stone_Wall_R", Sign = -1 } } do
	local startX = origin.X + side.Sign * (WALL_END + 0.5)
	local hit = workspace:Raycast(Vector3.new(startX, groundY + 14, config.Z), Vector3.new(side.Sign * 260, 0, 0), terrainOnly)
	local reach = if hit then math.abs(hit.Position.X - origin.X) + 8 else 260 -- 8 studs into the canyon
	local tiles = math.max(math.ceil((reach - WALL_END) / WALL_LENGTH), 0)
	for k = 1, tiles do
		local shift = Vector3.new(side.Sign * WALL_LENGTH * k, 0, 0)
		for _, part in groups[side.Group] or {} do
			local copy = part:Clone()
			copy.CFrame = part.CFrame + shift
			copy.Parent = part.Parent
		end
		invisible("WallCollision", origin * CFrame.new(side.Sign * (WALL_END - WALL_LENGTH / 2 + WALL_LENGTH * k), (WALL_HEIGHT - 1) / 2, 0), Vector3.new(WALL_LENGTH, WALL_HEIGHT, WALL_THICKNESS), true)
		wallPieces += 1
	end
end

-- Invisible collision: the gatehouse masses beside and over the passage, the towers, and the model's own walls.
local function block(local_, size)
	invisible("Collision", origin * CFrame.new(local_ * SCALE), size * SCALE, true)
end
block(Vector3.new(8.5, 11, 0), Vector3.new(7, 22, 10))
block(Vector3.new(-8.5, 11, 0), Vector3.new(7, 22, 10))
block(Vector3.new(0, 17.5, 0), Vector3.new(10, 9, 10))
for _, side in { 1, -1 } do
	block(Vector3.new(27 * side, 8.1, 0), Vector3.new(26, 16.2, 4))
	local tower = invisible("TowerCollision", origin * CFrame.new(12.2 * side * SCALE, 13.5 * SCALE, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(27, 11, 11) * SCALE, true)
	tower.Shape = Enum.PartType.Cylinder
end

-- Lantern light on the road.
for _, offset in LANTERNS do
	local light = invisible("Lantern", origin * CFrame.new(offset), Vector3.one * 0.5, false)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 176, 92)
	glow.Brightness = 2.2
	glow.Range = 34
	glow.Shadows = false
	glow.Parent = light
end

-- Doors and portcullis -------------------------------------------------------------------------------------------

local function pivotParts(prefix)
	local list = {}
	for group, parts in groups do
		if string.find(group, "^" .. prefix) then
			for _, part in parts do
				table.insert(list, { Part = part, Home = part.CFrame })
			end
		end
	end
	return list
end
local leftDoor, rightDoor, portcullis = pivotParts("Door_L"), pivotParts("Door_R"), pivotParts("Portcullis")
local passageBlock = invisible("PassageBlock", origin * CFrame.new(0, 11.5 * K, DOOR_Z - 1.5 * K), Vector3.new(PASSAGE_HALF_WIDTH * 2, 23 * K, 2.5 * K), true)

-- progress 0 = shut (portcullis down, doors closed), 1 = open (portcullis up, doors swung back). Opening raises the
-- portcullis first, then swings the doors; shutting is the same thing backwards.
local function apply(progress)
	local lift = math.clamp(progress / 0.45, 0, 1)
	local swing = math.clamp((progress - 0.35) / 0.65, 0, 1)
	local angle = math.rad(config.DoorOpenDegrees) * swing
	for _, entry in portcullis do
		entry.Part.CFrame = entry.Home - Vector3.new(0, PORTCULLIS_DROP * (1 - lift), 0)
	end
	local function swingDoor(list, hingeX, sign)
		local hinge = origin * CFrame.new(hingeX, 0, DOOR_Z)
		local turn = hinge * CFrame.Angles(0, sign * angle, 0) * hinge:Inverse()
		for _, entry in list do
			entry.Part.CFrame = turn * entry.Home
		end
	end
	swingDoor(leftDoor, DOOR_HINGE_X, 1)
	swingDoor(rightDoor, -DOOR_HINGE_X, -1)
	passageBlock.CanCollide = progress < 0.9
end

local progress = Instance.new("NumberValue")
local isOpen = false
local opening
local function setOpen(open)
	if isOpen == open then
		return
	end
	isOpen = open
	if opening then
		opening:Cancel()
	end
	opening = TweenService:Create(progress, TweenInfo.new(config.OpenSeconds * math.abs(if open then 1 - progress.Value else progress.Value), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = if open then 1 else 0 })
	opening:Play()
end
progress.Changed:Connect(apply)
apply(0)

-- Entering the town ----------------------------------------------------------------------------------------------

local entering = {} -- [player] = true while the fade and teleport run
local function enter(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if entering[player] or not root then
		return
	end
	entering[player] = true
	local placeId = config.DestinationPlaceId
	enterRemote:FireClient(player, zone.Gate.Name, placeId > 0)
	task.wait(config.FadeSeconds) -- the screen is black now
	local teleported = false
	if placeId > 0 then
		teleported = pcall(function()
			TeleportService:TeleportAsync(placeId, { player })
		end)
	end
	if not teleported then
		-- The town place is not connected yet: put the player back in front of the gate, as if they had walked out again.
		local current = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if current then
			local spot = Vector3.new(0, groundAt(0, config.Z - config.ReturnDistance) + 4, config.Z - config.ReturnDistance)
			player.Character:PivotTo(CFrame.lookAt(spot, spot + Vector3.new(0, 0, 1)))
		end
	end
	task.wait(3)
	entering[player] = nil
end

-- Pressing F in front of the gate.
local promptPart = invisible("EnterPrompt", origin * CFrame.new(0, 3, -config.PromptDistance * 0.35), Vector3.one, false)
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Enter"
prompt.ObjectText = config.Name
prompt.KeyboardKeyCode = config.PromptKey
prompt.HoldDuration = 0.3
prompt.MaxActivationDistance = config.PromptDistance
prompt.RequiresLineOfSight = false
prompt.Triggered:Connect(enter)
prompt.Parent = promptPart

-- Walking into the passage while the gate is open.
local doorway = invisible("Doorway", origin * CFrame.new(0, 11 * K, 4 * K), Vector3.new(PASSAGE_HALF_WIDTH * 2, 22 * K, 6 * K), false)
doorway.CanTouch = true
doorway.Touched:Connect(function(other)
	local player = Players:GetPlayerFromCharacter(other.Parent)
	if player and progress.Value > 0.85 then
		enter(player)
	end
end)

-- The gate opens when someone comes near, and shuts again when everyone has gone.
task.spawn(function()
	while true do
		local near = false
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(0, 0, config.Z)).Magnitude < config.OpenDistance then
				near = true
			end
		end
		setOpen(near)
		task.wait(0.5)
	end
end)

print(`[Gate] {config.Name} gate built at z={config.Z}, scale {K}: {wallPieces} extra wall pieces`)

return true
