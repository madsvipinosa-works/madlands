-- Quests on screen: the tracker under the profile panel, the chief's name with "!" or "?" over their head, and what they
-- say. Display only: the server owns the quest state (the "Quests" attribute, set by PlayerData.Sync).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Quests"))
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 215, 90)
local GREY = Color3.fromRGB(190, 190, 200)

local gui = Instance.new("ScreenGui")
gui.Name = "Quests"
gui.ResetOnSpawn = false
gui.DisplayOrder = 102
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent, size, position, boxSize, color, alignment)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.Text = ""
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = alignment or Enum.TextXAlignment.Left
	l.Position = position
	l.Size = boxSize
	local stroke = Instance.new("UIStroke", l)
	stroke.Color = Color3.fromRGB(20, 20, 26)
	stroke.Thickness = 1.5
	l.Parent = parent
	return l
end

local function panel(class, anchor, position, size)
	local frame = Instance.new(class)
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
	return frame
end

local tracker = panel("Frame", Vector2.new(1, 0), UDim2.new(1, -16, 0, 150), UDim2.fromOffset(280, 58))
local trackerTitle = text(tracker, 16, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 20), GOLD)
local trackerLine = text(tracker, 14, UDim2.fromOffset(14, 31), UDim2.new(1, -28, 0, 18), Color3.new(1, 1, 1))

local speech = panel("TextButton", Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.69), UDim2.fromOffset(520, 130))
speech.Text = "" -- a button so a click closes it
local speaker = text(speech, 17, UDim2.fromOffset(18, 10), UDim2.new(1, -36, 0, 22), GOLD)
local words = text(speech, 15, UDim2.fromOffset(18, 38), UDim2.new(1, -36, 1, -48), Color3.new(1, 1, 1))
words.TextWrapped = true
words.TextYAlignment = Enum.TextYAlignment.Top

local marker -- the "!" / "?" label over the chief

-- Where the player stands with the next quest: "Offer", "Active", "Ready" or "None" (all done). nil until data arrives.
local function current()
	local saved = player:GetAttribute("Quests")
	if not saved then
		return nil
	end
	saved = HttpService:JSONDecode(saved)
	for _, quest in Config.List do
		local state = saved[quest.Id]
		if not (state and state.Done) then
			local stage = if not state then "Offer" elseif state.Progress < quest.Count then "Active" else "Ready"
			return stage, quest, state
		end
	end
	return "None"
end

local function refresh()
	local stage, quest, state = current()
	tracker.Visible = quest ~= nil
	if quest then
		trackerTitle.Text = quest.Title
		if stage == "Offer" then
			trackerLine.Text = "Talk to the " .. Config.Chief.Name
		elseif stage == "Active" then
			trackerLine.Text = `{quest.Objective}: {state.Progress} / {quest.Count}`
		else
			trackerLine.Text = "Return to the " .. Config.Chief.Name
		end
	end
	if marker then
		marker.Text = if stage == "Offer" then "!" elseif stage == "Active" or stage == "Ready" then "?" else ""
		marker.TextColor3 = if stage == "Active" then GREY else GOLD
	end
end

local function label(model)
	local head = model:WaitForChild("Head", 10)
	if not head then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "QuestGiver"
	board.Adornee = head
	board.Size = UDim2.fromOffset(200, 66)
	board.StudsOffset = Vector3.new(0, 2.6, 0)
	board.MaxDistance = 150
	board.Parent = head
	marker = text(board, 38, UDim2.new(), UDim2.new(1, 0, 0, 42), GOLD, Enum.TextXAlignment.Center)
	text(board, 15, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 18), Color3.new(1, 1, 1), Enum.TextXAlignment.Center).Text = Config.Chief.Name
	refresh()
end

local shown = 0 -- counts the lines, so an old timer does not close a newer one
local function say(name, line)
	shown += 1
	local this = shown
	speaker.Text = name
	words.Text = line
	speech.Visible = true
	task.delay(4 + #line / 20, function()
		if shown == this then
			speech.Visible = false
		end
	end)
end
speech.Activated:Connect(function()
	speech.Visible = false
end)

task.spawn(function() -- the server makes the remote after the zone is built, a while after joining
	ReplicatedStorage:WaitForChild("QuestDialog", math.huge).OnClientEvent:Connect(say)
end)

CollectionService:GetInstanceAddedSignal("QuestGiver"):Connect(label)
for _, model in CollectionService:GetTagged("QuestGiver") do
	task.spawn(label, model)
end
player:GetAttributeChangedSignal("Quests"):Connect(refresh)
refresh()

return true
