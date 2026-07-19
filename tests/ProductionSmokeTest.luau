local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local monetization = require(shared.Config.MonetizationConfig)
local pve = require(shared.Config.PvELevels)
local progression = require(shared.Config.ProgressionConfig)
local gameConfig = require(shared.Config.GameConfig)
local heroWeapons = require(shared.Config.HeroWeapons)
local units = require(shared.Config.Units)
local turrets = require(shared.Config.Turrets)
local soundConfig = require(shared.Config.SoundConfig)
local musicConfig = require(shared.Config.MusicConfig)
local remotes = require(shared.Remotes)

assert(pve.difficultyForLevel("Normal", 100).hpMult > pve.difficultyForLevel("Normal", 50).hpMult, "endless PvE difficulty must keep scaling")
local expectedBosses = { "age1_heavy", "age2_heavy", "age3_heavy", "age4_heavy", "age5_super_heavy" }
for tier, unitId in expectedBosses do
	local boss = pve.getBossConfig("Normal", tier * 5)
	assert(boss.unitId == unitId, `boss tier {tier} is not age-appropriate`)
	assert(boss.slamTelegraphDuration >= 0.75, `boss tier {tier} has no usable dodge window`)
	assert(boss.slamMaxHeroHpRatio <= 0.45, `boss tier {tier} can one-shot the commander`)
end
assert(progression.Ladder[50] ~= nil, "level 50 reward missing")
assert(progression.WAR_BONDS_PER_LEVEL == 5, "continuous commander-level reward missing")
assert(monetization.productByRobloxId(0) == nil, "disabled product ID must never resolve")
assert(monetization.configuredOfferCount() >= 0 and monetization.configuredOfferCount() <= 4, "commerce readiness count invalid")
assert(monetization.DAILY_WAR_BONDS + monetization.DAILY_BATTLE_BONDS + monetization.DAILY_WIN_BONDS == 20, "daily free earning pace changed")
assert(monetization.SUPPORTER_DAILY_BONUS <= monetization.DAILY_WAR_BONDS, "supporter daily bonus is disproportionate")
assert(gameConfig.ESCALATION_START < gameConfig.SUDDEN_DEATH_START, "pacing phase order invalid")
assert(gameConfig.HERO_UPGRADE_MAX_TIER == 5, "hero upgrade cap mismatch")
for _, ageUnits in units.byAge do
	for _, unit in ageUnits do
		assert(unit.killGold < unit.cost, `{unit.id} creates gold on a normal kill`)
		assert(unit.killGold * gameConfig.HERO_KILL_BONUS_MULT < unit.cost, `{unit.id} creates gold on a hero kill`)
	end
end
for age = 1, 5 do
	local income = gameConfig.PASSIVE_INCOME_BY_AGE[age]
	local meleeWait = units.byId[`age{age}_melee`].cost / income
	local heavyWait = units.byId[`age{age}_heavy`].cost / income
	local turretWait = turrets[age].cost / income
	assert(meleeWait >= 5 and meleeWait <= 15, `age {age} basic purchase cadence is broken`)
	assert(heavyWait >= 35 and heavyWait <= 60, `age {age} heavy purchase cadence is broken`)
	assert(turretWait >= 40 and turretWait <= 70, `age {age} turret investment cadence is broken`)
	local melee = units.byId[`age{age}_melee`]
	local ranged = units.byId[`age{age}_ranged`]
	local heavy = units.byId[`age{age}_heavy`]
	assert(ranged.range >= melee.range * 4, `age {age} ranged unit has no spacing advantage`)
	assert((heavy.hp / heavy.cost) >= 0.8 * (melee.hp / melee.cost), `age {age} heavy is an economic trap`)
	assert(((heavy.damage / heavy.attackSpeed) / heavy.cost) <= 0.5 * ((melee.damage / melee.attackSpeed) / melee.cost), `age {age} heavy is universally efficient`)
end
local super = units.byId.age5_super_heavy
local finalHeavy = units.byId.age5_heavy
assert(super.hp / super.cost <= 1.05 * (finalHeavy.hp / finalHeavy.cost), "super-heavy health efficiency is dominant")
assert((super.damage / super.attackSpeed) / super.cost <= 1.05 * ((finalHeavy.damage / finalHeavy.attackSpeed) / finalHeavy.cost), "super-heavy damage efficiency is dominant")
assert(heroWeapons[4].kind == "hitscan" and heroWeapons[5].kind == "hitscan", "late-age ranged weapons missing")
for _, sound in soundConfig do assert(sound.group ~= "Music", "empty music group should not be exposed") end
for name, track in musicConfig.Tracks do
	assert(track.volume >= 0 and track.volume <= 1, `{name} long-form volume is valid`)
	assert(track.id == "" or string.match(track.id, "^rbxassetid://%d+$") ~= nil,
		`{name} uses an approved asset URI format`)
end
for _, scene in musicConfig.Scenes do
	assert(scene.music == "" or musicConfig.Tracks[scene.music], "music scene references a known track")
	assert(scene.ambience == "" or musicConfig.Tracks[scene.ambience], "ambience scene references a known track")
end
for age = 1, 5 do assert(musicConfig.AgeMix[age], `age {age} has a soundtrack identity mix`) end
assert(remotes.ResultAction ~= nil, "explicit post-match actions are missing")
assert(ReplicatedStorage.Remotes:FindFirstChild("LeaveMatch") == nil, "obsolete forced-return remote still exists")
for _, cosmetic in monetization.Cosmetics do
	assert(cosmetic.cost >= monetization.DAILY_WAR_BONDS, "invalid cosmetic price")
	assert(cosmetic.damage == nil and cosmetic.hp == nil and cosmetic.gold == nil, "paid cosmetic grants gameplay power")
end
local theme = monetization.themeById("theme_royal")
assert(theme and theme.kind == "theme" and typeof(theme.color) == "Color3", "army signal themes are missing")
assert(monetization.themeById("title_tactician") == nil, "title incorrectly resolves as an army theme")

local checks = require(ServerScriptService.Server.Services.ProductionChecks)
checks.run()

print("PRODUCTION_SMOKE_PASS")
