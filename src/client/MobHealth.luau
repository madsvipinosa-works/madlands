-- The health bar over a mob (Config/MobBar): its name and level, a smooth bar that changes color as it empties, a pale chip that
-- shows the health just lost and drains away, and the numbers. Hidden at full health; appears when the mob is hit.
-- Looks only: the server owns the health. Runs on each client.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Mobs = require(Config:WaitForChild("Mobs"))
local Style = require(Config:WaitForChild("MobBar"))

local bars = {} -- [humanoid] = { gui, group, visibleUntil, shown }

local function healthColor(fraction)
	if fraction > 0.5 then
		return Style.Half:Lerp(Style.Full, (fraction - 0.5) * 2)
	end
	return Style.Low:Lerp(Style.Half, fraction * 2)
end

local function label(parent, text, size, color, position, alignment)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.Font = Enum.Font[Style.Font]
	l.TextColor3 = color
	l.Size = UDim2.new(1, 0, 0, size + 2)
	l.Position = position
	l.TextXAlignment = alignment or Enum.TextXAlignment.Center
	l.Parent = parent
	local stroke = Instance.new("UIStroke") -- a dark outline, so it reads on any background
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = l
	return l
end

local function build(model)
	local def = Mobs[model.Name]
	local humanoid = model:WaitForChild("Humanoid", 5)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not (def and humanoid and root) or bars[humanoid] then
		return
	end

	local top = model:GetExtentsSize().Y / 2 + Style.RaiseStuds
	local height = Style.BarHeight + Style.TextSize * 2 + 14
	local gui = Instance.new("BillboardGui")
	gui.Name = "MobHealth"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(Style.Width, height)
	gui.StudsOffset = Vector3.new(0, top, 0)
	gui.MaxDistance = Style.MaxDistance
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local group = Instance.new("CanvasGroup") -- fades everything at once
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = gui

	-- "Lv 3  Wolf"
	local title = label(group, "", Style.TextSize, Style.NameColor, UDim2.fromOffset(0, 0))
	title.RichText = true
	title.Text = string.format('<font color="#%s">Lv %d</font>  %s', Style.LevelColor:ToHex(), def.Level or 1, model.Name)

	local slot = Instance.new("Frame")
	slot.Position = UDim2.new(0, 0, 0, Style.TextSize + 6)
	slot.Size = UDim2.new(1, 0, 0, Style.BarHeight)
	slot.BackgroundColor3 = Style.Back
	slot.BorderSizePixel = 0
	slot.ClipsDescendants = true
	slot.Parent = group
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, Style.BarHeight / 2)
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = 2
	outline.Parent = slot

	local trail = Instance.new("Frame")
	trail.Size = UDim2.fromScale(1, 1)
	trail.BackgroundColor3 = Style.Trail
	trail.BorderSizePixel = 0
	trail.Parent = slot
	Instance.new("UICorner", trail).CornerRadius = UDim.new(0, Style.BarHeight / 2)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Style.Full
	fill.BorderSizePixel = 0
	fill.Parent = slot
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, Style.BarHeight / 2)
	local shine = Instance.new("UIGradient") -- a lighter top edge, so the bar looks rounded
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	shine.Parent = fill

	local numbers = Instance.new("TextLabel")
	numbers.BackgroundTransparency = 1
	numbers.Size = UDim2.fromScale(1, 1)
	numbers.Font = Enum.Font[Style.Font]
	numbers.TextSize = Style.BarHeight - 3
	numbers.TextColor3 = Color3.new(1, 1, 1)
	numbers.ZIndex = 3
	numbers.Parent = slot
	local numbersStroke = Instance.new("UIStroke")
	numbersStroke.Thickness = 1.2
	numbersStroke.Color = Color3.new(0, 0, 0)
	numbersStroke.Parent = numbers

	gui.Parent = root

	local builtAt = os.clock()
	local bar = { gui = gui, group = group, visibleUntil = 0, shown = false }
	bars[humanoid] = bar

	local function show()
		bar.visibleUntil = os.clock() + Style.ShowSeconds
		if not bar.shown then
			bar.shown = true
			TweenService:Create(group, TweenInfo.new(Style.FadeSeconds), { GroupTransparency = 0 }):Play()
		end
	end
	local function hide()
		if bar.shown then
			bar.shown = false
			TweenService:Create(group, TweenInfo.new(Style.FadeSeconds), { GroupTransparency = 1 }):Play()
		end
	end
	bar.hide = hide

	local last = humanoid.Health
	local function update(health, animate)
		local fraction = math.clamp(health / humanoid.MaxHealth, 0, 1)
		numbers.Text = string.format("%d / %d", math.ceil(health), humanoid.MaxHealth)
		local info = TweenInfo.new(if animate then 0.14 else 0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(fill, info, { Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = healthColor(fraction) }):Play()
		if health < last then
			-- the chip stays where the bar was, waits, then drains down to the new level
			TweenService:Create(trail, TweenInfo.new(Style.TrailSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, Style.TrailDelay), { Size = UDim2.fromScale(fraction, 1) }):Play()
		else
			trail.Size = UDim2.fromScale(fraction, 1)
		end
		last = health
	end
	update(humanoid.Health, false)

	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			hide()
			task.delay(Style.FadeSeconds + 0.1, function()
				gui:Destroy()
			end)
			bars[humanoid] = nil
			return
		end
		local hurt = health < last
		update(health, true)
		if health >= humanoid.MaxHealth then
			bar.visibleUntil = 0 -- a mob at full health never shows its bar
			hide()
		elseif hurt and os.clock() - builtAt > 1.5 then -- not while the mob's health is still arriving from the server
			show()
		end
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function() -- a new mob's max health can arrive after its health
		update(humanoid.Health, false)
		if humanoid.Health >= humanoid.MaxHealth then
			hide()
		end
	end)
	model.AncestryChanged:Connect(function()
		if not model.Parent then
			bars[humanoid] = nil
		end
	end)
end

-- Fade the bar out once nobody has hit the mob for a while.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, bar in bars do
		if bar.shown and now > bar.visibleUntil then
			bar.hide()
		end
	end
end)

CollectionService:GetInstanceAddedSignal("WalkingMob"):Connect(function(model)
	task.spawn(build, model)
end)
for _, model in CollectionService:GetTagged("WalkingMob") do
	task.spawn(build, model)
end

return true
