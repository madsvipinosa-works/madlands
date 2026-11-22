-- Visual/audio feedback only. Reads Humanoid health the server already replicated; changes no rules.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Weapons"))

local Style = require(ReplicatedStorage.Shared.Config:WaitForChild("DamageNumbers"))

local Animations = require(script.Parent.Animations)
local SwingAnimations = require(ReplicatedStorage.Shared.Config:WaitForChild("SwingAnimations"))
local Players = game:GetService("Players")
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)

local Feedback = {}

-- The swing sound starts on the click, not when the server answers. This guesses the combo the way the server counts it
-- (shortcut: if the server refuses a swing, the sound still played; it only plays once per Cooldown).
local lastClick, guess, guessExpires = 0, 0, 0
function Feedback.ClickSound()
	local weapon = Weapons.Sword -- shortcut: always the Sword, see PlaySwing
	local now = os.clock()
	if now - lastClick < weapon.Cooldown + 0.02 then
		return
	end
	lastClick = now
	guess = if now < guessExpires then guess % #weapon.SwingCombo + 1 else 1
	guessExpires = now + weapon.ComboResetSeconds
	Sounds.Play(weapon.SwingCombo[guess], Players.LocalPlayer.Character)
end

function Feedback.PlaySwing(comboIndex)
	-- shortcut: always the Sword's swings, the client doesn't know the equipped weapon yet; fix in build step 5
	local name = Weapons.Sword.SwingCombo[comboIndex] or Weapons.Sword.SwingCombo[1]
	Animations.Play(name)

	-- The crescent of the cut, in front of you, tilted the way the blade travels.
	local fx = SwingAnimations[name].Slash
	if fx then
		task.delay(fx.Delay, function()
			local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if root then
				-- The crescent mesh (the same as the Wave Slash), tilted to the cut, with its curved edge toward you and the tips pointing out, like the Wave Slash.
				local tilt = CFrame.Angles(0, 0, math.rad(fx.Angle))
				Effects.CutMark(root.CFrame * CFrame.new(0, fx.Height, -fx.Ahead) * tilt, fx.Size / 6, 0.3)
			end
		end)
	end
end

local function flash(model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.Adornee = model
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(0.25), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.3)
end

local rng = Random.new()

local function floatNumber(root, amount)
	local style = amount >= Style.StrongThreshold and Style.Strong or Style.Normal

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, Style.StartHeight, 0)
	gui.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.round(amount))
	label.TextColor3 = style.Color
	label.Font = Enum.Font[Style.Font]
	label.TextSize = style.TextSize
	label.Parent = gui

	local outline = Instance.new("UIStroke") -- TextStrokeTransparency is too thin for a thick outline
	outline.Color = Style.OutlineColor
	outline.Thickness = Style.OutlineThickness
	outline.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = Style.StartScale
	scale.Parent = label

	gui.Parent = root

	-- Pop: Back easing overshoots slightly, then settles at full size.
	TweenService:Create(scale, TweenInfo.new(Style.PopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- Drift up and a little sideways, fast at first, slowing down.
	local side = rng:NextNumber(-Style.SideStuds, Style.SideStuds)
	local drift = TweenInfo.new(Style.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, drift, { StudsOffset = Vector3.new(side, Style.StartHeight + Style.RiseStuds, 0) }):Play()

	-- Fade out over the last part of the lifetime.
	local fade = TweenInfo.new(Style.Lifetime - Style.FadeStart, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, Style.FadeStart)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(outline, fade, { Transparency = 1 }):Play()

	Debris:AddItem(gui, Style.Lifetime + 0.1)
end

local function watch(humanoid)
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		local lost = last - health
		last = health
		local model = humanoid.Parent
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if lost > 0 and root then
			flash(model)
			local strong = lost >= Style.StrongThreshold
			Effects.HitSpark(root, strong)
			Sounds.Play(if model == Players.LocalPlayer.Character then "PlayerHurt" elseif strong then "HitStrong" else "Hit", root)
			if strong then
				Effects.Impact(root.Position)
			end
			floatNumber(root, lost)
		end
	end)
end

for _, d in workspace:GetDescendants() do
	if d:IsA("Humanoid") then
		watch(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then
		watch(d)
	end
end)

return Feedback
