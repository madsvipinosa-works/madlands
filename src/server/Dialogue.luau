-- Talking to villagers. Server only. A villager answers with a conversation ({ Lines = { pages of text }, Choices =
-- { { Label, Action?, Arg? } } }); client/Dialogue shows it and sends back the choice clicked. Who is talking, from how far
-- and how often is checked here; each villager's own code checks the player may really do what was chosen.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
