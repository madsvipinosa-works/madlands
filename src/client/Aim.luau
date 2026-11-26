-- The weapon in your hand and where you are pointing. Input only: the server checks everything it is sent.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Weapons"))
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Aim = {}

-- The equipped weapon's config, or nil before you have one.
function Aim.Weapon()
	return Weapons[player:GetAttribute("Weapon") or ""]
end

-- True if that skill is open (not locked), as the server last said. Only for the screen: the server checks again.
function Aim.HasSkill(skillId)
	local open = player:GetAttribute("Skills")
	return open ~= nil and HttpService:JSONDecode(open)[skillId] == true
end

-- The point under the mouse. With a bow or wand your character also turns to face it, so the shot leaves your front.
function Aim.Take()
	local point = mouse.Hit.Position
	local weapon = Aim.Weapon()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if weapon and weapon.Aimed and root then
		local to = (point - root.Position) * Vector3.new(1, 0, 1)
		if to.Magnitude > 0.5 then
			root.CFrame = CFrame.lookAlong(root.Position, to.Unit)
		end
	end
	return point
end

return Aim
