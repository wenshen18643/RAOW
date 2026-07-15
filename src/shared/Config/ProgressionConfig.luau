--!strict
-- Defines XP curves, unlock ladders, and progression configuration.

local ProgressionConfig = {}

ProgressionConfig.MAX_LEVEL = 50

-- Base XP rewards for matches
ProgressionConfig.XP_WIN = 100
ProgressionConfig.XP_LOSS = 50
ProgressionConfig.XP_TUTORIAL = 200
ProgressionConfig.WAR_BONDS_PER_LEVEL = 5

-- Calculate XP required for a given level
function ProgressionConfig.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	-- Cumulative total XP required to reach `level` (1->2 costs 300). Scales up.
	return 250 * (level - 1) + 50 * math.floor((level - 1) ^ 1.5)
end

type Reward = {
	type: "Title" | "Skin" | "BaseDecoration",
	id: string,
	name: string,
}

ProgressionConfig.Ladder = {
	[2] = { type = "Title", id = "title_recruit", name = "Title: Recruit" } :: Reward,
	[5] = { type = "Title", id = "title_skirmisher", name = "Title: Skirmisher" } :: Reward,
	[10] = { type = "Title", id = "title_veteran", name = "Title: Veteran" } :: Reward,
	[15] = { type = "Title", id = "title_strategist", name = "Title: Strategist" } :: Reward,
	[20] = { type = "Title", id = "title_commander", name = "Title: Commander" } :: Reward,
	[30] = { type = "Title", id = "title_warlord", name = "Title: Warlord" } :: Reward,
	[40] = { type = "Title", id = "title_agebreaker", name = "Title: Agebreaker" } :: Reward,
	[50] = { type = "Title", id = "title_eternal", name = "Title: Eternal Commander" } :: Reward,
}

return ProgressionConfig
