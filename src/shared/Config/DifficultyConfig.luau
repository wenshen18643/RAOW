--!strict
-- Difficulty presets that scale enemy stats and tune AI aggressiveness.

local DifficultyConfig = {}

-- Describes one difficulty preset
export type DifficultyDef = {
	hpMult: number, -- multiplier for enemy unit HP
	damageMult: number, -- multiplier for enemy unit damage
	aiTickRate: number, -- seconds between AI brain ticks
	aiSpecialThreshold: number, -- minimum enemy units before AI uses special ability
	aiSpawnInterval: number, -- time in seconds between each AI unit spawn
	aiEvolveInterval: number, -- pacing interval between fair XP-gated evolution attempts
	aiTurretInterval: number, -- time in seconds between AI turret purchases
	aiCounterSpawn: boolean, -- enables reactive counter-spawning (Hard/Impossible)
}

-- All available difficulty levels keyed by display name
local LEVELS: { [string]: DifficultyDef } = {
	Normal = {
		hpMult = 1.0,
		damageMult = 1.0,
		aiTickRate = 1.0,
		aiSpecialThreshold = 6,
		aiSpawnInterval = 4.5,
		aiEvolveInterval = 180,
		aiTurretInterval = 60,
		aiCounterSpawn = false,
	},
	Harder = {
		hpMult = 1.3,
		damageMult = 1.3,
		aiTickRate = 0.8,
		aiSpecialThreshold = 4,
		aiSpawnInterval = 3.0,
		aiEvolveInterval = 135,
		aiTurretInterval = 40,
		aiCounterSpawn = true,
	},
	Impossible = {
		hpMult = 2.0,
		damageMult = 2.0,
		aiTickRate = 0.5,
		aiSpecialThreshold = 2,
		aiSpawnInterval = 2.0,
		aiEvolveInterval = 90,
		aiTurretInterval = 25,
		aiCounterSpawn = true,
	},
}
DifficultyConfig.LEVELS = LEVELS

-- Fallback difficulty when none is explicitly chosen
DifficultyConfig.DEFAULT = "Normal"

return DifficultyConfig
