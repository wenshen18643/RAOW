--!strict
-- Semantic string catalog with locale and per-key English fallback.

local LocalizationService = game:GetService("LocalizationService")

local Localization = {}

type Arguments = { [string]: any }
type Catalog = { [string]: string }

local catalogs: { [string]: Catalog } = {
	en = {
		["common.back"] = "BACK",
		["common.cancel"] = "CANCEL",
		["common.cancelling"] = "CANCELLING...",
		["common.retry"] = "RETRY",
		["common.locked"] = "LOCKED",
		["common.boss"] = "BOSS",
		["common.max"] = "MAX",
		["common.maxed"] = "MAXED",
		["common.ready"] = "READY",
		["common.current"] = "CURRENT",
		["common.close"] = "CLOSE",
		["common.build"] = "BUILD",
		["common.sell"] = "SELL",
		["common.level"] = "LEVEL {level}",
		["common.level_short"] = "Lv {level}",
		["common.coins"] = "Coins: {coins}",

		["pve_start.title"] = "PREPARING BATTLE",
		["pve_start.checking"] = "Checking your stage and preparing a server...",
		["pve_start.cancelling"] = "Cancelling battle preparation...",
		["pve_start.server_ready"] = "Server ready. Joining battle...",
		["pve_start.starting"] = "Starting battle...",
		["pve_start.preparing"] = "Preparing a battle server...",
		["pve_start.failed"] = "Battle could not start. Retry or go back.",
		["pve_start.timeout"] = "The battle server did not respond. Retry or go back.",

		["portal.pvp_title"] = "RANKED 1v1",
		["portal.campaign_title"] = "{difficulty} CAMPAIGN",
		["portal.rating"] = "YOUR RATING: {rating}",
		["portal.pvp_description"] = "Queue for matchmaking against another player.",
		["portal.queue"] = "QUEUE BATTLE",
		["portal.level_prompt"] = "Select a level to start your assault",
		["portal.go_level"] = "GO — LEVEL {level}",

		["menu.game_title"] = "AGE OF WAR",
		["menu.game_subtitle"] = "F I R S T   P E R S O N",
		["menu.tagline"] = "Fight through five ages. Command your army. Destroy the enemy base.",
		["menu.select_mode"] = "SELECT MODE",
		["menu.play"] = "PLAY",
		["menu.pve"] = "PvE",
		["menu.pvp"] = "PvP 1v1",
		["menu.upgrades"] = "UPGRADES",
		["menu.shop"] = "SHOP",
		["menu.first_battle"] = "FIRST BATTLE — WIN FOR 300 XP",
		["menu.pve_description"] = "Endless stages across three difficulties. Boss every 5 levels.",
		["menu.pvp_description"] = "Ranked matchmaking against another player.",
		["menu.pve_levels"] = "PvE LEVELS",
		["menu.level_range"] = "Levels {first} - {last}",
		["menu.play_next"] = "PLAY NEXT — LEVEL {level}",
		["menu.stage_preview"] = "NEXT: {name} — {map} / {objective} — {modifier}\nEnemy HP x{health} | Damage x{damage} | Recommended: {tiers} tiers — {guidance}",
		["menu.stage_map_objective"] = "{map} • {objective}",
		["menu.stage_power"] = "HP x{health}  DMG x{damage}",
		["menu.pve_upgrades"] = "PvE UPGRADES & PERKS",
		["menu.upgrade_tier"] = "{name} (Tier {tier})",
		["menu.buy_cost"] = "BUY ({cost}c)",
		["menu.leaderboard"] = "LEADERBOARD",
		["menu.pvp_rating"] = "PVP RATING",
		["menu.campaign_score"] = "CAMPAIGN SCORE",
		["menu.loading"] = "Loading...",
		["menu.settings"] = "SETTINGS",
		["menu.accessibility"] = "ACCESSIBILITY",
		["menu.mouse_sensitivity"] = "Mouse Sensitivity",
		["menu.sfx_volume"] = "SFX Volume",
		["menu.ui_volume"] = "UI Volume",
		["menu.music_volume"] = "Music Volume",
		["menu.ui_scale"] = "UI / Text Scale",
		["menu.crosshair_size"] = "Crosshair Size",
		["menu.field_of_view"] = "Field of View",
		["menu.reduced_effects_on"] = "REDUCED EFFECTS: ON",
		["menu.reduced_effects_off"] = "REDUCED EFFECTS: OFF",
		["menu.damage_numbers_on"] = "DAMAGE NUMBERS: ON",
		["menu.damage_numbers_off"] = "DAMAGE NUMBERS: OFF",
		["menu.team_colors_accessible"] = "TEAM COLORS: ACCESSIBLE",
		["menu.team_colors_standard"] = "TEAM COLORS: STANDARD",
		["menu.crosshair_on"] = "CROSSHAIR: ON",
		["menu.crosshair_off"] = "CROSSHAIR: OFF",
		["menu.high_contrast_on"] = "HIGH CONTRAST: ON",
		["menu.high_contrast_off"] = "HIGH CONTRAST: OFF",
		["menu.captions_on"] = "CRITICAL CAPTIONS: ON",
		["menu.captions_off"] = "CRITICAL CAPTIONS: OFF",
		["menu.leave_title"] = "LEAVE ACTIVE MATCH?",
		["menu.surrender"] = "SURRENDER",
		["menu.keep_playing"] = "KEEP PLAYING",
		["menu.leave_match"] = "LEAVE MATCH",
		["menu.surrender_pvp_warning"] = "This counts as a ranked loss and your rating will decrease. A disconnect has the same result after a short reconnect grace period.",
		["menu.surrender_pve_warning"] = "This ends the run immediately and records a defeat. Current match rewards will be forfeited.",
		["menu.how_to_play"] = "HOW TO PLAY",
		["menu.help_intro"] = "You are the HERO — fight in first person AND command your army.",
		["menu.help_touch"] = "Drag to aim • Use ATTACK and HEAVY buttons to fight\nTap unit cards to recruit • Tap turret, special, evolve, and panel buttons",
		["menu.help_gamepad"] = "LEFT STICK — move • RIGHT STICK — aim • [RT] attack • [LT] heavy\n[{slot1}] / [{slot2}] / [{slot3}] / [{slot4}] — recruit units\n[{slot5}] build turret • [{turrets}] manage turrets • [{slot6}] special • [{evolve}] evolve",
		["menu.help_keyboard"] = "WASD — move • Mouse — aim • [LMB] attack • [RMB] heavy\n[1] / [2] / [3] / [4] — recruit units\n[5] build turret • [B] manage turrets • [6] special • [Q] evolve • [E]/[G] upgrades/guide",
		["menu.help_ages"] = "There are 5 stages: Stone, Medieval, Renaissance, Modern, and Future.",
		["menu.help_economy"] = "Kills earn GOLD for troops and XP for evolution.",
		["menu.help_unlocks"] = "Evolving unlocks units, hero weapons, turrets, specials, and a tougher base.",
		["menu.help_goal"] = "YOUR GOAL: destroy the RED enemy base while protecting your BLUE base.",
		["menu.replay_tutorial"] = "REPLAY TUTORIAL",
		["menu.back_to_settings"] = "BACK TO SETTINGS",
		["menu.victory"] = "VICTORY",
		["menu.defeat"] = "DEFEAT",
		["menu.rematch_requested"] = "REMATCH REQUESTED",
		["menu.starting"] = "STARTING...",
		["menu.request_rematch"] = "REQUEST REMATCH",
		["menu.play_next_stage"] = "PLAY NEXT STAGE",
		["menu.retry_stage"] = "RETRY STAGE",
		["menu.return_lobby"] = "RETURN TO LOBBY",
		["menu.return_menu"] = "RETURN TO MENU",
		["menu.play_again"] = "PLAY AGAIN",
		["menu.replay_stage"] = "REPLAY STAGE",
		["menu.next_stage"] = "NEXT STAGE ({level})",
		["menu.armory_rewards"] = "ARMORY / REWARDS",
		["menu.result_mode"] = "Mode: {mode}",
		["menu.mode_pvp"] = "1v1 PvP",
		["menu.mode_pve"] = "PvE {difficulty} Level {level}",
		["menu.result_age"] = "Age reached: {age}",
		["menu.result_time"] = "Battle time: {minutes}m {seconds}s",
		["menu.result_rating"] = "Rating: {rating}",
		["menu.result_xp"] = "XP Earned: +{xp}",
		["menu.result_level_up"] = "Level Up! (+{levels}) • +{bonds} War Bonds",
		["menu.result_unlocked"] = "Unlocked: {unlocks}",
		["menu.result_next_unlock"] = "Next unlock: {unlock}",
		["menu.result_coins"] = "Coins Earned: +{coins}",
		["menu.result_first_clear"] = "First Clear Bonus!",
		["menu.result_daily"] = "Daily Orders: +{bonds} War Bonds",
		["menu.choose_countdown"] = "Choose an option • returning to {destination} in {seconds}s",
		["menu.rematch_countdown"] = "Rematch ready: {ready}/2 • returning to {destination} in {seconds}s",
		["menu.returning"] = "Returning to {destination}...",
		["menu.all_rewards"] = "All rewards unlocked",
		["menu.next_unlock"] = "Next: {unlock}",
		["menu.no_pvp_scores"] = "No ratings yet. Win a PvP match to get on the board!",
		["menu.no_pve_scores"] = "No campaign score yet. Clear a stage in any difficulty to get on the board!",
		["menu.rematch_ready"] = "Rematch ready: {ready}/{required} players",
		["menu.return_failed"] = "Couldn't return to the lobby. Press Return to retry.",
		["menu.opponent_reconnected"] = "Opponent reconnected.",
		["menu.opponent_grace"] = "Opponent disconnected — reconnect grace: {seconds}s. The battle remains active until they return or forfeit.",
		["menu.stage_reward"] = "+{coins}c",

		["tutorial.skip_step"] = "SKIP STEP",
		["tutorial.skip_all"] = "SKIP ALL",
		["tutorial.finish"] = "FINISH",
		["tutorial.recruit_press"] = "Press {prompt} to recruit a Club Man",
		["tutorial.recruit_touch"] = "Tap the first unit card to recruit a Club Man",
		["tutorial.earn_xp"] = "Damage the enemy base or defeat an enemy to earn XP",
		["tutorial.build_turret"] = "Build a turret with your hotbar",
		["tutorial.evolve"] = "Evolve to the next Age when your XP is full",
		["tutorial.win"] = "Destroy the enemy base to win! First win grants bonus XP → Level 2",

		["hud.your_base"] = "YOUR BASE",
		["hud.enemy_base"] = "ENEMY BASE",
		["hud.goal_destroy"] = "GOAL: DESTROY THE ENEMY BASE",
		["hud.evolve_hint"] = "Kills grant XP • Evolve to unlock stronger armies",
		["hud.mode_pvp"] = "Mode: 1v1 PvP",
		["hud.evolve"] = "EVOLVE",
		["hud.upgrades"] = "UPGRADES",
		["hud.combo_guide"] = "COMBO GUIDE",
		["hud.guide_title"] = "ARMY COMBINATION GUIDE",
		["hud.guide_description"] = "The first formation you complete locks your doctrine for this battle. Choose carefully.",
		["hud.doctrine_none"] = "Current doctrine: Not chosen",
		["hud.turrets"] = "TURRETS",
		["hud.turret_manager"] = "TURRET MANAGER",
		["hud.turret_credit"] = "Upgrades automatically include the old turret's 50% sell credit.",
		["hud.slot_empty"] = "SLOT {slot} • EMPTY",
		["hud.slot_turret"] = "SLOT {slot} • {name} (AGE {age})",
		["hud.build_cost"] = "BUILD {cost}g",
		["hud.upgrade_cost"] = "UPGRADE {cost}g",
		["hud.sell_value"] = "SELL +{value}",
		["hud.cancel_matchmaking"] = "CANCEL MATCHMAKING",
		["hud.queue_full"] = "UNIT QUEUE FULL",
		["hud.need_gold"] = "NEED {amount} MORE GOLD",
		["hud.special_cooldown"] = "SPECIAL READY IN {seconds}s",
		["hud.need_xp"] = "NEED {amount} MORE XP TO EVOLVE",
		["hud.all_turrets_full"] = "ALL SLOTS FULL • OPEN TURRETS TO UPGRADE OR SELL",
		["hud.doctrine_locked"] = "Current doctrine: {doctrine} (LOCKED)",
		["hud.doctrine_active"] = "ACTIVE FOR THIS BATTLE",
		["hud.doctrine_unavailable"] = "LOCKED OUT THIS BATTLE",
		["hud.progress"] = "Progress: {progress}",
		["hud.gold_income"] = "{gold} g (+{income}/s)",
		["hud.army_count"] = "units {units}/20  queue {queue}",
		["hud.age"] = "AGE {age} / {total} • {name}",
		["hud.hold_objective"] = "{time} • HOLD FOR {seconds}s",
		["hud.sudden_death"] = "{time} • SUDDEN DEATH • 3x BASE DAMAGE",
		["hud.sudden_death_in"] = "{time} • ESCALATION • SUDDEN DEATH IN {seconds}s",
		["hud.escalation_in"] = "{time} • ESCALATION IN {seconds}s",
		["hud.xp"] = "XP {xp} / {required}",
		["hud.pve_stage"] = "{difficulty} • LV {level} • {stage} • {objective}",
		["hud.pve_level"] = "{difficulty} • LEVEL {level}",
		["hud.versus"] = "VS {opponent}",
		["hud.goal_stage"] = "GOAL: {objective} • {stage}",
		["hud.evolve_to_age"] = "EVOLVE TO AGE {age}",
		["hud.age_locked"] = "AGE {age} LOCKED",
		["hud.base_health"] = "{label} • {health} / {maximum}",
		["hud.hero_health"] = "HERO • {health} / {maximum}",
		["hud.full"] = "FULL",
		["hud.max_age"] = "MAX AGE",
		["hud.final_age"] = "FINAL AGE REACHED • Lead your army to destroy the enemy base",
		["hud.battle_start_pvp"] = "1v1 BATTLE START",
		["hud.battle_start_pve"] = "BATTLE START — {difficulty} MODE",
		["hud.advanced_age"] = "ADVANCED TO {age}!",
		["hud.enemy_special"] = "Enemy {name}! Take cover!",
		["hud.doctrine_unlocked"] = "{name} DOCTRINE LOCKED IN!",
		["hud.enemy_doctrine"] = "Enemy formed {name}",
		["hud.enemy_advanced"] = "Enemy advanced an age!",
		["hud.respawn"] = "Respawn in {seconds}...",
		["hud.waiting_opponent"] = "WAITING FOR AN OPPONENT TO JOIN...",
		["hud.queue_position"] = "MATCHMAKING • QUEUE POSITION {position}",
		["hud.opponent_found"] = "OPPONENT FOUND • CREATING MATCH SERVER...",
		["hud.queue_cancelled"] = "MATCHMAKING CANCELLED",
		["hud.queue_retrying"] = "MATCHMAKING RETRYING...",
		["hud.opponent_join_failed"] = "OPPONENT FAILED TO JOIN • RETURNING TO LOBBY",
		["hud.cancelling"] = "CANCELLING...",
		["hud.stage_detail"] = "{description} • {modifier}: {modifierDescription}",
		["caption.sound"] = "[SOUND] {text}",
		["caption.base_under_attack"] = "YOUR BASE IS UNDER ATTACK",
		["caption.boss_slam"] = "BOSS SLAM CHARGING — MOVE OUT OF THE RING",
		["caption.enemy_special"] = "ENEMY {name} — TAKE COVER",
	},
}

local warned: { [string]: boolean } = {}

local function normalizeLocale(localeId: string?): string
	local locale = string.lower(localeId or "en")
	return string.match(locale, "^[a-z]+") or "en"
end

local function playerLocale(): string
	return normalizeLocale(LocalizationService.RobloxLocaleId)
end

local function interpolate(template: string, arguments: Arguments?): string
	if not arguments then return template end
	return (string.gsub(template, "{([%w_]+)}", function(name)
		local value = arguments[name]
		return if value == nil then "{" .. name .. "}" else tostring(value)
	end))
end

function Localization.t(key: string, arguments: Arguments?, localeId: string?): string
	local locale = normalizeLocale(localeId or playerLocale())
	local localized = catalogs[locale]
	local template = localized and localized[key] or catalogs.en[key]
	if not template then
		if not warned[key] then
			warned[key] = true
			warn(`[Localization] Missing English string for '{key}'`)
		end
		return key
	end
	return interpolate(template, arguments)
end

return Localization
