--!strict
-- Configuration for the PvE Levels mode.

local PvELevels = {}

PvELevels.MAX_LEVEL = 25

export type DifficultyDef = {
	hpMult: number,
	damageMult: number,
	aiTickRate: number,
	aiSpecialThreshold: number,
	aiSpawnInterval: number,
	aiEvolveInterval: number,
	aiTurretInterval: number,
	aiCounterSpawn: boolean,
	aiIncomeMult: number, -- multiplies the AI side's passive gold income
	aiTrainSpeedMult: number, -- divides the AI side's unit train times
}

-- Level-1 baseline: a touch hotter than the classic Normal preset.
local NORMAL = {
	hpMult = 1.0,
	damageMult = 1.0,
	aiTickRate = 0.9,
	aiSpecialThreshold = 5,
	aiSpawnInterval = 4.0,
	aiEvolveInterval = 170,
	aiTurretInterval = 55,
	aiCounterSpawn = false,
}

local IMPOSSIBLE = {
	hpMult = 2.0,
	damageMult = 2.0,
	aiTickRate = 0.5,
	aiSpecialThreshold = 2,
	aiSpawnInterval = 2.0,
	aiEvolveInterval = 90,
	aiTurretInterval = 25,
	aiCounterSpawn = true,
}

function PvELevels.difficultyForLevel(level: number): DifficultyDef
	level = math.clamp(math.floor(level), 1, PvELevels.MAX_LEVEL)
	local t = math.clamp((level - 1) / 19, 0, 1) -- 1..20
	
	local function lerp(a: number, b: number, t: number)
		return a + (b - a) * t
	end

	return {
		hpMult = level <= 10 and (1 + 0.1 * (level - 1)) or (1.9 * 1.08 ^ (level - 10)),
		damageMult = level <= 10 and (1 + 0.1 * (level - 1)) or (1.9 * 1.08 ^ (level - 10)),
		aiTickRate = lerp(NORMAL.aiTickRate, IMPOSSIBLE.aiTickRate, t),
		aiSpecialThreshold = math.floor(lerp(NORMAL.aiSpecialThreshold, IMPOSSIBLE.aiSpecialThreshold, t)),
		aiSpawnInterval = lerp(NORMAL.aiSpawnInterval, IMPOSSIBLE.aiSpawnInterval, t),
		aiEvolveInterval = lerp(NORMAL.aiEvolveInterval, IMPOSSIBLE.aiEvolveInterval, t),
		aiTurretInterval = lerp(NORMAL.aiTurretInterval, IMPOSSIBLE.aiTurretInterval, t),
		aiCounterSpawn = level >= 6,
		-- Economy/production pressure keeps growing past level 20 alongside stats.
		aiIncomeMult = math.min(1.04 ^ (level - 1), 8),
		aiTrainSpeedMult = math.min(1 + 0.04 * (level - 1), 2.5),
	}
end

function PvELevels.isBossLevel(level: number): boolean
	return level > 0 and level % 5 == 0
end

function PvELevels.isFinalLevel(level: number): boolean
	return level == PvELevels.MAX_LEVEL
end

function PvELevels.coinsForClear(level: number, isReplay: boolean): number
	local coins = 50 + 25 * level
	if PvELevels.isBossLevel(level) then
		coins *= 2
	end
	if isReplay then
		coins *= 0.25
	end
	return math.floor(coins)
end

PvELevels.PVP_WIN_COINS = 100
PvELevels.PVP_LOSS_COINS = 25

PvELevels.UPGRADE_TRACKS = {
	unitHp = { name = "Unit HP (+2%/tier)", maxTier = 10 },
	unitDamage = { name = "Unit Damage (+2%/tier)", maxTier = 10 },
	startingGold = { name = "Starting Gold (+15)", maxTier = 8 },
} :: { [string]: { name: string, maxTier: number } }

function PvELevels.upgradeCost(tier: number): number
	return math.floor(100 * 1.35 ^ (tier - 1))
end

PvELevels.PERKS = {
	headStart = { name = "Head Start (Age 2, PvE only)", cost = 2000 },
	freeTurret = { name = "Free First Turret (PvE only)", cost = 1500 },
} :: { [string]: { name: string, cost: number } }

-- Boss configuration
function PvELevels.getBossConfig(level: number)
	local tier = math.clamp(math.ceil(level / 5), 1, 5)
	local bosses = {
		{ unitId = "age1_heavy", hpScale = 5, damageScale = 1.0 },
		{ unitId = "age2_heavy", hpScale = 5, damageScale = 1.0 },
		{ unitId = "age3_heavy", hpScale = 4.5, damageScale = 1.0 },
		{ unitId = "age4_heavy", hpScale = 4.5, damageScale = 1.0 },
		{ unitId = "age5_super_heavy", hpScale = 4, damageScale = 1.1 },
	}
	local boss = bosses[tier]
	local diff = PvELevels.difficultyForLevel(level)
	return {
		unitId = boss.unitId,
		modelScale = tier == 5 and 1.75 or 1.6,
		hpMult = diff.hpMult * boss.hpScale,
		damageMult = diff.damageMult * boss.damageScale,
		slamCooldown = 12,
		slamRadius = 15,
		slamDamageMult = 1.2,
		slamMaxUnitHpRatio = 0.6,
		slamMaxHeroHpRatio = 0.45,
		slamTelegraphDuration = 0.9,
		slamStunDuration = 1.25,
	}
end

return PvELevels
