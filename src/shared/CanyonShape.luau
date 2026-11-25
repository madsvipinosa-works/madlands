-- The shape of the canyon's face, shared by the builder that cuts it (server/ZoneBuilder) and by whatever must meet it (the gate's
-- flank walls in server/GateBuilder). Pure maths on Config/Zones: no side effects.
local Shape = {}

function Shape.smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- How far the canyon's face is moved in or out at this angle (radians, 0 = east, pi/2 = north, where the gate is). Near the
-- gate the wandering fades out, so the cliff meets the gate's walls cleanly.
function Shape.faceOffset(zone, angle)
	local c = zone.Canyon
	local seed = c.Seed
	local ux, uy = math.cos(angle), math.sin(angle)
	local n = math.noise(ux * 3 + seed, uy * 3 + seed, 0.5) + 0.5 * math.noise(ux * 9 + seed, uy * 9 + seed, 1.5) + 0.25 * math.noise(ux * 24 + seed, uy * 24 + seed, 2.5)
	local fromNorth = math.abs((angle - math.pi / 2 + math.pi) % (2 * math.pi) - math.pi) -- 0 right at the gate
	local calm = Shape.smooth((fromNorth - c.GateCalm[1]) / (c.GateCalm[2] - c.GateCalm[1]))
	return math.clamp(n * 1.3, -1, 1) * c.EdgeWobble * calm
end

return Shape
