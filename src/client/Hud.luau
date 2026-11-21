-- The profile panel in the top right corner: a round avatar with the level, the name, health, XP and gold.
-- Display only: it reads the Humanoid and the attributes the server sets on the player (PlayerData.Sync).
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Effects = require(script.Parent.Effects)
local player = Players.LocalPlayer

local HIDE_PLAYER_LIST = true -- Roblox's player list sits in the same corner; turn this off to bring it back
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- ours replaces Roblox's
	if HIDE_PLAYER_LIST then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end
end)

local GOLD = Color3.fromRGB(255, 215, 90)
local DARK = Color3.fromRGB(28, 28, 36)

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 99
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 16)
panel.Size = UDim2.fromOffset(330, 104)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 52)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(200, 200, 210)
panelStroke.Transparency = 0.6

local function text(parent, size, position, boxSize, alignment, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.Text = "" -- blank until the data arrives, not Roblox's default word
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = alignment or Enum.TextXAlignment.Left
	l.Position = position
	l.Size = boxSize
	local stroke = Instance.new("UIStroke", l)
	stroke.Color = Color3.fromRGB(20, 20, 26)
	stroke.Thickness = 1.5
	l.Parent = parent
	return l
end

-- the round avatar, with a ring and the level badge ------------------------------------------------
local portrait = Instance.new("Frame")
portrait.Position = UDim2.fromOffset(8, 8)
portrait.Size = UDim2.fromOffset(88, 88)
portrait.BackgroundColor3 = DARK
portrait.BorderSizePixel = 0
portrait.Parent = panel
Instance.new("UICorner", portrait).CornerRadius = UDim.new(0.5, 0)
local ring = Instance.new("UIStroke", portrait)
ring.Color = GOLD
ring.Thickness = 3

local face = Instance.new("ImageLabel")
face.Size = UDim2.fromScale(1, 1)
face.BackgroundTransparency = 1
face.Parent = portrait
Instance.new("UICorner", face).CornerRadius = UDim.new(0.5, 0)
task.spawn(function()
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok then
		face.Image = image
	end
end)

local badge = Instance.new("Frame")
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.fromOffset(18, 86)
badge.Size = UDim2.fromOffset(34, 34)
badge.BackgroundColor3 = Color3.fromRGB(60, 40, 10)
badge.BorderSizePixel = 0
badge.ZIndex = 5
badge.Parent = panel
Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)
local badgeStroke = Instance.new("UIStroke", badge)
badgeStroke.Color = GOLD
badgeStroke.Thickness = 2
local levelText = text(badge, 17, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, GOLD)
levelText.ZIndex = 6

-- the name, bars and gold -------------------------------------------------------------------------------
local nameText = text(panel, 17, UDim2.fromOffset(106, 6), UDim2.fromOffset(204, 20))
nameText.Text = player.DisplayName

local function bar(y, height, color)
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(106, y)
	back.Size = UDim2.fromOffset(204, height)
	back.BackgroundColor3 = DARK
	back.BorderSizePixel = 0
	back.Parent = panel
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, height / 2)
	local stroke = Instance.new("UIStroke", back)
	stroke.Color = Color3.fromRGB(200, 200, 210)
	stroke.Transparency = 0.6
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, height / 2)
	return back, fill
end

local healthBack, healthFill = bar(30, 22, Color3.fromRGB(205, 55, 60))
local healthText = text(healthBack, 14, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)
healthText.ZIndex = 3
local xpBack, xpFill = bar(58, 10, Color3.fromRGB(240, 190, 70))
local xpText = text(panel, 12, UDim2.fromOffset(106, 70), UDim2.fromOffset(110, 18), Enum.TextXAlignment.Left, Color3.fromRGB(235, 225, 190))

local coin = Instance.new("Frame")
coin.AnchorPoint = Vector2.new(0, 0.5)
coin.Position = UDim2.fromOffset(222, 79)
coin.Size = UDim2.fromOffset(14, 14)
coin.BackgroundColor3 = GOLD
coin.BorderSizePixel = 0
coin.Parent = panel
Instance.new("UICorner", coin).CornerRadius = UDim.new(0.5, 0)
local goldText = text(panel, 17, UDim2.fromOffset(240, 70), UDim2.fromOffset(72, 18), Enum.TextXAlignment.Left, GOLD)

local function show(fill, fraction)
	TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }):Play()
end

-- health ---------------------------------------------------------------------------------------------------
local healthConnections = {}
local function bindHealth(character)
	for _, c in healthConnections do
		c:Disconnect()
	end
	table.clear(healthConnections)
	local humanoid = character:WaitForChild("Humanoid")
	local function update()
		local hp = math.max(humanoid.Health, 0)
		show(healthFill, hp / math.max(humanoid.MaxHealth, 1))
		healthText.Text = string.format("%d / %d", math.ceil(hp), humanoid.MaxHealth)
	end
	table.insert(healthConnections, humanoid.HealthChanged:Connect(update))
	table.insert(healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update))
	update()
end
player.CharacterAdded:Connect(bindHealth)
if player.Character then
	task.spawn(bindHealth, player.Character)
end

-- the popups -------------------------------------------------------------------------------------------------
local lastLevel, lastXp = nil, nil

local function popText(message, color)
	local pop = text(panel, 16, UDim2.new(1, -150, 1, 4), UDim2.fromOffset(140, 20), Enum.TextXAlignment.Right, color)
	pop.Text = message
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pop, info, { Position = UDim2.new(1, -150, 1, 22), TextTransparency = 1 }):Play()
	TweenService:Create(pop:FindFirstChildOfClass("UIStroke"), info, { Transparency = 1 }):Play()
	task.delay(1, pop.Destroy, pop)
end

local function levelUp(level)
	local banner = Instance.new("TextLabel")
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.LuckiestGuy
	banner.TextSize = 54
	banner.TextColor3 = Color3.fromRGB(255, 215, 0)
	banner.Text = "LEVEL UP!  " .. level
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(420, 70)
	banner.Parent = gui
	local stroke = Instance.new("UIStroke", banner)
	stroke.Color = Color3.fromRGB(60, 30, 0)
	stroke.Thickness = 3
	local scale = Instance.new("UIScale", banner)
	scale.Scale = 0.4
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local fade = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4)
	TweenService:Create(banner, fade, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.26) }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	task.delay(2.6, banner.Destroy, banner)

	-- a burst of light and a ring around you
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local ground = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), RaycastParams.new())
		local at = ground and ground.Position or root.Position - Vector3.new(0, 3, 0)
		Effects.Flash(root.Position, 9, Color3.fromRGB(255, 225, 120))
		Effects.Ring(at, 18, 0.6)
	end
end

local function refresh()
	local level = player:GetAttribute("Level")
	if not level then
		return -- the server has not loaded the data yet
	end
	local xp, needed = player:GetAttribute("Xp") or 0, player:GetAttribute("XpNeeded") or 0
	levelText.Text = tostring(level)
	goldText.Text = tostring(player:GetAttribute("Gold") or 0)
	if needed > 0 then
		show(xpFill, xp / needed)
		xpText.Text = string.format("XP %d / %d", xp, needed)
	else
		show(xpFill, 1)
		xpText.Text = "MAX LEVEL"
	end
	if lastLevel and level > lastLevel then
		levelUp(level)
	elseif lastLevel == level and lastXp and xp > lastXp then
		popText("+" .. (xp - lastXp) .. " XP", Color3.fromRGB(240, 205, 110))
	end
	lastLevel, lastXp = level, xp
end

player.AttributeChanged:Connect(refresh)
refresh()

return true
