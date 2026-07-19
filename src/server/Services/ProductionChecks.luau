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
local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)
local CampaignStages = require(ReplicatedStorage.Shared.Config.CampaignStages)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)
local MusicConfig = require(ReplicatedStorage.Shared.Config.MusicConfig)

local ProductionChecks = {}

local function check(value: boolean, message: string)
	if not value then error(`[ProductionChecks] {message}`, 2) end
end

function ProductionChecks.run()
	local seenMaps: { [string]: boolean } = {}
	local seenObjectives: { [string]: boolean } = {}
	for level = 1, 20 do
		local stage = CampaignStages.forLevel(level)
		check(#stage.aiFormation > 0 and #stage.aiLanePattern > 0, `PvE stage {level} needs an AI formation`)
		check(stage.aiSpawnIntervalMult > 0 and stage.aiIncomeMult > 0 and stage.enemyBaseHpMult > 0, `PvE stage {level} has an invalid modifier`)
		seenMaps[stage.mapVariant] = true
		seenObjectives[stage.objective.kind] = true
	end
	check(seenMaps.Frontier and seenMaps.Canyon and seenMaps.Ruins and seenMaps.Frost, "PvE campaign must rotate all map variants")
	check(seenObjectives.DestroyBase and seenObjectives.Survive and seenObjectives.DefeatBoss, "PvE campaign must expose all objective types")
	check(#Ages == 5, "PvP progression must contain exactly five ages")
	check(PvELevels.difficultyForLevel("Normal", 100).hpMult > PvELevels.difficultyForLevel("Normal", 50).hpMult, "endless PvE difficulty must keep scaling")
	check(#GameConfig.PASSIVE_INCOME_BY_AGE == #Ages, "income table must cover every age")
	check(#GameConfig.BASE_HP_MULT_BY_AGE == #Ages, "base HP table must cover every age")
	check(GameConfig.ESCALATION_START < GameConfig.SUDDEN_DEATH_START, "match pacing phases are out of order")
	check(GameConfig.SUDDEN_DEATH_START <= 15 * 60, "sudden death starts too late for the target session length")
	check(GameConfig.SUDDEN_DEATH_BASE_DAMAGE_MULT >= GameConfig.ESCALATION_BASE_DAMAGE_MULT, "base pressure must increase over time")
	check(GameConfig.HERO_UPGRADE_MAX_TIER <= 5, "hero upgrades exceed the balance ceiling")
	for age = 1, #Ages do
		check(Ages[age].id == age, `age index mismatch at {age}`)
		if age > 1 then check(Ages[age].xpRequired > Ages[age - 1].xpRequired, "XP thresholds must increase") end
		check(#Units.byAge[age] >= 3, `age {age} needs melee, ranged, and heavy units`)
		check(Turrets[age] ~= nil and Specials[age] ~= nil and HeroWeapons[age] ~= nil, `age {age} unlock set is incomplete`)
		if age > 1 then
			local previousDps = HeroWeapons[age - 1].damage / HeroWeapons[age - 1].fireCooldown
			local currentDps = HeroWeapons[age].damage / HeroWeapons[age].fireCooldown
			check(currentDps >= previousDps, `hero weapon DPS regresses at age {age}`)
		end
		for _, unit in Units.byAge[age] do
			check(unit.cost > 0 and unit.hp > 0 and unit.damage > 0, `{unit.id} has non-positive combat stats`)
			check(unit.attackSpeed >= 0.15 and unit.moveSpeed > 0 and unit.moveSpeed <= 30, `{unit.id} has unsafe timing or speed`)
		end
		local melee = Units.byId[`age{age}_melee`]
		local ranged = Units.byId[`age{age}_ranged`]
		local heavy = Units.byId[`age{age}_heavy`]
		local heavyCostRatio = heavy.cost / melee.cost
		local heavyHpEfficiency = (heavy.hp / heavy.cost) / (melee.hp / melee.cost)
		local heavyDpsEfficiency = ((heavy.damage / heavy.attackSpeed) / heavy.cost) / ((melee.damage / melee.attackSpeed) / melee.cost)
		check(heavyCostRatio >= 3.5 and heavyCostRatio <= 6, `age {age} heavy commitment cost is incoherent`)
		check(heavyHpEfficiency >= 0.8 and heavyHpEfficiency <= 1.25, `age {age} heavy tank value is a trap or dominant`)
		check(heavyDpsEfficiency >= 0.2 and heavyDpsEfficiency <= 0.5, `age {age} heavy damage erases its tradeoff`)
		check(ranged.range >= melee.range * 4 and ranged.hp / ranged.cost < melee.hp / melee.cost,
			`age {age} ranged unit lacks a range-for-durability tradeoff`)
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
	for id, track in PvELevels.UPGRADE_TRACKS do
		check(track.maxTier > 0 and track.maxTier <= 10, `PvE upgrade {id} needs a safe finite cap`)
	end
	local cosmeticIds: { [string]: boolean } = {}
	local themeCount = 0
	local dailyGameplayBonds = MonetizationConfig.DAILY_WAR_BONDS + MonetizationConfig.DAILY_BATTLE_BONDS + MonetizationConfig.DAILY_WIN_BONDS
	check(ProgressionConfig.WAR_BONDS_PER_LEVEL > 0 and ProgressionConfig.WAR_BONDS_PER_LEVEL <= MonetizationConfig.DAILY_WAR_BONDS,
		"level reward must be meaningful without eclipsing daily play")
	check(MonetizationConfig.SUPPORTER_DAILY_BONUS <= MonetizationConfig.DAILY_WAR_BONDS, "supporter daily bonus is disproportionate")
	for _, cosmetic in MonetizationConfig.Cosmetics do
		check(not cosmeticIds[cosmetic.id], `duplicate cosmetic ID {cosmetic.id}`)
		check(cosmetic.cost >= dailyGameplayBonds * 3, `{cosmetic.id} unlocks in fewer than three fully active free days`)
		check(cosmetic.kind == "title" or cosmetic.kind == "theme", `{cosmetic.id} has unsupported cosmetic kind`)
		check(cosmetic.damage == nil and cosmetic.hp == nil and cosmetic.gold == nil and cosmetic.xp == nil,
			`{cosmetic.id} exposes paid gameplay power`)
		if cosmetic.kind == "theme" then
			themeCount += 1
			check(typeof(cosmetic.color) == "Color3", `{cosmetic.id} has no signal color`)
		end
		cosmeticIds[cosmetic.id] = true
	end
	check(themeCount >= 3, "armory needs a meaningful visual theme collection")
	for _, cosmetic in MonetizationConfig.EarnedCosmetics do
		check(not cosmeticIds[cosmetic.id], `duplicate cosmetic ID {cosmetic.id}`)
		check(cosmetic.unlockLevel >= 2 and cosmetic.unlockLevel <= 50, `{cosmetic.id} has invalid level requirement`)
		cosmeticIds[cosmetic.id] = true
	end
	check(not cosmeticIds[MonetizationConfig.SupporterCosmetic.id], "supporter cosmetic ID is duplicated")
	check(MonetizationConfig.SupporterCosmetic.kind == "title", "supporter reward must remain cosmetic")
	cosmeticIds[MonetizationConfig.SupporterCosmetic.id] = true
	local productIds: { [number]: boolean } = {}
	local configuredOffers = MonetizationConfig.SUPPORTER_PASS_ID > 0 and 1 or 0
	for _, product in MonetizationConfig.Products do
		check(product.amount > 0, `{product.id} has no War Bonds grant`)
		if product.productId > 0 then
			check(not productIds[product.productId], `duplicate developer product ID {product.productId}`)
			productIds[product.productId] = true
			configuredOffers += 1
		end
	end
	check(MonetizationConfig.configuredOfferCount() == configuredOffers, "commerce readiness count is inconsistent")
	local super = Units.byId.age5_super_heavy
	local finalHeavy = Units.byId.age5_heavy
	check(super.hp / super.cost <= 1.05 * (finalHeavy.hp / finalHeavy.cost), "super-heavy has dominant health efficiency")
	check((super.damage / super.attackSpeed) / super.cost <= 1.05 * ((finalHeavy.damage / finalHeavy.attackSpeed) / finalHeavy.cost),
		"super-heavy has dominant damage efficiency")
	for soundName, sound in SoundConfig do
		check(sound.volume >= 0 and sound.volume <= 1, `{soundName} volume is outside 0..1`)
		check(sound.group == "SFX" or sound.group == "UI", `{soundName} uses an unsupported or empty sound group`)
		check(string.sub(sound.id, 1, 11) == "rbxasset://", `{soundName} has an invalid sound asset URI`)
	end
	for trackName, track in MusicConfig.Tracks do
		check(track.volume >= 0 and track.volume <= 1, `{trackName} music volume is outside 0..1`)
		check(track.id == "" or string.match(track.id, "^rbxassetid://%d+$") ~= nil,
			`{trackName} must use an approved numeric rbxassetid URI or remain empty`)
	end
	for sceneName, scene in MusicConfig.Scenes do
		for _, trackName in { scene.music, scene.ambience } do
			check(trackName == "" or MusicConfig.Tracks[trackName] ~= nil,
				`{sceneName} references unknown long-form track {trackName}`)
		end
	end
	for age = 1, 5 do
		local mix = MusicConfig.AgeMix[age]
		check(mix ~= nil, `missing music identity mix for age {age}`)
		if mix then
			check(mix.playbackSpeed >= 0.5 and mix.playbackSpeed <= 2,
				`age {age} music playback speed is unsafe`)
		end
	end
	print(`[ProductionChecks] passed; all opening paths require {allPathsOpeningCost}g vs {GameConfig.STARTING_GOLD}g starting gold`)
end

return ProductionChecks
