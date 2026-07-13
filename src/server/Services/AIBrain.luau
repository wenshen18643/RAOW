--!strict
-- Side B AI opponent: timer-driven but constrained by the same economy as the player.
-- Evolving, spawning, and building turrets are driven by pacing timers set in DifficultyConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Units = require(ReplicatedStorage.Shared.Config.Units)
local Turrets = require(ReplicatedStorage.Shared.Config.Turrets)
local DifficultyConfig = require(ReplicatedStorage.Shared.Config.DifficultyConfig)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)
local TurretSystem = require(script.Parent.TurretSystem)
local SpecialSystem = require(script.Parent.SpecialSystem)

local AIBrain = {}

local SIDE = "B"
local rng = Random.new()

local aiState = setmetatable({}, { __mode = "k" })

local ROLE_WEIGHTS = {
	{ role = "melee", w = 0.45 },
	{ role = "ranged", w = 0.35 },
	{ role = "heavy", w = 0.18 },
	{ role = "super_heavy", w = 0.02 },
}

local COUNTER_ROLE: { [string]: string } = {
	melee = "ranged",
	ranged = "heavy",
	heavy = "melee",
	super_heavy = "super_heavy", -- no clean counter, meet force with force
}

local function getDominantPlayerRole(match: Match.Match): string?
	local playerSide = Match.enemyOf(SIDE)
	local playerUnits = match.sides[playerSide].units

	if #playerUnits == 0 then
		return nil
	end

	local counts: { [string]: number } = { melee = 0, ranged = 0, heavy = 0, super_heavy = 0 }
	for _, unit in playerUnits do
		if not unit.dead then
			local role = unit.def.role
			counts[role] = (counts[role] or 0) + 1
		end
	end

	local bestRole: string? = nil
	local bestCount = 0
	for role, count in counts do
		if count > bestCount then
			bestCount = count
			bestRole = role
		end
	end

	return bestRole
end

local function pickUnit(age: number, preferredRole: string?): string?
	if preferredRole then
		local def = Units.byId[`age{age}_{preferredRole}`]
		if def then
			return def.id
		end
	end

	local roll = rng:NextNumber()
	local acc = 0
	for _, entry in ROLE_WEIGHTS do
		acc += entry.w
		if roll <= acc then
			local def = Units.byId[`age{age}_{entry.role}`]
			if def then
				return def.id
			end
			break
		end
	end

	local cheap = Units.byId[`age{age}_melee`]
	if cheap then
		return cheap.id
	end
	return nil
end

local function rebuildTurretsForNewAge(match: Match.Match)
	local s = match.sides[SIDE]
	for slot = 1, GameConfig.TURRET_SLOTS do
		local turret = s.turrets[slot]
		if turret and turret.def.age < s.age then
			TurretSystem.trySell(match, SIDE, slot)
			TurretSystem.tryBuild(match, SIDE, slot, false)
		end
	end
end

function AIBrain.tick(match: Match.Match)
	if match.status ~= "Active" then
		return
	end

	local diffConfig = DifficultyConfig.LEVELS[match.difficulty] or DifficultyConfig.LEVELS[DifficultyConfig.DEFAULT]
	local s = match.sides[SIDE]
	local now = os.clock()

	local state = aiState[match]
	if not state then
		state = {
			nextSpawnAt = now + 1,
			nextEvolveAt = now + diffConfig.aiEvolveInterval,
			nextTurretAt = now + diffConfig.aiTurretInterval,
			counterSpawns = 0,
			counterRole = nil,
		}
		aiState[match] = state
	end

	-- 1. EVOLVE
	-- Rubberbanding Tracking System
	local playerAge = match.sides[Match.enemyOf(SIDE)].age
	if playerAge > s.age then
		if not state.rubberbandEvolveAt then
			state.rubberbandEvolveAt = now + rng:NextNumber(30, 60)
		end
	else
		state.rubberbandEvolveAt = nil
	end

	-- Try standard XP evolution first (in case the AI is actually killing tons of units)
	if Match.canEvolve(match, SIDE) then
		Match.tryEvolve(match, SIDE, false)
		state.nextEvolveAt = now + diffConfig.aiEvolveInterval
		if diffConfig.aiCounterSpawn then
			rebuildTurretsForNewAge(match)
		end
	-- If pacing falls behind, the AI still has to earn the required XP.
	elseif now >= state.nextEvolveAt or (state.rubberbandEvolveAt and now >= state.rubberbandEvolveAt) then
		if Match.tryEvolve(match, SIDE, false) then
			state.nextEvolveAt = now + diffConfig.aiEvolveInterval
			state.rubberbandEvolveAt = nil
			if diffConfig.aiCounterSpawn then
				rebuildTurretsForNewAge(match)
			end
		end
	end

	-- 2. SPECIAL ABILITY
	if os.clock() >= s.specialReadyAt then
		local enemyUnits = #match.sides[Match.enemyOf(SIDE)].units
		local shouldCast = enemyUnits >= diffConfig.aiSpecialThreshold

		if diffConfig.aiCounterSpawn and not shouldCast then
			local baseHp = match.map.bases[SIDE].core:GetAttribute("Hp") :: number
			if baseHp < (GameConfig.BASE_MAX_HP * 0.7) then
				shouldCast = true
			end
		end

		if shouldCast then
			SpecialSystem.tryCast(match, SIDE)
		end
	end

	-- 3. TURRETS
	if now >= state.nextTurretAt then
		local emptySlot: number? = nil
		for i = 1, GameConfig.TURRET_SLOTS do
			if s.turrets[i] == nil then
				emptySlot = i
				break
			end
		end

		if emptySlot then
			if TurretSystem.tryBuild(match, SIDE, emptySlot, false) then
				state.nextTurretAt = now + diffConfig.aiTurretInterval
			end
		end
	end

	-- 4. SPAWN UNITS
	if now >= state.nextSpawnAt then
		if #s.queue < GameConfig.QUEUE_CAP then
			local unitId: string?

			if diffConfig.aiCounterSpawn and state.counterSpawns <= 0 then
				local dominant = getDominantPlayerRole(match)
				if dominant then
					state.counterRole = COUNTER_ROLE[dominant]
					state.counterSpawns = rng:NextInteger(2, 3)
				end
			end

			if state.counterSpawns > 0 and state.counterRole then
				unitId = pickUnit(s.age, state.counterRole)
				state.counterSpawns -= 1
			else
				unitId = pickUnit(s.age, nil)
			end

			-- If the chosen unit is unaffordable, fall back to the priciest one we can pay for,
			-- so an expensive counter pick never stalls spawning entirely.
			if unitId and Units.byId[unitId].cost > s.gold then
				local best: string? = nil
				local bestCost = -1
				for _, def in Units.byAge[s.age] do
					if def.cost <= s.gold and def.cost > bestCost then
						best = def.id
						bestCost = def.cost
					end
				end
				unitId = best
			end

			if unitId then
				if UnitSim.requestSpawn(match, SIDE, unitId, false) then
					state.nextSpawnAt = now + diffConfig.aiSpawnInterval
				end
			end
		end
	end
end

return AIBrain
