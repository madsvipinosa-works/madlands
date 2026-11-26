-- Skill hotkeys (1-4) and the cooldown bar. Input and display only; the server decides if a skill fires.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Weapons = require(Config:WaitForChild("Weapons"))
local Skills = require(Config:WaitForChild("Skills"))
local Animations = require(script.Parent.Animations)
local Effects = require(script.Parent.Effects)
local skillRemote = ReplicatedStorage:WaitForChild("UseSkill")
local skillUsedRemote = ReplicatedStorage:WaitForChild("SkillUsed")

-- shortcut: always shows the Sword's skills, the client doesn't know the equipped weapon yet; fix in build step 5
local skillIds = Weapons.Sword.Skills
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local SLOT = 72
local GAP = 8

local gui = Instance.new("ScreenGui")
gui.Name = "SkillBar"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100 -- above other UI
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.fromScale(0.5, 0.82) -- not at the very bottom: a tall Studio test window can push the bottom edge off your screen
holder.Size = UDim2.fromOffset(#skillIds * (SLOT + GAP) - GAP, SLOT)
holder.BackgroundTransparency = 1
holder.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, GAP)
layout.Parent = holder

local function label(parent, text, size, position, anchor, zIndex)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Position = position
	l.AnchorPoint = anchor
	l.Size = UDim2.fromScale(1, 0.3)
	l.ZIndex = zIndex
	l.Parent = parent
	return l
end

local slots = {} -- [slot] = { overlay, timeLabel, endTime, duration }
for i, skillId in skillIds do
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(SLOT, SLOT)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.LayoutOrder = i
	frame.Parent = holder
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(200, 200, 210)
	stroke.Transparency = 0.5

	label(frame, tostring(i), 18, UDim2.fromOffset(6, 2), Vector2.new(0, 0), 3).TextXAlignment = Enum.TextXAlignment.Left
	label(frame, Skills[skillId].Name, 12, UDim2.fromScale(0, 1), Vector2.new(0, 1), 3)

	local overlay = Instance.new("Frame") -- dark cover that shrinks as the cooldown runs out
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 2
	overlay.Parent = frame

	local timeLabel = label(frame, "", 22, UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5), 4)
	slots[i] = { overlay = overlay, timeLabel = timeLabel, endTime = 0, duration = 1 }
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, s in slots do
		local remaining = s.endTime - now
		if remaining > 0 then
			s.overlay.Size = UDim2.fromScale(1, remaining / s.duration)
			s.timeLabel.Text = string.format("%.1f", remaining)
		elseif s.timeLabel.Text ~= "" then
			s.overlay.Size = UDim2.fromScale(1, 0)
			s.timeLabel.Text = ""
		end
	end
end)

-- The server confirms a skill and sends its cooldown; the bar only shows what the server accepted.
skillUsedRemote.OnClientEvent:Connect(function(slot, cooldown)
	local s = slots[slot]
	if s then
		s.endTime = os.clock() + cooldown
		s.duration = cooldown
		local skill = Skills[skillIds[slot]]
		Animations.Play(skill.Animation, skill.AnimationSpeed)
		Effects.SkillStarted(skill)
	end
end)

-- No weapon yet, no skills: the bar shows once the server says you have one.
local player = Players.LocalPlayer
local function showBar()
	holder.Visible = Weapons[player:GetAttribute("Weapon") or ""] ~= nil
end
player:GetAttributeChangedSignal("Weapon"):Connect(showBar)
showBar()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not holder.Visible then
		return
	end
	for i, key in KEYS do
		if input.KeyCode == key then
			skillRemote:FireServer(i)
			local s = slots[i]
			if s and os.clock() >= s.endTime and skillIds[i] then -- ready: the sound starts now; the server still decides
				Effects.SkillSounds(Skills[skillIds[i]])
			end
		end
	end
end)

return true
