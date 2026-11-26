-- The arrows on the ground that lead to your next step (client/Guide). Looks only.
return {
	Color = Color3.fromRGB(255, 206, 74),
	Spacing = 4.5, -- studs between arrows
	Count = 14, -- most arrows shown ahead of you
	StartAhead = 4, -- studs in front of you where the first arrow is
	Speed = 5, -- studs per second the arrows flow toward the goal
	HeightOnPath = 0.35, -- studs above dirt or stone...
	HeightOnGrass = 2.1, -- ...and above grass, which is tall
	HideAtVillager = 9, -- the arrows go away this close to a villager...
	HideAtCamp = 30, -- ...or to a mob camp
	DirectWithin = 45, -- goals closer than this are pointed at in a straight line; farther ones go by the lane and trail
}
