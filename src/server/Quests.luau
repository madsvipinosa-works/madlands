-- Quests (Config/Quests): the Village Chief who gives them, the kill count and the rewards. Server only: the client is only
-- told what to show. Progress is kept in the player's saved data (ProfileStore, through PlayerData).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config.Quests)
local village = require(ReplicatedStorage.Shared.Config.Zones).OutsideZone1.Village
local PlayerData = require(script.Parent.PlayerData)

local chief = Config.Chief
local lastTalk = {} -- [player] = when they last talked

local dialog = Instance.new("RemoteEvent") -- server -> client only: what the chief says
dialog.Name = "QuestDialog"
dialog.Parent = ReplicatedStorage

local Quests = {}

-- The first quest the player has not finished, and their state in it (nil = not taken yet).
local function nextQuest(data)
	for _, quest in Config.List do
		local state = data.Quests[quest.Id]
		if not (state and state.Done) then
			return quest, state
		end
	end
	return nil
end

-- Talking takes the next quest, asks after it, or hands it in for the reward.
local function talk(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local quest, state = nextQuest(data)
	local line
	if not quest then
		line = chief.NoMoreQuests
	elseif not state then
		data.Quests[quest.Id] = { Progress = 0 }
		line = `{quest.Offer}\nReward: {quest.Reward.Gold} gold, {quest.Reward.Xp} XP`
	elseif state.Progress < quest.Count then
		line = string.format(quest.Reminder, state.Progress, quest.Count)
	else
		data.Quests[quest.Id] = { Done = true } -- marked before paying, so it can never pay twice
		PlayerData.AddGold(player, quest.Reward.Gold)
		PlayerData.AddXp(player, quest.Reward.Xp)
		line = `{quest.Thanks}\nYou got {quest.Reward.Gold} gold and {quest.Reward.Xp} XP.`
		print(`[Quest] {player.Name} finished {quest.Id}`)
	end
	PlayerData.Sync(player)
	dialog:FireClient(player, chief.Name, line)
end

-- Called by MobSpawner for the player who gets the kill.
function Quests.MobKilled(player, mobName)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local quest, state = nextQuest(data)
	if quest and state and quest.Mob == mobName and state.Progress < quest.Count then
		state.Progress += 1
		PlayerData.Sync(player)
	end
end

-- A cheating client can fire a prompt from anywhere, so who is asking, and from how far, is checked here.
local function asked(player, at)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and root) or (root.Position - at).Magnitude > chief.TalkDistance + 4 then
		return
	end
	local now = os.clock()
	if now - (lastTalk[player] or 0) >= chief.Cooldown then
		lastTalk[player] = now
		talk(player)
	end
end

-- The chief is the hand-made model, anchored. Its idle movement is only a look, so client/Quests does it.
local function buildChief()
	local model = ServerStorage:WaitForChild("Models"):WaitForChild(chief.Model):Clone()
	model.Name = chief.Name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- reaches a client all at once
	model:ScaleTo(model:GetScale() * chief.Scale)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.Color = Color3.new(1, 1, 1) -- white shows the model's own colors
		end
	end

	local spot, faces = village.Chief.Position, village.Chief.Faces
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(spot.X, 120, spot.Z), Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position.Y else 0
	-- the model's face is toward -Z, which lookAlong turns toward the spot
	model:PivotTo(CFrame.lookAlong(model:GetPivot().Position, Vector3.new(faces.X - spot.X, 0, faces.Z - spot.Z)))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(spot.X - box.X, ground - (box.Y - size.Y / 2), spot.Z - box.Z))

	-- an invisible post: players cannot walk through it, and the prompt and the name hang on it
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(2, size.Y, 2)
	root.CFrame = CFrame.lookAlong(Vector3.new(spot.X, ground + size.Y / 2, spot.Z), Vector3.new(faces.X - spot.X, 0, faces.Z - spot.Z)) -- the client reads which way is forward
	root.Parent = model
	model.PrimaryPart = root

	CollectionService:AddTag(model, "QuestGiver")
	model.Parent = workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = chief.Name
	prompt.KeyboardKeyCode = chief.PromptKey
	prompt.MaxActivationDistance = chief.TalkDistance
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		asked(player, root.Position)
	end)
	prompt.Parent = root
end

Players.PlayerRemoving:Connect(function(player)
	lastTalk[player] = nil
end)

task.spawn(function()
	while not workspace:GetAttribute("ZoneReady") do -- set by init.server once the ground is built
		task.wait(0.2)
	end
	buildChief()
end)

return Quests
