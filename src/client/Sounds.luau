-- Plays the sound cues in Config/Sounds. Client only: sounds are feedback, they change no rules.
-- Sounds.Play("Swing1", somePart) plays the cue's layers at that part, so they come from where the thing happened
-- (nearer is louder). Pass nil to play without a position.
-- shortcut: only you hear your own skills and swings; other players' sounds come when PvP needs them (build step 8).
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))
local Dev = require(ReplicatedStorage.Shared.Config:WaitForChild("Dev"))
local rng = Random.new()

local Sounds = {}

local function pick(value)
	if type(value) == "table" then
		return rng:NextNumber(value[1], value[2])
	end
	return value or 1
end

local function playLayer(layer, parent, volumeScale)
	local sound = Instance.new("Sound")
	sound.SoundId = layer.Id
	sound.Volume = (layer.Volume or 0.5) * Config.MasterVolume * (volumeScale or 1) * rng:NextNumber(0.9, 1.1)
	sound.PlaybackSpeed = pick(layer.Speed)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Config.NearDistance
	sound.RollOffMaxDistance = Config.FarDistance
	if layer.Eq then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = layer.Eq.Low or 0
		eq.MidGain = layer.Eq.Mid or 0
		eq.HighGain = layer.Eq.High or 0
		eq.Parent = sound
	end
	if layer.Start then
		sound.TimePosition = layer.Start
	end
	sound.Parent = parent or SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, (layer.Seconds or 8) + 1) -- in case it never reports that it ended
	if layer.Seconds then -- cut a long sound off, fading out so it does not click
		local fade = 0.2
		task.delay(math.max(layer.Seconds - fade, 0), function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 }):Play()
			end
		end)
	end
	return sound
end

-- `where` is a part (or a model with a HumanoidRootPart) the sound comes from, or nil. `volumeScale` is optional.
function Sounds.Play(cueName, where, volumeScale)
	local cue = Config.Cues[cueName]
	if not cue then
		warn(`[Sounds] no cue called {cueName}`)
		return
	end
	local parent = where
	if parent and not parent:IsA("BasePart") then
		parent = parent:FindFirstChild("HumanoidRootPart")
	end
	for _, layer in cue do
		if layer.Id == "" then
			continue -- no sound set yet
		end
		if (layer.Delay or 0) > 0 then
			task.delay(layer.Delay, playLayer, layer, parent, volumeScale)
		else
			playLayer(layer, parent, volumeScale)
		end
	end
end

-- Load every sound now, so the first swing is not silent while it downloads.
task.spawn(function()
	local wanted, seen = {}, {}
	for _, cue in Config.Cues do
		for _, layer in cue do
			if layer.Id ~= "" and not seen[layer.Id] then
				seen[layer.Id] = true
				local sound = Instance.new("Sound")
				sound.SoundId = layer.Id
				table.insert(wanted, sound)
			end
		end
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, wanted)
	for _, sound in wanted do
		sound:Destroy()
	end
end)

-- Dev only: [ and ] step through every cue and play it, so you can hear each one and pick better ones.
if Dev.DEV_MODE then
	local names = {}
	for name in Config.Cues do
		table.insert(names, name)
	end
	table.sort(names)
	local index = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightBracket or input.KeyCode == Enum.KeyCode.LeftBracket then
			index = (index + (if input.KeyCode == Enum.KeyCode.RightBracket then 1 else -1) - 1) % #names + 1
			print(`[Sounds] cue {index}/{#names}: {names[index]}`)
			local character = Players.LocalPlayer.Character
			Sounds.Play(names[index], character and character:FindFirstChild("HumanoidRootPart"))
		end
	end)
	print("[Sounds] dev: press ] for the next sound and [ for the previous one")
end

return Sounds
