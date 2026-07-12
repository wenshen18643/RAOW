--!strict
-- DataStore-backed player persistence.
-- Profiles are loaded into an in-memory cache on join and saved on leave.
-- A periodic auto-save task runs every 60 seconds for all online players.
-- All DataStore operations are wrapped in pcall for safety.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PlayerData = {}

local DATASTORE_NAME = "PlayerProfiles_v1"
local AUTO_SAVE_INTERVAL = 60 -- seconds between periodic auto-saves

export type PlayerProfile = {
	wins: number,
	losses: number,
	totalKills: number,
	unlockedSkins: { string },
}

-- Returns a fresh default profile.
local function defaultProfile(): PlayerProfile
	return {
		wins = 0,
		losses = 0,
		totalKills = 0,
		unlockedSkins = {},
	}
end

-- In-memory cache: Player → profile
local cache: { [Player]: PlayerProfile } = {}

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
		if result.unlockedSkins and typeof(result.unlockedSkins) == "table" then
			profile.unlockedSkins = result.unlockedSkins
		end
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
function PlayerData.save(player: Player)
	local profile = cache[player]
	if not profile then
		return
	end

	local ds = getStore()
	if not ds then
		warn("[PlayerData] DataStore unavailable; cannot save profile for " .. player.Name)
		return
	end

	local key = keyFor(player)
	local ok, err = pcall(function()
		ds:SetAsync(key, profile)
	end)

	if not ok then
		warn("[PlayerData] Failed to save profile for " .. player.Name .. ": " .. tostring(err))
	end
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

-- Clean up: save and remove from cache when a player leaves.
Players.PlayerRemoving:Connect(function(player: Player)
	PlayerData.save(player)
	cache[player] = nil
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
