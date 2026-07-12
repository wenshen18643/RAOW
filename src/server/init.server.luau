--!strict
-- Bootstrap: build map, run match loops, wire remotes, restart on match end.
-- Integrates difficulty selection, status effects, player data, and dynamic AI tick rate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

Players.CharacterAutoLoads = false

local map = MapBuilder.build()
Environment.setup(map)

-- Difficulty state: selected by host player before match starts, defaults to Normal
local selectedDifficulty: string = DifficultyConfig.DEFAULT
local currentMatch = Match.new(map, selectedDifficulty)

local function getMatch(): Match.Match
	return currentMatch
end

local RESTART_DELAY = 10

local function resetMap()
	for _, base in map.bases do
		base.core:SetAttribute("Hp", GameConfig.BASE_MAX_HP)
		base.core.Color = base.side == "A" and Color3.fromRGB(52, 120, 200) or Color3.fromRGB(200, 70, 60)
	end
end

local wireMatch: (Match.Match) -> ()

-- Tears down the current match and starts a fresh one at selectedDifficulty.
local function startNewMatch()
	UnitSim.clearAll(currentMatch)
	TurretSystem.clearAll(currentMatch)
	StatusEffectSystem.clearAll(currentMatch)
	resetMap()
	currentMatch = Match.new(map, selectedDifficulty)
	wireMatch(currentMatch)
	Remotes.MatchEvent:FireAllClients("MatchStart", { difficulty = selectedDifficulty })
	for _, player in Players:GetPlayers() do
		player:LoadCharacter()
	end
end

function wireMatch(match: Match.Match)
	match.onAgeUp = function(side, newAge)
		Remotes.MatchEvent:FireAllClients("AgeUp", { side = side, age = newAge })
		if side == match.playerSide then
			for _, player in Players:GetPlayers() do
				HeroSystem.onAgeUp(match, player)
			end
		end
	end
	match.onBaseDamaged = function(side, amount)
		if side == match.playerSide then
			Remotes.MatchEvent:FireAllClients("BaseUnderAttack", { amount = amount })
		end
	end
	match.onEnd = function(winner)
		local event = winner == match.playerSide and "Victory" or "Defeat"
		Remotes.MatchEvent:FireAllClients(event, { restartIn = RESTART_DELAY })
		-- Record win/loss for player persistence (Phase 4)
		for _, player in Players:GetPlayers() do
			if winner == match.playerSide then
				PlayerData.recordWin(player)
			else
				PlayerData.recordLoss(player)
			end
		end
		task.delay(RESTART_DELAY, startNewMatch)
	end
end
wireMatch(currentMatch)

-- Difficulty selection (from the main menu PLAY flow): starts a fresh match
-- at the chosen difficulty so the choice always takes effect immediately.
Remotes.SelectDifficulty.OnServerEvent:Connect(function(_player, difficulty)
	if typeof(difficulty) == "string" and DifficultyConfig.LEVELS[difficulty] then
		selectedDifficulty = difficulty
		Remotes.DifficultySelected:FireAllClients(difficulty)
		print(`[AgeOfWarFP] Difficulty set to: {difficulty} — starting fresh match`)
		if currentMatch.status == "Active" then
			startNewMatch()
		end
	end
end)

-- Remote handlers (single-player MVP: every player controls side A)
Remotes.SpawnUnit.OnServerEvent:Connect(function(_player, unitId)
	if typeof(unitId) == "string" then
		UnitSim.requestSpawn(currentMatch, currentMatch.playerSide, unitId)
	end
end)

Remotes.BuildTurret.OnServerEvent:Connect(function(_player, slot)
	if typeof(slot) == "number" then
		TurretSystem.tryBuild(currentMatch, currentMatch.playerSide, slot)
	end
end)

Remotes.SellTurret.OnServerEvent:Connect(function(_player, slot)
	if typeof(slot) == "number" then
		TurretSystem.trySell(currentMatch, currentMatch.playerSide, slot)
	end
end)

Remotes.UseSpecial.OnServerEvent:Connect(function(_player)
	SpecialSystem.tryCast(currentMatch, currentMatch.playerSide)
end)

Remotes.Evolve.OnServerEvent:Connect(function(_player)
	Match.tryEvolve(currentMatch, currentMatch.playerSide)
end)

Remotes.FireWeapon.OnServerEvent:Connect(function(player, origin, direction)
	HeroSystem.handleFire(currentMatch, player, origin, direction, false)
end)

Remotes.FireWeaponSecondary.OnServerEvent:Connect(function(player, origin, direction)
	HeroSystem.handleFire(currentMatch, player, origin, direction, true)
end)

Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, stat)
	if typeof(stat) ~= "string" then return end
	HeroSystem.buyUpgrade(currentMatch, player, stat)
end)

-- Player join: load data, bind hero, load character
Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
	HeroSystem.bindPlayer(getMatch, player)
	player:LoadCharacter()
	Remotes.MatchEvent:FireClient(player, "MatchStart", { difficulty = selectedDifficulty })
end)

-- Loops
local simAccum = 0
RunService.Heartbeat:Connect(function(dt)
	simAccum += dt
	local step = 1 / GameConfig.SIM_RATE
	if simAccum >= step then
		UnitSim.tick(currentMatch, simAccum)
		-- Status effect processing runs alongside unit sim (Phase 4)
		StatusEffectSystem.tick(currentMatch, simAccum)
		simAccum = 0
	end
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		TurretSystem.tick(currentMatch)
	end
end)



-- AI brain tick: rate is dynamic based on difficulty
task.spawn(function()
	while true do
		local diffConfig = DifficultyConfig.LEVELS[currentMatch.difficulty] or DifficultyConfig.LEVELS[DifficultyConfig.DEFAULT]
		task.wait(diffConfig.aiTickRate)
		AIBrain.tick(currentMatch)
	end
end)

task.spawn(function()
	while true do
		task.wait(1 / GameConfig.STATE_SYNC_RATE)
		local snapshot = Match.buildSnapshot(currentMatch)
		for _, player in Players:GetPlayers() do
			Remotes.StateUpdate:FireClient(player, snapshot)
		end
	end
end)

-- debug handle for Studio testing: DebugCmd:Invoke("addGold", side, amount) etc.
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
		return Match.buildSnapshot(match)
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

print("[AgeOfWarFP] Server ready")
print("[AgeOfWarFP] If you see this, the server script is running.")
