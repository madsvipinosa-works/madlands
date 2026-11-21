-- The profile screen and the buttons on the left edge that open it. Display only: it reads the attributes the server
-- sets on the player (PlayerData.Sync) and the config tables, and changes nothing itself.
-- Left: your character with its equipment slots. Right: tabs for the bag, the weapon's skills and the stats.
-- Hover a card for its tooltip. Hotkeys: P profile (stats), I bag, K skills.
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Weapons = require(Config:WaitForChild("Weapons"))
local Skills = require(Config:WaitForChild("Skills"))
local Items = require(Config:WaitForChild("Items"))
local player = Players.LocalPlayer

local BAG_SLOTS = 30 -- how many squares the bag shows (a real limit comes with the shops)
local CARD = 58 -- six of these fit across the page
-- Card colours by rarity (an item's Rarity in Config/Items).
local RARITY = {
	Common = Color3.fromRGB(120, 130, 150),
	Uncommon = Color3.fromRGB(90, 190, 110),
	Rare = Color3.fromRGB(70, 130, 235),
	Epic = Color3.fromRGB(165, 95, 230),
	Legendary = Color3.fromRGB(240, 175, 50),
}
local SKILL_COLOR = Color3.fromRGB(70, 130, 235)
local GOLD = Color3.fromRGB(255, 215, 90)
local WINDOW = Color3.fromRGB(38, 48, 70)
local INNER = Color3.fromRGB(26, 33, 49)
local SLOT = Color3.fromRGB(52, 64, 92)
local MUTED = Color3.fromRGB(165, 175, 195)

local gui = Instance.new("ScreenGui")
gui.Name = "Menu"
gui.ResetOnSpawn = false
gui.DisplayOrder = 101
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(item, radius)
	Instance.new("UICorner", item).CornerRadius = UDim.new(0, radius)
end

local function stroke(item, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0
	s.Thickness = thickness or 1
	s.Parent = item
	return s
end

local function label(parent, message, size, position, boxSize, alignment, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = alignment or Enum.TextXAlignment.Left
	l.Text = message
	l.Position = position
	l.Size = boxSize
	l.Parent = parent
	return l
end

-- the tooltip -----------------------------------------------------------------------------------------------------
-- spec: Title, Color, Subtitle, Description, Rows = { { name, value }, ... }
local tooltip = Instance.new("Frame")
tooltip.Size = UDim2.fromOffset(240, 0)
tooltip.AutomaticSize = Enum.AutomaticSize.Y
tooltip.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.ZIndex = 50
tooltip.Parent = gui
corner(tooltip, 8)
stroke(tooltip, Color3.fromRGB(200, 210, 230), 0.4)
local tipPad = Instance.new("UIPadding", tooltip)
tipPad.PaddingTop, tipPad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
tipPad.PaddingLeft, tipPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
local tipList = Instance.new("UIListLayout", tooltip)
tipList.Padding = UDim.new(0, 6)
tipList.SortOrder = Enum.SortOrder.LayoutOrder

local function tipText(message, size, color, order)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = message
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = order
	l.ZIndex = 51
	l.Parent = tooltip
	return l
end

local function moveTooltip()
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local size, screen = tooltip.AbsoluteSize, gui.AbsoluteSize
	local x = math.clamp(mouse.X + 18, 4, math.max(4, screen.X - size.X - 4))
	local y = math.clamp(mouse.Y + 18, 4, math.max(4, screen.Y - size.Y - 4))
	tooltip.Position = UDim2.fromOffset(x, y)
end

local function showTooltip(spec)
	for _, child in tooltip:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	tipText(spec.Title, 18, spec.Color or Color3.new(1, 1, 1), nextOrder())
	if spec.Subtitle then
		tipText(spec.Subtitle, 12, MUTED, nextOrder())
	end
	if spec.Description then
		tipText(spec.Description, 13, Color3.fromRGB(215, 220, 232), nextOrder())
	end
	for _, row in spec.Rows or {} do
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(40, 50, 74)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, 24)
		frame.LayoutOrder = nextOrder()
		frame.ZIndex = 51
		frame.Parent = tooltip
		corner(frame, 5)
		label(frame, row[1], 13, UDim2.fromOffset(8, 0), UDim2.new(0.5, 0, 1, 0), Enum.TextXAlignment.Left, MUTED).ZIndex = 52
		label(frame, row[2], 13, UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -8, 1, 0), Enum.TextXAlignment.Right).ZIndex = 52
	end
	tooltip.Visible = true
	task.defer(moveTooltip)
end

local function hideTooltip()
	tooltip.Visible = false
end

-- a card: one square of the bag, skills or equipment ----------------------------------------------------------
-- spec: Name, Color, Level, Count, Badge (a small tag in the corner), Tooltip
local function card(parent, spec, size)
	local button = Instance.new("TextButton")
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(size or CARD, size or CARD)
	button.BackgroundColor3 = spec.Color:Lerp(Color3.new(0, 0, 0), 0.55)
	button.BorderSizePixel = 0
	button.Name = "Card_" .. spec.Name
	button.Parent = parent
	corner(button, 8)
	stroke(button, spec.Color, 0, 2)
	if spec.Icon and spec.Icon ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = spec.Icon
		icon.Size = UDim2.new(1, -12, 1, -12)
		icon.Position = UDim2.fromOffset(6, 6)
		icon.Parent = button
	else
		local name = label(button, spec.Name, 11, UDim2.fromOffset(3, 8), UDim2.new(1, -6, 1, -26), Enum.TextXAlignment.Center)
		name.TextWrapped = true
		name.TextScaled = true -- long names shrink to fit instead of splitting a word
		local fit = Instance.new("UITextSizeConstraint", name)
		fit.MaxTextSize, fit.MinTextSize = 12, 8
	end
	if spec.Level then
		label(button, "Lvl " .. spec.Level, 10, UDim2.new(0, 4, 1, -15), UDim2.new(0.6, 0, 0, 12), Enum.TextXAlignment.Left, Color3.fromRGB(235, 235, 245))
	end
	if spec.Count and spec.Count > 1 then
		label(button, "x" .. spec.Count, 12, UDim2.new(0.3, 0, 1, -16), UDim2.new(0.7, -4, 0, 14), Enum.TextXAlignment.Right, GOLD)
	end
	if spec.Badge then
		local badge = label(button, spec.Badge, 11, UDim2.fromOffset(4, 2), UDim2.fromOffset(16, 14), Enum.TextXAlignment.Left, GOLD)
		badge.ZIndex = 3
	end
	if spec.Tooltip then
		button.MouseEnter:Connect(function()
			showTooltip(spec.Tooltip)
		end)
		button.MouseLeave:Connect(hideTooltip)
		button.MouseMoved:Connect(moveTooltip)
	end
	return button
end

-- the window -----------------------------------------------------------------------------------------------------
local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(800, 480)
window.BackgroundColor3 = WINDOW
window.BorderSizePixel = 0
window.Active = true -- clicks on the window must not reach the game and swing the sword
window.Visible = false
window.Parent = gui
corner(window, 14)
stroke(window, Color3.fromRGB(190, 200, 225), 0.35, 2)

-- left: the character and its equipment
local left = Instance.new("Frame")
left.Position = UDim2.fromOffset(14, 14)
left.Size = UDim2.fromOffset(330, 452)
left.Name = "Left"
left.BackgroundColor3 = INNER
left.BorderSizePixel = 0
left.Parent = window
corner(left, 10)

local viewport = Instance.new("ViewportFrame")
viewport.Position = UDim2.fromOffset(86, 18)
viewport.Size = UDim2.fromOffset(158, 340)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(170, 170, 185)
viewport.LightColor = Color3.fromRGB(255, 250, 240)
viewport.Parent = left

local nameText = label(left, player.DisplayName, 20, UDim2.fromOffset(0, 372), UDim2.new(1, 0, 0, 26), Enum.TextXAlignment.Center)
local levelText = label(left, "", 16, UDim2.fromOffset(0, 400), UDim2.new(1, 0, 0, 22), Enum.TextXAlignment.Center, GOLD)

-- six equipment slots, three down each side; only the weapon exists in the game so far
local equipSlots = {}
for _, spec in {
	{ "Hat", 0, 0 },
	{ "Weapon", 0, 1 },
	{ "Aura", 0, 2 },
	{ "Armor", 1, 0 },
	{ "Secondary", 1, 1 },
	{ "Mount", 1, 2 },
} do
	local x = if spec[2] == 0 then 12 else 330 - 12 - 66
	local y = 30 + spec[3] * 112
	local slot = Instance.new("Frame")
	slot.Position = UDim2.fromOffset(x, y)
	slot.Size = UDim2.fromOffset(66, 66)
	slot.BackgroundColor3 = SLOT
	slot.BackgroundTransparency = 0.2
	slot.BorderSizePixel = 0
	slot.Parent = left
	corner(slot, 10)
	stroke(slot, Color3.fromRGB(110, 124, 156), 0.3, 2)
	local name = label(slot, spec[1], 12, UDim2.new(0, 0, 0.5, -8), UDim2.new(1, 0, 0, 16), Enum.TextXAlignment.Center, Color3.fromRGB(110, 124, 156))
	equipSlots[spec[1]] = { frame = slot, label = name }
end

-- right: tabs and their pages
local right = Instance.new("Frame")
right.Position = UDim2.fromOffset(358, 14)
right.Size = UDim2.fromOffset(428, 452)
right.Name = "Right"
right.BackgroundColor3 = INNER
right.BorderSizePixel = 0
right.Parent = window
corner(right, 10)

local tabs, pages, current = {}, {}, nil
local TAB_NAMES = { "Items", "Skills", "Stats" }

local function setTab(name)
	current = name
	for tabName, button in tabs do
		local on = tabName == name
		button.BackgroundColor3 = if on then Color3.fromRGB(70, 96, 150) else SLOT
		button.TextColor3 = if on then Color3.new(1, 1, 1) else MUTED
		pages[tabName].Visible = on
	end
end

for index, name in TAB_NAMES do
	local button = Instance.new("TextButton")
	button.Text = name
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Position = UDim2.fromOffset(10 + (index - 1) * 134, 10)
	button.Size = UDim2.fromOffset(128, 34)
	button.Parent = right
	corner(button, 8)
	tabs[name] = button
	button.Activated:Connect(function()
		hideTooltip()
		setTab(name)
	end)

	local page
	if name == "Stats" then
		page = Instance.new("Frame")
		page.BackgroundTransparency = 1
	else
		page = Instance.new("ScrollingFrame")
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 5
		page.CanvasSize = UDim2.new()
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.ScrollingDirection = Enum.ScrollingDirection.Y
	end
	page.Name = name .. "Page"
	page.Position = UDim2.fromOffset(10, 54)
	page.Size = UDim2.new(1, -20, 1, -64)
	page.Visible = false
	page.Parent = right
	pages[name] = page
end

local function newGrid(page)
	local layout = Instance.new("UIGridLayout", page)
	layout.CellSize = UDim2.fromOffset(CARD, CARD)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	local pad = Instance.new("UIPadding", page)
	pad.PaddingTop, pad.PaddingLeft = UDim.new(0, 4), UDim.new(0, 4)
	return page
end
local itemsGrid, skillsGrid = newGrid(pages.Items), newGrid(pages.Skills)

-- stats page
local statList = Instance.new("UIListLayout", pages.Stats)
statList.Padding = UDim.new(0, 6)
local statValues = {}
for index, name in { "Level", "Experience", "Gold", "Bank gold", "Weapon", "Damage", "Reach", "Swing speed" } do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = SLOT
	row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0
	row.LayoutOrder = index
	row.Parent = pages.Stats
	corner(row, 8)
	label(row, name, 15, UDim2.fromOffset(14, 0), UDim2.new(0.5, 0, 1, 0), Enum.TextXAlignment.Left, MUTED)
	statValues[name] = label(row, "", 15, UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -14, 1, 0), Enum.TextXAlignment.Right)
end

local close = Instance.new("TextButton")
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(205, 60, 65)
close.BorderSizePixel = 0
close.AnchorPoint = Vector2.new(0.5, 0.5)
close.Position = UDim2.new(1, -4, 0, 4)
close.Size = UDim2.fromOffset(32, 32)
close.ZIndex = 5
close.Parent = window
corner(close, 16)
stroke(close, Color3.new(1, 1, 1), 0.2, 2)

-- the live picture of your character ------------------------------------------------------------------------
-- Drag it with the mouse (or a finger) to turn it round.
local DEFAULT_TURN = math.rad(-22) -- shown a little turned, not flat on
local figure, turn = nil, DEFAULT_TURN
local dragging, lastX = false, 0
viewport.Active = true -- so it receives the mouse
viewport.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging, lastX = true, input.Position.X
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and figure and figure.Parent and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		turn += (input.Position.X - lastX) * 0.015 -- dragging right turns the front of the character to the right
		lastX = input.Position.X
		figure:PivotTo(CFrame.Angles(0, turn, 0))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
label(left, "Drag to rotate", 12, UDim2.fromOffset(0, 346), UDim2.new(1, 0, 0, 16), Enum.TextXAlignment.Center, Color3.fromRGB(110, 124, 156))

local function buildFigure()
	for _, child in viewport:GetChildren() do
		child:Destroy()
	end
	local character = player.Character
	if not character then
		return
	end
	local ok, clone = pcall(function()
		character.Archivable = true
		return character:Clone()
	end)
	if not (ok and clone) then
		return
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	clone.Parent = viewport
	figure, turn, dragging = clone, DEFAULT_TURN, false
	clone:PivotTo(CFrame.Angles(0, turn, 0))
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.4, -15), Vector3.new(0, 0.2, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- filling everything with the current numbers -----------------------------------------------------------------
local function inventory()
	local raw = player:GetAttribute("Inventory")
	if not raw or raw == "" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded else {}
end

local function clearCards(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function skillTooltip(index, id, skill)
	local rows = {}
	local damage = if skill.Hits then string.format("%d x %d", skill.Damage, skill.Hits) else tostring(skill.Damage)
	table.insert(rows, { "Damage", damage })
	if skill.Range then
		table.insert(rows, { "Range", skill.Range .. " studs" })
	end
	table.insert(rows, { "Cooldown", skill.Cooldown .. " sec" })
	table.insert(rows, { "Hotkey", tostring(index) })
	return {
		Title = skill.Name,
		Color = SKILL_COLOR:Lerp(Color3.new(1, 1, 1), 0.35),
		Subtitle = "Skill  -  Melee",
		Description = skill.Description,
		Rows = rows,
	}
end

local function refresh()
	local level = player:GetAttribute("Level")
	if not level then
		return
	end
	local weaponId = player:GetAttribute("Weapon") or "Sword"
	local weapon = Weapons[weaponId]
	local xp, needed = player:GetAttribute("Xp") or 0, player:GetAttribute("XpNeeded") or 0

	levelText.Text = "Level " .. level

	-- stats
	statValues.Level.Text = tostring(level)
	statValues.Experience.Text = if needed > 0 then string.format("%d / %d", xp, needed) else "MAX"
	statValues.Gold.Text = tostring(player:GetAttribute("Gold") or 0)
	statValues["Bank gold"].Text = tostring(player:GetAttribute("BankGold") or 0)
	statValues.Weapon.Text = weapon and weapon.Name or weaponId
	statValues.Damage.Text = if weapon then tostring(weapon.Damage) else "-"
	statValues.Reach.Text = if weapon then weapon.Range .. " studs" else "-"
	statValues["Swing speed"].Text = if weapon then string.format("%.1f / sec", 1 / weapon.Cooldown) else "-"

	-- the weapon slot
	for _, child in equipSlots.Weapon.frame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	equipSlots.Weapon.label.Visible = weapon == nil
	if weapon then
		local color = RARITY[weapon.Rarity or "Common"]
		local button = card(equipSlots.Weapon.frame, {
			Name = weapon.Name or weaponId,
			Color = color,
			Tooltip = {
				Title = weapon.Name or weaponId,
				Color = color:Lerp(Color3.new(1, 1, 1), 0.4),
				Subtitle = "Weapon  -  Melee",
				Description = weapon.Description,
				Rows = {
					{ "Damage", tostring(weapon.Damage) },
					{ "Reach", weapon.Range .. " studs" },
					{ "Swing speed", string.format("%.1f / sec", 1 / weapon.Cooldown) },
					{ "Skills", tostring(#weapon.Skills) },
				},
			},
		}, 66)
		button.ZIndex = 2
	end

	-- the bag
	clearCards(itemsGrid)
	local owned = {}
	for id, count in inventory() do
		table.insert(owned, { id = id, count = count })
	end
	table.sort(owned, function(a, b)
		return a.id < b.id
	end)
	for index = 1, math.max(BAG_SLOTS, #owned) do
		local item = owned[index]
		if item then
			local def = Items[item.id] or {}
			local color = RARITY[def.Rarity or "Common"]
			local button = card(itemsGrid, {
				Name = def.Name or item.id,
				Icon = def.Icon,
				Color = color,
				Level = def.Level,
				Count = item.count,
				Tooltip = {
					Title = def.Name or item.id,
					Color = color:Lerp(Color3.new(1, 1, 1), 0.4),
					Subtitle = (def.Rarity or "Common") .. "  -  Item",
					Description = def.Description,
					Rows = { { "Owned", tostring(item.count) } },
				},
			})
			button.LayoutOrder = index
		else
			local empty = Instance.new("Frame")
			empty.LayoutOrder = index
			empty.BackgroundColor3 = SLOT
			empty.BackgroundTransparency = 0.6
			empty.BorderSizePixel = 0
			empty.Parent = itemsGrid
			corner(empty, 8)
		end
	end
	tabs.Items.Text = string.format("Items  %d/%d", #owned, math.max(BAG_SLOTS, #owned))

	-- the weapon's skills
	clearCards(skillsGrid)
	for index, id in (weapon and weapon.Skills or {}) do
		local skill = Skills[id]
		if skill then
			local button = card(skillsGrid, {
				Name = skill.Name,
				Color = SKILL_COLOR,
				Badge = tostring(index),
				Tooltip = skillTooltip(index, id, skill),
			})
			button.LayoutOrder = index
		end
	end
end

-- opening and closing ------------------------------------------------------------------------------------------------
local function openWindow(name)
	if window.Visible and current == name then
		window.Visible = false
		hideTooltip()
	else
		window.Visible = true
		setTab(name)
		refresh()
		buildFigure()
	end
end
close.Activated:Connect(function()
	window.Visible = false
	hideTooltip()
end)

local column = Instance.new("Frame")
column.AnchorPoint = Vector2.new(0, 0.5)
column.Position = UDim2.new(0, 14, 0.5, 0)
column.Size = UDim2.fromOffset(66, 220)
column.BackgroundTransparency = 1
column.Parent = gui
local columnLayout = Instance.new("UIListLayout", column)
columnLayout.Padding = UDim.new(0, 8)

for _, spec in { { "Profile", "P", "Stats" }, { "Bag", "I", "Items" }, { "Skills", "K", "Skills" } } do
	local button = Instance.new("TextButton")
	button.Text = ""
	button.BackgroundColor3 = INNER
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(66, 66)
	button.Parent = column
	corner(button, 14)
	stroke(button, Color3.fromRGB(190, 200, 225), 0.45)
	label(button, spec[1], 14, UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 22), Enum.TextXAlignment.Center)
	label(button, "[" .. spec[2] .. "]", 13, UDim2.fromOffset(0, 36), UDim2.new(1, 0, 0, 18), Enum.TextXAlignment.Center, GOLD)
	button.Activated:Connect(function()
		openWindow(spec[3])
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		openWindow("Stats")
	elseif input.KeyCode == Enum.KeyCode.I then
		openWindow("Items")
	elseif input.KeyCode == Enum.KeyCode.K then
		openWindow("Skills")
	end
end)

player.AttributeChanged:Connect(function()
	if window.Visible then
		refresh()
	end
end)

return true
