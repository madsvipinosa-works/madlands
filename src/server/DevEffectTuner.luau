-- Dev only: stands a copy of each ready-made effect next to the spawn, with an arrow showing which way it
-- would fly. Drag the model's attributes in Studio's Properties panel to turn, scale and shift it; the copy
-- updates as you type and prints the numbers to paste into Config/Effects. Does nothing once DEV_MODE is off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Dev = require(ReplicatedStorage.Shared.Config.Dev)
local EffectStyle = require(ReplicatedStorage.Shared.Config.Effects)

if not Dev.DEV_MODE then
	return true
end

local PREVIEW_AT = Vector3.new(-10, 5, -10) -- a clear spot near the spawn

local function preview(name, style)
	local models = ServerStorage:FindFirstChild("Models")
	local template = style.Model ~= "" and models and models:FindFirstChild(style.Model)
	if not template then
		return
	end

	local holder = Instance.new("Model")
	holder.Name = name .. "Preview"

	-- The arrow marks the direction the effect would fly, so you can line the crescent up with it.
	local arrow = Instance.new("Part")
	arrow.Name = "FlightDirection"
	arrow.Size = Vector3.new(0.2, 0.2, 14)
	arrow.Color = Color3.fromRGB(255, 220, 0)
	arrow.Material = Enum.Material.Neon
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CFrame = CFrame.new(PREVIEW_AT) * CFrame.new(0, 0, -7) -- -Z is forward
	arrow.Parent = holder

	local visual = template:Clone()
	for _, item in visual:GetDescendants() do
		if item:IsA("WeldConstraint") or item:IsA("JointInstance") then
			item:Destroy()
		end
	end
	visual.Parent = holder
	holder.Parent = workspace

	local meshes, baseScales = {}, {}
	for _, item in holder:GetDescendants() do
		if item:IsA("SpecialMesh") then
			table.insert(meshes, item)
			baseScales[item] = item.Scale
		end
	end
	local parts = {}
	for _, item in holder:GetDescendants() do
		if item:IsA("BasePart") and item ~= arrow then
			item.Anchored = true
			item.CanCollide = false
			table.insert(parts, item)
		end
	end

	local function apply()
		local rx, ry, rz = holder:GetAttribute("RotX"), holder:GetAttribute("RotY"), holder:GetAttribute("RotZ")
		local ox, oy, oz = holder:GetAttribute("OffsetX"), holder:GetAttribute("OffsetY"), holder:GetAttribute("OffsetZ")
		local scale = holder:GetAttribute("Scale")
		local cframe = CFrame.new(PREVIEW_AT) * CFrame.new(ox, oy, oz) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
		for _, part in parts do
			part.CFrame = cframe
		end
		for _, mesh in meshes do
			mesh.Scale = baseScales[mesh] * scale
		end
		print(
			`[EffectTuner] {name}: ModelScale = {scale}, ModelRotation = Vector3.new({rx}, {ry}, {rz}), ModelOffset = Vector3.new({ox}, {oy}, {oz})`
		)
	end

	local rotation, offset = style.ModelRotation, style.ModelOffset
	holder:SetAttribute("RotX", rotation.X)
	holder:SetAttribute("RotY", rotation.Y)
	holder:SetAttribute("RotZ", rotation.Z)
	holder:SetAttribute("OffsetX", offset.X)
	holder:SetAttribute("OffsetY", offset.Y)
	holder:SetAttribute("OffsetZ", offset.Z)
	holder:SetAttribute("Scale", style.ModelScale)
	holder.AttributeChanged:Connect(apply)
	apply()
	print(`[EffectTuner] {name} preview at {PREVIEW_AT}: select {holder.Name} in Workspace and edit its Attributes`)
end

preview("Wave", EffectStyle.Wave)

return true
