-- Puts the equipped weapon's model in the character's right hand, so everyone sees it, and shows a blade trail
-- during swings and skills. Looks only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Dev = require(ReplicatedStorage.Shared.Config.Dev)
local PlayerData = require(script.Parent.PlayerData)

local effects = setmetatable({}, { __mode = "k" }) -- [character] = { trail, token }

local WeaponVisuals = {}

-- Shows the blade trail for the part of a move where the blade is cutting (called by Combat).
-- `style` ({ Color, LightEmission }, optional) tints this one move; without it the weapon's plain trail shows.
function WeaponVisuals.ShowTrail(character, delay, seconds, style)
	local fx = effects[character]
	if not (fx and fx.trail.Parent) then
		return
	end
	fx.token += 1
	local token = fx.token
	task.delay(delay, function()
		if fx.token ~= token or not fx.trail.Parent then
			return
		end
		fx.trail.Color = if style then ColorSequence.new(style.Color) else fx.color
		fx.trail.LightEmission = if style then style.LightEmission else fx.emission
		fx.trail.Enabled = true
		task.wait(seconds)
		if fx.token == token and fx.trail.Parent then
			fx.trail.Enabled = false
		end
	end)
end

local function addTrail(character, model, visual)
	local blade = model:FindFirstChild(visual.TrailPart)
	if not blade then
		return
	end
	local axis = visual.TrailAxis
	local half = Vector3.new(blade.Size.X * axis.X, blade.Size.Y * axis.Y, blade.Size.Z * axis.Z).Magnitude / 2
	local base = Instance.new("Attachment")
	base.Position = axis * half * (visual.Trail.FromBladeFraction * 2 - 1)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Position = axis * half
	tip.Parent = blade

	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = base, tip
	trail.Color = ColorSequence.new(visual.Trail.Color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = visual.Trail.Lifetime
	trail.MaxLength = visual.Trail.MaxLength -- keeps the ribbon from smearing across the screen
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) }) -- tapers to a point
	trail.LightEmission = 0 -- plain, not glowing
	trail.FaceCamera = false -- lies along the blade, like the path of the edge
	trail.MinLength = 0.2
	trail.Enabled = false
	trail.Parent = blade

	effects[character] = { trail = trail, token = 0, color = trail.Color, emission = trail.LightEmission }
end

-- Returns the weapon's parts, positioned relative to each other. Uses the imported mesh, or plain stand-in parts if it is missing.
local function collectParts(visual)
	local models = ServerStorage:FindFirstChild("Models")
	local template = models and models:FindFirstChild(visual.Model)
	local parts = {}
	if template then
		local copy = template:Clone()
		local size = copy:GetExtentsSize()
		copy:ScaleTo(visual.Length / math.max(size.X, size.Y, size.Z)) -- the importer's scale is unknown, so size it by length
		for _, part in copy:GetDescendants() do
			if part:IsA("MeshPart") then
				table.insert(parts, part)
			end
		end
		return parts, copy
	end
	warn(`[WeaponVisuals] ServerStorage.Models.{visual.Model} not found, using plain parts: import the mesh and save it as assets/models/{visual.Model}.rbxm`)
	for _, spec in visual.Parts do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Size = spec.Size
		part.CFrame = CFrame.new(spec.Offset) -- the handle part has Offset 0, so it sits at the origin
		table.insert(parts, part)
	end
	return parts
end

-- Dev only: puts the grip numbers on the WeaponVisual model as attributes you can drag in Studio's
-- Properties panel while playing. The weapon moves as you change them, and the values print so you can
-- copy them into Config/Weapons. Does nothing once DEV_MODE is off.
local function addTuner(model, grip, visual)
	if not Dev.DEV_MODE then
		return
	end
	local offset, rotation = visual.GripOffset, visual.MeshRotation
	model:SetAttribute("GripX", offset.X)
	model:SetAttribute("GripY", offset.Y)
	model:SetAttribute("GripZ", offset.Z)
	model:SetAttribute("RotX", rotation.X + visual.GripAngleDegrees)
	model:SetAttribute("RotY", rotation.Y)
	model:SetAttribute("RotZ", rotation.Z)
	model.AttributeChanged:Connect(function()
		local x, y, z = model:GetAttribute("GripX"), model:GetAttribute("GripY"), model:GetAttribute("GripZ")
		local rx, ry, rz = model:GetAttribute("RotX"), model:GetAttribute("RotY"), model:GetAttribute("RotZ")
		grip.C0 = CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
		print(`[WeaponVisuals] GripOffset = Vector3.new({x}, {y}, {z}), MeshRotation = Vector3.new({rx}, {ry}, {rz})`)
	end)
end

local function attach(player, character)
	local data
	for _ = 1, 50 do -- saved data loads a moment after the character appears
		data = PlayerData.Get(player)
		if data or not character.Parent then
			break
		end
		task.wait(0.2)
	end
	local visual = data and Weapons[data.Weapon] and Weapons[data.Weapon].Visual
	local hand = character:WaitForChild("RightHand", 10) -- R15 only
	if not (visual and hand) or character:FindFirstChild("WeaponVisual") then
		return
	end

	local parts, copy = collectParts(visual)
	local handle
	for _, part in parts do
		if part.Name == visual.HandlePart then
			handle = part
		end
	end
	if not handle then
		warn(`[WeaponVisuals] no part named {visual.HandlePart} in the {visual.Model} model`)
		return
	end

	-- Where each part sits relative to the handle, kept while the whole weapon moves into the hand.
	local rotation = visual.MeshRotation
	local gripCFrame = CFrame.new(visual.GripOffset)
		* CFrame.Angles(math.rad(visual.GripAngleDegrees), 0, 0)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	local handleCFrame = handle.CFrame
	local relative = {}
	for _, part in parts do
		relative[part] = handleCFrame:ToObjectSpace(part.CFrame)
	end

	local model = Instance.new("Model")
	model.Name = "WeaponVisual"
	handle.CFrame = hand.CFrame * gripCFrame
	for _, part in parts do
		local style = visual.Colors[part.Name] or visual.Colors.Default
		part.Color = style.Color
		part.Material = Enum.Material[style.Material]
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if part ~= handle then
			part.CFrame = handle.CFrame * relative[part]
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, part
			weld.Parent = part
		end
		part.Parent = model
	end
	if copy then
		copy:Destroy()
	end

	local grip = Instance.new("Weld") -- holds the weapon in the fist
	grip.Part0, grip.Part1 = hand, handle
	grip.C0 = gripCFrame
	grip.Parent = handle
	model.Parent = character
	addTrail(character, model, visual)
	addTuner(model, grip, visual)
end

local function track(player)
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
end

Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end

return WeaponVisuals
