--!strict
-- Bootstrap: build map, run match loops, wire remotes, restart on match end.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Services = script.Services
local MapBuilder = require(Services.MapBuilder)
local Match = require(Services.Match)
local UnitSim = require(Services.UnitSim)
local TurretSystem = require(Services.TurretSystem)
local SpecialSystem = require(Services.SpecialSystem)
local HeroSystem = require(Services.HeroSystem)
local AIBrain = require(Services.AIBrain)

Players.CharacterAutoLoads = false

local map = MapBuilder.build()
local currentMatch = Match.new(map)

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

local function wireMatch(match: Match.Match)
	match.onAgeUp = function(side, newAge)
		Remotes.MatchEvent:FireAllClients("AgeUp", { side = side, age = newAge })
		if side == match.playerSide then
			for _, player in Players:GetPlayers() do
				HeroSystem.onAgeUp(match, player)
			end
		end
	end
	match.onEnd = function(winner)
		local event = winner == match.playerSide and "Victory" or "Defeat"
		Remotes.MatchEvent:FireAllClients(event, { restartIn = RESTART_DELAY })
		task.delay(RESTART_DELAY, function()
			UnitSim.clearAll(currentMatch)
			TurretSystem.clearAll(currentMatch)
			resetMap()
			currentMatch = Match.new(map)
			wireMatch(currentMatch)
			Remotes.MatchEvent:FireAllClients("MatchStart", {})
			for _, player in Players:GetPlayers() do
				player:LoadCharacter()
			end
		end)
	end
end
wireMatch(currentMatch)

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
	HeroSystem.handleFire(currentMatch, player, origin, direction)
end)

-- Player join
Players.PlayerAdded:Connect(function(player)
	HeroSystem.bindPlayer(getMatch, player)
	player:LoadCharacter()
	Remotes.MatchEvent:FireClient(player, "MatchStart", {})
end)

-- Loops
local simAccum = 0
RunService.Heartbeat:Connect(function(dt)
	simAccum += dt
	local step = 1 / GameConfig.SIM_RATE
	if simAccum >= step then
		UnitSim.tick(currentMatch, simAccum)
		simAccum = 0
	end
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		TurretSystem.tick(currentMatch)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		Match.incomeTick(currentMatch)
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
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

print("[AgeOfWarFP] Server ready")
