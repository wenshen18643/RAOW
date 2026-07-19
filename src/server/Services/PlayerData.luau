--!strict
-- DataStore-backed player persistence.
-- Profiles are loaded into an in-memory cache on join and saved on leave.
-- A periodic auto-save task runs every 60 seconds for all online players.
-- All DataStore operations are wrapped in pcall for safety.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)

local PlayerData = {}

local DATASTORE_NAME = "PlayerProfiles_v1"
local AUTO_SAVE_INTERVAL = 60 -- seconds between periodic auto-saves
local LOAD_ATTEMPTS = 3

export type PlayerProfile = {
	schemaVersion: number,
	wins: number,
	losses: number,
	totalKills: number,
	rating: number,
	level: number,
	xp: number,
	tutorialDone: boolean,
	coins: number,
	pveProgress: { Normal: number, Hard: number, Impossible: number },
	pveUpgrades: { unitHp: number, unitDamage: number, startingGold: number },
	pvePerks: { string },
	warBonds: number,
	ownedCosmetics: { string },
	equippedTitle: string,
	equippedTheme: string,
	lastDailyBondDay: number,
	lastDailyBattleDay: number,
	lastDailyWinDay: number,
	processedReceipts: { string },
	settings: {
		mouseSensitivity: number,
		sfxVolume: number,
		uiVolume: number,
		reducedEffects: boolean,
		showDamageNumbers: boolean,
	},
}

-- Returns a fresh default profile.
local function defaultProfile(): PlayerProfile
	return {
		schemaVersion = 8,
		wins = 0,
		losses = 0,
		totalKills = 0,
		rating = 1000,
		level = 1,
		xp = 0,
		tutorialDone = false,
		coins = 0,
		pveProgress = { Normal = 0, Hard = 0, Impossible = 0 },
		pveUpgrades = { unitHp = 0, unitDamage = 0, startingGold = 0 },
		pvePerks = {},
		warBonds = 0,
		ownedCosmetics = {},
		equippedTitle = "",
		equippedTheme = "",
		lastDailyBondDay = -1,
		lastDailyBattleDay = -1,
		lastDailyWinDay = -1,
		processedReceipts = {},
		settings = {
			mouseSensitivity = 0.35,
			sfxVolume = 1,
			uiVolume = 1,
			reducedEffects = false,
			showDamageNumbers = true,
		},
	}
end

-- In-memory cache: Player → profile
local cache: { [Player]: PlayerProfile } = {}
local saving: { [Player]: boolean } = {}
local saveRequested: { [Player]: boolean } = {}
type LoadState = "loading" | "ready" | "retry"
local loadState: { [Player]: LoadState } = {}

-- Reference to the DataStore (nil in Studio when DataStores are disabled)
local store: DataStore? = nil

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
		return store
	else
		warn("[PlayerData] Failed to access DataStore: " .. tostring(result))
		return nil
	end
end

-- Builds the DataStore key for a given player.
local function keyFor(player: Player): string
	return "player_" .. tostring(player.UserId)
end

-- Loads the player's profile from the DataStore into the cache. A successful
-- nil read confirms a new account. Failed or malformed reads retain a default
-- session profile, but leave it in a non-saving state so unknown stored data
-- cannot be overwritten. Calling load again retries the read.
function PlayerData.load(player: Player): boolean
	loadState[player] = "loading"
	local ds = getStore()
	if not ds then
		warn("[PlayerData] DataStore unavailable; profile will remain unsaved until load is retried for " .. player.Name)
		cache[player] = defaultProfile()
		loadState[player] = "retry"
		return false
	end

	local key = keyFor(player)
	local ok = false
	local result: any = nil
	for attempt = 1, LOAD_ATTEMPTS do
		ok, result = pcall(function()
			return ds:GetAsync(key)
		end)
		if ok then break end
		if attempt < LOAD_ATTEMPTS then task.wait(0.5 * attempt) end
	end

	if ok and result and typeof(result) == "table" then
		-- Merge with defaults to fill in any missing fields from older schemas
		local profile = defaultProfile()
		profile.wins = result.wins or 0
		profile.losses = result.losses or 0
		profile.totalKills = result.totalKills or 0
		profile.rating = math.clamp(tonumber(result.rating) or 1000, 0, 5000)
		profile.level = math.clamp(math.floor(tonumber(result.level) or 1), 1, ProgressionConfig.MAX_LEVEL)
		profile.xp = math.max(tonumber(result.xp) or 0, 0)
		profile.tutorialDone = result.tutorialDone == true
		profile.coins = math.max(tonumber(result.coins) or 0, 0)
		if result.pveProgress and typeof(result.pveProgress) == "table" then
			profile.pveProgress.Normal = math.max(math.floor(tonumber(result.pveProgress.Normal) or 0), 0)
			profile.pveProgress.Hard = math.max(math.floor(tonumber(result.pveProgress.Hard) or 0), 0)
			profile.pveProgress.Impossible = math.max(math.floor(tonumber(result.pveProgress.Impossible) or 0), 0)
		else
			profile.pveProgress.Normal = math.max(math.floor(tonumber(result.pveLevel) or 0), 0)
		end
		if result.pveUpgrades and typeof(result.pveUpgrades) == "table" then
			profile.pveUpgrades.unitHp = math.clamp(math.floor(tonumber(result.pveUpgrades.unitHp) or 0), 0, 10)
			profile.pveUpgrades.unitDamage = math.clamp(math.floor(tonumber(result.pveUpgrades.unitDamage) or 0), 0, 10)
			profile.pveUpgrades.startingGold = math.clamp(math.floor(tonumber(result.pveUpgrades.startingGold) or 0), 0, 8)
		end
		if result.pvePerks and typeof(result.pvePerks) == "table" then
			profile.pvePerks = result.pvePerks
		end
		profile.warBonds = math.max(math.floor(tonumber(result.warBonds) or 0), 0)
		if result.ownedCosmetics and typeof(result.ownedCosmetics) == "table" then
			for _, cosmeticId in result.ownedCosmetics do
				if typeof(cosmeticId) == "string"
					and MonetizationConfig.cosmeticById(cosmeticId)
					and not table.find(profile.ownedCosmetics, cosmeticId) then
					table.insert(profile.ownedCosmetics, cosmeticId)
				end
			end
		end
		if typeof(result.equippedTitle) == "string" and #result.equippedTitle <= 64 then
			profile.equippedTitle = result.equippedTitle
		end
		if typeof(result.equippedTheme) == "string" and #result.equippedTheme <= 64 then
			profile.equippedTheme = result.equippedTheme
		end
		profile.lastDailyBondDay = math.floor(tonumber(result.lastDailyBondDay) or -1)
		profile.lastDailyBattleDay = math.floor(tonumber(result.lastDailyBattleDay) or -1)
		profile.lastDailyWinDay = math.floor(tonumber(result.lastDailyWinDay) or -1)
		if result.processedReceipts and typeof(result.processedReceipts) == "table" then
			for _, receiptId in result.processedReceipts do
				if typeof(receiptId) == "string" and #receiptId <= 128 then
					table.insert(profile.processedReceipts, receiptId)
					if #profile.processedReceipts >= 50 then break end
				end
			end
		end
		if result.settings and typeof(result.settings) == "table" then
			profile.settings.mouseSensitivity = math.clamp(tonumber(result.settings.mouseSensitivity) or 0.35, 0, 1)
			profile.settings.sfxVolume = math.clamp(tonumber(result.settings.sfxVolume) or 1, 0, 1)
			profile.settings.uiVolume = math.clamp(tonumber(result.settings.uiVolume) or 1, 0, 1)
			profile.settings.reducedEffects = result.settings.reducedEffects == true
			profile.settings.showDamageNumbers = result.settings.showDamageNumbers ~= false
		end
		-- Reconcile deterministic level rewards for old and new profiles.
		for level, reward in ProgressionConfig.Ladder do
			if level <= profile.level and reward.type == "Title" and not table.find(profile.ownedCosmetics, reward.id) then
				table.insert(profile.ownedCosmetics, reward.id)
			end
		end
		if profile.equippedTitle ~= "" and not table.find(profile.ownedCosmetics, profile.equippedTitle) then
			profile.equippedTitle = ""
		end
		local equippedTitle = MonetizationConfig.cosmeticById(profile.equippedTitle)
		if equippedTitle and equippedTitle.kind == "theme" then profile.equippedTitle = "" end
		if profile.equippedTheme ~= "" and (not table.find(profile.ownedCosmetics, profile.equippedTheme)
			or not MonetizationConfig.themeById(profile.equippedTheme)) then
			profile.equippedTheme = ""
		end
		cache[player] = profile
		loadState[player] = "ready"
		return true
	elseif ok and result == nil then
		cache[player] = defaultProfile()
		loadState[player] = "ready"
		return true
	else
		if not ok then
			warn("[PlayerData] Failed to load profile for " .. player.Name .. " after retries: " .. tostring(result))
		else
			warn("[PlayerData] Invalid stored profile for " .. player.Name .. "; saving is disabled until load is retried")
		end
		cache[player] = defaultProfile()
		loadState[player] = "retry"
		return false
	end
end

-- Saves the cached profile for the player to the DataStore.
-- Does nothing unless the profile came from a confirmed load or new account.
function PlayerData.save(player: Player): boolean
	local profile = cache[player]
	if not profile or loadState[player] ~= "ready" then
		return false
	end
	if saving[player] then
		saveRequested[player] = true
		return false
	end
	saving[player] = true

	local ds = getStore()
	if not ds then
		warn("[PlayerData] DataStore unavailable; cannot save profile for " .. player.Name)
		saving[player] = nil
		return false
	end

	local key = keyFor(player)
	local ok = false
	local err: any = nil
	for attempt = 1, 3 do
		ok, err = pcall(function()
			ds:UpdateAsync(key, function()
				return profile
			end)
		end)
		if ok then break end
		if attempt < 3 then task.wait(0.5 * attempt) end
	end
	saving[player] = nil
	local shouldSaveAgain = saveRequested[player] == true
	saveRequested[player] = nil

	if not ok then
		warn("[PlayerData] Failed to save profile for " .. player.Name .. ": " .. tostring(err))
	else
		Leaderboard.submit(player.UserId, profile.rating)
		local totalPve = profile.pveProgress.Normal + profile.pveProgress.Hard + profile.pveProgress.Impossible
		if totalPve > 0 then
			Leaderboard.submitPveLevel(player.UserId, totalPve)
		end
	end
	if shouldSaveAgain and cache[player] and player.Parent then
		task.defer(function() PlayerData.save(player) end)
	end
	return ok
end

-- Returns the cached profile for the player, or a default if not yet loaded.
function PlayerData.get(player: Player): PlayerProfile
	return cache[player] or defaultProfile()
end

-- Increments the win count for the player.
function PlayerData.recordWin(player: Player)
	local profile = cache[player]
	if profile then
		profile.wins += 1
	end
end

-- Increments the loss count for the player.
function PlayerData.recordLoss(player: Player)
	local profile = cache[player]
	if profile then
		profile.losses += 1
	end
end

-- Adds the given number of kills to the player's total kill count.
function PlayerData.addKills(player: Player, count: number)
	local profile = cache[player]
	if profile then
		profile.totalKills += count
	end
end

-- Add XP and handle level ups
function PlayerData.addXp(player: Player, amount: number): {oldXp: number, newXp: number, levelups: number, unlocks: {string}, warBondsEarned: number}
	local profile = cache[player]
	if not profile then return {oldXp = 0, newXp = 0, levelups = 0, unlocks = {}, warBondsEarned = 0} end
	
	local oldXp = profile.xp
	local newXp = profile.xp + amount
	profile.xp = newXp
	
	local levelups = 0
	local unlocks = {}
	local warBondsEarned = 0
	
	while profile.level < ProgressionConfig.MAX_LEVEL do
		local req = ProgressionConfig.xpForLevel(profile.level + 1)
		if newXp >= req then
			profile.level += 1
			levelups += 1
			profile.warBonds += ProgressionConfig.WAR_BONDS_PER_LEVEL
			warBondsEarned += ProgressionConfig.WAR_BONDS_PER_LEVEL
			local reward = ProgressionConfig.Ladder[profile.level]
			if reward then
				table.insert(unlocks, reward.name)
				if reward.type == "Title" and not table.find(profile.ownedCosmetics, reward.id) then
					table.insert(profile.ownedCosmetics, reward.id)
				end
			end
		else
			break
		end
	end
	
	return {oldXp = oldXp, newXp = newXp, levelups = levelups, unlocks = unlocks, warBondsEarned = warBondsEarned}
end

function PlayerData.addCoins(player: Player, amount: number)
	local profile = cache[player]
	if profile then
		profile.coins += amount
	end
end

function PlayerData.spendCoins(player: Player, amount: number): boolean
	local profile = cache[player]
	if profile and profile.coins >= amount then
		profile.coins -= amount
		return true
	end
	return false
end

function PlayerData.recordPveClear(player: Player, mode: string, level: number): boolean
	local profile = cache[player]
	if profile then
		local currentProg = profile.pveProgress[mode] or 0
		if level > currentProg then
			profile.pveProgress[mode] = level
			return true
		end
	end
	return false
end

-- Sync profile to client
function PlayerData.sync(player: Player)
	local profile = cache[player]
	if profile then
		local title = MonetizationConfig.cosmeticById(profile.equippedTitle)
		player:SetAttribute("CommanderTitle", title and title.name or "")
		player:SetAttribute("ArmyTheme", profile.equippedTheme)
		local publicProfile: any = table.clone(profile)
		publicProfile.pveLevel = profile.pveProgress.Normal
		publicProfile.processedReceipts = nil
		Remotes.ProfileSync:FireClient(player, publicProfile)
	end
end

function PlayerData.claimDailyBonds(player: Player): (boolean, number)
	local profile = cache[player]
	if not profile then return false, 0 end
	local utcDay = math.floor(os.time() / 86400)
	if profile.lastDailyBondDay == utcDay then return false, 0 end
	profile.lastDailyBondDay = utcDay
	local amount = MonetizationConfig.DAILY_WAR_BONDS
	if table.find(profile.ownedCosmetics, MonetizationConfig.SupporterCosmetic.id) then
		amount += MonetizationConfig.SUPPORTER_DAILY_BONUS
	end
	profile.warBonds += amount
	return true, amount
end

function PlayerData.recordDailyBattle(player: Player, won: boolean): number
	local profile = cache[player]
	if not profile then return 0 end
	local utcDay = math.floor(os.time() / 86400)
	local amount = 0
	if profile.lastDailyBattleDay ~= utcDay then
		profile.lastDailyBattleDay = utcDay
		amount += MonetizationConfig.DAILY_BATTLE_BONDS
	end
	if won and profile.lastDailyWinDay ~= utcDay then
		profile.lastDailyWinDay = utcDay
		amount += MonetizationConfig.DAILY_WIN_BONDS
	end
	profile.warBonds += amount
	return amount
end

function PlayerData.updateSetting(player: Player, key: string, value: any): boolean
	local profile = cache[player]
	if not profile then return false end
	if key == "mouseSensitivity" or key == "sfxVolume" or key == "uiVolume" then
		if typeof(value) ~= "number" or value ~= value then return false end
		(profile.settings :: any)[key] = math.clamp(value, 0, 1)
		return true
	elseif key == "reducedEffects" or key == "showDamageNumbers" then
		if typeof(value) ~= "boolean" then return false end
		(profile.settings :: any)[key] = value
		return true
	end
	return false
end

function PlayerData.buyCosmetic(player: Player, cosmeticId: string): boolean
	local profile = cache[player]
	local cosmetic = MonetizationConfig.cosmeticById(cosmeticId)
	if not profile or not cosmetic or not cosmetic.cost then return false end
	if table.find(profile.ownedCosmetics, cosmeticId) then return false end
	if profile.warBonds < cosmetic.cost then return false end
	profile.warBonds -= cosmetic.cost
	table.insert(profile.ownedCosmetics, cosmeticId)
	if cosmetic.kind == "theme" then
		profile.equippedTheme = cosmeticId
	else
		profile.equippedTitle = cosmeticId
	end
	return true
end

function PlayerData.grantCosmetic(player: Player, cosmeticId: string): boolean
	local profile = cache[player]
	if not profile or not MonetizationConfig.cosmeticById(cosmeticId) then return false end
	if not table.find(profile.ownedCosmetics, cosmeticId) then table.insert(profile.ownedCosmetics, cosmeticId) end
	return true
end

function PlayerData.equipCosmetic(player: Player, cosmeticId: string): boolean
	local profile = cache[player]
	local cosmetic = MonetizationConfig.cosmeticById(cosmeticId)
	if not profile or not cosmetic or not table.find(profile.ownedCosmetics, cosmeticId) then return false end
	if cosmetic.kind == "theme" then
		profile.equippedTheme = cosmeticId
	else
		profile.equippedTitle = cosmeticId
	end
	return true
end

function PlayerData.grantProductReceipt(player: Player, receiptId: string, amount: number): boolean
	local profile = cache[player]
	if not profile then return false end
	if table.find(profile.processedReceipts, receiptId) then return true end
	local timeout = os.clock() + 10
	while saving[player] and os.clock() < timeout do task.wait(0.1) end
	if saving[player] then return false end
	local oldBonds = profile.warBonds
	table.insert(profile.processedReceipts, receiptId)
	while #profile.processedReceipts > 50 do table.remove(profile.processedReceipts, 1) end
	profile.warBonds += math.max(math.floor(amount), 0)
	if PlayerData.save(player) then return true end
	profile.warBonds = oldBonds
	local index = table.find(profile.processedReceipts, receiptId)
	if index then table.remove(profile.processedReceipts, index) end
	return false
end

-- Clients request a sync once their listener is connected; the join-time sync
-- can fire before the client script is ready and be dropped.
Remotes.RequestProfile.OnServerEvent:Connect(function(player)
	PlayerData.sync(player)
end)

-- Saves and removes a profile. The match owner calls this after recording any
-- forfeit so result persistence cannot race a separate PlayerRemoving handler.
function PlayerData.unload(player: Player)
	local timeout = os.clock() + 10
	while saving[player] and os.clock() < timeout do task.wait(0.1) end
	PlayerData.save(player)
	cache[player] = nil
	saving[player] = nil
	saveRequested[player] = nil
	loadState[player] = nil
end

-- Applies one idempotent match result to both loaded profiles. The caller owns
-- match-level idempotency and invokes this exactly once per match.
-- Bot fallback matches are unranked so waiting out the human queue cannot be
-- used to farm the competitive ladder. They still count toward win/loss stats.
function PlayerData.recordBotMatch(player: Player, _botRating: number, won: boolean)
	local profile = cache[player]
	if not profile then return end
	if won then
		profile.wins += 1
	else
		profile.losses += 1
	end
end

function PlayerData.recordMatch(winner: Player, loser: Player): (number, number)
	local winnerProfile = cache[winner]
	local loserProfile = cache[loser]
	if not winnerProfile or not loserProfile then return 0, 0 end
	local expectedWinner = 1 / (1 + 10 ^ ((loserProfile.rating - winnerProfile.rating) / 400))
	local delta = math.max(1, math.round(32 * (1 - expectedWinner)))
	winnerProfile.wins += 1
	loserProfile.losses += 1
	winnerProfile.rating = math.clamp(winnerProfile.rating + delta, 0, 5000)
	loserProfile.rating = math.clamp(loserProfile.rating - delta, 0, 5000)
	return delta, -delta
end

game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			local timeout = os.clock() + 20
			while saving[player] and os.clock() < timeout do task.wait(0.1) end
			PlayerData.save(player)
			pending -= 1
		end)
	end
	local timeout = os.clock() + 25
	while pending > 0 and os.clock() < timeout do task.wait(0.1) end
end)

-- Periodic auto-save: every AUTO_SAVE_INTERVAL seconds, save all online players.
-- Uses a simple coroutine loop driven by task.wait.
task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			-- Spawn each save independently so one failure doesn't block others
			task.spawn(function()
				PlayerData.save(player)
			end)
		end
	end
end)

return PlayerData
