local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local MapBuilder = require(services.MapBuilder)
local Match = require(services.Match)
local UnitSim = require(services.UnitSim)
local TurretSystem = require(services.TurretSystem)
local AIBrain = require(services.AIBrain)

local function activeMatch()
	local map = MapBuilder.build()
	local match = Match.new(map, "Normal")
	match.status = "Active"
	match.startedAt = os.clock()
	return match
end

local formationMatch = activeMatch()
for _ = 1, 5 do
	assert(UnitSim.requestSpawn(formationMatch, "A", "age1_melee", true), "formation unit did not queue")
	formationMatch.sides.A.lastSpawnAt = os.clock() - 10
	UnitSim.tick(formationMatch, 0.1)
end
assert(#formationMatch.sides.A.units == 5, "formation units did not spawn")
local occupiedLanes = {}
for _, rec in formationMatch.sides.A.units do
	occupiedLanes[math.round(rec.laneOffset)] = true
	assert(UnitSim.findRecordByPart(formationMatch, rec.body) == rec, "model-to-record lookup failed")
end
local laneCount = 0
for _ in occupiedLanes do laneCount += 1 end
assert(laneCount == 5, `expected five formation lanes, got {laneCount}`)
assert(Match.buildSnapshot(formationMatch, "A").roleCounts.melee == 5, "live doctrine role counts are missing")
UnitSim.clearAll(formationMatch)
formationMatch.map.folder:Destroy()

local projectileMatch = activeMatch()
projectileMatch.sides.A.age = 3
projectileMatch.sides.B.age = 3
assert(UnitSim.requestSpawn(projectileMatch, "A", "age3_heavy", true), "heavy unit did not queue")
assert(UnitSim.requestSpawn(projectileMatch, "B", "age3_melee", true), "target unit did not queue")
projectileMatch.sides.A.lastSpawnAt = os.clock() - 10
projectileMatch.sides.B.lastSpawnAt = os.clock() - 10
UnitSim.tick(projectileMatch, 0.1)

local heavy = projectileMatch.sides.A.units[1]
local target = projectileMatch.sides.B.units[1]
assert(heavy and target, "projectile test units did not spawn")
heavy.body.CFrame = CFrame.lookAt(Vector3.new(-10, heavy.body.Position.Y, 0), Vector3.new(10, heavy.body.Position.Y, 0))
target.body.CFrame = CFrame.lookAt(Vector3.new(10, target.body.Position.Y, 0), Vector3.new(-10, target.body.Position.Y, 0))
heavy.targetCache = nil
heavy.targetRefreshAt = 0
UnitSim.tick(projectileMatch, 0.1)
assert(#projectileMatch.projectiles > 0, "long-range heavy still attacks as instant melee")
UnitSim.clearAll(projectileMatch)
projectileMatch.map.folder:Destroy()

local bossMatch = activeMatch()
assert(UnitSim.requestSpawn(bossMatch, "B", "age1_heavy", true), "ordinary pre-boss heavy did not queue")
bossMatch.sides.B.lastSpawnAt = os.clock() - 10
UnitSim.tick(bossMatch, 0.1)
local ordinaryHeavy = bossMatch.sides.B.units[1]
assert(ordinaryHeavy ~= nil, "ordinary pre-boss heavy did not spawn")
local existingCandidates = { [ordinaryHeavy] = true }
assert(UnitSim.requestSpawn(bossMatch, "B", "age1_heavy", true), "new boss candidate did not queue")
bossMatch.sides.B.lastSpawnAt = os.clock() - 10
UnitSim.tick(bossMatch, 0.1)
local promotedBoss = AIBrain.findNewBossCandidate(bossMatch.sides.B.units, "age1_heavy", existingCandidates)
assert(promotedBoss and promotedBoss ~= ordinaryHeavy, "boss selection returned an existing ordinary heavy")
assert((ordinaryHeavy :: any).isBoss ~= true, "ordinary heavy received boss abilities")
UnitSim.clearAll(bossMatch)
bossMatch.map.folder:Destroy()

local turretMatch = activeMatch()
turretMatch.sides.A.gold = 1000
assert(TurretSystem.tryBuild(turretMatch, "A", 1, false), "age-1 turret purchase failed")
assert(turretMatch.sides.A.gold == 900, "age-1 turret charged the wrong amount")
local turretSnapshot = Match.buildSnapshot(turretMatch, "A")
assert(typeof(turretSnapshot.turrets[1]) == "table" and turretSnapshot.turrets[1].sellValue == 50, "turret management snapshot is incomplete")
turretMatch.sides.A.age = 2
assert(TurretSystem.tryBuild(turretMatch, "A", 1, false), "obsolete turret upgrade failed")
assert(turretMatch.sides.A.gold == 650, "turret upgrade did not apply its 50% sell credit")
assert(not TurretSystem.tryBuild(turretMatch, "A", 1, false), "current-age turret can be repurchased accidentally")
turretMatch.sides.A.heroUpgrades.def = 3
assert(math.abs(Match.reduceHeroDamage(turretMatch, "A", 100) - 70) < 0.001, "hero defense is not applied consistently")
TurretSystem.clearAll(turretMatch)
turretMatch.map.folder:Destroy()

print("NPC_SIMULATION_SMOKE_PASS")
