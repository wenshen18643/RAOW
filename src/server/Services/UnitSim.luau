--!strict
-- Unit spawning, queue, movement, targeting, combat. Server-authoritative,
-- anchored parts moved via PivotTo (no Humanoids).
-- Integrates: difficulty scaling, object pooling, animation controller, status effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Units = require(ReplicatedStorage.Shared.Config.Units)
local DifficultyConfig = require(ReplicatedStorage.Shared.Config.DifficultyConfig)
local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Match = require(script.Parent.Match)
local UnitFactory = require(script.Parent.UnitFactory)
local Synergies = require(ReplicatedStorage.Shared.Config.Synergies)
local AnimController = require(script.Parent.AnimController)
local ObjectPool = require(script.Parent.ObjectPool)

local UnitSim = {}

local ATTACK_ANIM_DURATION = 0.35
-- Whole-body lunge/recoil is now just a subtle accent; the client UnitAnimator
-- plays the real limb swings via Motor6D.Transform.
local ATTACK_LUNGE = { melee = 1.8, ranged = -0.8, heavy = -0.5 }

-- Sets the animation state attribute the client UnitAnimator reads.
-- Cached on the record so we only write on change.
local function setAnimState(rec: Match.UnitRecord, state: string)
	if (rec :: any).animState ~= state then
		(rec :: any).animState = state
		rec.body:SetAttribute("AnimState", state)
	end
end

local unitsFolder: Folder? = nil

-- Object pool for recycling unit models (Phase 2 optimization)
local unitPool = ObjectPool.new(10)

local function getUnitsFolder(): Folder
	if not unitsFolder or not unitsFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Units"
		f.Parent = workspace
		unitsFolder = f
	end
	return unitsFolder :: Folder
end

local function makeHpBar(body: BasePart, side: string, unitName: string): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(72, 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 1.5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 160
	local team = Instance.new("TextLabel")
	team.Name = "TeamLabel"
	team.Size = UDim2.new(1, 0, 0, 15)
	team.BackgroundTransparency = 1
	team.Font = Enum.Font.GothamBold
	team.TextSize = 11
	team.TextStrokeTransparency = 0.45
	team.TextColor3 = side == "A" and Color3.fromRGB(100, 190, 255) or Color3.fromRGB(255, 105, 95)
	team.Text = side == "A" and `ALLY  {string.upper(unitName)}` or `ENEMY  {string.upper(unitName)}`
	team.Parent = gui
	local bg = Instance.new("Frame")
	bg.Position = UDim2.fromOffset(0, 17)
	bg.Size = UDim2.new(1, 0, 0, 7)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = side == "A" and Color3.fromRGB(70, 190, 255) or Color3.fromRGB(235, 75, 65)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	gui.Parent = body
	return fill
end

local function buildUnitModel(def: any, side: string, spawnCf: CFrame): (Model, BasePart)
	-- Try to acquire a recycled model from the pool
	local poolKey = def.id .. "_" .. side
	local recycled = ObjectPool.acquire(unitPool, poolKey)
	if recycled then
		local body = recycled.PrimaryPart :: BasePart
		body.CFrame = spawnCf * CFrame.new(0, body.Size.Y / 2, 0)
		-- Reset HP bar
		local bar = body:FindFirstChild("HpBar")
		local fill = bar and bar:FindFirstChild("Fill", true) :: Frame?
		if fill then
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = side == "A" and Color3.fromRGB(70, 190, 255) or Color3.fromRGB(235, 75, 65)
		end
		-- Reset animation state for the new life (pool acquire restores transparency)
		body:SetAttribute("AnimState", "walk")
		recycled.Parent = getUnitsFolder()
		return recycled, body
	end

	-- No recycled model available — build a fresh one
	local model, body = UnitFactory.build(def, side, spawnCf)
	makeHpBar(body, side, def.name)
	model.Parent = getUnitsFolder()
	return model, body
end

-- Decorative parts are welded to the anchored body: one CFrame write moves everything.
local function moveModel(rec: Match.UnitRecord, cf: CFrame)
	rec.body.CFrame = cf
end

local function updateHpBar(rec: Match.UnitRecord)
	local bar = rec.body:FindFirstChild("HpBar")
	local fill = bar and bar:FindFirstChild("Fill", true) :: Frame?
	if fill then
		local frac = math.clamp(rec.hp / rec.maxHp, 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		fill.BackgroundColor3 = frac > 0.5 and Color3.fromRGB(80, 220, 80)
			or frac > 0.25 and Color3.fromRGB(230, 200, 60)
			or Color3.fromRGB(220, 70, 60)
	end
end

function UnitSim.killUnit(match: Match.Match, rec: Match.UnitRecord, killerSide: string?, isHeroKill: boolean?)
	if rec.dead then
		return
	end
	rec.dead = true
	if killerSide then
		local goldAwarded = Match.awardKill(match, killerSide, rec.def, isHeroKill)
		-- gold popup for kills made by the player's side
		if killerSide == match.playerSide then
			Remotes.FX:FireAllClients("Reward", {
				pos = rec.body.Position + Vector3.new(0, rec.body.Size.Y / 2 + 1, 0),
				amount = goldAwarded,
			})
		end
	end
	-- Award pity XP to the side whose unit died
	Match.awardPityXp(match, rec.side, rec.def)
	-- client plays the limp-limbs death anim; server topples the whole body
	setAnimState(rec, "death")
	-- Death topple animation over 0.6s, then recycle to pool
	rec.deathStartedAt = os.clock()
	rec.deathBasePos = rec.body.Position
	task.delay(0.6, function()
		-- Release model to pool for recycling instead of destroying
		local poolKey = rec.def.id .. "_" .. rec.side
		if rec.model.Parent then
			ObjectPool.release(unitPool, poolKey, rec.model)
		end
	end)
	local sideUnits = match.sides[rec.side].units
	local idx = table.find(sideUnits, rec)
	if idx then
		table.remove(sideUnits, idx)
	end
end

function UnitSim.damageUnit(match: Match.Match, rec: Match.UnitRecord, amount: number, killerSide: string?, isHeroKill: boolean?)
	if rec.dead then
		return
	end
	-- Apply ArmorMelt damage amplification (Phase 4 status effect)
	local effectiveAmount = amount * (1 + rec.damageAmp)
	rec.hp -= effectiveAmount
	if rec.hp <= 0 then
		UnitSim.killUnit(match, rec, killerSide, isHeroKill)
	else
		updateHpBar(rec)
	end
end

function UnitSim.findRecordByPart(match: Match.Match, part: BasePart): Match.UnitRecord?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	for _, side in match.sides do
		for _, rec in side.units do
			if rec.model == model then
				return rec
			end
		end
	end
	return nil
end

-- Get the difficulty config for the current match
local function getDifficulty(match: Match.Match): DifficultyConfig.DifficultyDef
	return DifficultyConfig.LEVELS[match.difficulty] or DifficultyConfig.LEVELS[DifficultyConfig.DEFAULT]
end

local function applyDoctrineBuff(rec: Match.UnitRecord, doctrineId: string)
	if rec.synergyApplied then return end
	local doctrine = Synergies.byId[doctrineId]
	local buff = doctrine and doctrine.roleBuffs[rec.def.role]
	if not buff then return end
	local oldMax = rec.maxHp
	rec.maxHp = math.floor(rec.maxHp * (1 + (buff.health or 0)))
	rec.hp += rec.maxHp - oldMax
	rec.scaledDamage = math.floor(rec.scaledDamage * (1 + (buff.damage or 0)))
	rec.moveSpeedMult = 1 + (buff.speed or 0)
	rec.synergyApplied = true
	rec.body:SetAttribute("Doctrine", doctrineId)
end

local function checkDoctrine(match: Match.Match, s: Match.SideState)
	if s.doctrine then
		for _, rec in s.units do applyDoctrineBuff(rec, s.doctrine) end
		return
	end
	local counts: { [string]: number } = {}
	for _, rec in s.units do
		if not rec.dead then counts[rec.def.role] = (counts[rec.def.role] or 0) + 1 end
	end
	for _, doctrine in Synergies.list do
		local complete = true
		for role, required in doctrine.requirements do
			if (counts[role] or 0) < required then complete = false break end
		end
		if complete then
			s.doctrine = doctrine.id
			for _, rec in s.units do applyDoctrineBuff(rec, doctrine.id) end
			Remotes.MatchEvent:FireAllClients("SynergyUnlocked", { side = s.side, doctrine = doctrine.id, name = doctrine.name })
			return
		end
	end
end

-- Request a unit spawn: validates cost/age, pays, queues.
function UnitSim.requestSpawn(match: Match.Match, side: string, unitId: string, bypassCost: boolean?): boolean
	if match.status ~= "Active" then
		return false
	end
	local s = match.sides[side]
	local def = Units.byId[unitId]
	if not def or def.age > s.age then
		return false
	end
	if #s.queue >= GameConfig.QUEUE_CAP then
		return false
	end
	if not bypassCost then
		if s.gold < def.cost then
			return false
		end
		s.gold -= def.cost
	end
	if #s.queue == 0 then
		s.lastSpawnAt = os.clock() -- training starts now; unit spawns after its trainTime
	end
	table.insert(s.queue, unitId)
	return true
end

local function popQueue(match: Match.Match, s: Match.SideState, now: number)
	if #s.queue == 0 or #s.units >= GameConfig.UNIT_CAP then
		return
	end
	-- Each unit trains for its own duration: (trainTime) --> unit --> (trainTime) --> unit ...
	local frontDef = Units.byId[s.queue[1]]
	if now - s.lastSpawnAt < frontDef.trainTime then
		return
	end
	s.lastSpawnAt = now
	local unitId = table.remove(s.queue, 1) :: string
	local def = Units.byId[unitId]
	local spawnCf = match.map.bases[s.side].unitSpawn
	-- Single-file queue formation: each unit spawns slightly behind the previous one.
	-- Max offset must stay under 14 (spawn point is 14 studs in front of the base).
	local formationSlots = { 0, 3, 6, 9, 12 }
	local formationIndex = (#s.units % #formationSlots) + 1
	local backOff = formationSlots[formationIndex]
	spawnCf = spawnCf * CFrame.new(0, 0, backOff) -- spawn cf faces lane; +z is behind
	local model, body = buildUnitModel(def, s.side, spawnCf)

	-- Apply difficulty scaling for enemy (side B) units
	local diffConfig = getDifficulty(match)
	local scaledHp = def.hp
	local scaledDamage = def.damage
	if s.side ~= match.playerSide then
		scaledHp = math.floor(def.hp * diffConfig.hpMult)
		scaledDamage = math.floor(def.damage * diffConfig.damageMult)
	end

	local rec: Match.UnitRecord = {
		model = model,
		body = body,
		def = def,
		hp = scaledHp,
		maxHp = scaledHp,
		scaledDamage = scaledDamage,
		side = s.side,
		nextAttackAt = 0,
		dead = false,
		damageAmp = 0,
		moveSpeedMult = 1,
		synergyApplied = false,
		laneOffset = body.Position.Z,
		moveHeading = s.side == "A" and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0),
		walkStart = now,
	}
	table.insert(s.units, rec)
	checkDoctrine(match, s)
end

export type Target = {
	kind: "unit" | "hero" | "base",
	pos: Vector3,
	unitRec: Match.UnitRecord?,
	humanoid: Humanoid?,
	radius: number,
}

local function heroTargetFor(match: Match.Match, enemySide: string): Target?
	-- only side A (player) has a hero
	if enemySide ~= match.playerSide then
		return nil
	end
	local player = Players:GetPlayers()[1]
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root and hum.Health > 0 then
		return { kind = "hero", pos = root.Position, unitRec = nil, humanoid = hum, radius = 2 }
	end
	return nil
end

local function findTarget(match: Match.Match, rec: Match.UnitRecord): Target
	local enemySide = Match.enemyOf(rec.side)
	local myPos = rec.body.Position
	local best: Target? = nil
	local bestDist = math.huge
	local isRanged = rec.def.role == "ranged"

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local mapFolder = workspace:FindFirstChild("Map")
	if mapFolder then
		params.FilterDescendantsInstances = {mapFolder}
	end

	local function hasLOS(targetPos: Vector3): boolean
		if not isRanged or not mapFolder then return true end
		local fromPos = myPos + Vector3.new(0, 1.5, 0)
		local toTarget = targetPos - fromPos
		local res = workspace:Raycast(fromPos, toTarget, params)
		return not (res and res.Instance.Name == "Rock")
	end

	for _, enemy in match.sides[enemySide].units do
		if not enemy.dead then
			local radius = enemy.body.Size.Z / 2
			local d = (enemy.body.Position - myPos).Magnitude - radius
			if d < bestDist and hasLOS(enemy.body.Position) then
				bestDist = d
				best = { kind = "unit", pos = enemy.body.Position, unitRec = enemy, humanoid = nil, radius = radius }
			end
		end
	end

	local hero = heroTargetFor(match, enemySide)
	if hero then
		local d = (hero.pos - myPos).Magnitude - hero.radius
		if d < bestDist and hasLOS(hero.pos) then
			bestDist = d
			best = hero
		end
	end

	local core = match.map.bases[enemySide].core
	local baseRadius = core.Size.X / 2
	local dBase = (core.Position - myPos).Magnitude - baseRadius
	if dBase < bestDist then
		bestDist = dBase
		best = { kind = "base", pos = core.Position, unitRec = nil, humanoid = nil, radius = baseRadius }
	end

	return best :: Target
end

-- Apply age-based status effect on attack
local function applyStatusEffect(match: Match.Match, rec: Match.UnitRecord, target: Target)
	local effectDef = StatusEffects.byAge[rec.def.age]
	if not effectDef then
		return
	end
	-- Lazy-require to avoid circular dependency
	local StatusEffectSystem = require(script.Parent.StatusEffectSystem)
	if target.kind == "unit" and target.unitRec then
		StatusEffectSystem.apply(match, target.unitRec, effectDef.id, rec.scaledDamage, rec.side)
	elseif target.kind == "hero" and target.humanoid then
		StatusEffectSystem.applyToHero(target.humanoid, effectDef.id, rec.scaledDamage)
	end
end

local function attack(match: Match.Match, rec: Match.UnitRecord, target: Target, now: number)
	if now < rec.nextAttackAt then
		return
	end
	rec.nextAttackAt = now + rec.def.attackSpeed

	-- start attack lunge/recoil animation (server accent) + notify the client
	-- animator to play the real limb swing
	rec.attackStartedAt = now
	rec.animBasePos = rec.body.Position
	rec.body:SetAttribute("AttackCount", ((rec.body:GetAttribute("AttackCount") :: number?) or 0) + 1)

	if rec.def.role == "ranged" then
		Remotes.FX:FireAllClients("Tracer", {
			from = rec.body.Position + Vector3.new(0, 1, 0),
			to = target.pos,
			color = rec.side == "A" and Color3.fromRGB(120, 180, 255) or Color3.fromRGB(255, 140, 120),
		})
	end

	local damage = rec.scaledDamage

	if rec.def.role == "ranged" then
		-- Spawn Projectile instead of instant damage
		local fromPos = rec.body.Position + Vector3.new(0, 1.5, 0)
		local targetPos = target.pos
		if target.kind == "hero" and target.humanoid then
			local hrp = target.humanoid.Parent and target.humanoid.Parent:FindFirstChild("HumanoidRootPart")
			if hrp then targetPos = hrp.Position end
		end
		
		local toTarget = (targetPos - fromPos)
		-- Check Line of Sight
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local mapFolder = workspace:FindFirstChild("Map")
		if mapFolder then
			params.FilterDescendantsInstances = {mapFolder}
			local res = workspace:Raycast(fromPos, toTarget, params)
			if res and res.Instance.Name == "Rock" then
				-- Blocked by terrain! Do not attack.
				rec.nextAttackAt = now + 0.2 -- check again soon
				return
			end
		end

		local dir = toTarget.Magnitude > 0.01 and toTarget.Unit or Vector3.new(1,0,0)
		local projId = tostring(math.random(100000, 999999))
		table.insert(match.projectiles, {
			id = projId,
			pos = fromPos,
			dir = dir,
			speed = 25,
			damage = damage,
			side = rec.side,
			age = rec.def.age,
			target = target,
			distanceTraveled = 0,
			maxDistance = rec.def.range + 10,
		})
	else
		-- Melee / Heavy instant attacks: Delay the damage to match the animation and allow the player to dodge
		task.delay(ATTACK_ANIM_DURATION * 0.6, function()
			if rec.dead or match.status ~= "Active" then return end
			
			-- Get the current position of the target to check if they dodged
			local currentPos = nil
			if target.kind == "unit" and target.unitRec and not target.unitRec.dead then
				currentPos = target.unitRec.body.Position
			elseif target.kind == "hero" and target.humanoid and target.humanoid.Health > 0 then
				local hrp = target.humanoid.Parent and target.humanoid.Parent:FindFirstChild("HumanoidRootPart")
				if hrp then currentPos = hrp.Position end
			elseif target.kind == "base" then
				currentPos = target.pos
			end
			
			if not currentPos then return end
			
			-- Verify the target is still within melee range (0 tolerance for easiest dodging)
			local toTarget = currentPos - rec.body.Position
			local flatDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude - target.radius
			if flatDist > rec.def.range then
				return -- The player/unit dodged out of range!
			end

			-- Apply damage
			if target.kind == "unit" and target.unitRec then
				UnitSim.damageUnit(match, target.unitRec, damage, rec.side, false)
				applyStatusEffect(match, rec, target)
				Remotes.FX:FireAllClients("ImpactVFX", { pos = target.unitRec.body.Position, age = rec.def.age })
			elseif target.kind == "hero" and target.humanoid then
				local s = match.sides[match.playerSide]
				local defLevel = (s.heroUpgrades and s.heroUpgrades.def) or 0
				local defMult = 1 - math.min(0.50, 0.10 * defLevel)
				target.humanoid:TakeDamage(damage * defMult)
				applyStatusEffect(match, rec, target)
			elseif target.kind == "base" then
				Match.damageBase(match, Match.enemyOf(rec.side), damage, rec.side, false)
			end
		end)
	end
end

-- Process active projectiles
local function processProjectiles(match: Match.Match, dt: number)
	for i = #match.projectiles, 1, -1 do
		local p = match.projectiles[i]
		local travel = p.speed * dt
		local nextPos = p.pos + p.dir * travel
		p.distanceTraveled += travel

		local hit = false
		local hitTerrain = false
		
		-- Raycast to check for terrain hit
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local mapFolder = workspace:FindFirstChild("Map")
		if mapFolder then
			params.FilterDescendantsInstances = {mapFolder}
			local res = workspace:Raycast(p.pos, p.dir * travel, params)
			if res and res.Instance.Name == "Rock" then
				hitTerrain = true
			end
		end

		if hitTerrain then
			hit = true
		else
			-- Check for entity collisions
			local enemySide = Match.enemyOf(p.side)
			
			-- Hero hit?
			if p.target and p.target.kind == "hero" and p.target.humanoid then
				local char = p.target.humanoid.Parent
				if char then
					local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and (root.Position - nextPos).Magnitude < 2.5 then
						local s = match.sides[match.playerSide]
						local defLevel = (s.heroUpgrades and s.heroUpgrades.def) or 0
						local defMult = 1 - math.min(0.50, 0.10 * defLevel)
						p.target.humanoid:TakeDamage(p.damage * defMult)
						hit = true
					end
				end
			end
			
			-- Unit hit?
			if not hit then
				for _, enemyRec in match.sides[enemySide].units do
					if not enemyRec.dead and (enemyRec.body.Position - nextPos).Magnitude < 4.0 then
						UnitSim.damageUnit(match, enemyRec, p.damage, p.side, false)
						Remotes.FX:FireAllClients("ImpactVFX", { pos = enemyRec.body.Position, age = p.age })
						hit = true
						break
					end
				end
			end
			
			-- Base hit?
			if not hit then
				local base = match.map.bases[enemySide].core
				if (base.Position - nextPos).Magnitude < base.Size.X / 2 + 2 then
					Match.damageBase(match, enemySide, p.damage, p.side, false)
					hit = true
				end
			end
		end

		if hit or p.distanceTraveled > p.maxDistance then
			table.remove(match.projectiles, i)
		else
			p.pos = nextPos
		end
	end
end

-- Main sim tick; dt is time since last tick.
function UnitSim.tick(match: Match.Match, dt: number)
	if match.status ~= "Active" then
		return
	end
	local now = os.clock()
	for _, s in match.sides do
		popQueue(match, s, now)
	end
	
	processProjectiles(match, dt)

	for _, s in match.sides do
		-- iterate over a copy: kills mutate the list
		local snapshot = table.clone(s.units)
		for _, rec in snapshot do
			if rec.dead then
				continue
			end

			-- Death topple animation (runs on dead units still in the world)
			if (rec :: any).deathStartedAt then
				local progress = math.clamp((now - (rec :: any).deathStartedAt) / 0.6, 0, 1)
				AnimController.applyDeathTopple(rec, progress)
				continue
			end

			local target = findTarget(match, rec)
			local myPos = rec.body.Position

			-- attack animation: lunge for melee, recoil for ranged/heavy
			if rec.attackStartedAt then
				local elapsed = now - rec.attackStartedAt
				if elapsed < ATTACK_ANIM_DURATION then
					local t = elapsed / ATTACK_ANIM_DURATION
					local wave = math.sin(t * math.pi)
					local dist = ATTACK_LUNGE[rec.def.role] or 0
					local base = rec.animBasePos or myPos
					local toTargetFlat = target.pos - base
					local dir = Vector3.new(toTargetFlat.X, 0, toTargetFlat.Z)
					if dir.Magnitude > 0.01 then
						dir = dir.Unit
					else
						dir = rec.body.CFrame.LookVector
					end
					local pos = base + dir * dist * wave
					moveModel(rec, CFrame.lookAt(pos, target.pos))
					continue
				else
					rec.attackStartedAt = nil
					rec.animBasePos = nil
				end
			end

			local toTarget = target.pos - myPos
			local flatDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude - target.radius

			local hasLOS = true
			if rec.def.role == "ranged" then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				local mapFolder = workspace:FindFirstChild("Map")
				if mapFolder then
					params.FilterDescendantsInstances = {mapFolder}
					local fromPos = myPos + Vector3.new(0, 1.5, 0)
					local targetPos = target.pos
					if target.kind == "hero" and target.humanoid then
						local hrp = target.humanoid.Parent and target.humanoid.Parent:FindFirstChild("HumanoidRootPart")
						if hrp then targetPos = hrp.Position end
					end
					local res = workspace:Raycast(fromPos, targetPos - fromPos, params)
					if res and res.Instance.Name == "Rock" then
						hasLOS = false
					end
				end
			end

			if flatDist <= rec.def.range and hasLOS then
				setAnimState(rec, "combat")
				attack(match, rec, target, now)
				-- face target
				local look = Vector3.new(target.pos.X, myPos.Y, target.pos.Z)
				if (look - myPos).Magnitude > 0.1 then
					moveModel(rec, CFrame.lookAt(myPos, look))
				end
			else
				-- advance toward target with separation steering
				local flatTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
				local dir = flatTarget.Magnitude > 0.01 and flatTarget.Unit or rec.moveHeading
				local separation = Vector3.zero
				for _, friend in s.units do
					if friend ~= rec and not friend.dead then
						local off = myPos - friend.body.Position
						local flatOff = Vector3.new(off.X, 0, off.Z)
						local d = flatOff.Magnitude
						local personalSpace = (rec.def.role == "heavy" or rec.def.role == "super_heavy") and 6.5 or 4
						if d < personalSpace and d > 0.01 then
							separation += flatOff.Unit * ((personalSpace - d) / personalSpace)
						end
					end
				end
				
				-- Obstacle Avoidance Steering (Blockcast for unit width)
				local obstacleAvoid = Vector3.zero
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				local mapFolder = workspace:FindFirstChild("Map")
				if mapFolder then
					params.FilterDescendantsInstances = {mapFolder}
					local cf = CFrame.new(myPos + Vector3.new(0, 1, 0), myPos + Vector3.new(0, 1, 0) + dir)
					local res = workspace:Blockcast(cf, rec.body.Size, dir * 8, params)
					if res and res.Instance.Name == "Rock" then
						-- Steer laterally away from the obstacle
						local normal = res.Normal
						local lateral = Vector3.new(dir.Z, 0, -dir.X)
						if lateral:Dot(normal) < 0 then
							lateral = -lateral
						end
						obstacleAvoid = lateral * 3.5
					end
				end

				local laneCorrection = Vector3.zero
				if flatDist > rec.def.range * 1.8 then
					laneCorrection = Vector3.new(0, 0, math.clamp((rec.laneOffset - myPos.Z) / 10, -0.75, 0.75))
				end
				local moveDir = dir + separation * 1.35 + obstacleAvoid + laneCorrection
				if moveDir.Magnitude > 0.01 then
					setAnimState(rec, "walk")
					moveDir = moveDir.Unit
					local steerAlpha = 1 - math.exp(-dt * 7)
					rec.moveHeading = rec.moveHeading:Lerp(moveDir, steerAlpha)
					if rec.moveHeading.Magnitude > 0.01 then rec.moveHeading = rec.moveHeading.Unit end
					local newPos = myPos + rec.moveHeading * rec.def.moveSpeed * rec.moveSpeedMult * dt
					moveModel(rec, CFrame.lookAt(newPos, newPos + rec.moveHeading))
				end
			end
		end
	end
end

-- Clears all units for a match reset.
function UnitSim.clearAll(match: Match.Match)
	for _, s in match.sides do
		for _, rec in table.clone(s.units) do
			rec.dead = true
			rec.model:Destroy()
		end
		table.clear(s.units)
		table.clear(s.queue)
	end
	-- Clear the object pool as well
	ObjectPool.clear(unitPool)
end

return UnitSim
