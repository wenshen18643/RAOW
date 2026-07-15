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

-- Damage is tuned so each turret two-shots the same-age ranged unit
-- (ranged HP: 85/170/340/680/1360). The Machine Gun keeps its rapid-fire
-- identity instead: 6 hits at 0.4s matches the others' two-shot kill time.
local Turrets: { [number]: TurretDef } = {
	[1] = { age = 1, name = "Rock Thrower", cost = 100, damage = 43, range = 70, attackSpeed = 1.2 },
	[2] = { age = 2, name = "Ballista", cost = 300, damage = 85, range = 80, attackSpeed = 1.2 },
	[3] = { age = 3, name = "Cannon", cost = 1200, damage = 170, range = 90, attackSpeed = 1.3 },
	[4] = { age = 4, name = "Machine Gun", cost = 7500, damage = 115, range = 95, attackSpeed = 0.4 },
	[5] = { age = 5, name = "Ion Turret", cost = 25000, damage = 680, range = 110, attackSpeed = 1.4 },
}

return Turrets
