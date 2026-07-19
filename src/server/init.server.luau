--!strict
-- Bootstrap: supports both PvE (lobby local match vs AI) and PvP (reserved server 1v1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DifficultyConfig = require(ReplicatedStorage.Shared.Config.DifficultyConfig)
local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
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
local LobbyFlex = require(Services.LobbyFlex)
local LobbyBots = require(Services.LobbyBots)
local MonetizationService = require(Services.MonetizationService)
require(Services.ProductionChecks).run()
MonetizationService.start()

Players.CharacterAutoLoads = false

local isReservedMatch = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local isStudio = RunService:IsStudio()
local isLobby = not isStudio and not isReservedMatch

local serverType = isReservedMatch and "match" or "lobby"
workspace:SetAttribute("ServerType", serverType)

-- The match world only exists where a match can actually run. Live lobby
-- servers skip it entirely: it buried the lobby island in map geometry and
-- doubled load time for players who never see the arena.
local map: MapBuilder.MapHandle? = nil
if isStudio or isReservedMatch then
	map = MapBuilder.build()
	Environment.setup(map :: MapBuilder.MapHandle)
end

local currentMatch: Match.Match? = nil
local playerSides: { [Player]: string } = {}
local sidePlayers: { [string]: Player? } = { A = nil, B = nil }
local playerReady: { [Player]: boolean } = {}
local actionTimes: { [Player]: { [string]: number } } = {}
local expectedMatchId: string? = nil
local matchMode: "PvE" | "PvP" = "PvE"
local simAccum = 0
local rematchVotes: { [Player]: boolean } = {}

local function sideFor(player: Player): string?
	return playerSides[player]
end

local function allowRate(player: Player, action: string, interval: number): boolean
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

local function allowAction(player: Player, action: string, interval: number): boolean
	local match = currentMatch
	if not match or not sideFor(player) or match.status ~= "Active" then
		Telemetry.count(`remote_rejected_{action}`)
		return false
	end
	return allowRate(player, action, interval)
end

local function loadPlayerProfile(player: Player)
	PlayerData.load(player)
	PlayerData.sync(player)
	MonetizationService.refreshSupporterEntitlement(player)
	local profile = PlayerData.get(player)
	Telemetry.event(player, "session_started", 1, {
		returning = profile.tutorialDone,
		level = profile.level,
		pveLevel = profile.pveLevel,
	})
end

local function validSlot(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= GameConfig.TURRET_SLOTS and value % 1 == 0
end

local function getMatch(): Match.Match
	return currentMatch :: Match.Match
end

local RESULT_TIMEOUT = 30
local MATCH_JOIN_TIMEOUT = 60
local joinTimeoutScheduled = false

local function resetMap()
	local m = map
	if not m then return end
	for _, base in m.bases do
		MapBuilder.evolveBase(m, base.side, 1, Ages[1].color)
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
	rematchVotes = {}
	actionTimes = {}
	expectedMatchId = nil
	joinTimeoutScheduled = false

	if isLobby or isStudio then
		for _, player in Players:GetPlayers() do
			player.CameraMode = Enum.CameraMode.Classic
		end
	end
end

local function teleportToLobby(players: { Player }): boolean
	if #players == 0 then return true end
	local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, players) end)
	if not ok then
		warn("[Match] Return-to-lobby teleport failed:", err)
		for _, player in players do
			Remotes.MatchEvent:FireClient(player, "ReturnError", { message = "Couldn't return to the lobby. Press Return to retry." })
		end
	end
	return ok
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

		if match.botMatch then
			local player = sidePlayers["A"]
			if player then
				local won = winner == "A"
				PlayerData.recordBotMatch(player, match.botRating or 1000, won)
				local xpResult = PlayerData.addXp(player, won and ProgressionConfig.XP_WIN or ProgressionConfig.XP_LOSS)
				PlayerData.addCoins(player, won and PvELevels.PVP_WIN_COINS or PvELevels.PVP_LOSS_COINS)
				local dailyWarBonds = PlayerData.recordDailyBattle(player, won)
				if dailyWarBonds > 0 then Telemetry.event(player, "daily_battle_bonds_earned", dailyWarBonds) end
				PlayerData.sync(player)
				task.spawn(function() PlayerData.save(player) end)
				Telemetry.event(player, won and "pvp_bot_match_won" or "pvp_bot_match_lost", os.clock() - match.startedAt)
				Remotes.MatchEvent:FireClient(player, won and "Victory" or "Defeat", {
					decisionIn = RESULT_TIMEOUT,
					xpData = xpResult,
					coins = won and PvELevels.PVP_WIN_COINS or PvELevels.PVP_LOSS_COINS,
					dailyWarBonds = dailyWarBonds,
				})
			end
			task.delay(RESULT_TIMEOUT, function()
				if currentMatch ~= match then return end
				local survivors = Players:GetPlayers()
				if isStudio then
					for _, p in survivors do
						p.CameraMode = Enum.CameraMode.Classic
						Remotes.MatchEvent:FireClient(p, "ReturnToMenu", {})
					end
					clearMatchState()
				elseif #survivors > 0 then
					teleportToLobby(survivors)
				end
			end)
		elseif matchMode == "PvE" then
			local player = sidePlayers["A"]
			if player then
				local xpResult
				local tutorialComplete = false
				if winner == "A" then
					PlayerData.recordWin(player)
					xpResult = PlayerData.addXp(player, ProgressionConfig.XP_WIN)
					Telemetry.event(player, "pve_match_won", os.clock() - match.startedAt)

					local profile = PlayerData.get(player)
					if not profile.tutorialDone then
						local tutXpResult = PlayerData.addXp(player, ProgressionConfig.XP_TUTORIAL)
						local combinedUnlocks = {}
						for _, unlock in ipairs(xpResult.unlocks) do
							table.insert(combinedUnlocks, unlock)
						end
						for _, unlock in ipairs(tutXpResult.unlocks) do
							table.insert(combinedUnlocks, unlock)
						end
						xpResult = {
							oldXp = xpResult.oldXp,
							newXp = tutXpResult.newXp,
							levelups = xpResult.levelups + tutXpResult.levelups,
							unlocks = combinedUnlocks,
							warBondsEarned = (xpResult.warBondsEarned or 0) + (tutXpResult.warBondsEarned or 0),
						}
						profile.tutorialDone = true
						tutorialComplete = true
					end
				else
					PlayerData.recordLoss(player)
					xpResult = PlayerData.addXp(player, ProgressionConfig.XP_LOSS)
					Telemetry.event(player, "pve_match_lost", os.clock() - match.startedAt)
				end
				local dailyWarBonds = PlayerData.recordDailyBattle(player, winner == "A")
				if dailyWarBonds > 0 then Telemetry.event(player, "daily_battle_bonds_earned", dailyWarBonds) end

				if winner == "A" then
					local victoryPayload: { decisionIn: number, xpData: any, tutorialComplete: boolean?, coins: number?, firstClear: boolean?, dailyWarBonds: number?, canNextStage: boolean? } = {
						decisionIn = RESULT_TIMEOUT,
						xpData = xpResult,
						dailyWarBonds = dailyWarBonds,
					}
					if tutorialComplete then
						victoryPayload.tutorialComplete = true
					end
					if matchMode == "PvE" and match.pveLevel and match.pveMode then
						local firstClear = PlayerData.recordPveClear(player, match.pveMode, match.pveLevel)
						local rewardCoins = PvELevels.coinsForClear(match.pveMode, match.pveLevel, not firstClear)
						PlayerData.addCoins(player, rewardCoins)
						victoryPayload.coins = rewardCoins
						victoryPayload.firstClear = firstClear
						victoryPayload.canNextStage = true
					end
					PlayerData.sync(player)
					task.spawn(function() PlayerData.save(player) end)
					Remotes.MatchEvent:FireClient(player, "Victory", victoryPayload)
				else
					local defeatPayload: { decisionIn: number, xpData: any, coins: number?, dailyWarBonds: number? } = {
						decisionIn = RESULT_TIMEOUT,
						xpData = xpResult,
						dailyWarBonds = dailyWarBonds,
					}
					if matchMode == "PvE" then
						defeatPayload.coins = 0
					end
					PlayerData.sync(player)
					task.spawn(function() PlayerData.save(player) end)
					Remotes.MatchEvent:FireClient(player, "Defeat", defeatPayload)
				end
			end
			task.delay(RESULT_TIMEOUT, function()
				if currentMatch ~= match then return end
				if isStudio then
					for _, player in Players:GetPlayers() do
						player.CameraMode = Enum.CameraMode.Classic
						Remotes.MatchEvent:FireClient(player, "ReturnToMenu", {})
					end
					clearMatchState()
				else
					local survivors = Players:GetPlayers()
					if #survivors > 0 then
						teleportToLobby(survivors)
					end
				end
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
			local winnerXp, loserXp = nil, nil
			local winnerDailyBonds, loserDailyBonds = 0, 0
			if winnerPlayer then
				winnerXp = PlayerData.addXp(winnerPlayer, ProgressionConfig.XP_WIN)
				PlayerData.addCoins(winnerPlayer, PvELevels.PVP_WIN_COINS)
				winnerDailyBonds = PlayerData.recordDailyBattle(winnerPlayer, true)
				PlayerData.sync(winnerPlayer)
				task.spawn(function() PlayerData.save(winnerPlayer) end)
				if winnerDailyBonds > 0 then Telemetry.event(winnerPlayer, "daily_battle_bonds_earned", winnerDailyBonds) end
				Telemetry.event(winnerPlayer, "pvp_match_won", os.clock() - match.startedAt, { matchId = expectedMatchId or "studio" })
			end
			if loserPlayer then
				loserXp = PlayerData.addXp(loserPlayer, ProgressionConfig.XP_LOSS)
				PlayerData.addCoins(loserPlayer, PvELevels.PVP_LOSS_COINS)
				loserDailyBonds = PlayerData.recordDailyBattle(loserPlayer, false)
				PlayerData.sync(loserPlayer)
				task.spawn(function() PlayerData.save(loserPlayer) end)
				if loserDailyBonds > 0 then Telemetry.event(loserPlayer, "daily_battle_bonds_earned", loserDailyBonds) end
				Telemetry.event(loserPlayer, "pvp_match_lost", os.clock() - match.startedAt, { matchId = expectedMatchId or "studio" })
			end
			for side, player in sidePlayers do
				if player then
					local won = side == winner
					Remotes.MatchEvent:FireClient(player, won and "Victory" or "Defeat", {
						decisionIn = RESULT_TIMEOUT,
						ratingDelta = won and winnerDelta or loserDelta,
						xpData = won and winnerXp or loserXp,
						coins = won and PvELevels.PVP_WIN_COINS or PvELevels.PVP_LOSS_COINS,
						dailyWarBonds = won and winnerDailyBonds or loserDailyBonds,
					})
				end
			end
			task.delay(RESULT_TIMEOUT, function()
				if currentMatch ~= match then return end
				local survivors = Players:GetPlayers()
				if isStudio then
					for _, player in survivors do
						player.CameraMode = Enum.CameraMode.Classic
						Remotes.MatchEvent:FireClient(player, "ReturnToMenu", {})
					end
					clearMatchState()
				elseif #survivors > 0 then
					teleportToLobby(survivors)
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
	local displayMode = if match.botMatch then "PvP" else matchMode
	Remotes.MatchEvent:FireAllClients("MatchStart", { difficulty = match.difficulty, mode = displayMode })
	for _, player in Players:GetPlayers() do
		local side = sideFor(player)
		if side then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			player:LoadCharacter()
			Telemetry.event(player, "match_started", 1, { mode = matchMode, difficulty = match.difficulty })
		end
	end
end

local function startPvELevel(player: Player, mode: string, level: number)
	if currentMatch then
		Remotes.MatchEvent:FireClient(player, "QueueError", { message = "A match is already running in this lobby." })
		return
	end
	
	matchMode = "PvE"
	currentMatch = Match.new(map :: MapBuilder.MapHandle, "Normal")
	currentMatch.pveLevel = level
	currentMatch.pveMode = mode
	currentMatch.mode = matchMode
	wireMatch(currentMatch)
	assignPlayer(player, "A")
	
	local profile = PlayerData.get(player)
	local s = currentMatch.sides["A"]
	s.pveUpgrades = profile.pveUpgrades
	s.pvePerks = profile.pvePerks
	s.gold += 15 * math.min(profile.pveUpgrades.startingGold, PvELevels.UPGRADE_TRACKS.startingGold.maxTier)
	
	playerReady[player] = true
	startMatch()
	
	if table.find(profile.pvePerks, "headStart") then
		Match.tryEvolve(currentMatch, "A", true)
	end
	if table.find(profile.pvePerks, "freeTurret") then
		TurretSystem.tryBuild(currentMatch, "A", 1, true)
	end
end

-- Fallback opponent: runs on the PvE sim (AIBrain drives side B) but is
-- presented to the client as a PvP match against a named opponent.
local function startBotMatch(player: Player, botName: string, botRating: number)
	if currentMatch then return end
	matchMode = "PvE"
	local difficulty = if botRating < 1100 then "Normal" elseif botRating < 1700 then "Harder" else "Impossible"
	currentMatch = Match.new(map :: MapBuilder.MapHandle, difficulty)
	currentMatch.mode = "PvE"
	currentMatch.botMatch = true
	currentMatch.botName = botName
	currentMatch.botRating = botRating
	-- Synthetic level maps bot strength onto the existing PvE scaling curve;
	-- boss levels are skipped so the "opponent" never spawns a boss unit.
	local level = math.clamp(math.round((botRating - 850) / 40), 1, 60)
	while PvELevels.isBossLevel(level) and level > 1 do
		level -= 1
	end
	currentMatch.pveLevel = level
	currentMatch.pveMode = "Normal"
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

local function initReservedServer()
	local initialized = false

	Players.PlayerAdded:Connect(function(player)
		loadPlayerProfile(player)
		local joinData = player:GetJoinData()
		local teleportData = joinData.TeleportData
		
		local tdMode = typeof(teleportData) == "table" and teleportData.mode or nil
		if not initialized then
			if tdMode == "pve_match" or tdMode == "pvp_bot_match" then
				matchMode = "PvE"
			else
				matchMode = "PvP"
				currentMatch = Match.new(map :: MapBuilder.MapHandle, DifficultyConfig.DEFAULT)
				currentMatch.mode = matchMode
				wireMatch(currentMatch)
			end
			initialized = true
		end

		if matchMode == "PvE" then
			local baseValid = typeof(teleportData) == "table"
				and joinData.SourcePlaceId == game.PlaceId
				and typeof(teleportData.userId) == "number"
				and typeof(teleportData.createdAt) == "number"
				and math.abs(os.time() - teleportData.createdAt) <= 600
				and teleportData.userId == player.UserId
			if baseValid
				and tdMode == "pve_match"
				and typeof(teleportData.pveMode) == "string"
				and typeof(teleportData.pveLevel) == "number" then
				startPvELevel(player, teleportData.pveMode, teleportData.pveLevel)
			elseif baseValid
				and tdMode == "pvp_bot_match"
				and typeof(teleportData.botName) == "string"
				and typeof(teleportData.botRating) == "number" then
				startBotMatch(player, teleportData.botName, teleportData.botRating)
			else
				player:Kick("Invalid or expired match ticket.")
				PlayerData.unload(player)
			end
		else
			local side: string? = nil
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

Remotes.StartPveLevel.OnServerEvent:Connect(function(player, mode, level)
	if typeof(level) ~= "number" or typeof(mode) ~= "string" then return end
	if not allowRate(player, "start_pve_level", 1) then return end
	level = math.floor(level)
	if not table.find(PvELevels.MODES, mode) then return end
	local profile = PlayerData.get(player)
	local prog = profile.pveProgress[mode] or 0
	if level < 1 or level > prog + 1 then return end
	
	if isStudio then
		startPvELevel(player, mode, level)
	elseif isLobby then
		local reserved, accessCode = pcall(function()
			return TeleportService:ReserveServerAsync(game.PlaceId)
		end)
		if not reserved or typeof(accessCode) ~= "string" then
			Remotes.MatchEvent:FireClient(player, "QueueError", { message = "Failed to reserve a PvE server." })
			return
		end
		
		local data = {
			mode = "pve_match",
			pveMode = mode,
			pveLevel = level,
			userId = player.UserId,
			createdAt = os.time(),
		}
		
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		options:SetTeleportData(data)
		
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if not ok then
			Remotes.MatchEvent:FireClient(player, "QueueError", { message = "Failed to teleport to PvE server." })
		end
	end
end)

Remotes.BuyPveUpgrade.OnServerEvent:Connect(function(player, trackOrPerkId)
	if typeof(trackOrPerkId) ~= "string" or #trackOrPerkId > 64 or currentMatch then return end
	if not allowRate(player, "buy_pve_upgrade", 0.2) then return end
	local profile = PlayerData.get(player)
	
	if PvELevels.UPGRADE_TRACKS[trackOrPerkId] then
		local currentTier = profile.pveUpgrades[trackOrPerkId] or 0
		local maxTier = PvELevels.UPGRADE_TRACKS[trackOrPerkId].maxTier
		if currentTier >= maxTier then return end
		local cost = PvELevels.upgradeCost(currentTier + 1)
		if PlayerData.spendCoins(player, cost) then
			profile.pveUpgrades[trackOrPerkId] = currentTier + 1
			PlayerData.sync(player)
			PlayerData.save(player)
		end
	elseif PvELevels.PERKS[trackOrPerkId] then
		if table.find(profile.pvePerks, trackOrPerkId) then return end
		local cost = PvELevels.PERKS[trackOrPerkId].cost
		if PlayerData.spendCoins(player, cost) then
			table.insert(profile.pvePerks, trackOrPerkId)
			PlayerData.sync(player)
			PlayerData.save(player)
		end
	end
end)

Remotes.UpdateSettings.OnServerEvent:Connect(function(player, key, value)
	if typeof(key) ~= "string" or #key > 32 or not allowRate(player, "update_settings", 0.15) then return end
	if PlayerData.updateSetting(player, key, value) then task.spawn(function() PlayerData.save(player) end) end
end)

Remotes.ResultAction.OnServerEvent:Connect(function(player, action)
	local match = currentMatch
	if not match or match.status ~= "Ended" or not sideFor(player) then return end
	if typeof(action) ~= "string" or not allowRate(player, "result_action", 0.5) then return end
	if action ~= "replay" and action ~= "next" and action ~= "menu" then return end
	Telemetry.event(player, "result_action", 1, { action = action, mode = matchMode })

	if action == "menu" then
		playerReady[player] = false
		rematchVotes[player] = nil
		if isStudio then
			if matchMode == "PvE" then
				player.CameraMode = Enum.CameraMode.Classic
				Remotes.MatchEvent:FireClient(player, "ReturnToMenu", {})
				clearMatchState()
			else
				for _, participant in Players:GetPlayers() do
					participant.CameraMode = Enum.CameraMode.Classic
					Remotes.MatchEvent:FireClient(participant, "ReturnToMenu", {})
				end
				clearMatchState()
			end
		else
			local participants = Players:GetPlayers()
			teleportToLobby(participants)
		end
		return
	end

	if matchMode == "PvE" and match.botMatch then
		if action ~= "replay" then return end
		local botName = match.botName or "Opponent"
		local botRating = match.botRating or 1000
		clearMatchState()
		startBotMatch(player, botName, botRating)
		return
	end

	if matchMode == "PvE" then
		local oldLevel = match.pveLevel or 1
		local oldMode = match.pveMode or "Normal"
		if action == "next" then
			if match.winner ~= "A" then return end
			local profile = PlayerData.get(player)
			if (profile.pveProgress[oldMode] or 0) < oldLevel then return end
		end
		clearMatchState()
		startPvELevel(player, oldMode, action == "next" and oldLevel + 1 or oldLevel)
		return
	end

	if action ~= "replay" or not sidePlayers.A or not sidePlayers.B then return end
	rematchVotes[player] = true
	local readyCount = (rematchVotes[sidePlayers.A :: Player] and 1 or 0) + (rematchVotes[sidePlayers.B :: Player] and 1 or 0)
	Remotes.MatchEvent:FireAllClients("RematchStatus", { ready = readyCount, required = 2 })
	if readyCount < 2 or currentMatch ~= match then return end

	UnitSim.clearAll(match)
	TurretSystem.clearAll(match)
	StatusEffectSystem.clearAll(match)
	resetMap()
	rematchVotes = {}
	currentMatch = Match.new(map :: MapBuilder.MapHandle, match.difficulty)
	currentMatch.mode = "PvP"
	wireMatch(currentMatch)
	startMatch()
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
					snapshot.opponentName = opponent and opponent.DisplayName or match.botName or "AI Commander"
					snapshot.matchId = expectedMatchId
					snapshot.mode = if match.botMatch then "PvP" else matchMode
					if match.botMatch then
						-- The synthetic scaling level must never reach the client.
						snapshot.pveLevel = nil
						snapshot.pveMode = nil
					end
					Remotes.StateUpdate:FireClient(player, snapshot)
				end
			end
		end
	end
end)

-- Server type branches
if isLobby or isStudio then
	LobbyBuilder.build()
	LobbyFlex.buildLeaderboardWall()
	LobbyBots.start()
	if not isStudio then
		MatchmakingService.start()
	end

	Remotes.SelectMode.OnServerEvent:Connect(function(player, mode, diffId)
		if not allowRate(player, "select_mode", 0.75) then return end
		if mode ~= "pvp" and mode ~= "pve" then return end
		Telemetry.event(player, "mode_selected", 1, { mode = mode, difficulty = tostring(diffId) })
		if mode == "pvp" then
			if isStudio then
				-- Cloud matchmaking/teleports do not run in Studio. Two local clients
				-- instead join this server's direct A/B test match.
				if currentMatch and matchMode ~= "PvP" then
					Remotes.MatchEvent:FireClient(player, "QueueError", { message = "A PvE match is already running." })
					return
				end
				if not currentMatch then
					matchMode = "PvP"
					currentMatch = Match.new(map :: MapBuilder.MapHandle, DifficultyConfig.DEFAULT)
					currentMatch.mode = matchMode
					wireMatch(currentMatch)
				end
				if currentMatch.status ~= "Waiting" then return end
				if not sideFor(player) then
					local side = sidePlayers.A == nil and "A" or (sidePlayers.B == nil and "B" or nil)
					if not side then
						Remotes.MatchEvent:FireClient(player, "QueueError", { message = "The local 1v1 test is full." })
						return
					end
					assignPlayer(player, side)
				end
				playerReady[player] = true
				tryStartPvP()
			else
				MatchmakingService.enqueue(player)
			end
		end
	end)

	local lobbyPlayersSetUp: { [Player]: boolean } = {}
	local lobbyRespawnPending: { [Player]: boolean } = {}
	local function requestLobbyRespawn(player: Player)
		if lobbyRespawnPending[player] or player.Parent ~= Players or sideFor(player) then return end
		lobbyRespawnPending[player] = true
		task.delay(1.5, function()
			lobbyRespawnPending[player] = nil
			if player.Parent == Players and not sideFor(player) then
				player.CameraMode = Enum.CameraMode.Classic
				player:LoadCharacter()
			end
		end)
	end

	local function setUpLobbyPlayer(player: Player)
		if lobbyPlayersSetUp[player] then return end
		lobbyPlayersSetUp[player] = true
		loadPlayerProfile(player)
		LobbyFlex.bindPlayer(player)
		player.CameraMode = Enum.CameraMode.Classic
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					requestLobbyRespawn(player)
				end)
			end
		end)
		player:LoadCharacter()
	end

	Players.PlayerAdded:Connect(setUpLobbyPlayer)
	-- Players who joined while the lobby was still building (always the case in
	-- Studio) missed the PlayerAdded signal and would keep the StarterPlayer
	-- LockFirstPerson camera, freezing the mouse cursor in the lobby.
	for _, player in Players:GetPlayers() do
		setUpLobbyPlayer(player)
	end

	-- CharacterAutoLoads is disabled for match-controlled hero respawns. Recover
	-- lobby players who walk off the island before Roblox destroys the model.
	RunService.Heartbeat:Connect(function()
		for player in lobbyPlayersSetUp do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y < -30 and not sideFor(player) then
				requestLobbyRespawn(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lobbyPlayersSetUp[player] = nil
		lobbyRespawnPending[player] = nil
		local side = sideFor(player)
		if side and currentMatch and currentMatch.status == "Active" then
			currentMatch.status = "Ended"
			currentMatch.winner = Match.enemyOf(side)
			if currentMatch.onEnd then currentMatch.onEnd(currentMatch.winner :: string) end
		end
		playerSides[player] = nil
		if side then sidePlayers[side] = nil end
		playerReady[player] = nil
		actionTimes[player] = nil
		PlayerData.unload(player)
	end)
else
	-- Reserved Server (PvP or PvE)
	initReservedServer()

	Players.PlayerRemoving:Connect(function(player)
		local side = sideFor(player)
		if side and currentMatch and currentMatch.status == "Active" then
			currentMatch.status = "Ended"
			currentMatch.winner = Match.enemyOf(side)
			if currentMatch.onEnd then currentMatch.onEnd(currentMatch.winner :: string) end
		end
		playerSides[player] = nil
		if side then sidePlayers[side] = nil end
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
