-- How arrows, spells and their landings look (client/Projectiles). Looks only: speeds, ranges and damage are in
-- Config/Weapons and Config/Skills. Kind picks the drawing: Arrow, Orb, Fireball (shared/FireballVFX), Rain (falling arrows) or Meteor.
return {
	Arrow = { Kind = "Arrow", Length = 3, Color = Color3.fromRGB(150, 108, 66), Trail = Color3.fromRGB(235, 235, 240) },
	PowerArrow = { Kind = "Arrow", Length = 4.5, Color = Color3.fromRGB(190, 140, 60), Trail = Color3.fromRGB(255, 205, 90), Glow = true },
	Bolt = { Kind = "Orb", Size = 1.1, Color = Color3.fromRGB(110, 200, 255), Burst = 4 },
	-- Glow = colour of the charge-up; Color = colour of the flames, sparks and blast; Scale = size of the charge-up and the
	-- flying ball; BlastScale = size of the explosion (1.15 fits its 9 stud burst)
	Fireball = { Kind = "Fireball", Glow = Color3.fromRGB(255, 205, 110), Scale = 1, Color = Color3.fromRGB(255, 120, 25), BlastScale = 1.15, Cue = "Explosion" },
	Rain = { Kind = "Rain", Color = Color3.fromRGB(255, 215, 130), PerHit = 12, Height = 30, FallSeconds = 0.28, Cue = "RainFall" },
	Meteor = { Kind = "Meteor", Color = Color3.fromRGB(255, 105, 35), Size = 7, Height = 65, FallSeconds = 0.65, Cue = "MeteorLand" },
}
