-- Input only. Click to ask the server for a swing; the server decides if it hits.
local UserInputService = game:GetService("UserInputService")
local swingRemote = game:GetService("ReplicatedStorage"):WaitForChild("Swing")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		swingRemote:FireServer()
	end
end)
