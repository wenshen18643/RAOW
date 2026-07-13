--!strict
-- Bootstrap: supports both PvE (lobby local match vs AI) and PvP (reserved server 1v1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DifficultyConfig = require(ReplicatedStorage.Shared.Config.DifficultyConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Services = script.Services
local MapBuilder = require(Services.MapBuilder)
local Environment = require(Services.Environment)
local Match = require(Services.Match)
local UnitSim = require(Services.UnitSim)
local TurretSystem = require(Services.TurretSystem)
local SpecialSystem = require(Services.SpecialSystem)
local HeroSystem = require(Services.HeroSystem)
local AIBrain = require(Services.AIBrain)
local StatusEffectSystem = require(Services.StatusEffectSystem)
local PlayerData = require(Services.PlayerData)
local Telemetry = require(Services.Telemetry)
local MatchmakingService = require(Services.MatchmakingService)
local LobbyBuilder = require(Services.LobbyBuilder)
require(Services.ProductionChecks).run()

Players.CharacterAutoLoads = false

local isReservedMatch = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local isStudio = RunService:IsStudio()
local isLobby = not isStudio and not isReservedMatch

local map = MapBuilder.build()
Environment.setup(map)

local currentMatch: Match.Match? = nil
local playerSides: { [Player]: string } = {}
local sidePlayers: { [string]: Player? } = { A = nil, B = nil }
local playerReady: { [Player]: boolean } = {}
local actionTimes: { [Player]: { [string]: number } } = {}
local expectedMatchId: string? = nil
local matchMode: "PvE" | "PvP" = "PvE"
local simAccum = 0

local function sideFor(player: Player): string?
	return playerSides[player]
end

local function allowAction(player: Player, action: string, interval: number): boolean
	local match = currentMatch
	if not match or not sideFor(player) or match.status ~= "Active" then
		Telemetry.count(`remote_rejected_{action}`)
		return false
	end
	local now = os.clock()
	local times = actionTimes[player] or {}
	actionTimes[player] = times
	if now - (times[action] or 0) < interval then
		Telemetry.count(`remote_rate_limited_{action}`)
		return false
	end
	times[action] = now
	return true
end

local function validSlot(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= GameConfig.TURRET_SLOTS and value % 1 == 0
end

local function getMatch(): Match.Match
	return currentMatch :: Match.Match
end

local RESTART_DELAY = 10
local MATCH_JOIN_TIMEOUT = 60
local joinTimeoutScheduled = false

local function resetMap()
	for _, base in map.bases do
		base.core:SetAttribute("Hp", GameConfig.BASE_MAX_HP)
		base.core.Color = base.side == "A" and Color3.fromRGB(52, 120, 200) or Color3.fromRGB(200, 70, 60)
	end
end

local function clearMatchState()
	local match = currentMatch
	if match then
		UnitSim.clearAll(match)
		TurretSystem.clearAll(match)
		StatusEffectSystem.clearAll(match)
	end
	resetMap()
	currentMatch = nil
	playerSides = {}
	sidePlayers = { A = nil, B = nil }
	playerReady = {}
	actionTimes = {}
	expectedMatchId = nil
	joinTimeoutScheduled = false
end

local function wireMatch(match: Match.Match)
	match.onAgeUp = function(side, newAge)
		Remotes.MatchEvent:FireAllClients("AgeUp", { side = side, age = newAge })
		local player = sidePlayers[side]
		if player then HeroSystem.onAgeUp(match, player) end
	end
	match.onBaseDamaged = function(side, amount)
		local player = sidePlayers[side]
		if player then Remotes.MatchEvent:FireClient(player, "BaseUnderAttack", { amount = amount }) end
	end
	match.onEnd = function(winner)
		if match.resultCommitted then return end
		match.resultCommitted = true

		if matchMode == "PvE" then
			local player = sidePlayers["A"]
			if player then
				if winner == "A" then
					PlayerData.recordWin(player)
					Telemetry.event(player, "pve_match_won", os.clock() - match.startedAt)
				else
					PlayerData.recordLoss(player)
					Telemetry.event(player, "pve_match_lost", os.clock() - match.startedAt)
				end
				Remotes.MatchEvent:FireClient(player, winner == "A" and "Victory" or "Defeat", { restartIn = RESTART_DELAY })
			end
			task.delay(RESTART_DELAY, function()
				-- In a lobby server the player never left; just clear the match and reopen the menu.
				if currentMatch ~= match then return end
				for _, player in Players:GetPlayers() do
					Remotes.MatchEvent:FireClient(player, "ReturnToMenu", {})
				end
				clearMatchState()
			end)
		else
			local winnerPlayer = sidePlayers[winner]
			local loserPlayer = sidePlayers[Match.enemyOf(winner)]
			local winnerDelta, loserDelta = 0, 0
			if winnerPlayer and loserPlayer then
				winnerDelta, loserDelta = PlayerData.recordMatch(winnerPlayer, loserPlayer)
			elseif winnerPlayer then
				PlayerData.recordWin(winnerPlayer)
			end
			Telemetry.event(winnerPlayer, "pvp_match_won", os.clock() - match.startedAt, { matchId = expectedMatchId or "studio" })
			Telemetry.event(loserPlayer, "pvp_match_lost", os.clock() - match.startedAt, { matchId = expectedMatchId or "studio" })
			for side, player in sidePlayers do
				if player then
					local won = side == winner
					Remotes.MatchEvent:FireClient(player, won and "Victory" or "Defeat", {
						restartIn = RESTART_DELAY,
						ratingDelta = won and winnerDelta or loserDelta,
					})
				end
			end
			task.delay(RESTART_DELAY, function()
				if sidePlayers.A and sidePlayers.B then
					-- Both still here: start a rematch in place.
					UnitSim.clearAll(match)
					TurretSystem.clearAll(match)
					StatusEffectSystem.clearAll(match)
					resetMap()
					currentMatch = Match.new(map, match.difficulty)
					currentMatch.mode = matchMode
					wireMatch(currentMatch)
					Match.start(currentMatch)
					for side, player in sidePlayers do
						if player then
							player:SetAttribute("Side", side)
							HeroSystem.bindPlayer(getMatch, player)
							player:LoadCharacter()
						end
					end
					return
				end
				local survivors = Players:GetPlayers()
				if #survivors > 0 and not isStudio then
					pcall(function() TeleportService:TeleportAsync(game.PlaceId, survivors) end)
				end
			end)
		end
	end
end

local function assignPlayer(player: Player, side: string)
	playerSides[player] = side
	sidePlayers[side] = player
	player:SetAttribute("Side", side)
	HeroSystem.bindPlayer(getMatch, player)
end

local function startMatch()
	local match = currentMatch
	if not match or match.status ~= "Waiting" then return end
	Match.start(match)
	Remotes.MatchEvent:FireAllClients("MatchStart", { difficulty = match.difficulty, mode = matchMode })
	for _, player in Players:GetPlayers() do
		local side = sideFor(player)
		if side then player:LoadCharacter() end
	end
end

local function startPvE(player: Player, difficulty: string)
	if currentMatch then
		Remotes.MatchEvent:FireClient(player, "QueueError", { message = "A match is already running in this lobby." })
		return
	end
	if not DifficultyConfig.LEVELS[difficulty] then
		difficulty = DifficultyConfig.DEFAULT
	end

	matchMode = "PvE"
	currentMatch = Match.new(map, difficulty)
	currentMatch.mode = matchMode
	wireMatch(currentMatch)
	assignPlayer(player, "A")
	playerReady[player] = true

	startMatch()
end

local function tryStartPvP()
	local match = currentMatch
	if not match then return end
	if sidePlayers.A and sidePlayers.B and playerReady[sidePlayers.A] and playerReady[sidePlayers.B] then
		startMatch()
	else
		for _, player in Players:GetPlayers() do
			Remotes.MatchEvent:FireClient(player, "WaitingForOpponent", {})
		end
	end
end

local function initPvPReservedServer()
	matchMode = "PvP"
	currentMatch = Match.new(map, DifficultyConfig.DEFAULT)
	currentMatch.mode = matchMode
	wireMatch(currentMatch)

	Players.PlayerAdded:Connect(function(player)
		PlayerData.load(player)
		local side: string? = nil
		local joinData = player:GetJoinData()
		local teleportData = joinData.TeleportData
		if typeof(teleportData) == "table"
			and joinData.SourcePlaceId == game.PlaceId
			and teleportData.mode == "pvp_match"
			and typeof(teleportData.matchId) == "string"
			and typeof(teleportData.createdAt) == "number"
			and math.abs(os.time() - teleportData.createdAt) <= 600
			and typeof(teleportData.userIds) == "table" then
			if expectedMatchId == nil then expectedMatchId = teleportData.matchId end
			if teleportData.matchId == expectedMatchId then
				if teleportData.userIds[1] == player.UserId then side = "A" end
				if teleportData.userIds[2] == player.UserId then side = "B" end
			end
		end
		if not side then
			player:Kick("Invalid or expired PvP match ticket.")
			PlayerData.unload(player)
			return
		end
		assignPlayer(player, side)
		playerReady[player] = true
		player:LoadCharacter()
		tryStartPvP()
		if not joinTimeoutScheduled and currentMatch and currentMatch.status == "Waiting" then
			joinTimeoutScheduled = true
			local waitingMatch = currentMatch
			task.delay(MATCH_JOIN_TIMEOUT, function()
				if currentMatch ~= waitingMatch or waitingMatch.status ~= "Waiting" then return end
				local waitingPlayers = Players:GetPlayers()
				for _, waitingPlayer in waitingPlayers do
					Remotes.MatchEvent:FireClient(waitingPlayer, "OpponentJoinFailed", {})
				end
				task.wait(2)
				if #waitingPlayers > 0 then
					pcall(function() TeleportService:TeleportAsync(game.PlaceId, waitingPlayers) end)
				end
			end)
		end
	end)
end

-- Remote handlers
Remotes.SpawnUnit.OnServerEvent:Connect(function(player, unitId)
	local match = currentMatch
	local side = sideFor(player)
	if match and side and allowAction(player, "spawn", 0.08) and typeof(unitId) == "string" and #unitId <= 64 then
		UnitSim.requestSpawn(match, side, unitId)
	end
end)

Remotes.BuildTurret.OnServerEvent:Connect(function(player, slot)
	local match = currentMatch
	local side = sideFor(player)
	if match and side and allowAction(player, "turret", 0.2) and validSlot(slot) then
		TurretSystem.tryBuild(match, side, slot)
	end
end)

Remotes.SellTurret.OnServerEvent:Connect(function(player, slot)
	local match = currentMatch
	local side = sideFor(player)
	if match and side and allowAction(player, "turret", 0.2) and validSlot(slot) then
		TurretSystem.trySell(match, side, slot)
	end
end)

Remotes.UseSpecial.OnServerEvent:Connect(function(player)
	local match = currentMatch
	local side = sideFor(player)
	if match and side and allowAction(player, "special", 0.3) then SpecialSystem.tryCast(match, side) end
end)

Remotes.Evolve.OnServerEvent:Connect(function(player)
	local match = currentMatch
	local side = sideFor(player)
	if match and side and allowAction(player, "evolve", 0.3) then Match.tryEvolve(match, side) end
end)

Remotes.FireWeapon.OnServerEvent:Connect(function(player, origin, direction)
	local match = currentMatch
	if match then HeroSystem.handleFire(match, player, origin, direction, false) end
end)

Remotes.FireWeaponSecondary.OnServerEvent:Connect(function(player, origin, direction)
	local match = currentMatch
	if match then HeroSystem.handleFire(match, player, origin, direction, true) end
end)

Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, stat)
	local match = currentMatch
	if not match or not allowAction(player, "upgrade", 0.15) or typeof(stat) ~= "string" then return end
	HeroSystem.buyUpgrade(match, player, stat)
end)

Remotes.LeaveMatch.OnServerEvent:Connect(function(player)
	local match = currentMatch
	if not match or match.status ~= "Ended" or not sideFor(player) then return end
	playerReady[player] = false
	if isStudio then return end
	if matchMode == "PvE" then
		-- Lobby PvE: reopen the menu and free the match slot for a new game.
		Remotes.MatchEvent:FireClient(player, "ReturnToMenu", {})
		clearMatchState()
		return
	end
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
end)

-- Loops
RunService.Heartbeat:Connect(function(dt)
	local match = currentMatch
	if not match then
		simAccum = 0
		return
	end
	simAccum += dt
	local step = 1 / GameConfig.SIM_RATE
	if simAccum >= step then
		if matchMode == "PvE" and match.status == "Active" then
			AIBrain.tick(match)
		end
		UnitSim.tick(match, simAccum)
		HeroSystem.tickMovement(match)
		StatusEffectSystem.tick(match, simAccum)
		simAccum = 0
	end
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		local match = currentMatch
		if match then
			Match.tickEconomy(match, os.clock())
			TurretSystem.tick(match)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1 / GameConfig.STATE_SYNC_RATE)
		local match = currentMatch
		if match then
			for _, player in Players:GetPlayers() do
				local side = sideFor(player)
				if side then
					local snapshot = Match.buildSnapshot(match, side)
					local opponent = sidePlayers[Match.enemyOf(side)]
					snapshot.opponentName = opponent and opponent.DisplayName or "AI Commander"
					snapshot.matchId = expectedMatchId
					snapshot.mode = matchMode
					Remotes.StateUpdate:FireClient(player, snapshot)
				end
			end
		end
	end
end)

-- Server type branches
if isLobby or isStudio then
	if not isStudio then
		LobbyBuilder.build()
		MatchmakingService.start()
	end

	Remotes.SelectMode.OnServerEvent:Connect(function(player, mode, diffId)
		if mode == "pvp" then
			if isStudio then
				-- Reserved-server teleports don't work in Studio; run PvP as a local PvE match instead.
				Remotes.MatchEvent:FireClient(player, "QueueError", { message = "PvP unavailable in Studio — starting PvE match." })
				startPvE(player, DifficultyConfig.DEFAULT)
			else
				MatchmakingService.enqueue(player)
			end
		elseif mode == "pve" then
			startPvE(player, diffId)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerData.load(player)
		-- Lobby players wait in menu; character loads when a mode is selected.
	end)

	Players.PlayerRemoving:Connect(function(player)
		local side = sideFor(player)
		if side and currentMatch and currentMatch.status == "Active" then
			currentMatch.status = "Ended"
			currentMatch.winner = Match.enemyOf(side)
			if currentMatch.onEnd then currentMatch.onEnd(currentMatch.winner :: string) end
		end
		playerSides[player] = nil
		sidePlayers[side] = nil
		playerReady[player] = nil
		actionTimes[player] = nil
		PlayerData.unload(player)
	end)
else
	-- Reserved PvP server
	initPvPReservedServer()

	Players.PlayerRemoving:Connect(function(player)
		local side = sideFor(player)
		if side and currentMatch and currentMatch.status == "Active" then
			currentMatch.status = "Ended"
			currentMatch.winner = Match.enemyOf(side)
			if currentMatch.onEnd then currentMatch.onEnd(currentMatch.winner :: string) end
		end
		playerSides[player] = nil
		sidePlayers[side] = nil
		playerReady[player] = nil
		actionTimes[player] = nil
		PlayerData.unload(player)
	end)
end

-- debug handle for Studio testing
if isStudio then
	local debugCmd = Instance.new("BindableFunction")
	debugCmd.Name = "DebugCmd"
	debugCmd.Parent = game:GetService("ServerStorage")
	debugCmd.OnInvoke = function(cmd: string, ...)
		local match = currentMatch
		if not match then return nil end
		if cmd == "addGold" then
			local side, amount = ...
			match.sides[side].gold += amount
		elseif cmd == "addXp" then
			local side, amount = ...
			match.sides[side].xp += amount
		elseif cmd == "spawn" then
			local side, unitId = ...
			return UnitSim.requestSpawn(match, side, unitId)
		elseif cmd == "evolve" then
			return Match.tryEvolve(match, (...))
		elseif cmd == "state" then
			return Match.buildSnapshot(match, "A")
		elseif cmd == "sideState" then
			local s = match.sides[(...)]
			return { gold = s.gold, xp = s.xp, age = s.age, units = #s.units, queue = #s.queue, heroDeaths = s.heroDeaths }
		elseif cmd == "setDifficulty" then
			local diff = (...)
			if typeof(diff) == "string" and DifficultyConfig.LEVELS[diff] then
				match.difficulty = diff
				return true
			end
		end
		return nil
	end
end

print("[AgeOfWarFP] Server ready")
