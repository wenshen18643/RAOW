--!strict
-- Bootstrap: build map, run match loops, wire remotes, restart on match end.
-- Integrates difficulty selection, status effects, player data, and dynamic AI tick rate.

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
local StatusEffectSystem = require(Services.StatusEffectSystem)
local PlayerData = require(Services.PlayerData)
local Telemetry = require(Services.Telemetry)
require(Services.ProductionChecks).run()

local isReservedMatch = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not RunService:IsStudio() and not isReservedMatch then
	require(Services.LobbyBuilder).build()
	require(Services.MatchmakingService).start()
	return
end

Players.CharacterAutoLoads = false

local map = MapBuilder.build()
Environment.setup(map)

-- Difficulty state: selected by host player before match starts, defaults to Normal
local selectedDifficulty: string = DifficultyConfig.DEFAULT
local currentMatch = Match.new(map, selectedDifficulty)
local playerSides: { [Player]: string } = {}
local sidePlayers: { [string]: Player? } = { A = nil, B = nil }
local playerReady: { [Player]: boolean } = {}
local actionTimes: { [Player]: { [string]: number } } = {}
local expectedMatchId: string? = nil

local function sideFor(player: Player): string?
	return playerSides[player]
end

local function allowAction(player: Player, action: string, interval: number): boolean
	if not sideFor(player) or currentMatch.status ~= "Active" then
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
	return currentMatch
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

local wireMatch: (Match.Match) -> ()

local function tryStartMatch()
	if sidePlayers.A and sidePlayers.B and playerReady[sidePlayers.A] and playerReady[sidePlayers.B] and Match.start(currentMatch) then
		Telemetry.event(sidePlayers.A, "pvp_match_started", 1, { matchId = expectedMatchId or "studio" })
		Telemetry.event(sidePlayers.B, "pvp_match_started", 1, { matchId = expectedMatchId or "studio" })
		Remotes.MatchEvent:FireAllClients("MatchStart", { difficulty = selectedDifficulty })
		for _, player in { sidePlayers.A, sidePlayers.B } do
			if player then player:LoadCharacter() end
		end
	else
		for _, player in Players:GetPlayers() do
			Remotes.MatchEvent:FireClient(player, "WaitingForOpponent", {})
		end
	end
end

-- Tears down the current match and starts a fresh one at selectedDifficulty.
local function startNewMatch()
	UnitSim.clearAll(currentMatch)
	TurretSystem.clearAll(currentMatch)
	StatusEffectSystem.clearAll(currentMatch)
	resetMap()
	currentMatch = Match.new(map, selectedDifficulty)
	wireMatch(currentMatch)
	tryStartMatch()
end

function wireMatch(match: Match.Match)
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
				startNewMatch()
				return
			end
			local survivors = Players:GetPlayers()
			if #survivors > 0 and not RunService:IsStudio() then
				local ok, err = pcall(function()
					TeleportService:TeleportAsync(game.PlaceId, survivors)
				end)
				if not ok then warn("[PvP] Failed to return players to lobby:", err) end
			end
		end)
	end
end
wireMatch(currentMatch)

-- Difficulty selection (from the main menu PLAY flow): starts a fresh match
-- at the chosen difficulty so the choice always takes effect immediately.
Remotes.SelectDifficulty.OnServerEvent:Connect(function(player, difficulty)
	local side = sideFor(player)
	if side and currentMatch.status == "Waiting" and typeof(difficulty) == "string" and DifficultyConfig.LEVELS[difficulty] then
		playerReady[player] = true
		if side == "A" then
			selectedDifficulty = difficulty
			currentMatch.difficulty = difficulty
			Remotes.DifficultySelected:FireAllClients(difficulty)
		end
		print(`[AgeOfWarFP] Difficulty set to: {difficulty} — starting fresh match`)
		tryStartMatch()
	end
end)

-- Remote handlers (single-player MVP: every player controls side A)
Remotes.SpawnUnit.OnServerEvent:Connect(function(player, unitId)
	local side = sideFor(player)
	if side and allowAction(player, "spawn", 0.08) and typeof(unitId) == "string" and #unitId <= 64 then
		UnitSim.requestSpawn(currentMatch, side, unitId)
	end
end)

Remotes.BuildTurret.OnServerEvent:Connect(function(player, slot)
	local side = sideFor(player)
	if side and allowAction(player, "turret", 0.2) and validSlot(slot) then
		TurretSystem.tryBuild(currentMatch, side, slot)
	end
end)

Remotes.SellTurret.OnServerEvent:Connect(function(player, slot)
	local side = sideFor(player)
	if side and allowAction(player, "turret", 0.2) and validSlot(slot) then
		TurretSystem.trySell(currentMatch, side, slot)
	end
end)

Remotes.UseSpecial.OnServerEvent:Connect(function(player)
	local side = sideFor(player)
	if side and allowAction(player, "special", 0.3) then SpecialSystem.tryCast(currentMatch, side) end
end)

Remotes.Evolve.OnServerEvent:Connect(function(player)
	local side = sideFor(player)
	if side and allowAction(player, "evolve", 0.3) then Match.tryEvolve(currentMatch, side) end
end)

Remotes.FireWeapon.OnServerEvent:Connect(function(player, origin, direction)
	HeroSystem.handleFire(currentMatch, player, origin, direction, false)
end)

Remotes.FireWeaponSecondary.OnServerEvent:Connect(function(player, origin, direction)
	HeroSystem.handleFire(currentMatch, player, origin, direction, true)
end)

Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, stat)
	if not allowAction(player, "upgrade", 0.15) or typeof(stat) ~= "string" then return end
	HeroSystem.buyUpgrade(currentMatch, player, stat)
end)

Remotes.LeaveMatch.OnServerEvent:Connect(function(player)
	if currentMatch.status ~= "Ended" or not sideFor(player) or RunService:IsStudio() then return end
	playerReady[player] = false
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
end)

-- Player join: load data, bind hero, load character
Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
	local side: string? = nil
	if RunService:IsStudio() then
		side = sidePlayers.A == nil and "A" or (sidePlayers.B == nil and "B" or nil)
	else
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
	end
	if not side then
		player:Kick("Invalid or expired PvP match ticket.")
		PlayerData.unload(player)
		return
	end
	playerSides[player] = side
	playerReady[player] = not RunService:IsStudio() -- validated teleport tickets are already ready
	sidePlayers[side] = player
	player:SetAttribute("Side", side)
	HeroSystem.bindPlayer(getMatch, player)
	player:LoadCharacter()
	tryStartMatch()
	if not joinTimeoutScheduled and currentMatch.status == "Waiting" and not RunService:IsStudio() then
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

Players.PlayerRemoving:Connect(function(player)
	local side = playerSides[player]
	if side then
		if currentMatch.status == "Active" then
			currentMatch.status = "Ended"
			currentMatch.winner = Match.enemyOf(side)
			if currentMatch.onEnd then currentMatch.onEnd(currentMatch.winner :: string) end
		end
		playerSides[player] = nil
		playerReady[player] = nil
		sidePlayers[side] = nil
		actionTimes[player] = nil
	end
	PlayerData.unload(player)
end)

-- Loops
local simAccum = 0
RunService.Heartbeat:Connect(function(dt)
	simAccum += dt
	local step = 1 / GameConfig.SIM_RATE
	if simAccum >= step then
		UnitSim.tick(currentMatch, simAccum)
		HeroSystem.tickMovement(currentMatch)
		-- Status effect processing runs alongside unit sim (Phase 4)
		StatusEffectSystem.tick(currentMatch, simAccum)
		simAccum = 0
	end
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		Match.tickEconomy(currentMatch, os.clock())
		TurretSystem.tick(currentMatch)
	end
end)



-- PvP servers do not run the campaign AI. Both sides are player controlled.

task.spawn(function()
	while true do
		task.wait(1 / GameConfig.STATE_SYNC_RATE)
		for _, player in Players:GetPlayers() do
			local side = sideFor(player)
			if side then
				local snapshot = Match.buildSnapshot(currentMatch, side)
				local opponent = sidePlayers[Match.enemyOf(side)]
				snapshot.opponentName = opponent and opponent.DisplayName or "Waiting..."
				snapshot.matchId = expectedMatchId
				Remotes.StateUpdate:FireClient(player, snapshot)
			end
		end
	end
end)

-- debug handle for Studio testing: DebugCmd:Invoke("addGold", side, amount) etc.
if RunService:IsStudio() then
local debugCmd = Instance.new("BindableFunction")
debugCmd.Name = "DebugCmd"
debugCmd.Parent = game:GetService("ServerStorage")
debugCmd.OnInvoke = function(cmd: string, ...)
	local match = currentMatch
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
			selectedDifficulty = diff
			currentMatch.difficulty = diff
			return true
		end
	end
	return nil
end
end

print("[AgeOfWarFP] Server ready")
