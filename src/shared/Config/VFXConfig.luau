--!strict
-- Per-age impact visual effect parameters for combat feedback.

local VFXConfig = {}

-- Describes the visual effects for one age
export type VFXDef = {
	age: number, -- age this definition applies to
	name: string, -- descriptive label
	impactColor: Color3, -- primary impact color
	secondaryColor: Color3, -- secondary particle color
	impactSize: number, -- base size of impact effect in studs
	particleCount: number, -- number of particles to spawn
	trailWidth: number, -- width of tracer trail
	tracerColor: Color3, -- color for ranged unit tracers
}

-- VFX definitions indexed by age number
local AGES: { [number]: VFXDef } = {
	[1] = {
		age = 1,
		name = "Stone Sparks",
		impactColor = Color3.fromRGB(160, 150, 140), -- grey
		secondaryColor = Color3.fromRGB(130, 100, 70), -- brown
		impactSize = 3,
		particleCount = 6,
		trailWidth = 0.3,
		tracerColor = Color3.fromRGB(170, 160, 145), -- warm grey
	},
	[2] = {
		age = 2,
		name = "Bronze Sparks",
		impactColor = Color3.fromRGB(210, 180, 80), -- gold
		secondaryColor = Color3.fromRGB(180, 130, 60), -- bronze
		impactSize = 3.5,
		particleCount = 8,
		trailWidth = 0.35,
		tracerColor = Color3.fromRGB(190, 145, 70), -- bronze
	},
	[3] = {
		age = 3,
		name = "Steel Clash",
		impactColor = Color3.fromRGB(200, 200, 210), -- silver
		secondaryColor = Color3.fromRGB(180, 50, 50), -- red
		impactSize = 4,
		particleCount = 10,
		trailWidth = 0.4,
		tracerColor = Color3.fromRGB(210, 210, 220), -- silver
	},
	[4] = {
		age = 4,
		name = "Bullet Impact",
		impactColor = Color3.fromRGB(255, 160, 40), -- orange
		secondaryColor = Color3.fromRGB(255, 255, 240), -- white
		impactSize = 4.5,
		particleCount = 8,
		trailWidth = 0.2,
		tracerColor = Color3.fromRGB(255, 220, 80), -- yellow
	},
	[5] = {
		age = 5,
		name = "Plasma Burst",
		impactColor = Color3.fromRGB(0, 230, 255), -- cyan
		secondaryColor = Color3.fromRGB(60, 120, 255), -- neon blue
		impactSize = 6,
		particleCount = 12,
		trailWidth = 0.5,
		tracerColor = Color3.fromRGB(0, 240, 255), -- cyan
	},
}
VFXConfig.AGES = AGES

return VFXConfig
