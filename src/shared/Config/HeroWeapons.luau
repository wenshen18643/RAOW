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
	[2] = { age = 2, name = "Spear", kind = "melee", damage = 55, range = 16, fireCooldown = 0.6 },
	[3] = { age = 3, name = "Longsword", kind = "melee", damage = 130, range = 13, fireCooldown = 0.6 },
	[4] = { age = 4, name = "Service Rifle", kind = "hitscan", damage = 105, range = 120, fireCooldown = 0.35 },
	[5] = { age = 5, name = "Pulse Rifle", kind = "hitscan", damage = 170, range = 150, fireCooldown = 0.3 },
}

return HeroWeapons
