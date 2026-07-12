--!strict
-- 5 ages. xpRequired is cumulative XP needed to reach the age.

export type AgeDef = {
	id: number,
	name: string,
	xpRequired: number,
	color: Color3,
	heroMaxHp: number,
}

local Ages: { AgeDef } = {
	{ id = 1, name = "Stone Age", xpRequired = 0, color = Color3.fromRGB(150, 120, 90), heroMaxHp = 300 },
	{ id = 2, name = "Medieval Age", xpRequired = 1200, color = Color3.fromRGB(200, 170, 60), heroMaxHp = 450 },
	{ id = 3, name = "Renaissance Age", xpRequired = 4500, color = Color3.fromRGB(120, 120, 140), heroMaxHp = 675 },
	{ id = 4, name = "Modern Age", xpRequired = 14000, color = Color3.fromRGB(70, 110, 70), heroMaxHp = 975 },
	{ id = 5, name = "Future Age", xpRequired = 40000, color = Color3.fromRGB(80, 180, 220), heroMaxHp = 1350 },
}

return Ages
