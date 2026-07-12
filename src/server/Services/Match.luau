--!strict
-- Match state container: side state, economy, evolution, win condition.
-- Systems (UnitSim, TurretSystem, ...) operate on this state.
-- Supports difficulty scaling (Normal/Harder/Impossible) and status effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Units = require(ReplicatedStorage.Shared.Config.Units)

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
}

export type Match = {
	map: MapBuilder.MapHandle,
	sides: { [string]: SideState },
	status: "Active" | "Ended",
	startedAt: number,
	winner: string?,
	playerSide: string,
	difficulty: string, -- "Normal" | "Harder" | "Impossible"
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
	}
end

function Match.new(map: MapBuilder.MapHandle, difficulty: string?): Match
	return {
		map = map,
		sides = { A = newSide("A"), B = newSide("B") },
		status = "Active" :: "Active",
		startedAt = os.clock(),
		winner = nil,
		playerSide = "A",
		difficulty = difficulty or "Normal",
		projectiles = {},
		onAgeUp = nil,
		onBaseDamaged = nil,
		onEnd = nil,
	}
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
	
	local newColor = Ages[s.age].color
	-- Visually evolve the base
	MapBuilder.evolveBase(match.map, side, s.age, newColor)
	
	-- Remount existing turrets onto the new structures
	local TurretSystem = require(script.Parent.TurretSystem)
	TurretSystem.remountTurrets(match, side)
	
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
	local hp = math.max(0, (core:GetAttribute("Hp") :: number) - amount)
	core:SetAttribute("Hp", hp)
	-- Small XP drip for hitting the base (no gold, prevents farming)
	match.sides[killerSide].xp += math.floor(amount * 0.05)
	if match.onBaseDamaged then
		match.onBaseDamaged(side, amount)
	end
	if hp <= 0 then
		match.status = "Ended"
		match.winner = Match.enemyOf(side)
		if match.onEnd then
			match.onEnd(match.winner :: string)
		end
	end
end


function Match.buildSnapshot(match: Match): { [string]: any }
	local s = match.sides[match.playerSide]
	local enemy = match.sides[Match.enemyOf(match.playerSide)]
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
		canEvolve = Match.canEvolve(match, match.playerSide),
		baseHpSelf = match.map.bases[match.playerSide].core:GetAttribute("Hp"),
		baseHpEnemy = match.map.bases[Match.enemyOf(match.playerSide)].core:GetAttribute("Hp"),
		baseMaxHp = GameConfig.BASE_MAX_HP,
		specialCd = math.max(0, s.specialReadyAt - os.clock()),
		enemyAge = enemy.age,
		unitCount = #s.units,
		queueCount = #s.queue,
		turrets = turretInfo,
		status = match.status,
		difficulty = match.difficulty,
		heroUpgrades = s.heroUpgrades,
	}
end

return Match
