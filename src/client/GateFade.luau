-- "Entering the town": the screen fades to black with the town's name, then (if the player is still here, because the town
-- place is not connected yet) fades back. The server decides everything; this is only the look.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local gui = Instance.new("ScreenGui")
gui.Name = "GateFade"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 500 -- above everything
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.new(0, 0, 0)
cover.BackgroundTransparency = 1
cover.BorderSizePixel = 0
cover.Parent = gui

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.5)
label.Size = UDim2.fromOffset(600, 60)
label.BackgroundTransparency = 1
label.TextTransparency = 1
label.TextColor3 = Color3.fromRGB(240, 228, 200)
label.Font = Enum.Font.GothamBold
label.TextSize = 34
label.Parent = cover

task.spawn(function() -- the server makes the remote when the gate is built, a while after joining
	ReplicatedStorage:WaitForChild("GateEnter").OnClientEvent:Connect(function(townName, connected)
		label.Text = "Entering " .. townName
		TweenService:Create(cover, TweenInfo.new(0.8), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		if not connected then
			task.wait(2.6) -- no town place yet: the server puts you back in front of the gate, then the screen clears
			TweenService:Create(cover, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end)

return true
