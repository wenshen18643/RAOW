--!strict
-- Match state container: side state, economy, evolution, win condition.
-- Systems (UnitSim, TurretSystem, ...) operate on this state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)

local MapBuilder = require(script.Parent.MapBuilder)

export type UnitRecord = {
	model: Model,
	body: BasePart,
	def: any, -- Units.UnitDef
	hp: number,
	side: string,
	nextAttackAt: number,
	dead: boolean,
}

export type TurretRecord = {
	def: any, -- Turrets.TurretDef
	model: Model,
	muzzle: BasePart,
	nextFireAt: number,
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
}

export type Match = {
	map: MapBuilder.MapHandle,
	sides: { [string]: SideState },
	status: "Active" | "Ended",
	startedAt: number,
	winner: string?,
	playerSide: string,
	-- callbacks wired by init
	onAgeUp: (side: string, newAge: number) -> ()?,
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
	}
end

function Match.new(map: MapBuilder.MapHandle): Match
	return {
		map = map,
		sides = { A = newSide("A"), B = newSide("B") },
		status = "Active" :: "Active",
		startedAt = os.clock(),
		winner = nil,
		playerSide = "A",
		onAgeUp = nil,
		onEnd = nil,
	}
end

function Match.enemyOf(side: string): string
	return side == "A" and "B" or "A"
end

-- Gold + XP reward for a kill. Hero kills give a bonus.
function Match.award(match: Match, side: string, amount: number, isHeroKill: boolean?)
	if match.status ~= "Active" then
		return
	end
	local mult = isHeroKill and GameConfig.HERO_KILL_BONUS_MULT or 1
	local s = match.sides[side]
	s.gold += math.floor(amount * mult)
	s.xp += math.floor(amount * mult)
end

function Match.canEvolve(match: Match, side: string): boolean
	local s = match.sides[side]
	local nextAge = Ages[s.age + 1]
	return nextAge ~= nil and s.xp >= nextAge.xpRequired
end

function Match.tryEvolve(match: Match, side: string): boolean
	if match.status ~= "Active" or not Match.canEvolve(match, side) then
		return false
	end
	local s = match.sides[side]
	s.age += 1
	-- Recolor base to new age color
	local base = match.map.bases[side]
	base.core.Color = Ages[s.age].color
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
	if hp <= 0 then
		match.status = "Ended"
		match.winner = Match.enemyOf(side)
		if match.onEnd then
			match.onEnd(match.winner :: string)
		end
	end
end

-- Passive income tick; call once per second.
function Match.incomeTick(match: Match)
	if match.status ~= "Active" then
		return
	end
	local elapsed = os.clock() - match.startedAt
	local income = GameConfig.PASSIVE_GOLD_PER_SEC
	if elapsed > GameConfig.SURGE_TIME then
		income *= GameConfig.SURGE_MULT
	end
	for _, s in match.sides do
		s.gold += income
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
	}
end

return Match
