-- The conversation box: pages of text with "Next", then the villager's choices. Display and input only: the server decides
-- what is said and checks every choice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CLOSE_BEYOND = 18 -- studs: walking this far from the villager ends the talk

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 215, 90)

local gui = Instance.new("ScreenGui")
gui.Name = "Dialogue"
gui.ResetOnSpawn = false
gui.DisplayOrder = 103
gui.Parent = player:WaitForChild("PlayerGui")

local box = Instance.new("Frame")
box.AnchorPoint = Vector2.new(0.5, 1)
box.Position = UDim2.fromScale(0.5, 0.72)
box.Size = UDim2.fromOffset(560, 180)
box.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
box.BackgroundTransparency = 0.1
box.BorderSizePixel = 0
box.Active = true -- clicks on the box do not swing your weapon
box.Visible = false
box.Parent = gui
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)
local outline = Instance.new("UIStroke", box)
outline.Color = GOLD
outline.Transparency = 0.4

local function label(size, position, boxSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Position = position
	l.Size = boxSize
	l.Parent = box
	return l
end
local speaker = label(18, UDim2.fromOffset(20, 12), UDim2.new(1, -40, 0, 22), GOLD)
local words = label(16, UDim2.fromOffset(20, 42), UDim2.new(1, -40, 1, -100), Color3.new(1, 1, 1))

local row = Instance.new("Frame")
row.AnchorPoint = Vector2.new(1, 1)
row.Position = UDim2.new(1, -14, 1, -12)
row.Size = UDim2.new(1, -28, 0, 38)
row.BackgroundTransparency = 1
row.Parent = box
local layout = Instance.new("UIListLayout", row)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local current -- { id, position, lines, choices, page, until }
local chooseRemote -- made by the server a while after joining

local Dialogue = {}

-- True while that villager is "speaking" a page (so their model can gesture).
function Dialogue.Speaking(id)
	return current ~= nil and current.id == id and os.clock() < current.speakingUntil
end

local function close()
	current = nil
	box.Visible = false
end

local function show()
	local line = current.lines[current.page]
	words.Text = line
	current.speakingUntil = os.clock() + math.min(1.5 + #line / 30, 5)
	for _, child in row:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local last = current.page >= #current.lines
	local choices = if not last then { { Label = "Next", Next = true } } elseif current.choices then current.choices else { { Label = "Goodbye" } }
	for i, choice in choices do
		local main = i == 1
		local button = Instance.new("TextButton")
		button.LayoutOrder = i
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(110, 38)
		button.BackgroundColor3 = if main then GOLD else Color3.fromRGB(55, 55, 68)
		button.TextColor3 = if main then Color3.fromRGB(30, 22, 8) else Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 15
		button.Text = choice.Label
		button.BorderSizePixel = 0
		button.Parent = row
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		local padding = Instance.new("UIPadding", button)
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
		button.Activated:Connect(function()
			if choice.Next then
				current.page += 1
				show()
				return
			end
			local id = current.id
			close()
			if choice.Action and chooseRemote then
				chooseRemote:FireServer(id, choice.Action, choice.Arg)
			end
		end)
	end
end

task.spawn(function()
	chooseRemote = ReplicatedStorage:WaitForChild("DialogueChoose", math.huge)
	ReplicatedStorage:WaitForChild("DialogueOpen", math.huge).OnClientEvent:Connect(function(id, name, position, conversation)
		current = { id = id, position = position, lines = conversation.Lines, choices = conversation.Choices, page = 1, speakingUntil = 0 }
		speaker.Text = name
		box.Visible = true
		show()
	end)
end)

RunService.Heartbeat:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if current and (not root or (root.Position - current.position).Magnitude > CLOSE_BEYOND) then
		close()
	end
end)

return Dialogue
