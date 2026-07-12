--!strict
-- Hero weapon per age. Server validates every shot against these numbers.

export type WeaponDef = {
	age: number,
	name: string,
	kind: "melee" | "hitscan",
	damage: number,
	range: number,
	fireCooldown: number, -- min seconds between attacks (server enforced)
}

local HeroWeapons: { [number]: WeaponDef } = {
	[1] = { age = 1, name = "Club", kind = "melee", damage = 35, range = 12, fireCooldown = 0.6 },
	[2] = { age = 2, name = "Spear", kind = "melee", damage = 55, range = 16, fireCooldown = 0.9 },
	[3] = { age = 3, name = "Longsword", kind = "melee", damage = 130, range = 13, fireCooldown = 0.55 },
	[4] = { age = 4, name = "Trench Knife", kind = "melee", damage = 90, range = 11, fireCooldown = 0.25 },
	[5] = { age = 5, name = "Energy Sword", kind = "melee", damage = 200, range = 14, fireCooldown = 0.2 },
}

return HeroWeapons
