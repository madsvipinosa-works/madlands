-- Talking to villagers. Server only. A villager answers with a conversation ({ Lines = { pages of text }, Choices =
-- { { Label, Action?, Arg? } } }); client/Dialogue shows it and sends back the choice clicked. Who is talking, from how far
-- and how often is checked here; each villager's own code checks the player may really do what was chosen.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local COOLDOWN = 0.3 -- seconds between two requests from one player

local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = ReplicatedStorage
	return r
end
local openRemote = remote("DialogueOpen") -- server -> client: show a conversation
local chooseRemote = remote("DialogueChoose") -- client -> server: villager id, action, argument

local villagers = {} -- [id] = the table given to Dialogue.Add
local last = {} -- [player] = os.clock() of their last accepted request

local Dialogue = {}

local function allowed(player, villager)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and root) then
		return false
	end
	if (root.Position - villager.Model.PrimaryPart.Position).Magnitude > villager.TalkDistance + 4 then
		return false -- a cheating client can ask from anywhere
	end
	local now = os.clock()
	if now - (last[player] or 0) < COOLDOWN then
		return false
	end
	last[player] = now
	return true
end

local function send(player, villager, conversation)
	if conversation then
		openRemote:FireClient(player, villager.Id, villager.Name, villager.Model.PrimaryPart.Position, conversation)
	end
end

-- Stands a villager's hand-made model on the ground and returns it. def = { Model (in assets/models), Name, Scale };
-- at = { Position, Faces } from Config/Zones. The model is anchored: its movement is only a look, so client/Quests does it.
function Dialogue.Place(def, at)
	local model = ServerStorage:WaitForChild("Models"):WaitForChild(def.Model):Clone()
	model.Name = def.Name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- reaches a client all at once
	model:ScaleTo(model:GetScale() * def.Scale)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.Color = Color3.new(1, 1, 1) -- white shows the model's own colors
		end
	end

	local spot = at.Position
	local forward = Vector3.new(at.Faces.X - spot.X, 0, at.Faces.Z - spot.Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(spot.X, 120, spot.Z), Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position.Y else 0
	-- the model's face is toward -Z, which lookAlong turns toward the spot
	model:PivotTo(CFrame.lookAlong(model:GetPivot().Position, forward))
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
	root.CFrame = CFrame.lookAlong(Vector3.new(spot.X, ground + size.Y / 2, spot.Z), forward) -- the client reads which way is forward
	root.Parent = model
	model.PrimaryPart = root

	model.Parent = workspace
	return model
end

-- villager = { Id, Name, Model (with a PrimaryPart), PromptKey, TalkDistance, Talk = function(player) -> conversation,
-- Actions = { [name] = function(player, argument) -> conversation? } }
function Dialogue.Add(villager)
	villagers[villager.Id] = villager
	villager.Model:SetAttribute("VillagerId", villager.Id)
	CollectionService:AddTag(villager.Model, "Villager") -- the client names them and marks who to see next

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = villager.Name
	prompt.KeyboardKeyCode = villager.PromptKey
	prompt.MaxActivationDistance = villager.TalkDistance
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		if allowed(player, villager) then
			send(player, villager, villager.Talk(player))
		end
	end)
	prompt.Parent = villager.Model.PrimaryPart
end

chooseRemote.OnServerEvent:Connect(function(player, id, action, argument)
	if type(id) ~= "string" or type(action) ~= "string" or (argument ~= nil and type(argument) ~= "string") then
		return
	end
	local villager = villagers[id]
	local handler = villager and villager.Actions[action]
	if handler and allowed(player, villager) then
		send(player, villager, handler(player, argument))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)

return Dialogue
