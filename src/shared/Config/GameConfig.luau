--!strict
-- Global match constants. All tuning knobs live in Config modules.

local GameConfig = {
	-- Economy
	STARTING_GOLD = 175,
	HERO_KILL_BONUS_MULT = 1.5, -- extra reward when hero lands the kill
	PASSIVE_INCOME_BY_AGE = { 2, 3.5, 6, 10, 16 }, -- gold per second
	COMEBACK_INCOME_MAX = 4, -- extra gold/sec when your base is behind
	ESCALATION_START = 15 * 60,
	SUDDEN_DEATH_START = 20 * 60,
	ESCALATION_INCOME_MULT = 2,
	SUDDEN_DEATH_INCOME_MULT = 4,

	-- Units
	UNIT_CAP = 20, -- alive per side
	QUEUE_CAP = 10, -- per-unit train times live in Units.luau (trainTime)
	RANGED_ARMOR_MULT = 0.5, -- heavies/super-heavies take this fraction of ranged projectile damage (armor)

	-- Base
	BASE_MAX_HP = 750,
	BASE_HP_MULT_BY_AGE = { 1, 2, 4, 8, 16 },
	BASE_DAMAGE_MULT = 0.35, -- bases take reduced damage from all attackers
	TURRET_SLOTS = 4,
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
