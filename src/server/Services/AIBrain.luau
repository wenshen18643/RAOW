--!strict
-- Side B AI opponent: timer-driven but constrained by the same economy as the player.
-- Evolving, spawning, and building turrets are driven by pacing timers set in DifficultyConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Units = require(ReplicatedStorage.Shared.Config.Units)
local Turrets = require(ReplicatedStorage.Shared.Config.Turrets)
local DifficultyConfig = require(ReplicatedStorage.Shared.Config.DifficultyConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)
local TurretSystem = require(script.Parent.TurretSystem)
local SpecialSystem = require(script.Parent.SpecialSystem)

local AIBrain = {}

local SIDE = "B"
local rng = Random.new()

local aiState = setmetatable({}, { __mode = "k" })

function AIBrain.findNewBossCandidate(units: { Match.UnitRecord }, unitId: string, existing: { [Match.UnitRecord]: boolean }): Match.UnitRecord?
	for _, rec in units do
		if rec.def.id == unitId and not existing[rec] and not (rec :: any).isBoss then return rec end
	end
	return nil
end

local ROLE_WEIGHTS = {
	{ role = "melee", w = 0.45 },
	{ role = "ranged", w = 0.35 },
	{ role = "heavy", w = 0.18 },
	{ role = "super_heavy", w = 0.02 },
}

local COUNTER_ROLE: { [string]: string } = {
	melee = "ranged",
	ranged = "heavy",
	heavy = "melee",
	super_heavy = "melee", -- cost-efficient melee swarms punish the elite unit's slot efficiency
}

local function getDominantPlayerRole(match: Match.Match): string?
	local playerSide = Match.enemyOf(SIDE)
	local playerUnits = match.sides[playerSide].units

	if #playerUnits == 0 then
		return nil
	end

	local counts: { [string]: number } = { melee = 0, ranged = 0, heavy = 0, super_heavy = 0 }
	for _, unit in playerUnits do
		if not unit.dead then
			local role = unit.def.role
			counts[role] = (counts[role] or 0) + 1
		end
	end

	local bestRole: string? = nil
	local bestCount = 0
	for role, count in counts do
		if count > bestCount then
			bestCount = count
			bestRole = role
		end
	end

	return bestRole
end

local function pickUnit(age: number, preferredRole: string?): string?
	if preferredRole then
		local def = Units.byId[`age{age}_{preferredRole}`]
		if def then
			return def.id
		end
	end

	local roll = rng:NextNumber()
	local acc = 0
	for _, entry in ROLE_WEIGHTS do
		acc += entry.w
		if roll <= acc then
			local def = Units.byId[`age{age}_{entry.role}`]
			if def then
				return def.id
			end
			break
		end
	end

	local cheap = Units.byId[`age{age}_melee`]
	if cheap then
		return cheap.id
	end
	return nil
end

local function rebuildTurretsForNewAge(match: Match.Match)
	local s = match.sides[SIDE]
	for slot = 1, GameConfig.TURRET_SLOTS do
		local turret = s.turrets[slot]
		if turret and turret.def.age < s.age then
			TurretSystem.tryBuild(match, SIDE, slot, false)
		end
	end
end

function AIBrain.tick(match: Match.Match)
	if match.status ~= "Active" then
		return
	end

	local diffConfig: any = DifficultyConfig.LEVELS[match.difficulty] or DifficultyConfig.LEVELS[DifficultyConfig.DEFAULT]
	if match.mode == "PvE" then
		local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)
		diffConfig = PvELevels.difficultyForLevel(match.pveMode or "Normal", match.pveLevel or 1)
	end
	local s = match.sides[SIDE]
	local now = os.clock()

	local state = aiState[match]
	if not state then
		state = {
			nextSpawnAt = now + 1,
			nextEvolveAt = now + diffConfig.aiEvolveInterval,
			nextTurretAt = now + diffConfig.aiTurretInterval,
			counterSpawns = 0,
			counterRole = nil,
			bossSpawned = false,
		}
		aiState[match] = state
	end

	-- Boss Spawn Check
	if match.mode == "PvE" and not state.bossSpawned then
		local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)
		local level = match.pveLevel or 1
		if PvELevels.isBossLevel(level) then
			-- Wait a short time before spawning boss (e.g. 5 seconds)
			if now - match.startedAt > 5 then
				state.bossSpawned = true
				local bossConf = PvELevels.getBossConfig(match.pveMode or "Normal", level)
				local def = Units.byId[bossConf.unitId]
				if def then
					-- Create a cloned def for the boss to modify its stats
					local bossDef = table.clone(def)
					bossDef.hp = math.floor(def.hp * bossConf.hpMult)
					bossDef.damage = math.floor(def.damage * bossConf.damageMult)
					local existingCandidates: { [Match.UnitRecord]: boolean } = {}
					for _, rec in s.units do
						if rec.def.id == bossConf.unitId then existingCandidates[rec] = true end
					end
					
					-- Inject directly into the front of the queue: popQueue doesn't gate
					-- on cost or age, so the AI's own age/economy stay untouched.
					table.insert(s.queue, 1, bossDef.id)
					
					-- We need to attach the slam ability. We can do this in a loop searching for the unit
					-- or wait for it to spawn.
					task.spawn(function()
						-- Poll until the boss unit appears in the world
						local bossRec = nil
						for i = 1, 40 do
							task.wait(0.5)
							if match.status ~= "Active" then return end
							bossRec = AIBrain.findNewBossCandidate(s.units, bossConf.unitId, existingCandidates)
							if bossRec then break end
						end
						
						if bossRec then
							(bossRec :: any).isBoss = true
							bossRec.model:ScaleTo(bossConf.modelScale)
							bossRec.hp = bossDef.hp
							bossRec.maxHp = bossDef.hp
							bossRec.scaledDamage = bossDef.damage
							UnitSim.refreshHpBar(bossRec)
							
							-- Periodic Slam
							task.spawn(function()
								while not bossRec.dead and match.status == "Active" do
									task.wait(bossConf.slamCooldown)
									if bossRec.dead or match.status ~= "Active" then break end

									local slamPos = bossRec.body.Position
									Remotes.FX:FireAllClients("BossSlamWarning", {
										pos = slamPos,
										radius = bossConf.slamRadius,
										duration = bossConf.slamTelegraphDuration,
									})
									task.wait(bossConf.slamTelegraphDuration)
									if bossRec.dead or match.status ~= "Active" then break end
									Remotes.FX:FireAllClients("ImpactVFX", { pos = slamPos, age = 5 })
									local rawSlamDamage = bossRec.scaledDamage * bossConf.slamDamageMult

									local enemySide = Match.enemyOf(SIDE)
									for _, enemyRec in match.sides[enemySide].units do
										if not enemyRec.dead and (enemyRec.body.Position - slamPos).Magnitude <= bossConf.slamRadius then
											local damage = math.min(rawSlamDamage, enemyRec.maxHp * bossConf.slamMaxUnitHpRatio)
											UnitSim.damageUnit(match, enemyRec, damage, SIDE, false)
											-- Brief stun: push the unit's next attack window out.
											enemyRec.nextAttackAt = os.clock() + bossConf.slamStunDuration
										end
									end

									for _, p in game:GetService("Players"):GetPlayers() do
										if p:GetAttribute("Side") == enemySide and p.Character then
											local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
											local hum = p.Character:FindFirstChildOfClass("Humanoid")
											if hrp and hum and hum.Health > 0 and (hrp.Position - slamPos).Magnitude <= bossConf.slamRadius then
												local heroDamage = Match.reduceHeroDamage(match, enemySide, math.min(rawSlamDamage, hum.MaxHealth * bossConf.slamMaxHeroHpRatio))
												hum:TakeDamage(heroDamage)
												local away = hrp.Position - slamPos
												local flatAway = Vector3.new(away.X, 0, away.Z)
												local knockDir = flatAway.Magnitude > 0.1 and flatAway.Unit or Vector3.new(0, 0, 1)
												hrp.AssemblyLinearVelocity += knockDir * 36 + Vector3.new(0, 18, 0)
											end
										end
									end
								end
							end)
						end
					end)
				end
			end
		else
			state.bossSpawned = true -- not a boss level
		end
	end

	-- 1. EVOLVE
	-- Rubberbanding Tracking System
	local playerAge = match.sides[Match.enemyOf(SIDE)].age
	if playerAge > s.age then
		if not state.rubberbandEvolveAt then
			state.rubberbandEvolveAt = now + rng:NextNumber(30, 60)
		end
	else
		state.rubberbandEvolveAt = nil
	end

	-- Try standard XP evolution first (in case the AI is actually killing tons of units)
	if Match.canEvolve(match, SIDE) then
		Match.tryEvolve(match, SIDE, false)
		state.nextEvolveAt = now + diffConfig.aiEvolveInterval
		if diffConfig.aiCounterSpawn then
			rebuildTurretsForNewAge(match)
		end
	-- If pacing falls behind, the AI still has to earn the required XP.
	elseif now >= state.nextEvolveAt or (state.rubberbandEvolveAt and now >= state.rubberbandEvolveAt) then
		if Match.tryEvolve(match, SIDE, false) then
			state.nextEvolveAt = now + diffConfig.aiEvolveInterval
			state.rubberbandEvolveAt = nil
			if diffConfig.aiCounterSpawn then
				rebuildTurretsForNewAge(match)
			end
		end
	end

	-- 2. SPECIAL ABILITY
	if os.clock() >= s.specialReadyAt then
		local enemyUnits = #match.sides[Match.enemyOf(SIDE)].units
		local shouldCast = enemyUnits >= diffConfig.aiSpecialThreshold

		if diffConfig.aiCounterSpawn and not shouldCast then
			local baseHp = match.map.bases[SIDE].core:GetAttribute("Hp") :: number
			if baseHp < (GameConfig.BASE_MAX_HP * 0.7) then
				shouldCast = true
			end
		end

		if shouldCast then
			SpecialSystem.tryCast(match, SIDE)
		end
	end

	-- 3. TURRETS
	if now >= state.nextTurretAt then
		local emptySlot: number? = nil
		for i = 1, GameConfig.TURRET_SLOTS do
			if s.turrets[i] == nil then
				emptySlot = i
				break
			end
		end

		if emptySlot then
			if TurretSystem.tryBuild(match, SIDE, emptySlot, false) then
				state.nextTurretAt = now + diffConfig.aiTurretInterval
			end
		end
	end

	-- 4. SPAWN UNITS
	if now >= state.nextSpawnAt then
		if #s.queue < GameConfig.QUEUE_CAP then
			local unitId: string?

			if diffConfig.aiCounterSpawn and state.counterSpawns <= 0 then
				local dominant = getDominantPlayerRole(match)
				if dominant then
					state.counterRole = COUNTER_ROLE[dominant]
					state.counterSpawns = rng:NextInteger(2, 3)
				end
			end

			if state.counterSpawns > 0 and state.counterRole then
				unitId = pickUnit(s.age, state.counterRole)
				state.counterSpawns -= 1
			else
				unitId = pickUnit(s.age, nil)
			end

			-- If the chosen unit is unaffordable, fall back to the priciest one we can pay for,
			-- so an expensive counter pick never stalls spawning entirely.
			if unitId and Units.byId[unitId].cost > s.gold then
				local best: string? = nil
				local bestCost = -1
				for _, def in Units.byAge[s.age] do
					if def.cost <= s.gold and def.cost > bestCost then
						best = def.id
						bestCost = def.cost
					end
				end
				unitId = best
			end

			if unitId then
				if UnitSim.requestSpawn(match, SIDE, unitId, false) then
					state.nextSpawnAt = now + diffConfig.aiSpawnInterval
				end
			end
		end
	end
end

return AIBrain
