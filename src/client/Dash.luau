-- E key: ask the server for a dash, and show it (pose, white streak, dust, camera zoom). The server decides if and
-- how far you move; it tells this client to draw the dash only when it accepted it.
local Debris = game:GetService("Debris")
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

-- A faint white ribbon behind your body for as long as the dash lasts; it fades out on its own.
local function streak(root)
	local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
	top.Position, bottom.Position = Vector3.new(0, 1.2, 0), Vector3.new(0, -1.5, 0)
	top.Parent, bottom.Parent = root, root
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color = ColorSequence.new(Dash.StreakColor)
	trail.Transparency = NumberSequence.new(Dash.StreakStart, 1) -- see-through at the body, gone at the tail
	trail.LightEmission = 0.4
	trail.Lifetime = Dash.StreakSeconds
	trail.Parent = root
	task.delay(Dash.Time, function()
		trail.Enabled = false -- stop growing; the ribbon fades over its lifetime, then everything is removed
	end)
	Debris:AddItem(trail, Dash.Time + Dash.StreakSeconds + 0.1)
	Debris:AddItem(top, Dash.Time + Dash.StreakSeconds + 0.1)
	Debris:AddItem(bottom, Dash.Time + Dash.StreakSeconds + 0.1)
end

local function show()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	Animations.Play(Dash.Animation)
	Effects.Puff(root.Position - Vector3.new(0, 2.5, 0), 5)
	streak(root)
	local camera = workspace.CurrentCamera
	local fov = camera.FieldOfView
	camera.FieldOfView = fov + Dash.FovKick
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
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
