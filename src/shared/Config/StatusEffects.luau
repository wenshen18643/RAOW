--!strict
-- Status effect definitions applied by age-specific units.
-- "dot" effects tick periodic damage; "amp" effects increase incoming damage.

local StatusEffects = {}

-- Describes a single status effect
export type StatusEffectDef = {
	id: string, -- unique identifier
	name: string, -- display name
	age: number, -- which age applies this effect
	kind: "dot" | "amp", -- dot = damage over time, amp = damage amplification
	duration: number, -- seconds the effect lasts
	interval: number?, -- seconds between DoT ticks (only for dot kind)
	damageRatio: number, -- dot: fraction of base attack per tick; amp: % damage increase
	color: Color3, -- visual indicator color
}

-- All defined status effects keyed by id
local EFFECTS: { [string]: StatusEffectDef } = {
	Burning = {
		id = "Burning",
		name = "Burning",
		age = 1,
		kind = "dot",
		duration = 3,
		interval = 0.75,
		damageRatio = 0.08,
		color = Color3.fromRGB(255, 140, 40),
	},
	Bleed = {
		id = "Bleed",
		name = "Bleed",
		age = 4,
		kind = "dot",
		duration = 4,
		interval = 1.0,
		damageRatio = 0.05,
		color = Color3.fromRGB(200, 40, 40),
	},
	ArmorMelt = {
		id = "ArmorMelt",
		name = "Armor Melt",
		age = 5,
		kind = "amp",
		duration = 5,
		interval = nil,
		damageRatio = 0.30,
		color = Color3.fromRGB(80, 220, 235),
	},
}

StatusEffects.EFFECTS = EFFECTS
-- Lookup by effect id (EFFECTS is already keyed by id)
StatusEffects.byId = EFFECTS

-- Quick lookup: age number -> effect for that age (nil if no effect)
StatusEffects.byAge = {
	[1] = EFFECTS.Burning,
	[2] = nil, -- no status effect in age 2
	[3] = nil, -- no status effect in age 3
	[4] = EFFECTS.Bleed,
	[5] = EFFECTS.ArmorMelt,
} :: { [number]: StatusEffectDef? }

return StatusEffects
