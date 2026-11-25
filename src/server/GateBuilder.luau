-- Builds the Starter Town gate at the north edge of the zone (Config/Zones: Gate): the hand-made curved gate model, whose walls
-- replace the canyon along that stretch of the edge (ZoneBuilder leaves a gap in the canyon for it). Walking into the closed
-- gate or pressing F at it "enters the town": the gate opens, the screen fades to black and the player is teleported to the
-- town's place (Gate.DestinationPlaceId). Server only; runs after ZoneBuilder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local zone = Zones.OutsideZone1
local config = zone.Gate
local K = config.Scale -- how much bigger than the model was saved (1 = as saved)

local enterRemote = ReplicatedStorage:WaitForChild("GateEnter") -- server -> client: fade the screen for "entering the town" (made by ZoneBuilder)

task.wait(1.5) -- freshly built terrain cannot be raycast for a moment
local template = ServerStorage:WaitForChild("Models"):WaitForChild(config.Model)
local folder = Instance.new("Folder")
folder.Name = "TownGate"
folder.Parent = workspace

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), terrainOnly)
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
-- In the model the front, where players arrive, is -Z (so with no rotation it faces the spawn); the doors are at the front of
-- the gatehouse, the portcullis in front of them, and the curved walls bend away behind it.

local groundY = groundAt(0, config.Z)
local gateModel = template:Clone():FindFirstChild("Gate", true)
gateModel.Name = "Gate"
gateModel:ScaleTo(gateModel:GetScale() * K) -- ScaleTo is absolute, and the saved model carries its own scale
gateModel:PivotTo(CFrame.new(0, groundY - 0.3, config.Z))
gateModel.Parent = folder
local origin = gateModel:GetPivot()
local inverse = origin:Inverse()

local MATERIALS = {
	Stone = Enum.Material.Slate, Roof = Enum.Material.Slate, Road = Enum.Material.Cobblestone, Door_Iron = Enum.Material.Metal,
	Door = Enum.Material.Wood, Sign = Enum.Material.Wood, Signpost = Enum.Material.Wood, Cloth = Enum.Material.Fabric,
	Lantern = Enum.Material.Neon, Flame = Enum.Material.Neon, Iron = Enum.Material.Metal, Portcullis = Enum.Material.Metal,
	Props = Enum.Material.Wood, Statue = Enum.Material.Slate, Crest = Enum.Material.Slate,
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

-- These stone parts block players (a convex hull of each: close to the wall, tower or gatehouse). The rest is for looking at.
local SOLID = { "Stone_Gatehouse", "Stone_Tower", "Stone_Wall", "Stone_Plinth", "Statue" }

local groups = {} -- group name -> list of its parts
for _, part in gateModel:GetDescendants() do
	if part:IsA("MeshPart") then
		local group = string.gsub(string.gsub(part.Name, "_H%d+$", ""), "_%d+$", "")
		part.Anchored = true
		part.CanQuery = false
		part.CanTouch = false
		part.Material = materialFor(group)
		part.Color = Color3.new(1, 1, 1) -- the meshes carry their own colors
		local solid = false
		for _, prefix in SOLID do
			solid = solid or string.find(group, "^" .. prefix) ~= nil
		end
		part.CanCollide = solid
		if solid then
			pcall(function()
				part.CollisionFidelity = Enum.CollisionFidelity.Hull
			end)
		end
		groups[group] = groups[group] or {}
		table.insert(groups[group], part)
	end
end

-- The extent of a group's parts in the gate's own space (x across, y up, z front to back).
local function bounds(prefix)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for group, parts in groups do
		if string.find(group, "^" .. prefix) then
			for _, part in parts do
				local cf = inverse * part.CFrame
				local half = part.Size / 2
				local r = cf:VectorToWorldSpace(Vector3.new(half.X, 0, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, half.Y, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, 0, half.Z)):Abs()
				lo = Vector3.new(math.min(lo.X, cf.X - r.X), math.min(lo.Y, cf.Y - r.Y), math.min(lo.Z, cf.Z - r.Z))
				hi = Vector3.new(math.max(hi.X, cf.X + r.X), math.max(hi.Y, cf.Y + r.Y), math.max(hi.Z, cf.Z + r.Z))
			end
		end
	end
	return lo, hi
end

-- Doors and portcullis -------------------------------------------------------------------------------------------

local function entries(prefix)
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
local leftDoor, rightDoor, portcullis = entries("Door_L"), entries("Door_R"), entries("Portcullis")
local leftLo, leftHi = bounds("Door_L")
local rightLo, rightHi = bounds("Door_R")
local portLo, portHi = bounds("Portcullis")
local doorZ = (leftLo.Z + leftHi.Z) / 2
local passageLo, passageHi = math.min(leftLo.X, rightLo.X), math.max(leftHi.X, rightHi.X) -- x across the passage
local doorHeight = math.max(leftHi.Y, rightHi.Y)
local portcullisDrop = math.max(portLo.Y, 0) -- it is saved raised; lowered, its bottom reaches the ground

-- The shut gate (portcullis down) blocks the passage.
local gateBlock = invisible("GateBlock", origin * CFrame.new((passageLo + passageHi) / 2, doorHeight / 2, (portLo.Z + portHi.Z) / 2), Vector3.new(passageHi - passageLo, doorHeight, math.max(portHi.Z - portLo.Z, 1) + 2 * K), true)

-- progress 0 = shut (portcullis down, doors closed), 1 = open (portcullis up, doors swung back). Opening raises the
-- portcullis first, then swings the doors; shutting is the same thing backwards.
local function apply(progress)
	local lift = math.clamp(progress / 0.45, 0, 1)
	local swing = math.clamp((progress - 0.35) / 0.65, 0, 1)
	local angle = math.rad(config.DoorOpenDegrees) * swing
	for _, entry in portcullis do
		entry.Part.CFrame = entry.Home - Vector3.new(0, portcullisDrop * (1 - lift), 0)
	end
	local function swingDoor(list, hingeX, sign)
		local hinge = origin * CFrame.new(hingeX, 0, doorZ)
		local turn = hinge * CFrame.Angles(0, sign * angle, 0) * hinge:Inverse()
		for _, entry in list do
			entry.Part.CFrame = turn * entry.Home
		end
	end
	swingDoor(leftDoor, passageHi, 1) -- the left leaf hangs from the right edge: the model is mirrored
	swingDoor(rightDoor, passageLo, -1)
	gateBlock.CanCollide = progress < 0.9
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

-- Light: braziers in front and lanterns up on the gatehouse.
for _, spot in { Vector3.new(15, 11, -17), Vector3.new(-15, 11, -17), Vector3.new(17, 18, 14), Vector3.new(-17, 18, 14) } do
	local anchor = invisible("Light", origin * CFrame.new(spot * K), Vector3.one * 0.5, false)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 176, 92)
	glow.Brightness = 2.2
	glow.Range = 38
	glow.Shadows = false
	glow.Parent = anchor
end

-- Entering the town ----------------------------------------------------------------------------------------------

local entering = {} -- [player] = true while the fade and teleport run
local function enter(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if entering[player] or not root then
		return
	end
	entering[player] = true
	setOpen(true) -- the gate opens as the screen goes dark
	local placeId = config.DestinationPlaceId
	enterRemote:FireClient(player, config.Name, placeId > 0)
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
			local z = config.Z - config.ReturnDistance
			local spot = Vector3.new(0, groundAt(0, z) + 4, z)
			player.Character:PivotTo(CFrame.lookAt(spot, spot + Vector3.new(0, 0, 1)))
		end
	end
	task.wait(3)
	entering[player] = nil
	if next(entering) == nil then
		task.wait(2)
		if next(entering) == nil then
			setOpen(false)
		end
	end
end

-- Pressing F in front of the gate.
local frontZ = portLo.Z - 2 * K
local promptPart = invisible("EnterPrompt", origin * CFrame.new((passageLo + passageHi) / 2, 3, frontZ - 6 * K), Vector3.one, false)
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Enter"
prompt.ObjectText = config.Name
prompt.KeyboardKeyCode = config.PromptKey
prompt.HoldDuration = 0.3
prompt.MaxActivationDistance = config.PromptDistance
prompt.RequiresLineOfSight = false
prompt.Triggered:Connect(enter)
prompt.Parent = promptPart

-- Walking into the gate: a strip just in front of it.
local touch = invisible("Doorway", origin * CFrame.new((passageLo + passageHi) / 2, 8, frontZ - 1.5 * K), Vector3.new(passageHi - passageLo, 16, 3 * K), false)
touch.CanTouch = true
touch.Touched:Connect(function(other)
	local player = Players:GetPlayerFromCharacter(other.Parent)
	if player then
		enter(player)
	end
end)

-- Optional: the gate opens by itself when someone comes near (Gate.AutoOpen). Off by default: an open gate shows what is behind it.
if config.AutoOpen then
	task.spawn(function()
		while true do
			local near = next(entering) ~= nil
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
end

print(`[Gate] {config.Name} gate built at z={config.Z}, scale {K}`)

return true
