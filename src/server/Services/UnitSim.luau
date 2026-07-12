--!strict
-- Unit spawning, queue, movement, targeting, combat. Server-authoritative,
-- anchored parts moved via PivotTo (no Humanoids).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Units = require(ReplicatedStorage.Shared.Config.Units)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Match = require(script.Parent.Match)

local UnitSim = {}

local unitsFolder: Folder? = nil

local ROLE_SIZE = {
	melee = Vector3.new(2.4, 5, 1.6),
	ranged = Vector3.new(2, 4.6, 1.4),
	heavy = Vector3.new(4.5, 6.5, 3.5),
}

local function getUnitsFolder(): Folder
	if not unitsFolder or not unitsFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Units"
		f.Parent = workspace
		unitsFolder = f
	end
	return unitsFolder :: Folder
end

local function makeHpBar(body: BasePart): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(50, 6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 1.5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 250
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	gui.Parent = body
	return fill
end

local function buildUnitModel(def: any, side: string, spawnCf: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = def.id

	local size = ROLE_SIZE[def.role]
	local ageColor = Ages[def.age].color
	local color = ageColor
	if def.role == "ranged" then
		color = ageColor:Lerp(Color3.new(1, 1, 1), 0.3)
	elseif def.role == "heavy" then
		color = ageColor:Lerp(Color3.new(0, 0, 0), 0.3)
	end

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.one * math.min(size.X, 2.2)
	head.Color = color:Lerp(Color3.new(1, 1, 1), 0.15)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	-- Team stripe so sides read instantly
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(size.X + 0.2, 0.8, size.Z + 0.2)
	stripe.Color = side == "A" and Color3.fromRGB(52, 120, 200) or Color3.fromRGB(200, 70, 60)
	stripe.Material = Enum.Material.Neon
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Parent = model

	model.PrimaryPart = body
	body:SetAttribute("EntityType", "Unit")
	body:SetAttribute("Side", side)

	-- position pieces relative to body
	local function place(cf: CFrame)
		body.CFrame = cf
		head.CFrame = cf * CFrame.new(0, size.Y / 2 + head.Size.Y / 2 - 0.3, 0)
		stripe.CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.6, 0)
	end
	place(spawnCf * CFrame.new(0, size.Y / 2, 0))

	makeHpBar(body)
	model.Parent = getUnitsFolder()
	return model, body
end

-- Move whole model, keeping pieces attached (all anchored).
local function moveModel(rec: Match.UnitRecord, cf: CFrame)
	local body = rec.body
	local model = rec.model
	local head = model:FindFirstChild("Head") :: BasePart?
	local stripe = model:FindFirstChild("Stripe") :: BasePart?
	body.CFrame = cf
	local size = body.Size
	if head then
		head.CFrame = cf * CFrame.new(0, size.Y / 2 + head.Size.Y / 2 - 0.3, 0)
	end
	if stripe then
		stripe.CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.6, 0)
	end
end

local function updateHpBar(rec: Match.UnitRecord)
	local bar = rec.body:FindFirstChild("HpBar")
	local fill = bar and bar:FindFirstChild("Fill", true) :: Frame?
	if fill then
		local frac = math.clamp(rec.hp / rec.def.hp, 0, 1)
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
		Match.award(match, killerSide, rec.def.reward, isHeroKill)
	end
	-- brief death fade
	for _, p in rec.model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 0.5
			p.Color = Color3.fromRGB(40, 40, 40)
		end
	end
	Debris:AddItem(rec.model, 0.6)
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
	rec.hp -= amount
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

-- Request a unit spawn: validates cost/age, pays, queues.
function UnitSim.requestSpawn(match: Match.Match, side: string, unitId: string): boolean
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
	if s.gold < def.cost then
		return false
	end
	s.gold -= def.cost
	table.insert(s.queue, unitId)
	return true
end

local function popQueue(match: Match.Match, s: Match.SideState, now: number)
	if #s.queue == 0 or #s.units >= GameConfig.UNIT_CAP then
		return
	end
	if now - s.lastSpawnAt < GameConfig.SPAWN_INTERVAL then
		return
	end
	s.lastSpawnAt = now
	local unitId = table.remove(s.queue, 1) :: string
	local def = Units.byId[unitId]
	local spawnCf = match.map.bases[s.side].unitSpawn
	-- random lane offset so units don't stack in one line
	local zOff = Random.new():NextNumber(-12, 12)
	spawnCf = spawnCf * CFrame.new(zOff, 0, 0) -- spawn cf faces lane; x is sideways after rotation
	local model, body = buildUnitModel(def, s.side, spawnCf)
	local rec: Match.UnitRecord = {
		model = model,
		body = body,
		def = def,
		hp = def.hp,
		side = s.side,
		nextAttackAt = 0,
		dead = false,
	}
	table.insert(s.units, rec)
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

	for _, enemy in match.sides[enemySide].units do
		if not enemy.dead then
			local d = (enemy.body.Position - myPos).Magnitude
			if d < bestDist then
				bestDist = d
				best = { kind = "unit", pos = enemy.body.Position, unitRec = enemy, humanoid = nil, radius = enemy.body.Size.Z / 2 }
			end
		end
	end

	local hero = heroTargetFor(match, enemySide)
	if hero then
		local d = (hero.pos - myPos).Magnitude
		if d < bestDist then
			bestDist = d
			best = hero
		end
	end

	if not best then
		local core = match.map.bases[enemySide].core
		best = { kind = "base", pos = core.Position, unitRec = nil, humanoid = nil, radius = core.Size.X / 2 }
	end
	return best :: Target
end

local function attack(match: Match.Match, rec: Match.UnitRecord, target: Target, now: number)
	if now < rec.nextAttackAt then
		return
	end
	rec.nextAttackAt = now + rec.def.attackSpeed

	if rec.def.role == "ranged" then
		Remotes.FX:FireAllClients("Tracer", {
			from = rec.body.Position + Vector3.new(0, 1, 0),
			to = target.pos,
			color = rec.side == "A" and Color3.fromRGB(120, 180, 255) or Color3.fromRGB(255, 140, 120),
		})
	end

	if target.kind == "unit" and target.unitRec then
		UnitSim.damageUnit(match, target.unitRec, rec.def.damage, rec.side, false)
	elseif target.kind == "hero" and target.humanoid then
		target.humanoid:TakeDamage(rec.def.damage)
	elseif target.kind == "base" then
		Match.damageBase(match, Match.enemyOf(rec.side), rec.def.damage, rec.side, false)
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

	for _, s in match.sides do
		-- iterate over a copy: kills mutate the list
		local snapshot = table.clone(s.units)
		for _, rec in snapshot do
			if rec.dead then
				continue
			end
			local target = findTarget(match, rec)
			local myPos = rec.body.Position
			local toTarget = target.pos - myPos
			local flatDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude - target.radius

			if flatDist <= rec.def.range then
				attack(match, rec, target, now)
				-- face target
				local look = Vector3.new(target.pos.X, myPos.Y, target.pos.Z)
				if (look - myPos).Magnitude > 0.1 then
					moveModel(rec, CFrame.lookAt(myPos, look))
				end
			else
				-- advance toward target
				local dir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
				local step = dir * rec.def.moveSpeed * dt
				local newPos = myPos + step
				-- crowd control: don't walk into a friendly standing ahead
				local blocked = false
				for _, friend in s.units do
					if friend ~= rec and not friend.dead then
						local fd = (friend.body.Position - newPos)
						if Vector3.new(fd.X, 0, fd.Z).Magnitude < 3 then
							blocked = true
							break
						end
					end
				end
				if not blocked then
					moveModel(rec, CFrame.lookAt(newPos, newPos + dir))
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
end

return UnitSim
