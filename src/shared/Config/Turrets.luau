--!strict
-- One turret type per age, mounted on base slots.

export type TurretDef = {
	age: number,
	name: string,
	cost: number,
	damage: number,
	range: number,
	attackSpeed: number,
}

local Turrets: { [number]: TurretDef } = {
	[1] = { age = 1, name = "Rock Thrower", cost = 100, damage = 12, range = 70, attackSpeed = 1.2 },
	[2] = { age = 2, name = "Ballista", cost = 220, damage = 28, range = 80, attackSpeed = 1.2 },
	[3] = { age = 3, name = "Cannon", cost = 480, damage = 60, range = 90, attackSpeed = 1.3 },
	[4] = { age = 4, name = "Machine Gun", cost = 1000, damage = 45, range = 95, attackSpeed = 0.4 },
	[5] = { age = 5, name = "Ion Turret", cost = 2200, damage = 260, range = 110, attackSpeed = 1.4 },
}

return Turrets
