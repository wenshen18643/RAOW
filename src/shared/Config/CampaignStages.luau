--!strict
-- Deterministic PvE stage identities. This is deliberately separate from the
-- endless stat curve: a stage changes how a battle plays, not just its numbers.

local CampaignStages = {}

export type ObjectiveDef = {
	kind: "DestroyBase" | "Survive" | "DefeatBoss",
	label: string,
	description: string,
	duration: number?,
}

export type StageDef = {
	name: string,
	mapVariant: string,
	objective: ObjectiveDef,
	modifierLabel: string,
	modifierDescription: string,
	aiFormation: { string },
	aiLanePattern: { number },
	aiSpawnIntervalMult: number,
	aiIncomeMult: number,
	enemyBaseHpMult: number,
	playerStartingGold: number,
	bossMechanic: string?,
}

local ASSAULTS: { StageDef } = {
	{
		name = "Frontier Clash",
		mapVariant = "Frontier",
		objective = {
			kind = "DestroyBase",
			label = "ASSAULT",
			description = "Break the enemy base.",
		},
		modifierLabel = "Balanced Forces",
		modifierDescription = "The enemy fields a mixed frontline.",
		aiFormation = { "melee", "ranged", "melee", "heavy" },
		aiLanePattern = { 0, -5, 5, -10, 10 },
		aiSpawnIntervalMult = 1,
		aiIncomeMult = 1,
		enemyBaseHpMult = 1,
		playerStartingGold = 0,
	},
	{
		name = "Canyon Rush",
		mapVariant = "Canyon",
		objective = {
			kind = "DestroyBase",
			label = "BREAKTHROUGH",
			description = "Push through a fast enemy vanguard.",
		},
		modifierLabel = "Rapid Deployment",
		modifierDescription = "Enemy units train 15% faster; you begin with +75 gold.",
		aiFormation = { "melee", "melee", "ranged", "heavy", "melee" },
		aiLanePattern = { 0, -5, 5, 0, -10, 10 },
		aiSpawnIntervalMult = 0.85,
		aiIncomeMult = 1,
		enemyBaseHpMult = 1,
		playerStartingGold = 75,
	},
	{
		name = "Ruined Stronghold",
		mapVariant = "Ruins",
		objective = {
			kind = "DestroyBase",
			label = "SIEGE",
			description = "Crack the reinforced enemy stronghold.",
		},
		modifierLabel = "Fortified Core",
		modifierDescription = "The enemy base has 35% more health.",
		aiFormation = { "heavy", "ranged", "melee", "ranged" },
		aiLanePattern = { -10, 10, -5, 5, 0 },
		aiSpawnIntervalMult = 1.05,
		aiIncomeMult = 0.95,
		enemyBaseHpMult = 1.35,
		playerStartingGold = 40,
	},
	{
		name = "Frozen Last Stand",
		mapVariant = "Frost",
		objective = {
			kind = "Survive",
			label = "HOLD THE LINE",
			description = "Keep your base standing until reinforcements arrive.",
			duration = 150,
		},
		modifierLabel = "Relentless Waves",
		modifierDescription = "Enemy income is 20% higher; its base cannot be destroyed.",
		aiFormation = { "melee", "ranged", "melee", "heavy", "ranged", "super_heavy" },
		aiLanePattern = { -10, 10, -5, 5, 0 },
		aiSpawnIntervalMult = 0.92,
		aiIncomeMult = 1.2,
		enemyBaseHpMult = 1,
		playerStartingGold = 100,
	},
}

local BOSS_MECHANICS = { "Slam", "Reinforcements", "Barrage", "SlamReinforcements", "BarrageSlam" }

function CampaignStages.forLevel(level: number): StageDef
	level = math.max(1, math.floor(level))
	if level % 5 == 0 then
		local tier = math.max(1, math.ceil(level / 5))
		local mechanic = BOSS_MECHANICS[((tier - 1) % #BOSS_MECHANICS) + 1]
		return {
			name = `Warlord's Stand {tier}`,
			mapVariant = ({ "Frontier", "Canyon", "Ruins", "Frost" })[((tier - 1) % 4) + 1],
			objective = {
				kind = "DefeatBoss",
				label = "BOSS HUNT",
				description = "Defeat the warlord. Its base is protected.",
			},
			modifierLabel = ({
				Slam = "Seismic Slam",
				Reinforcements = "Call Reinforcements",
				Barrage = "Targeted Barrage",
				SlamReinforcements = "Slam & Reinforcements",
				BarrageSlam = "Barrage & Slam",
			})[mechanic],
			modifierDescription = ({
				Slam = "Evade the telegraphed ground slam.",
				Reinforcements = "The warlord periodically calls an escort.",
				Barrage = "Move away from targeted artillery markers.",
				SlamReinforcements = "Manage shockwaves and repeated escorts.",
				BarrageSlam = "Keep moving between ranged and close-range attacks.",
			})[mechanic],
			aiFormation = { "heavy", "ranged", "melee", "heavy" },
			aiLanePattern = { 0, -5, 5, 0 },
			aiSpawnIntervalMult = 1,
			aiIncomeMult = 1.05,
			enemyBaseHpMult = 1,
			playerStartingGold = 125,
			bossMechanic = mechanic,
		}
	end

	return ASSAULTS[((level - 1) % #ASSAULTS) + 1]
end

function CampaignStages.preview(level: number): {
	name: string,
	map: string,
	objective: string,
	objectiveDescription: string,
	modifier: string,
	modifierDescription: string,
}
	local stage = CampaignStages.forLevel(level)
	return {
		name = stage.name,
		map = stage.mapVariant,
		objective = stage.objective.label,
		objectiveDescription = stage.objective.description,
		modifier = stage.modifierLabel,
		modifierDescription = stage.modifierDescription,
	}
end

return CampaignStages
