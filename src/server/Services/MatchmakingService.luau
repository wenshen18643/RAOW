--!strict
-- Universe-wide PvP queue. MemoryStore atomically claims pairs; source lobby
-- servers poll server-only assignments and teleport their local player into the
-- same reserved instance. All records expire to recover from crashed servers.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Telemetry = require(script.Parent.Telemetry)
local PlayerData = require(script.Parent.PlayerData)
local BotIdentity = require(script.Parent.BotIdentity)

local BOT_FALLBACK_SECONDS = 90

local MatchmakingService = {}
-- MemoryStore handles are created lazily: GetQueue/GetHashMap throw in
-- unpublished places (e.g. a local build.rbxl in Studio), which would kill the
-- whole server boot if run at require time.
local queue: MemoryStoreQueue = nil :: any
local presence: MemoryStoreHashMap = nil :: any
local assignments: MemoryStoreHashMap = nil :: any
local storesReady = false

local function ensureStores(): boolean
	if storesReady then return true end
	local ok, err = pcall(function()
		queue = MemoryStoreService:GetQueue("raow_pvp_queue_v2", 20)
		presence = MemoryStoreService:GetHashMap("raow_pvp_presence_v2")
		assignments = MemoryStoreService:GetHashMap("raow_pvp_assignments_v2")
	end)
	if not ok then
		warn("[Matchmaking] MemoryStore unavailable:", err)
	end
	storesReady = ok
	return ok
end

local tickets: { [Player]: string } = {}
local queuedAt: { [Player]: number } = {}
local pending: { [Player]: { code: string, data: any, attempts: number } } = {}
local started = false

local function playerKey(userId: number): string
	return `player_{userId}`
end

local function queueStatus(player: Player)
	local ok, size = pcall(function() return queue:GetSizeAsync(true) end)
	Remotes.MatchEvent:FireClient(player, "QueueStatus", { position = ok and math.max(1, size) or 1, size = ok and size or 1 })
end

local function clearLocal(player: Player)
	tickets[player] = nil
	queuedAt[player] = nil
	pending[player] = nil
	pcall(function() presence:RemoveAsync(playerKey(player.UserId)) end)
end

local enqueue: (Player) -> ()
enqueue = function(player: Player)
	if player.Parent ~= Players or tickets[player] or pending[player] then return end
	if not ensureStores() then
		Remotes.MatchEvent:FireClient(player, "QueueError", { message = "MATCHMAKING UNAVAILABLE ON THIS SERVER" })
		return
	end
	local ticket = HttpService:GenerateGUID(false)
	local item = { userId = player.UserId, jobId = game.JobId, ticket = ticket, queuedAt = os.time() }
	local ok, err = pcall(function()
		presence:SetAsync(playerKey(player.UserId), { jobId = game.JobId, ticket = ticket }, 90)
		queue:AddAsync(item, 90, 0)
	end)
	if not ok then
		Telemetry.event(player, "queue_backend_failed")
		Remotes.MatchEvent:FireClient(player, "QueueError", { message = "MATCHMAKING SERVICE BUSY • RETRYING" })
		task.delay(3, function() enqueue(player) end)
		warn("[Matchmaking] enqueue failed:", err)
		return
	end
	tickets[player] = ticket
	if not queuedAt[player] then queuedAt[player] = os.clock() end
	Telemetry.event(player, "queue_joined")
	queueStatus(player)
end

local function restore(player: Player, reason: string)
	pending[player] = nil
	tickets[player] = nil
	queuedAt[player] = nil
	if player.Parent == Players then
		Remotes.MatchEvent:FireClient(player, "QueueError", { message = reason })
		task.delay(2, function() enqueue(player) end)
	end
end

-- No human pair after the fallback window: hand the player an unranked bot match.
-- Same MATCH FOUND flow and reserved-server teleport as a real pairing.
local function startBotFallback(player: Player)
	local ticket = tickets[player]
	if not ticket then return end
	tickets[player] = nil
	queuedAt[player] = nil
	pcall(function() presence:RemoveAsync(playerKey(player.UserId)) end)

	local reserved, accessCode = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	if not reserved or typeof(accessCode) ~= "string" then
		Telemetry.count("bot_match_reservation_failed")
		restore(player, "MATCHMAKING SERVICE BUSY • RETRYING")
		return
	end
	local rating = PlayerData.get(player).rating
	local data = {
		mode = "pvp_bot_match",
		userId = player.UserId,
		botName = BotIdentity.pickName(),
		botRating = BotIdentity.ratingNear(rating),
		createdAt = os.time(),
	}
	pending[player] = { code = accessCode, data = data, attempts = 0 }
	Remotes.MatchEvent:FireClient(player, "MatchFound", {})
	Telemetry.event(player, "bot_match_started")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(data)
	local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
	if not ok then
		Telemetry.event(player, "match_teleport_failed")
		restore(player, "MATCH TELEPORT FAILED • RETURNED TO QUEUE")
		warn("[Matchmaking] Bot fallback teleport failed:", err)
	end
end

local function teleportAssigned(player: Player, assignment: any)
	local ticket = tickets[player]
	if not ticket or assignment.ticket ~= ticket or typeof(assignment.code) ~= "string" or typeof(assignment.data) ~= "table" then return end
	tickets[player] = nil
	pending[player] = { code = assignment.code, data = assignment.data, attempts = 0 }
	pcall(function() assignments:RemoveAsync(playerKey(player.UserId)) end)
	pcall(function() presence:RemoveAsync(playerKey(player.UserId)) end)
	Remotes.MatchEvent:FireClient(player, "MatchFound", {})
	Telemetry.event(player, "match_found")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = assignment.code
	options:SetTeleportData(assignment.data)
	local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
	if not ok then
		Telemetry.event(player, "match_teleport_failed")
		restore(player, "MATCH TELEPORT FAILED • RETURNED TO QUEUE")
		warn("[Matchmaking] TeleportAsync failed:", err)
	end
end

local function validPresence(item: any): boolean
	if typeof(item) ~= "table" or typeof(item.userId) ~= "number" or typeof(item.ticket) ~= "string" then return false end
	local ok, record = pcall(function() return presence:GetAsync(playerKey(item.userId)) end)
	return ok and typeof(record) == "table" and record.ticket == item.ticket and record.jobId == item.jobId
end

local function coordinateOnePair()
	local ok, items, readId = pcall(function() return queue:ReadAsync(2, true, 2) end)
	if not ok or #items ~= 2 then return end
	local first, second = items[1], items[2]
	local firstValid, secondValid = validPresence(first), validPresence(second)
	if not firstValid or not secondValid or first.userId == second.userId then
		pcall(function() queue:RemoveAsync(readId) end)
		if firstValid then pcall(function() queue:AddAsync(first, 60, 0) end) end
		if secondValid and second.userId ~= first.userId then pcall(function() queue:AddAsync(second, 60, 0) end) end
		return
	end
	local reserved, accessCode = pcall(function()
		local code = TeleportService:ReserveServerAsync(game.PlaceId)
		return code
	end)
	if not reserved or typeof(accessCode) ~= "string" then
		Telemetry.count("match_reservation_failed")
		return -- invisibility timeout safely releases both entries
	end
	local data = {
		mode = "pvp_match",
		matchId = HttpService:GenerateGUID(false),
		userIds = { first.userId, second.userId },
		createdAt = os.time(),
	}
	local assigned = pcall(function()
		assignments:SetAsync(playerKey(first.userId), { ticket = first.ticket, code = accessCode, data = data }, 120)
		assignments:SetAsync(playerKey(second.userId), { ticket = second.ticket, code = accessCode, data = data }, 120)
	end)
	if assigned then
		pcall(function() presence:RemoveAsync(playerKey(first.userId)) end)
		pcall(function() presence:RemoveAsync(playerKey(second.userId)) end)
		pcall(function() queue:RemoveAsync(readId) end)
	else
		pcall(function() assignments:RemoveAsync(playerKey(first.userId)) end)
		pcall(function() assignments:RemoveAsync(playerKey(second.userId)) end)
		Telemetry.count("match_assignment_failed")
	end
end

function MatchmakingService.enqueue(player: Player)
	enqueue(player)
end

function MatchmakingService.start()
	if started then return end
	if not ensureStores() then return end
	started = true
	Players.PlayerRemoving:Connect(clearLocal)
	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		local info = pending[player]
		if not info then return end
		info.attempts += 1
		Telemetry.event(player, "teleport_retry", info.attempts)
		if info.attempts >= 3 then restore(player, message) return end
		task.delay(info.attempts, function()
			if player.Parent ~= Players or pending[player] ~= info then return end
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = info.code
			options:SetTeleportData(info.data)
			local retryOk = pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
			if not retryOk and info.attempts >= 2 then restore(player, message) end
		end)
	end)

	-- Every lobby can coordinate; queue invisibility makes pair claims atomic.
	task.spawn(function()
		while true do
			coordinateOnePair()
			task.wait(3)
		end
	end)
	-- Assignment polling is reliable even if the coordinating lobby shuts down.
	task.spawn(function()
		while true do
			for player, ticket in tickets do
				if player.Parent == Players then
					local ok, assignment = pcall(function() return assignments:GetAsync(playerKey(player.UserId)) end)
					if ok and typeof(assignment) == "table" and assignment.ticket == ticket then
						teleportAssigned(player, assignment)
					elseif tickets[player] and os.clock() - (queuedAt[player] or os.clock()) >= BOT_FALLBACK_SECONDS then
						startBotFallback(player)
					end
				end
			end
			task.wait(2)
		end
	end)
	-- Keep queued-player presence alive; stale queue entries are discarded.
	task.spawn(function()
		while true do
			task.wait(20)
			for player, ticket in tickets do
				if player.Parent == Players then
					pcall(function() presence:SetAsync(playerKey(player.UserId), { jobId = game.JobId, ticket = ticket }, 90) end)
					queueStatus(player)
				end
			end
		end
	end)
	print("[AgeOfWarFP] Universe-wide matchmaking lobby ready")
end

return MatchmakingService
