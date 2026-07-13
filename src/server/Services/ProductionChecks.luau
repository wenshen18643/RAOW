--!strict
-- Fast deterministic invariants. These fail server startup when a configuration
-- change would break progression, economy, or mutually-exclusive army paths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Units = require(ReplicatedStorage.Shared.Config.Units)
local Turrets = require(ReplicatedStorage.Shared.Config.Turrets)
local Specials = require(ReplicatedStorage.Shared.Config.Specials)
local HeroWeapons = require(ReplicatedStorage.Shared.Config.HeroWeapons)
local Synergies = require(ReplicatedStorage.Shared.Config.Synergies)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ProductionChecks = {}

local function check(value: boolean, message: string)
	if not value then error(`[ProductionChecks] {message}`, 2) end
end

function ProductionChecks.run()
	check(#Ages == 5, "PvP progression must contain exactly five ages")
	check(#GameConfig.PASSIVE_INCOME_BY_AGE == #Ages, "income table must cover every age")
	check(#GameConfig.BASE_HP_MULT_BY_AGE == #Ages, "base HP table must cover every age")
	for age = 1, #Ages do
		check(Ages[age].id == age, `age index mismatch at {age}`)
		if age > 1 then check(Ages[age].xpRequired > Ages[age - 1].xpRequired, "XP thresholds must increase") end
		check(#Units.byAge[age] >= 3, `age {age} needs melee, ranged, and heavy units`)
		check(Turrets[age] ~= nil and Specials[age] ~= nil and HeroWeapons[age] ~= nil, `age {age} unlock set is incomplete`)
		for _, unit in Units.byAge[age] do
			check(unit.cost > 0 and unit.hp > 0 and unit.damage > 0, `{unit.id} has non-positive combat stats`)
			check(unit.attackSpeed >= 0.15 and unit.moveSpeed > 0 and unit.moveSpeed <= 30, `{unit.id} has unsafe timing or speed`)
		end
	end

	local combinedRequirements: { [string]: number } = {}
	for _, doctrine in Synergies.list do
		local requiredCount = 0
		for role, count in doctrine.requirements do
			requiredCount += count
			combinedRequirements[role] = math.max(combinedRequirements[role] or 0, count)
		end
		check(requiredCount <= GameConfig.UNIT_CAP, `{doctrine.id} cannot fit under the unit cap`)
		for _, buff in doctrine.roleBuffs do
			check((buff.damage or 0) <= 0.20 and (buff.health or 0) <= 0.20 and (buff.speed or 0) <= 0.20,
				`{doctrine.id} exceeds the 20% PvP synergy ceiling`)
		end
	end
	local allPathsOpeningCost = 0
	for role, count in combinedRequirements do
		local unit = Units.byId[`age1_{role}`]
		check(unit ~= nil, `opening doctrine role {role} has no age-one unit`)
		allPathsOpeningCost += unit.cost * count
	end
	check(allPathsOpeningCost > GameConfig.STARTING_GOLD, "starting gold can purchase every doctrine requirement")
	check(GameConfig.UNIT_CAP <= 25 and GameConfig.QUEUE_CAP <= 15, "PvP caps exceed the profiled production envelope")
	print(`[ProductionChecks] passed; all opening paths require {allPathsOpeningCost}g vs {GameConfig.STARTING_GOLD}g starting gold`)
end

return ProductionChecks
