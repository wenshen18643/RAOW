--!strict
-- Defines XP curves, unlock ladders, and progression configuration.

local ProgressionConfig = {}

ProgressionConfig.MAX_LEVEL = 50

-- Base XP rewards for matches
ProgressionConfig.XP_WIN = 100
ProgressionConfig.XP_LOSS = 50
ProgressionConfig.XP_TUTORIAL = 200

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
	[5] = { type = "Skin", id = "skin_flame_catapult", name = "Skin: Flame Catapult" } :: Reward,
	[10] = { type = "Title", id = "title_veteran", name = "Title: Veteran" } :: Reward,
	[15] = { type = "Skin", id = "skin_obsidian_club", name = "Skin: Obsidian Club" } :: Reward,
	[20] = { type = "Title", id = "title_commander", name = "Title: Commander" } :: Reward,
}

return ProgressionConfig
