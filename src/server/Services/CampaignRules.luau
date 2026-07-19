--!strict
-- Server-authoritative setup and completion checks for alternate PvE objectives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampaignStages = require(ReplicatedStorage.Shared.Config.CampaignStages)
local MapBuilder = require(script.Parent.MapBuilder)
local Match = require(script.Parent.Match)

local CampaignRules = {}

local function finish(match: Match.Match, winner: string)
	if match.status ~= "Active" then return end
	match.status = "Ended"
	match.winner = winner
	if match.onEnd then
		match.onEnd(winner)
	end
end

function CampaignRules.configure(match: Match.Match, level: number)
	local stage = CampaignStages.forLevel(level)
	match.campaignStage = stage
	MapBuilder.applyVariant(match.map, stage.mapVariant)

	local enemyCore = match.map.bases.B.core
	enemyCore:SetAttribute("Hp", Match.getBaseMaxHp(match, "B"))
	match.sides.A.gold += stage.playerStartingGold
end

function CampaignRules.tick(match: Match.Match)
	if match.status ~= "Active" or not match.campaignStage then return end

	local objective = match.campaignStage.objective
	if objective.kind == "Survive" then
		if os.clock() - match.startedAt >= (objective.duration or 0) then
			finish(match, "A")
		end
	elseif objective.kind == "DefeatBoss" then
		local boss = match.campaignBoss
		if boss and boss.dead then
			finish(match, "A")
		end
	end
end

return CampaignRules
