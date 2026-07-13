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
local TOP_N = 10
local REQUEST_COOLDOWN = 5 -- seconds between board requests per player
local CACHE_TTL = 30 -- seconds before the cached board is refetched

local store: OrderedDataStore? = nil

local function getStore(): OrderedDataStore?
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
	local ds = getStore()
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

export type Row = { name: string, rating: number }

-- Cached top rows so bursts of requests don't hammer the DataStore.
local cachedRows: { Row } = {}
local cachedAt = 0
local fetching = false

local function fetchTop(): { Row }
	local ds = getStore()
	if not ds then
		return cachedRows
	end
	local ok, pages = pcall(function()
		return ds:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		warn("[Leaderboard] Failed to fetch board: " .. tostring(pages))
		return cachedRows
	end
	local rows: { Row } = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(rows, { name = nameFor(userId), rating = entry.value })
		end
	end
	cachedRows = rows
	cachedAt = os.clock()
	return rows
end

local lastRequest: { [Player]: number } = {}

Remotes.RequestLeaderboard.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now

	if now - cachedAt < CACHE_TTL and #cachedRows > 0 then
		Remotes.LeaderboardData:FireClient(player, cachedRows)
		return
	end
	if fetching then
		Remotes.LeaderboardData:FireClient(player, cachedRows)
		return
	end
	fetching = true
	task.spawn(function()
		local rows = fetchTop()
		fetching = false
		if player.Parent then
			Remotes.LeaderboardData:FireClient(player, rows)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

return Leaderboard
