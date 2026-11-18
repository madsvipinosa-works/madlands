-- Puts the equipped weapon's model in the character's right hand, so everyone sees it, and shows a blade trail
-- during swings and skills. Looks only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local PlayerData = require(script.Parent.PlayerData)

local effects = setmetatable({}, { __mode = "k" }) -- [character] = { trail, token }

local WeaponVisuals = {}

-- Turns the blade trail on for a number of seconds (called by Combat when a swing or skill starts).
function WeaponVisuals.ShowTrail(character, seconds)
	local fx = effects[character]
	if not (fx and fx.trail.Parent) then
		return
	end
	fx.token += 1
	local token = fx.token
	fx.trail.Enabled = true
	task.delay(seconds, function()
		if fx.token == token and fx.trail.Parent then
			fx.trail.Enabled = false
		end
	end)
end

local function addTrail(character, model, visual)
	local blade = model:FindFirstChild(visual.TrailPart)
	if not blade then
		return
	end
	local half = blade.Size.Z / 2 -- the blade runs along Z; the tip is on the -Z side
	local base = Instance.new("Attachment")
	base.Position = Vector3.new(0, 0, half)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, 0, -half)
	tip.Parent = blade

	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = base, tip
	trail.Color = ColorSequence.new(visual.Trail.Color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = visual.Trail.Lifetime
	trail.LightEmission = 0 -- plain, not glowing
	trail.FaceCamera = true
	trail.MinLength = 0.05
	trail.Enabled = false
	trail.Parent = blade

	effects[character] = { trail = trail, token = 0 }
end

local function attach(player, character)
	local data
	for _ = 1, 50 do -- saved data loads a moment after the character appears
		data = PlayerData.Get(player)
		if data or not character.Parent then
			break
		end
		task.wait(0.2)
	end
	local visual = data and Weapons[data.Weapon] and Weapons[data.Weapon].Visual
	local hand = character:WaitForChild("RightHand", 10) -- R15 only
	if not (visual and hand) or character:FindFirstChild("WeaponVisual") then
		return
	end

	local model = Instance.new("Model")
	model.Name = "WeaponVisual"
	local handle
	for i, spec in visual.Parts do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Size = spec.Size
		part.Color = spec.Color
		part.Material = Enum.Material[spec.Material]
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if i == 1 then
			handle = part
			part.CFrame = hand.CFrame
		else
			part.CFrame = handle.CFrame * CFrame.new(spec.Offset)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, part
			weld.Parent = part
		end
		part.Parent = model
	end

	local grip = Instance.new("Weld") -- blade points forward and a little up from the fist
	grip.Part0, grip.Part1 = hand, handle
	grip.C0 = CFrame.new(visual.GripOffset) * CFrame.Angles(math.rad(visual.GripAngleDegrees), 0, 0)
	grip.Parent = handle
	model.Parent = character
	addTrail(character, model, visual)
end

local function track(player)
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
end

Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end

return WeaponVisuals
