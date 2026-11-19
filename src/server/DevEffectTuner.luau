-- Dev only: stands copies of the Wave effect in a row near the spawn, each turned a different amount about the
-- vertical, each with a yellow arrow showing the direction the wave flies. They use the TiltDegrees in Config/Effects.
-- Look at them from straight above (or behind): pick the one whose crescent sits squarely on its arrow, with both
-- tips level. Its label gives the number for the Y in ModelRotation in Config/Effects.
-- Does nothing once DEV_MODE is off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Dev = require(ReplicatedStorage.Shared.Config.Dev)
local EffectStyle = require(ReplicatedStorage.Shared.Config.Effects)

if not Dev.DEV_MODE then
	return true
end

local FIRST = Vector3.new(-20, 4, -14) -- the first copy; the rest stand beside it
local SPACING = 13
local TURNS = { 0, 90, 180, 270 } -- degrees about the vertical, tried one per copy

local function label(parent, text)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	local words = Instance.new("TextLabel")
	words.Size = UDim2.fromScale(1, 1)
	words.BackgroundTransparency = 1
	words.Text = text
	words.TextColor3 = Color3.new(1, 1, 1)
	words.TextStrokeTransparency = 0
	words.Font = Enum.Font.GothamBold
	words.TextSize = 22
	words.Parent = gui
	gui.Parent = parent
end

local function preview(style, index, turn)
	local models = ServerStorage:FindFirstChild("Models")
	local template = style.Model ~= "" and models and models:FindFirstChild(style.Model)
	if not template then
		return
	end

	local at = FIRST + Vector3.new((index - 1) * SPACING, 0, 0)
	local holder = Instance.new("Model")
	holder.Name = "WavePreview_Y" .. turn

	local arrow = Instance.new("Part")
	arrow.Name = "FlightDirection"
	arrow.Size = Vector3.new(0.3, 0.3, 12)
	arrow.Color = Color3.fromRGB(255, 220, 0)
	arrow.Material = Enum.Material.Neon
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CFrame = CFrame.new(at + Vector3.new(0, -1, -6)) -- the wave flies toward -Z, the same way you face at spawn
	arrow.Parent = holder
	label(arrow, "Y = " .. turn)

	local visual = template:Clone()
	for _, item in visual:GetDescendants() do
		if item:IsA("WeldConstraint") or item:IsA("JointInstance") then
			item:Destroy()
		elseif item:IsA("SpecialMesh") then
			item.Scale *= style.ModelScale
			item.VertexColor = style.Tint
		elseif item:IsA("MeshPart") then -- an imported slash
			item.Size *= style.ModelScale
			item.Color = Color3.new(1, 1, 1)
			item.Material = Enum.Material.Neon
		end
	end
	visual.Parent = holder
	for _, part in holder:GetDescendants() do
		if part:IsA("BasePart") and part ~= arrow then
			part.Anchored = true
			part.CanCollide = false
			local rotation = style.ModelRotation
			part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(style.TiltDegrees)) * CFrame.Angles(math.rad(rotation.X), math.rad(turn), math.rad(rotation.Z))
		end
	end
	holder.Parent = workspace
end

for index, turn in TURNS do
	preview(EffectStyle.Wave, index, turn)
end
print("[EffectTuner] four Wave previews stand across the spawn; look from above and pick the Y whose crescent sits squarely on its arrow")

return true
