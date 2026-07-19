--!strict
-- Configuration for the PvE Levels mode.

local PvELevels = {}

-- The campaign is endless: levels keep scaling forever. There is no cap.

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

PvELevels.MODES = { "Normal", "Hard", "Impossible" }

local MODE_DEFS = {
	Normal = { statMult = 1.0, coinMult = 1.0, aiPressureMult = 1.0, forceCounterSpawn = false },
	Hard = { statMult = 1.5, coinMult = 1.5, aiPressureMult = 1.25, forceCounterSpawn = false },
	Impossible = { statMult = 2.5, coinMult = 2.5, aiPressureMult = 1.5, forceCounterSpawn = true },
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

function PvELevels.difficultyForLevel(mode: string, level: number): DifficultyDef
	local modeDef = MODE_DEFS[mode] or MODE_DEFS.Normal
	level = math.max(math.floor(level), 1)
	local t = math.clamp((level - 1) / 19, 0, 1) -- 1..20
	
	local function lerp(a: number, b: number, t: number)
		return a + (b - a) * t
	end

	-- Readable milestone curve: early stages teach upgrades quickly, midgame
	-- grows steadily, and endless levels shift pressure toward smarter/faster AI
	-- instead of turning every enemy into an opaque exponential health wall.
	local earlySteps = math.min(level - 1, 9)
	local midSteps = math.clamp(level - 10, 0, 20)
	local endlessSteps = math.max(level - 30, 0)
	local baseHpMult = math.min(1 + earlySteps * 0.10 + midSteps * 0.06 + endlessSteps * 0.025, 6)
	local baseDamageMult = math.min(1 + earlySteps * 0.08 + midSteps * 0.045 + endlessSteps * 0.018, 4.5)

	return {
		hpMult = baseHpMult * modeDef.statMult,
		damageMult = baseDamageMult * modeDef.statMult,
		aiTickRate = math.max(0.35, lerp(NORMAL.aiTickRate, IMPOSSIBLE.aiTickRate, t) / modeDef.aiPressureMult),
		aiSpecialThreshold = math.max(2, math.floor(lerp(NORMAL.aiSpecialThreshold, IMPOSSIBLE.aiSpecialThreshold, t))),
		aiSpawnInterval = math.max(1.2, lerp(NORMAL.aiSpawnInterval, IMPOSSIBLE.aiSpawnInterval, t) / modeDef.aiPressureMult),
		aiEvolveInterval = lerp(NORMAL.aiEvolveInterval, IMPOSSIBLE.aiEvolveInterval, t) / modeDef.aiPressureMult,
		aiTurretInterval = lerp(NORMAL.aiTurretInterval, IMPOSSIBLE.aiTurretInterval, t) / modeDef.aiPressureMult,
		aiCounterSpawn = (level >= 6) or modeDef.forceCounterSpawn,
		-- Economy/production pressure keeps growing past level 20 alongside stats.
		aiIncomeMult = math.min(1.04 ^ (level - 1), 8) * modeDef.aiPressureMult,
		aiTrainSpeedMult = math.min(1 + 0.04 * (level - 1), 2.5) * modeDef.aiPressureMult,
	}
end

function PvELevels.recommendedPower(level: number): { totalUpgradeTiers: number, guidance: string }
	level = math.max(math.floor(level), 1)
	local tiers = math.clamp(math.floor((level - 1) / 2), 0, 28)
	local guidance = if tiers == 0 then "No permanent upgrades required"
		elseif tiers < 6 then "Invest in HP or Damage"
		elseif tiers < 16 then "Balance HP, Damage, and Starting Gold"
		else "Near-max upgrades; counter-units and turret timing matter most"
	return { totalUpgradeTiers = tiers, guidance = guidance }
end

function PvELevels.stagePreview(mode: string, level: number): {
	hpMult: number,
	damageMult: number,
	incomeMult: number,
	trainSpeedMult: number,
	recommendedTiers: number,
	guidance: string,
}
	local diff = PvELevels.difficultyForLevel(mode, level)
	local recommendation = PvELevels.recommendedPower(level)
	return {
		hpMult = diff.hpMult,
		damageMult = diff.damageMult,
		incomeMult = diff.aiIncomeMult,
		trainSpeedMult = diff.aiTrainSpeedMult,
		recommendedTiers = recommendation.totalUpgradeTiers,
		guidance = recommendation.guidance,
	}
end

function PvELevels.isBossLevel(level: number): boolean
	return level > 0 and level % 5 == 0
end

function PvELevels.coinsForClear(mode: string, level: number, isReplay: boolean): number
	local modeDef = MODE_DEFS[mode] or MODE_DEFS.Normal
	local coins = 50 + 25 * level
	if PvELevels.isBossLevel(level) then
		coins *= 2
	end
	if isReplay then
		coins *= 0.25
	end
	return math.floor(coins * modeDef.coinMult)
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
function PvELevels.getBossConfig(mode: string, level: number)
	local tier = math.clamp(math.ceil(level / 5), 1, 5)
	local bosses = {
		{ unitId = "age1_heavy", hpScale = 5, damageScale = 1.0 },
		{ unitId = "age2_heavy", hpScale = 5, damageScale = 1.0 },
		{ unitId = "age3_heavy", hpScale = 4.5, damageScale = 1.0 },
		{ unitId = "age4_heavy", hpScale = 4.5, damageScale = 1.0 },
		{ unitId = "age5_super_heavy", hpScale = 4, damageScale = 1.1 },
	}
	local boss = bosses[tier]
	local diff = PvELevels.difficultyForLevel(mode, level)
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
