--!strict
-- Global rating leaderboard backed by an OrderedDataStore.
-- Ratings are submitted whenever a profile saves; clients request the top
-- rows via the RequestLeaderboard remote (rate limited per player).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Leaderboard = {}

local STORE_NAME = "RatingBoard_v1"
local STORE_NAME_PVE = "PvELevels_v1"
local TOP_N = 10
local REQUEST_COOLDOWN = 5 -- seconds between board requests per player
local CACHE_TTL = 30 -- seconds before the cached board is refetched

local store: OrderedDataStore? = nil
local storePve: OrderedDataStore? = nil

local function getStore(isPve: boolean?): OrderedDataStore?
	if isPve then
		if storePve then return storePve end
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(STORE_NAME_PVE)
		end)
		if ok then
			storePve = result
			return storePve
		end
		warn("[Leaderboard] Failed to access PvE OrderedDataStore: " .. tostring(result))
		return nil
	end
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	else
		warn("[Leaderboard] Failed to access OrderedDataStore: " .. tostring(result))
		return nil
	end
end

-- Username cache: UserId -> name (avoids repeated GetNameFromUserIdAsync calls)
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = ok and name or ("Player" .. tostring(userId))
	nameCache[userId] = resolved
	return resolved
end

-- Writes a player's rating to the board. Fire-and-forget; failures only warn.
function Leaderboard.submit(userId: number, rating: number)
	local ds = getStore(false)
	if not ds then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ds:SetAsync(tostring(userId), math.round(rating))
		end)
		if not ok then
			warn("[Leaderboard] Failed to submit rating for " .. tostring(userId) .. ": " .. tostring(err))
		end
	end)
end

function Leaderboard.submitPveLevel(userId: number, level: number)
	local ds = getStore(true)
	if not ds then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ds:SetAsync(tostring(userId), math.round(level))
		end)
		if not ok then
			warn("[Leaderboard] Failed to submit PvE level for " .. tostring(userId) .. ": " .. tostring(err))
		end
	end)
end

export type Row = { name: string, rating: number }

local cachedRows: { Row } = {}
local cachedPveRows: { Row } = {}
local cachedAt = 0
local cachedPveAt = 0
local fetching = false
local fetchingPve = false

local function fetchTop(isPve: boolean?): { Row }
	local ds = getStore(isPve)
	if not ds then
		return isPve and cachedPveRows or cachedRows
	end
	local ok, pages = pcall(function()
		return ds:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		warn("[Leaderboard] Failed to fetch board: " .. tostring(pages))
		return isPve and cachedPveRows or cachedRows
	end
	local rows: { Row } = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(rows, { name = nameFor(userId), rating = entry.value })
		end
	end
	if isPve then
		cachedPveRows = rows
		cachedPveAt = os.clock()
	else
		cachedRows = rows
		cachedAt = os.clock()
	end
	return rows
end

local lastRequest: { [Player]: number } = {}

Remotes.RequestLeaderboard.OnServerEvent:Connect(function(player, boardType: string?)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now

	local isPve = boardType == "pve"
	local cacheTime = isPve and cachedPveAt or cachedAt
	local cache = isPve and cachedPveRows or cachedRows
	local isFetching = isPve and fetchingPve or fetching

	if now - cacheTime < CACHE_TTL and #cache > 0 then
		Remotes.LeaderboardData:FireClient(player, boardType or "pvp", cache)
		return
	end
	if isFetching then
		Remotes.LeaderboardData:FireClient(player, boardType or "pvp", cache)
		return
	end
	if isPve then fetchingPve = true else fetching = true end
	task.spawn(function()
		local rows = fetchTop(isPve)
		if isPve then fetchingPve = false else fetching = false end
		if player.Parent then
			Remotes.LeaderboardData:FireClient(player, boardType or "pvp", rows)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

return Leaderboard
