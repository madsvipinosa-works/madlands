local Config = game:GetService("ReplicatedStorage").Shared.Config

-- Load every config table at startup so a broken config shows up in Output right away.
for _, name in { "Weapons", "Skills", "Pets", "Leveling", "Items", "Sounds", "Zones", "Quests", "WeaponMaster", "Guide" } do
	local data = require(Config[name])
	assert(type(data) == "table", name .. " config must return a table")
end

require(script.PlayerData)
require(script.Combat)
require(script.WeaponVisuals)
require(script.ZoneBuilder) -- the ground, canyon wall, trail and trees; must load before the mobs, which stand on it
require(script.GateBuilder) -- the Starter Town gate at the end of the trail; needs the canyon wall from ZoneBuilder
require(script.WeaponMaster) -- gives new players their first weapon
require(script.Quests) -- the Village Chief and the quests
require(script.MobSpawner)
workspace:SetAttribute("ZoneReady", true) -- the ground is built, so returning players can be placed on it
require(script.LogoutSpot) -- puts you back where you logged out

print("Madlands is alive. Configs loaded: Weapons, Skills, Pets")
