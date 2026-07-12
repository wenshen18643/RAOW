--!strict
-- 15 units: 3 roles (melee/ranged/heavy) x 5 ages.
-- Generated from role base stats x per-age multipliers; explicit names per age.

export type UnitDef = {
	id: string,
	name: string,
	age: number,
	role: "melee" | "ranged" | "heavy",
	cost: number,
	hp: number,
	damage: number,
	range: number, -- studs
	attackSpeed: number, -- seconds between attacks
	moveSpeed: number, -- studs/sec
	reward: number, -- gold+xp given to the killing side
}

local roleBase = {
	melee = { cost = 25, hp = 110, damage = 14, range = 5, attackSpeed = 1.0, moveSpeed = 14 },
	ranged = { cost = 50, hp = 70, damage = 16, range = 35, attackSpeed = 1.4, moveSpeed = 12 },
	heavy = { cost = 110, hp = 320, damage = 30, range = 6, attackSpeed = 1.6, moveSpeed = 9 },
}

-- Stat & cost growth per age (roughly x2 combat power per age)
local ageMult = { 1.0, 2.0, 4.0, 8.0, 16.0 }

local names = {
	[1] = { melee = "Clubman", ranged = "Slingshot", heavy = "Mammoth Rider" },
	[2] = { melee = "Spearman", ranged = "Archer", heavy = "War Elephant" },
	[3] = { melee = "Knight", ranged = "Crossbowman", heavy = "Catapult" },
	[4] = { melee = "Infantry", ranged = "Sniper", heavy = "Tank" },
	[5] = { melee = "Blade Trooper", ranged = "Laser Gunner", heavy = "War Mech" },
}

local Units: { [string]: UnitDef } = {}
local byAge: { [number]: { UnitDef } } = {}

for age = 1, 5 do
	byAge[age] = {}
	for _, role in { "melee" :: "melee", "ranged" :: "ranged", "heavy" :: "heavy" } do
		local base = roleBase[role]
		local m = ageMult[age]
		local def: UnitDef = {
			id = `age{age}_{role}`,
			name = names[age][role],
			age = age,
			role = role,
			cost = math.floor(base.cost * m),
			hp = math.floor(base.hp * m),
			damage = math.floor(base.damage * m),
			range = base.range,
			attackSpeed = base.attackSpeed,
			moveSpeed = base.moveSpeed + (age - 1), -- slight speed creep
			reward = math.floor(base.cost * m * 0.9),
		}
		Units[def.id] = def
		table.insert(byAge[age], def)
	end
end

return {
	byId = Units,
	byAge = byAge,
}
