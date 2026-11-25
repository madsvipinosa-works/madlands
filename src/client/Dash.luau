-- E key: ask the server for a dash, and show it (pose, ghost copies, dust, camera zoom). The server decides if and
-- how far you move; it tells this client to draw the dash only when it accepted it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Dash = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Dash"))
local Animations = require(script.Parent.Animations)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local dashRemote = ReplicatedStorage:WaitForChild("DashStep")

local lastPress = 0

-- A see-through glowing copy of the body, left where you were; it fades away.
local function ghost(character)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			local copy = part:Clone()
			copy:ClearAllChildren()
			if copy:IsA("MeshPart") then
				copy.TextureID = ""
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.Material = Enum.Material.Neon
			copy.Color = Dash.GhostColor
			copy.Transparency = 0.5
			copy.CFrame = part.CFrame
			copy.Parent = workspace
			TweenService:Create(copy, TweenInfo.new(Dash.GhostSeconds), { Transparency = 1 }):Play()
			game:GetService("Debris"):AddItem(copy, Dash.GhostSeconds + 0.1)
		end
	end
end

local function show()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	Animations.Play(Dash.Animation)
	Effects.Puff(root.Position - Vector3.new(0, 2.5, 0), 5)
	local camera = workspace.CurrentCamera
	local fov = camera.FieldOfView
	camera.FieldOfView = fov + Dash.FovKick
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
	task.spawn(function()
		for _ = 1, math.ceil(Dash.Time / Dash.GhostEvery) do
			if not character.Parent then
				return
			end
			ghost(character)
			task.wait(Dash.GhostEvery)
		end
	end)
end

dashRemote.OnClientEvent:Connect(show)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.KeyCode ~= Dash.Key then
		return
	end
	dashRemote:FireServer()
	local now = os.clock()
	if now - lastPress >= Dash.Cooldown then -- shortcut: guesses the cooldown for the sound, the server still decides
		lastPress = now
		Sounds.Play(Dash.Sound, Players.LocalPlayer.Character)
	end
end)

return true
