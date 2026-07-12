--!strict
-- Side B opponent: evolves, spawns units, builds turrets, casts specials.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Units = require(ReplicatedStorage.Shared.Config.Units)
local Turrets = require(ReplicatedStorage.Shared.Config.Turrets)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)
local TurretSystem = require(script.Parent.TurretSystem)
local SpecialSystem = require(script.Parent.SpecialSystem)

local AIBrain = {}

local SIDE = "B"
local rng = Random.new()

-- weights for unit picks
local ROLE_WEIGHTS = { { role = "melee", w = 0.45 }, { role = "ranged", w = 0.35 }, { role = "heavy", w = 0.2 } }

local function pickUnit(age: number, gold: number): string?
	-- try up to 4 weighted rolls for an affordable unit
	for _ = 1, 4 do
		local roll = rng:NextNumber()
		local acc = 0
		for _, entry in ROLE_WEIGHTS do
			acc += entry.w
			if roll <= acc then
				-- prefer current age, sometimes previous age chaff when poor
				local def = Units.byId[`age{age}_{entry.role}`]
				if def and gold >= def.cost then
					return def.id
				end
				break
			end
		end
	end
	-- fallback: cheapest current-age unit
	local cheap = Units.byId[`age{age}_melee`]
	if cheap and gold >= cheap.cost then
		return cheap.id
	end
	return nil
end

-- Decision tick; call every ~2 seconds.
function AIBrain.tick(match: Match.Match)
	if match.status ~= "Active" then
		return
	end
	local s = match.sides[SIDE]

	-- 1) evolve as soon as possible
	if Match.canEvolve(match, SIDE) then
		Match.tryEvolve(match, SIDE)
	end

	-- 2) special when the player's army is threatening
	local enemyUnits = #match.sides[Match.enemyOf(SIDE)].units
	if enemyUnits >= 6 and os.clock() >= s.specialReadyAt then
		SpecialSystem.tryCast(match, SIDE)
	end

	-- 3) turret when rich: keep a reserve of ~1.5x turret cost
	local turretDef = Turrets[s.age]
	local emptySlot: number? = nil
	for i = 1, GameConfig.TURRET_SLOTS do
		if s.turrets[i] == nil then
			emptySlot = i
			break
		end
	end
	if emptySlot and s.gold > turretDef.cost * 2.5 then
		TurretSystem.tryBuild(match, SIDE, emptySlot)
	end

	-- 4) spend the rest on units (leave small buffer)
	local safety = 0
	while s.gold > 30 and #s.queue < GameConfig.QUEUE_CAP and safety < 5 do
		safety += 1
		local unitId = pickUnit(s.age, s.gold)
		if not unitId then
			break
		end
		if not UnitSim.requestSpawn(match, SIDE, unitId) then
			break
		end
	end
end

return AIBrain
