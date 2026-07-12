--!strict
-- Global match constants. All tuning knobs live in Config modules.

local GameConfig = {
	-- Economy
	STARTING_GOLD = 175,
	PASSIVE_GOLD_PER_SEC = 2,
	HERO_KILL_BONUS_MULT = 1.5, -- extra reward when hero lands the kill
	SURGE_TIME = 20 * 60, -- after this many seconds, passive income surges
	SURGE_MULT = 4,

	-- Units
	UNIT_CAP = 20, -- alive per side
	QUEUE_CAP = 10,
	SPAWN_INTERVAL = 1.2, -- seconds between queue pops

	-- Base
	BASE_MAX_HP = 4000,
	TURRET_SLOTS = 3,
	TURRET_SELL_REFUND = 0.5,

	-- Hero
	HERO_RESPAWN_BASE = 10, -- seconds, +HERO_RESPAWN_STEP per death
	HERO_RESPAWN_STEP = 10,
	HERO_RESPAWN_MAX = 40,

	-- Map
	LANE_LENGTH = 300,
	LANE_WIDTH = 60,

	-- Loop rates
	SIM_RATE = 10, -- unit sim updates per second
	STATE_SYNC_RATE = 5, -- HUD state snapshots per second
}

return GameConfig
