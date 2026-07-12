--!strict
-- Per-age special ability: free to cast, long cooldown, AoE damage on enemy half of lane.

export type SpecialDef = {
	age: number,
	name: string,
	cooldown: number,
	damagePerHit: number,
	hits: number, -- number of falling projectiles
	duration: number, -- seconds the barrage lasts
}

local Specials: { [number]: SpecialDef } = {
	[1] = { age = 1, name = "Meteor Rain", cooldown = 90, damagePerHit = 60, hits = 10, duration = 3 },
	[2] = { age = 2, name = "Arrow Storm", cooldown = 90, damagePerHit = 120, hits = 12, duration = 3 },
	[3] = { age = 3, name = "Flaming Boulders", cooldown = 90, damagePerHit = 260, hits = 12, duration = 3 },
	[4] = { age = 4, name = "Artillery Strike", cooldown = 90, damagePerHit = 550, hits = 14, duration = 3.5 },
	[5] = { age = 5, name = "Orbital Laser", cooldown = 90, damagePerHit = 1100, hits = 14, duration = 4 },
}

return Specials
