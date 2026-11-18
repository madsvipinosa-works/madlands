-- Server-side combat. The client only says "I swung"; the server decides everything else.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local PlayerData = require(script.Parent.PlayerData)

local swingRemote = Instance.new("RemoteEvent")
swingRemote.Name = "Swing"
swingRemote.Parent = ReplicatedStorage

local lastSwing = {} -- [player] = os.clock() of last accepted swing

swingRemote.OnServerEvent:Connect(function(player) -- extra arguments are ignored on purpose
	local data = PlayerData.Get(player)
	local weapon = data and Weapons[data.Weapon] -- weapon comes from saved data, never from the client
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (weapon and root and humanoid and humanoid.Health > 0) then
		return
	end

	local now = os.clock()
	if now - (lastSwing[player] or 0) < weapon.Cooldown then
		return
	end
	lastSwing[player] = now

	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local minDot = math.cos(math.rad(weapon.ArcDegrees / 2))
	local seen = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, weapon.Range) do
		local model = part.Parent
		local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model and model:FindFirstChild("HumanoidRootPart")
		-- Players are skipped until the PvP rules exist (build step 8).
		if
			targetHumanoid
			and targetRoot
			and not seen[model]
			and model ~= character
			and not Players:GetPlayerFromCharacter(model)
			and targetHumanoid.Health > 0
		then
			seen[model] = true
			local offset = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			if offset.Magnitude < 0.01 or forward:Dot(offset.Unit) >= minDot then
				model:SetAttribute("LastHitBy", player.UserId) -- lets mobs reward the killer
				targetHumanoid:TakeDamage(weapon.Damage)
				print(`[Combat] {player.Name} hit {model.Name} for {weapon.Damage}, health now {targetHumanoid.Health}`)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
end)

return true
