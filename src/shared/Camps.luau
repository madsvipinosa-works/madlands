-- Turns a zone's mob camps (Config/Zones) into spawn positions, the same way every time (each camp has a Seed), so the
-- mob spawner and the tree planter agree on where the mobs stand.
local Camps = {}

-- Returns a list of { Mob, Camp, Position } for every mob in the zone. Position is on the ground plane (y = 0).
function Camps.Positions(zone)
	local result = {}
	for index, camp in zone.Camps or {} do
		local rng = Random.new(camp.Seed or index)
		local spacing = camp.Spacing or 5 -- studs kept between two mobs of a camp, so they do not stand inside each other
		local placed = {}
		for _, group in camp.Groups do
			local center = camp.Center + (group.Offset or Vector3.zero)
			for _ = 1, group.Count do
				local position
				for _ = 1, 40 do -- try a few spots until one is clear of the others
					local angle = rng:NextNumber(0, math.pi * 2)
					local distance = math.sqrt(rng:NextNumber()) * group.Radius
					local try = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
					local clear = true
					for _, other in placed do
						if (other - try).Magnitude < spacing then
							clear = false
							break
						end
					end
					position = try
					if clear then
						break
					end
				end
				table.insert(placed, position)
				table.insert(result, { Mob = camp.Mob, Camp = camp.Name, Position = position })
			end
		end
	end
	return result
end

-- Each group of a camp as { Position, Radius }, for keeping other things (trees) out of the way.
function Camps.Areas(zone)
	local areas = {}
	for _, camp in zone.Camps or {} do
		for _, group in camp.Groups do
			table.insert(areas, { Position = camp.Center + (group.Offset or Vector3.zero), Radius = group.Radius })
		end
	end
	return areas
end

return Camps
