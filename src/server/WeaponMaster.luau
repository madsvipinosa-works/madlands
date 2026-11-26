-- The Weapon Master (Config/WeaponMaster): gives a player who has no weapon their first one. Server only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config.WeaponMaster)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local village = require(ReplicatedStorage.Shared.Config.Zones).OutsideZone1.Village
local Dialogue = require(script.Parent.Dialogue)
local PlayerData = require(script.Parent.PlayerData)
local WeaponVisuals = require(script.Parent.WeaponVisuals)

local IDLE_ANIMATION = "rbxassetid://507766388" -- Roblox's standard R15 idle

local function talk(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	if Weapons[data.Weapon] then
		return { Lines = Config.After }
	end
	local lines = table.clone(Config.Greeting)
	local choices = {}
	for _, id in Config.Offers do
		local weapon = Weapons[id]
		lines[#lines] ..= `\n{weapon.Name}: {weapon.Description}`
		table.insert(choices, { Label = weapon.Name, Action = "Take", Arg = id })
	end
	table.insert(choices, { Label = "Not yet" })
	return { Lines = lines, Choices = choices }
end

-- The first weapon only: one that is on offer, for a player who has none.
local function take(player, id)
	local data = PlayerData.Get(player)
	if not data or Weapons[data.Weapon] or not table.find(Config.Offers, id) or not Weapons[id] then
		return nil
	end
	data.Weapon = id
	PlayerData.Sync(player)
	WeaponVisuals.Refresh(player)
	print(`[WeaponMaster] {player.Name} chose {id}`)
	return { Lines = Config.Chosen }
end

local function part(parent, cframe, size, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.Material = material
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- A weapon stuck in a stump, so you can see what is on offer from a distance.
local function stand(at, weapon)
	local model = Instance.new("Model")
	model.Name = "WeaponStand"
	local stump = part(model, CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.6, 2, 2), Color3.fromRGB(104, 72, 44), Enum.Material.Wood)
	stump.Shape = Enum.PartType.Cylinder
	local visual = weapon.Visual
	local template = ServerStorage.Models:FindFirstChild(visual.Model)
	if template then
		local copy = template:Clone()
		local size = copy:GetExtentsSize()
		copy:ScaleTo(copy:GetScale() * visual.Length / math.max(size.X, size.Y, size.Z))
		for _, p in copy:GetDescendants() do
			if p:IsA("BasePart") then
				local style = visual.Colors[p.Name] or visual.Colors.Default
				p.Color = style.Color
				p.Material = Enum.Material[style.Material]
				p.Anchored = true
				p.CanCollide = false
				p.CanTouch = false
			end
		end
		copy:PivotTo(CFrame.new(copy:GetPivot().Position) * CFrame.Angles(if visual.StandFlip then math.pi else 0, 0, 0))
		local box, extent = copy:GetBoundingBox()
		-- its lower end sunk StandSink studs into the top of the stump
		copy:PivotTo(copy:GetPivot() + Vector3.new(at.X - box.X, at.Y + 1.4 - visual.StandSink - (box.Y - extent.Y / 2), at.Z - box.Z))
		copy.Parent = model
	end
	model.Parent = workspace
end

local function build()
	local look = Config.Look
	local description = Instance.new("HumanoidDescription")
	description.HeadColor, description.LeftArmColor, description.RightArmColor = look.Skin, look.Skin, look.Skin
	description.TorsoColor = look.Shirt
	description.LeftLegColor, description.RightLegColor = look.Trousers, look.Trousers
	local model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	model.Name = Config.Name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- reaches a client all at once
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- client/Quests draws the name and marker
	local root = model.HumanoidRootPart
	root.Anchored = true

	local spot, faces = village.WeaponMaster.Position, village.WeaponMaster.Faces
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(spot.X, 120, spot.Z), Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position.Y else 0
	local standing = Vector3.new(spot.X, ground + humanoid.HipHeight + root.Size.Y / 2, spot.Z)
	local facing = CFrame.lookAt(standing, Vector3.new(faces.X, standing.Y, faces.Z))
	model:PivotTo(facing)

	local torso = model.LowerTorso
	local apron = part(model, torso.CFrame * CFrame.new(0, -0.3, -0.58), Vector3.new(1.5, 1.7, 0.15), look.Apron, Enum.Material.Fabric)
	apron.Anchored = false
	apron.CanCollide = false
	apron.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = torso, apron
	weld.Parent = apron
	model.Parent = workspace

	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIMATION
	local track = humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(idle)
	track.Looped = true
	track:Play()

	for i, id in Config.Offers do -- a row of stumps beside them, on the side away from the chief
		local beside = facing * Vector3.new(-3.2 - (i - 1) * 2.6, 0, 0)
		stand(Vector3.new(beside.X, ground, beside.Z), Weapons[id])
	end

	Dialogue.Add({
		Id = "WeaponMaster",
		Name = Config.Name,
		Model = model,
		PromptKey = Config.PromptKey,
		TalkDistance = Config.TalkDistance,
		Talk = talk,
		Actions = { Take = take },
	})
end

task.spawn(function()
	while not workspace:GetAttribute("ZoneReady") do -- set by init.server once the ground is built
		task.wait(0.2)
	end
	build()
end)

return true
