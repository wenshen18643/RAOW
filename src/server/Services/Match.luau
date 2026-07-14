--!strict
-- Match state container: side state, economy, evolution, win condition.
-- Systems (UnitSim, TurretSystem, ...) operate on this state.
-- Supports difficulty scaling (Normal/Harder/Impossible) and status effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Units = require(ReplicatedStorage.Shared.Config.Units)
local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)

local MapBuilder = require(script.Parent.MapBuilder)

export type UnitRecord = {
	model: Model,
	body: BasePart,
	def: any, -- Units.UnitDef
	hp: number,
	maxHp: number, -- original max HP (for HP bar calculations)
	scaledDamage: number, -- actual damage after difficulty scaling
	side: string,
	nextAttackAt: number,
	dead: boolean,
	-- attack animation (lunge) state
	attackStartedAt: number?,
	animBasePos: Vector3?,
	-- status effects (Phase 4)
	damageAmp: number, -- extra damage taken multiplier from ArmorMelt (0 = none)
	moveSpeedMult: number,
	synergyApplied: boolean,
	laneOffset: number,
	moveHeading: Vector3,
	walkStart: number?, -- timestamp when unit started walking (for walk bob anim)
}

export type TurretRecord = {
	def: any, -- Turrets.TurretDef
	model: Model,
	muzzle: BasePart,
	nextFireAt: number,
}

export type ProjectileRecord = {
	id: string,
	pos: Vector3,
	dir: Vector3,
	speed: number,
	damage: number,
	side: string,
	age: number,
	target: any?,
	distanceTraveled: number,
	maxDistance: number,
}

export type SideState = {
	side: string,
	gold: number,
	xp: number,
	age: number,
	heroDeaths: number,
	specialReadyAt: number,
	lastSpawnAt: number,
	queue: { string }, -- unitIds waiting to spawn
	units: { UnitRecord },
	turrets: { [number]: TurretRecord? },
	heroUpgrades: { dmg: number, health: number, def: number },
	pveUpgrades: { unitHp: number, unitDamage: number, startingGold: number }?,
	pvePerks: { string }?,
	incomeCarry: number,
	lastEconomyAt: number,
	doctrine: string?,
}

export type Match = {
	map: MapBuilder.MapHandle,
	sides: { [string]: SideState },
	status: "Waiting" | "Active" | "Ended",
	startedAt: number,
	winner: string?,
	resultCommitted: boolean,
	difficulty: string, -- "Normal" | "Harder" | "Impossible"
	pveLevel: number?, -- Set for PvE-Levels mode
	mode: "PvE" | "PvP" | "PvE-Levels",
	projectiles: { ProjectileRecord },
	-- callbacks wired by init
	onAgeUp: (side: string, newAge: number) -> ()?,
	onBaseDamaged: (side: string, amount: number) -> ()?,
	onEnd: (winner: string) -> ()?,
}

local Match = {}

local function newSide(side: string): SideState
	return {
		side = side,
		gold = GameConfig.STARTING_GOLD,
		xp = 0,
		age = 1,
		heroDeaths = 0,
		specialReadyAt = 0,
		lastSpawnAt = 0,
		queue = {},
		units = {},
		turrets = {},
		heroUpgrades = { dmg = 0, health = 0, def = 0 },
		incomeCarry = 0,
		lastEconomyAt = os.clock(),
		doctrine = nil,
	}
end

function Match.getBaseMaxHp(match: Match, side: string): number
	local age = match.sides[side].age
	return GameConfig.BASE_MAX_HP * GameConfig.BASE_HP_MULT_BY_AGE[age]
end

function Match.getIncomeRate(match: Match, side: string): number
	local s = match.sides[side]
	local enemySide = Match.enemyOf(side)
	local enemyMax = Match.getBaseMaxHp(match, enemySide)
	local selfMax = Match.getBaseMaxHp(match, side)
	local selfRatio = (match.map.bases[side].core:GetAttribute("Hp") :: number) / selfMax
	local enemyRatio = (match.map.bases[enemySide].core:GetAttribute("Hp") :: number) / enemyMax
	local comeback = math.max(0, enemyRatio - selfRatio) * GameConfig.COMEBACK_INCOME_MAX
	local elapsed = os.clock() - match.startedAt
	local mult = 1
	if elapsed >= GameConfig.SUDDEN_DEATH_START then
		mult = GameConfig.SUDDEN_DEATH_INCOME_MULT
	elseif elapsed >= GameConfig.ESCALATION_START then
		mult = GameConfig.ESCALATION_INCOME_MULT
	end
	local rate = (GameConfig.PASSIVE_INCOME_BY_AGE[s.age] + comeback) * mult
	-- PvE Levels: the AI's gold production scales with the level.
	if match.mode == "PvE-Levels" and side == "B" then
		rate *= PvELevels.difficultyForLevel(match.pveLevel or 1).aiIncomeMult
	end
	return rate
end

function Match.tickEconomy(match: Match, now: number)
	if match.status ~= "Active" then return end
	for side, s in match.sides do
		local dt = math.clamp(now - s.lastEconomyAt, 0, 2)
		s.lastEconomyAt = now
		s.incomeCarry += Match.getIncomeRate(match, side) * dt
		local payout = math.floor(s.incomeCarry)
		if payout > 0 then
			s.gold += payout
			s.incomeCarry -= payout
		end
	end
end

function Match.new(map: MapBuilder.MapHandle, difficulty: string?): Match
	return {
		map = map,
		sides = { A = newSide("A"), B = newSide("B") },
		status = "Waiting" :: "Waiting",
		startedAt = os.clock(),
		winner = nil,
		resultCommitted = false,
		difficulty = difficulty or "Normal",
		pveLevel = nil,
		mode = "PvE" :: any,
		projectiles = {},
		onAgeUp = nil,
		onBaseDamaged = nil,
		onEnd = nil,
	}
end

function Match.start(match: Match): boolean
	if match.status ~= "Waiting" then return false end
	match.status = "Active"
	match.startedAt = os.clock()
	for _, s in match.sides do s.lastEconomyAt = match.startedAt end
	return true
end

function Match.enemyOf(side: string): string
	return side == "A" and "B" or "A"
end

-- Gold + XP reward for general fallback (kept for backward compatibility).
function Match.award(match: Match, side: string, amount: number, isHeroKill: boolean?)
	if match.status ~= "Active" then
		return
	end
	local mult = isHeroKill and GameConfig.HERO_KILL_BONUS_MULT or 1
	local s = match.sides[side]
	s.gold += math.floor(amount * mult)
	s.xp += math.floor(amount * mult)
end

-- Awards gold and XP for a unit kill. Hero kills multiply both by the bonus multiplier.
-- Returns the actual gold awarded.
function Match.awardKill(match: Match, killingSide: string, def: any, isHeroKill: boolean?): number
	if match.status ~= "Active" then
		return 0
	end
	local mult = isHeroKill and GameConfig.HERO_KILL_BONUS_MULT or 1
	local s = match.sides[killingSide]
	
	local goldAward = math.floor(def.killGold * mult)
	local xpAward = math.floor(def.killXp * mult)
	
	s.gold += goldAward
	s.xp += xpAward
	
	return goldAward
end

-- Awards pity XP to the side whose unit died.
function Match.awardPityXp(match: Match, dyingSide: string, def: any)
	if match.status ~= "Active" then
		return
	end
	local s = match.sides[dyingSide]
	s.xp += def.deathXp
end

-- Awards resources for killing the player's hero.
function Match.awardHeroKill(match: Match, killingSide: string, heroAge: number)
	if match.status ~= "Active" then
		return
	end
	local s = match.sides[killingSide]
	
	local meleeDef = Units.byId[`age{heroAge}_melee`]
	if meleeDef then
		local baseCost = meleeDef.cost
		local goldAward = baseCost * 3
		local xpAward = baseCost * 4
		
		s.gold += goldAward
		s.xp += xpAward
		
		print(`[Match] Hero killed! Side {killingSide} awarded {goldAward} Gold, {xpAward} XP`)
	end
end

function Match.canEvolve(match: Match, side: string): boolean
	local s = match.sides[side]
	local nextAge = Ages[s.age + 1]
	return nextAge ~= nil and s.xp >= nextAge.xpRequired
end

function Match.tryEvolve(match: Match, side: string, bypassXp: boolean?): boolean
	if match.status ~= "Active" or (not bypassXp and not Match.canEvolve(match, side)) then
		return false
	end
	local s = match.sides[side]
	s.age += 1
	local core = match.map.bases[side].core
	local oldMax = GameConfig.BASE_MAX_HP * GameConfig.BASE_HP_MULT_BY_AGE[s.age - 1]
	local newMax = Match.getBaseMaxHp(match, side)
	local hpRatio = (core:GetAttribute("Hp") :: number) / oldMax
	core:SetAttribute("Hp", math.max(1, math.floor(newMax * hpRatio)))
	
	local newColor = Ages[s.age].color
	-- Visually evolve the base
	MapBuilder.evolveBase(match.map, side, s.age, newColor)
	
	-- Remount existing turrets onto the new structures
	local TurretSystem = require(script.Parent.TurretSystem)
	TurretSystem.remountTurrets(match, side)
	
	if (match.mode == "PvE" or match.mode == "PvE-Levels") and side == "B" then
		local mDef = Units.byId[`age{s.age}_melee`]
		local rDef = Units.byId[`age{s.age}_ranged`]
		if mDef and rDef then
			s.gold += 2 * (mDef.cost + rDef.cost)
		end
	end

	if match.onAgeUp then
		match.onAgeUp(side, s.age)
	end
	return true
end

function Match.damageBase(match: Match, side: string, amount: number, killerSide: string, isHeroKill: boolean?)
	if match.status ~= "Active" then
		return
	end
	local core = match.map.bases[side].core
	local scaledAmount = amount * GameConfig.BASE_DAMAGE_MULT
	local hp = math.max(0, (core:GetAttribute("Hp") :: number) - scaledAmount)
	core:SetAttribute("Hp", hp)
	-- Small XP drip for hitting the base (no gold, prevents farming)
	match.sides[killerSide].xp += math.floor(scaledAmount * 0.05)
	if match.onBaseDamaged then
		match.onBaseDamaged(side, scaledAmount)
	end
	if hp <= 0 then
		match.status = "Ended"
		match.winner = Match.enemyOf(side)
		if match.onEnd then
			match.onEnd(match.winner :: string)
		end
	end
end


function Match.buildSnapshot(match: Match, playerSide: string): { [string]: any }
	local s = match.sides[playerSide]
	local enemySide = Match.enemyOf(playerSide)
	local enemy = match.sides[enemySide]
	local nextAge = Ages[s.age + 1]
	local turretInfo = {}
	for i = 1, GameConfig.TURRET_SLOTS do
		local t = s.turrets[i]
		turretInfo[i] = t ~= nil and t.def.name or false
	end
	return {
		gold = s.gold,
		xp = s.xp,
		age = s.age,
		ageName = Ages[s.age].name,
		nextAgeXp = nextAge and nextAge.xpRequired or nil,
		canEvolve = Match.canEvolve(match, playerSide),
		baseHpSelf = match.map.bases[playerSide].core:GetAttribute("Hp"),
		baseHpEnemy = match.map.bases[enemySide].core:GetAttribute("Hp"),
		baseMaxHpSelf = Match.getBaseMaxHp(match, playerSide),
		baseMaxHpEnemy = Match.getBaseMaxHp(match, enemySide),
		incomeRate = Match.getIncomeRate(match, playerSide),
		specialCd = math.max(0, s.specialReadyAt - os.clock()),
		enemyAge = enemy.age,
		unitCount = #s.units,
		queueCount = #s.queue,
		unitCap = GameConfig.UNIT_CAP,
		queueCap = GameConfig.QUEUE_CAP,
		turrets = turretInfo,
		status = match.status,
		difficulty = match.difficulty,
		pveLevel = match.pveLevel,
		mode = match.mode,
		heroUpgrades = s.heroUpgrades,
		pveUpgrades = s.pveUpgrades,
		pvePerks = s.pvePerks,
		doctrine = s.doctrine,
		playerSide = playerSide,
	}
end

return Match
