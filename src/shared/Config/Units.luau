--!strict
-- 16 units across 5 ages explicitly defined per AGE_OF_WAR.md

export type UnitDef = {
	id: string,
	name: string,
	age: number,
	role: "melee" | "ranged" | "heavy" | "super_heavy",
	cost: number,
	hp: number,
	damage: number,
	range: number, -- studs
	attackSpeed: number, -- seconds between attacks
	moveSpeed: number, -- studs/sec
	killGold: number,
	killXp: number,
	deathXp: number,
	reward: number, -- gold+xp given to the killing side
}

local rawUnits = {
	-- Age 1: Stone Age
	{ id = "age1_melee", name = "Club Man", age = 1, role = "melee", cost = 15, hp = 110, damage = 14, range = 5, attackSpeed = 1.0, moveSpeed = 14 },
	{ id = "age1_ranged", name = "Slingshot Man", age = 1, role = "ranged", cost = 25, hp = 70, damage = 16, range = 35, attackSpeed = 1.4, moveSpeed = 12 },
	{ id = "age1_heavy", name = "Dino Rider", age = 1, role = "heavy", cost = 100, hp = 320, damage = 30, range = 6, attackSpeed = 1.6, moveSpeed = 9 },
	
	-- Age 2: Medieval Age
	{ id = "age2_melee", name = "Sword Man", age = 2, role = "melee", cost = 50, hp = 220, damage = 28, range = 5, attackSpeed = 1.0, moveSpeed = 15 },
	{ id = "age2_ranged", name = "Archer", age = 2, role = "ranged", cost = 75, hp = 140, damage = 32, range = 35, attackSpeed = 1.4, moveSpeed = 13 },
	{ id = "age2_heavy", name = "Knight", age = 2, role = "heavy", cost = 500, hp = 640, damage = 60, range = 6, attackSpeed = 1.6, moveSpeed = 10 },

	-- Age 3: Renaissance Age
	{ id = "age3_melee", name = "Dueler", age = 3, role = "melee", cost = 200, hp = 440, damage = 56, range = 5, attackSpeed = 1.0, moveSpeed = 16 },
	{ id = "age3_ranged", name = "Musketeer", age = 3, role = "ranged", cost = 400, hp = 280, damage = 64, range = 45, attackSpeed = 1.4, moveSpeed = 14 },
	{ id = "age3_heavy", name = "Cannoneer", age = 3, role = "heavy", cost = 1000, hp = 1280, damage = 120, range = 30, attackSpeed = 2.0, moveSpeed = 11 },

	-- Age 4: Modern Age
	{ id = "age4_melee", name = "Melee Infantry", age = 4, role = "melee", cost = 1500, hp = 880, damage = 112, range = 5, attackSpeed = 1.0, moveSpeed = 17 },
	{ id = "age4_ranged", name = "Infantry", age = 4, role = "ranged", cost = 2000, hp = 560, damage = 128, range = 50, attackSpeed = 1.4, moveSpeed = 15 },
	{ id = "age4_heavy", name = "Tank", age = 4, role = "heavy", cost = 7000, hp = 2560, damage = 240, range = 40, attackSpeed = 1.6, moveSpeed = 12 },

	-- Age 5: Future Age
	{ id = "age5_melee", name = "God's Blade", age = 5, role = "melee", cost = 5000, hp = 1760, damage = 224, range = 5, attackSpeed = 1.0, moveSpeed = 18 },
	{ id = "age5_ranged", name = "Blaster", age = 5, role = "ranged", cost = 6000, hp = 1120, damage = 256, range = 55, attackSpeed = 1.4, moveSpeed = 16 },
	{ id = "age5_heavy", name = "War Machine", age = 5, role = "heavy", cost = 20000, hp = 5120, damage = 480, range = 40, attackSpeed = 1.6, moveSpeed = 13 },
	{ id = "age5_super_heavy", name = "Super Soldier", age = 5, role = "super_heavy", cost = 150000, hp = 15000, damage = 1000, range = 30, attackSpeed = 1.0, moveSpeed = 15 },
}

local Units: { [string]: UnitDef } = {}
local byAge: { [number]: { UnitDef } } = {}

for age = 1, 5 do
	byAge[age] = {}
end

for _, raw in rawUnits do
	local def: UnitDef = {
		id = raw.id,
		name = raw.name,
		age = raw.age,
		role = raw.role :: any,
		cost = raw.cost,
		hp = raw.hp,
		damage = raw.damage,
		range = raw.range,
		attackSpeed = raw.attackSpeed,
		moveSpeed = raw.moveSpeed,
		killGold = raw.cost + math.round(raw.cost * 0.3),
		killXp = raw.cost * 2,
		deathXp = math.floor(raw.cost * 0.5),
		reward = raw.cost + math.round(raw.cost * 0.3), -- Kept for backward compatibility
	}
	Units[def.id] = def
	table.insert(byAge[raw.age], def)
end

return {
	byId = Units,
	byAge = byAge,
}
