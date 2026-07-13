--!strict
-- DataStore-backed player persistence.
-- Profiles are loaded into an in-memory cache on join and saved on leave.
-- A periodic auto-save task runs every 60 seconds for all online players.
-- All DataStore operations are wrapped in pcall for safety.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)

local PlayerData = {}

local DATASTORE_NAME = "PlayerProfiles_v1"
local AUTO_SAVE_INTERVAL = 60 -- seconds between periodic auto-saves

export type PlayerProfile = {
	schemaVersion: number,
	wins: number,
	losses: number,
	totalKills: number,
	rating: number,
	unlockedSkins: { string },
	level: number,
	xp: number,
	tutorialDone: boolean,
}

-- Returns a fresh default profile.
local function defaultProfile(): PlayerProfile
	return {
		schemaVersion = 3,
		wins = 0,
		losses = 0,
		totalKills = 0,
		rating = 1000,
		unlockedSkins = {},
		level = 1,
		xp = 0,
		tutorialDone = false,
	}
end

-- In-memory cache: Player → profile
local cache: { [Player]: PlayerProfile } = {}
local saving: { [Player]: boolean } = {}

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

-- Loads the player's profile from the DataStore into the cache.
-- On failure (e.g. Studio with DataStores disabled, or network error), a
-- default profile is used and a warning is logged.
function PlayerData.load(player: Player)
	local ds = getStore()
	if not ds then
		warn("[PlayerData] DataStore unavailable; using default profile for " .. player.Name)
		cache[player] = defaultProfile()
		return
	end

	local key = keyFor(player)
	local ok, result = pcall(function()
		return ds:GetAsync(key)
	end)

	if ok and result and typeof(result) == "table" then
		-- Merge with defaults to fill in any missing fields from older schemas
		local profile = defaultProfile()
		profile.wins = result.wins or 0
		profile.losses = result.losses or 0
		profile.totalKills = result.totalKills or 0
		profile.rating = math.clamp(tonumber(result.rating) or 1000, 0, 5000)
		if result.unlockedSkins and typeof(result.unlockedSkins) == "table" then
			profile.unlockedSkins = result.unlockedSkins
		end
		profile.level = math.clamp(math.floor(tonumber(result.level) or 1), 1, ProgressionConfig.MAX_LEVEL)
		profile.xp = math.max(tonumber(result.xp) or 0, 0)
		profile.tutorialDone = result.tutorialDone == true
		cache[player] = profile
	else
		if not ok then
			warn("[PlayerData] Failed to load profile for " .. player.Name .. ": " .. tostring(result))
		end
		cache[player] = defaultProfile()
	end
end

-- Saves the cached profile for the player to the DataStore.
-- Does nothing if no cached profile exists.
function PlayerData.save(player: Player): boolean
	local profile = cache[player]
	if not profile or saving[player] then
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

	if not ok then
		warn("[PlayerData] Failed to save profile for " .. player.Name .. ": " .. tostring(err))
	else
		Leaderboard.submit(player.UserId, profile.rating)
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
function PlayerData.addXp(player: Player, amount: number): {oldXp: number, newXp: number, levelups: number, unlocks: {string}}
	local profile = cache[player]
	if not profile then return {oldXp = 0, newXp = 0, levelups = 0, unlocks = {}} end
	
	local oldXp = profile.xp
	local newXp = profile.xp + amount
	profile.xp = newXp
	
	local levelups = 0
	local unlocks = {}
	
	while profile.level < ProgressionConfig.MAX_LEVEL do
		local req = ProgressionConfig.xpForLevel(profile.level + 1)
		if newXp >= req then
			profile.level += 1
			levelups += 1
			local reward = ProgressionConfig.Ladder[profile.level]
			if reward then
				table.insert(unlocks, reward.name)
				if reward.type == "Skin" and not table.find(profile.unlockedSkins, reward.id) then
					table.insert(profile.unlockedSkins, reward.id)
				end
			end
		else
			break
		end
	end
	
	return {oldXp = oldXp, newXp = newXp, levelups = levelups, unlocks = unlocks}
end

-- Sync profile to client
function PlayerData.sync(player: Player)
	local profile = cache[player]
	if profile then
		Remotes.ProfileSync:FireClient(player, profile)
	end
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
end

-- Applies one idempotent match result to both loaded profiles. The caller owns
-- match-level idempotency and invokes this exactly once per match.
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
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
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
