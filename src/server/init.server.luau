local Config = game:GetService("ReplicatedStorage").Shared.Config

-- Load every config table at startup so a broken config shows up in Output right away.
for _, name in { "Weapons", "Skills", "Pets" } do
	local data = require(Config[name])
	assert(type(data) == "table", name .. " config must return a table")
end

require(script.PlayerData)
require(script.Combat)
require(script.DevDummy)

print("Madlands is alive. Configs loaded: Weapons, Skills, Pets")
