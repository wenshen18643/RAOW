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
	{ id = 1, name = "Stone Age", xpRequired = 0, color = Color3.fromRGB(150, 120, 90), heroMaxHp = 200 },
	{ id = 2, name = "Ancient Age", xpRequired = 800, color = Color3.fromRGB(200, 170, 60), heroMaxHp = 300 },
	{ id = 3, name = "Medieval Age", xpRequired = 2400, color = Color3.fromRGB(120, 120, 140), heroMaxHp = 450 },
	{ id = 4, name = "Modern Age", xpRequired = 6000, color = Color3.fromRGB(70, 110, 70), heroMaxHp = 650 },
	{ id = 5, name = "Future Age", xpRequired = 14000, color = Color3.fromRGB(80, 180, 220), heroMaxHp = 900 },
}

return Ages
