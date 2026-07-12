--!strict
-- Mutually exclusive army doctrines. The first completed formation locks in
-- for the rest of the match, so composition is a strategic commitment.

export type SynergyDef = {
	id: string,
	name: string,
	description: string,
	requirements: { [string]: number },
	roleBuffs: { [string]: { damage: number?, health: number?, speed: number? } },
	color: Color3,
}

local list: { SynergyDef } = {
	{
		id = "Vanguard",
		name = "Vanguard",
		description = "3 Melee + 1 Heavy. Melee gain +15% health and +10% damage.",
		requirements = { melee = 3, heavy = 1 },
		roleBuffs = { melee = { health = 0.15, damage = 0.10 } },
		color = Color3.fromRGB(235, 150, 75),
	},
	{
		id = "Volley",
		name = "Volley Line",
		description = "3 Ranged + 1 Melee. Ranged gain +12% damage and +8% speed.",
		requirements = { ranged = 3, melee = 1 },
		roleBuffs = { ranged = { damage = 0.12, speed = 0.08 } },
		color = Color3.fromRGB(100, 190, 245),
	},
	{
		id = "Siege",
		name = "Siege Column",
		description = "2 Heavy + 2 Ranged. Heavy units gain +18% health and +8% damage.",
		requirements = { heavy = 2, ranged = 2 },
		roleBuffs = { heavy = { health = 0.18, damage = 0.08 } },
		color = Color3.fromRGB(185, 135, 225),
	},
}

local byId: { [string]: SynergyDef } = {}
for _, def in list do
	byId[def.id] = def
end

return { list = list, byId = byId }
