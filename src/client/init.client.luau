-- Input only. Click to ask the server for a swing; the server decides if it hits.
local UserInputService = game:GetService("UserInputService")
local swingRemote = game:GetService("ReplicatedStorage"):WaitForChild("Swing")
local Feedback = require(script.Feedback)
local Effects = require(script.Effects)
require(script.MobAnimation)
require(script.SkillBar)
require(script.Hud)
require(script.Sounds)
require(script.Menu)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		swingRemote:FireServer()
	end
end)

-- The server answers an accepted swing with which swing of the combo it was.
swingRemote.OnClientEvent:Connect(function(index)
	Feedback.PlaySwing(index)
end)

-- The server announces every wave slash (anyone's); each client draws it.
game:GetService("ReplicatedStorage"):WaitForChild("WaveFired").OnClientEvent:Connect(Effects.Wave)
