-- What to do next: the tracker under the profile panel, the villagers' names with "!" or "?" over their heads, the arrows
-- on the ground (client/Guide), and how the villagers move. Display only: the server owns the weapon and quest state (the
-- "Weapon" and "Quests" attributes, set by PlayerData.Sync).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Config = require(Shared:WaitForChild("Quests"))
local WeaponMaster = require(Shared:WaitForChild("WeaponMaster"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local GuideStyle = require(Shared:WaitForChild("Guide"))
local zone = require(Shared:WaitForChild("Zones")).OutsideZone1
local Dialogue = require(script.Parent.Dialogue)
local Guide = require(script.Parent.Guide)
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 215, 90)
local GREY = Color3.fromRGB(190, 190, 200)

local gui = Instance.new("ScreenGui")
gui.Name = "Quests"
gui.ResetOnSpawn = false
gui.DisplayOrder = 98
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

local tracker = Instance.new("Frame")
tracker.AnchorPoint = Vector2.new(1, 0)
tracker.Position = UDim2.new(1, -16, 0, 150)
tracker.Size = UDim2.fromOffset(330, 58)
tracker.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
tracker.BackgroundTransparency = 0.2
tracker.BorderSizePixel = 0
tracker.Visible = false
tracker.Parent = gui
Instance.new("UICorner", tracker).CornerRadius = UDim.new(0, 14)
local trackerTitle = text(tracker, 16, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 20), GOLD)
local trackerLine = text(tracker, 14, UDim2.fromOffset(14, 31), UDim2.new(1, -28, 0, 18), Color3.new(1, 1, 1))

local markers = {} -- [villager id] = the "!" / "?" label over them

-- Where the player stands: "Weapon" (has none yet), then for the next quest "Offer", "Active" or "Ready", and "None" when
-- all are done. nil until the data arrives.
local function current()
	local saved, weapon = player:GetAttribute("Quests"), player:GetAttribute("Weapon")
	if not saved or not weapon then
		return nil
	end
	if not Weapons[weapon] then
		return "Weapon"
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

-- Where the arrows lead for each step.
local function goalFor(stage, quest)
	if stage == "Weapon" then
		return function()
			return zone.Village.WeaponMaster.Position, GuideStyle.HideAtVillager
		end
	elseif stage == "Offer" or stage == "Ready" then
		return function()
			return zone.Village.Chief.Position, GuideStyle.HideAtVillager
		end
	elseif stage == "Active" then
		return function(from) -- the nearest camp of the quest's mob
			local best, bestDistance = nil, math.huge
			for _, camp in zone.Camps do
				local d = (camp.Center - from).Magnitude
				if camp.Mob == quest.Mob and d < bestDistance then
					best, bestDistance = camp.Center, d
				end
			end
			return best, GuideStyle.HideAtCamp
		end
	end
	return nil
end

local function refresh()
	local stage, quest, state = current()
	tracker.Visible = stage ~= nil and stage ~= "None"
	if stage == "Weapon" then
		trackerTitle.Text = "First Steps"
		trackerLine.Text = "Pick a weapon from the " .. WeaponMaster.Name
	elseif quest then
		trackerTitle.Text = quest.Title
		if stage == "Offer" then
			trackerLine.Text = "Talk to the " .. Config.Chief.Name
		elseif stage == "Active" then
			trackerLine.Text = `{quest.Objective}: {state.Progress} / {quest.Count}`
		else
			trackerLine.Text = "Return to the " .. Config.Chief.Name
		end
	end
	if markers.WeaponMaster then
		markers.WeaponMaster.Text = if stage == "Weapon" then "!" else ""
	end
	if markers.VillageChief then
		markers.VillageChief.Text = if stage == "Offer" then "!" elseif stage == "Active" or stage == "Ready" then "?" else ""
		markers.VillageChief.TextColor3 = if stage == "Active" then GREY else GOLD
	end
	Guide.SetGoal(goalFor(stage, quest))
end

-- Brings a value part of the way to its target, the same speed at any frame rate.
local function ease(value, target, speed, dt)
	return value + (target - value) * (1 - math.exp(-speed * dt))
end

-- A villager breathes, shifts their weight and moves their free hand. When you are near, the head follows you and the body
-- turns after it; otherwise they look around. While talking they gesture and nod. Looks only: the model is anchored and
-- each client moves its own copy. Everything is worked out in the villager's own space: y up, forward -z.
local function animate(model, root, id, lookDistance)
	local base = root.CFrame * CFrame.new(0, -root.Size.Y / 2, 0) -- on the ground, facing the villager's forward
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
			if flat < lookDistance and flat > 0.5 then
				local yaw = math.atan2(-to.X, -to.Z)
				yawGoal = math.clamp(yaw * 0.75, -math.rad(55), math.rad(55)) -- the head turns most of the way...
				bodyGoal = yaw - yawGoal -- ...and the body the rest
				pitchGoal = math.clamp(math.atan2(to.Y, flat), -math.rad(10), math.rad(14))
			end
		end
		headYaw = ease(headYaw, yawGoal, 6, dt)
		headPitch = ease(headPitch, pitchGoal, 6, dt)
		bodyYaw = ease(bodyYaw, bodyYaw + (bodyGoal - bodyYaw + math.pi) % (2 * math.pi) - math.pi, 2.5, dt) -- the short way round
		talk = ease(talk, if Dialogue.Speaking(id) then 1 else 0, 5, dt)

		local turn = CFrame.Angles(0, bodyYaw, 0)
		local breath = CFrame.new(0, math.sin(now * 1.8) * 0.05, 0)
		local sway = about(Vector3.new(0, 0.8, 0), CFrame.Angles(math.sin(now * 0.7) * math.rad(1.2), 0, math.sin(now * 0.55) * math.rad(1.8)))
		local nod = math.sin(now * 5) * math.rad(5) * talk
		local head = about(neck, CFrame.Angles(0, headYaw, 0) * CFrame.Angles(headPitch + nod, 0, 0))
		-- the free hand drifts a little, and comes up and moves while they speak
		local swing = math.sin(now * 0.9) * math.rad(7) * (1 - talk) + (math.rad(38) + math.sin(now * 4) * math.rad(12)) * talk
		local arm = if shoulder then about(shoulder, CFrame.Angles(swing, 0, 0)) else CFrame.identity

		local body = turn * breath * sway
		for part, cframe in rest do
			local pose
			if string.find(part.Name, "Leg") then
				pose = turn
			elseif part.Name == "Staff" or part.Name == "Sword" then -- planted on the ground
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
	local root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local id = model:GetAttribute("VillagerId")
	local box, size = model:GetBoundingBox()
	local board = Instance.new("BillboardGui")
	board.Name = "Villager"
	board.Adornee = root
	board.Size = UDim2.fromOffset(200, 66)
	board.StudsOffsetWorldSpace = Vector3.new(0, box.Y + size.Y / 2 - root.Position.Y + 1.4, 0)
	board.MaxDistance = 150
	board.Parent = root
	markers[id] = text(board, 38, UDim2.new(), UDim2.new(1, 0, 0, 42), GOLD, Enum.TextXAlignment.Center)
	text(board, 15, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 18), Color3.new(1, 1, 1), Enum.TextXAlignment.Center).Text = model.Name
	refresh()
	local settings = if id == "VillageChief" then Config.Chief else WeaponMaster
	animate(model, root, id, settings.LookDistance)
end

CollectionService:GetInstanceAddedSignal("Villager"):Connect(label)
for _, model in CollectionService:GetTagged("Villager") do
	task.spawn(label, model)
end
player:GetAttributeChangedSignal("Quests"):Connect(refresh)
player:GetAttributeChangedSignal("Weapon"):Connect(refresh)
refresh()

return true
