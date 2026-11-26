-- Quests on screen: the tracker under the profile panel, the chief's name with "!" or "?" over their head, and what they
-- say, and how the chief moves. Display only: the server owns the quest state (the "Quests" attribute, set by PlayerData.Sync).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local talkingUntil = 0 -- while this is ahead, the chief gestures and nods

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

-- Brings a value part of the way to its target, the same speed at any frame rate.
local function ease(value, target, speed, dt)
	return value + (target - value) * (1 - math.exp(-speed * dt))
end

-- The chief breathes, shifts their weight and moves their free hand. When you are near, the head follows you and the body
-- turns after it; otherwise they look around. While talking they gesture and nod. Looks only: the model is anchored and
-- each client moves its own copy. Everything is worked out in the chief's own space: y up, forward -z.
local function animate(model, root)
	local base = root.CFrame * CFrame.new(0, -root.Size.Y / 2, 0) -- on the ground, facing the chief's forward
	local rest, neck, heads, shoulder = {}, Vector3.zero, 0, nil
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			rest[part] = base:ToObjectSpace(part.CFrame)
			if string.find(part.Name, "^Head") then
				neck += rest[part].Position
				heads += 1
			elseif part.Name == "LeftArm" then
				shoulder = rest[part].Position + Vector3.new(0, part.Size.Y / 2 - 0.2, 0)
			end
		end
	end
	neck = neck / math.max(heads, 1) - Vector3.new(0, 0.4, 0)

	local function about(point, rotation)
		return CFrame.new(point) * rotation * CFrame.new(-point)
	end

	local headYaw, headPitch, bodyYaw, talk = 0, 0, 0, 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not model.Parent then
			connection:Disconnect()
			return
		end
		local now = os.clock()

		local yawGoal, pitchGoal, bodyGoal = math.sin(now * 0.45) * math.rad(22), 0, 0 -- looking around
		local you = player.Character and player.Character:FindFirstChild("Head")
		if you then
			local to = base:PointToObjectSpace(you.Position) - neck
			local flat = math.sqrt(to.X ^ 2 + to.Z ^ 2)
			if flat < Config.Chief.LookDistance and flat > 0.5 then
				local yaw = math.atan2(-to.X, -to.Z)
				yawGoal = math.clamp(yaw * 0.75, -math.rad(55), math.rad(55)) -- the head turns most of the way...
				bodyGoal = yaw - yawGoal -- ...and the body the rest
				pitchGoal = math.clamp(math.atan2(to.Y, flat), -math.rad(10), math.rad(14))
			end
		end
		headYaw = ease(headYaw, yawGoal, 6, dt)
		headPitch = ease(headPitch, pitchGoal, 6, dt)
		bodyYaw = ease(bodyYaw, bodyYaw + (bodyGoal - bodyYaw + math.pi) % (2 * math.pi) - math.pi, 2.5, dt) -- the short way round
		talk = ease(talk, if now < talkingUntil then 1 else 0, 5, dt)

		local turn = CFrame.Angles(0, bodyYaw, 0)
		local breath = CFrame.new(0, math.sin(now * 1.8) * 0.05, 0)
		local sway = about(Vector3.new(0, 0.8, 0), CFrame.Angles(math.sin(now * 0.7) * math.rad(1.2), 0, math.sin(now * 0.55) * math.rad(1.8)))
		local nod = math.sin(now * 5) * math.rad(5) * talk
		local head = about(neck, CFrame.Angles(0, headYaw, 0) * CFrame.Angles(headPitch + nod, 0, 0))
		-- the free hand drifts a little, and comes up and moves while the chief speaks
		local swing = math.sin(now * 0.9) * math.rad(7) * (1 - talk) + (math.rad(38) + math.sin(now * 4) * math.rad(12)) * talk
		local arm = if shoulder then about(shoulder, CFrame.Angles(swing, 0, 0)) else CFrame.identity

		local body = turn * breath * sway
		for part, cframe in rest do
			local pose
			if string.find(part.Name, "Leg") then
				pose = turn
			elseif part.Name == "Staff" then
				pose = turn * sway
			elseif string.find(part.Name, "^Head") then
				pose = body * head
			elseif part.Name == "LeftArm" then
				pose = body * arm
			else
				pose = body
			end
			part.CFrame = base * pose * cframe
		end
	end)
end

local function label(model)
	local root = model:WaitForChild("Root", 10)
	if not root then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "QuestGiver"
	board.Adornee = root
	board.Size = UDim2.fromOffset(200, 66)
	board.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 1.4, 0)
	board.MaxDistance = 150
	board.Parent = root
	marker = text(board, 38, UDim2.new(), UDim2.new(1, 0, 0, 42), GOLD, Enum.TextXAlignment.Center)
	text(board, 15, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 18), Color3.new(1, 1, 1), Enum.TextXAlignment.Center).Text = Config.Chief.Name
	refresh()
	animate(model, root)
end

local shown = 0 -- counts the lines, so an old timer does not close a newer one
local function say(name, line)
	shown += 1
	local this = shown
	speaker.Text = name
	words.Text = line
	speech.Visible = true
	talkingUntil = os.clock() + math.min(1.5 + #line / 30, 5)
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
