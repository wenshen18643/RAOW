--!strict
-- Base turrets: buy/sell on mounts, auto-fire at nearest enemy in range.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Turrets = require(ReplicatedStorage.Shared.Config.Turrets)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)

local TurretSystem = {}

local function buildTurretModel(def: any, mount: BasePart): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = `Turret_{def.name}`

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(3, 2.4, 3)
	head.Color = Ages[def.age].color
	head.Material = Enum.Material.Metal
	head.Anchored = true
	head.CanCollide = false
	head.CFrame = mount.CFrame * CFrame.new(0, mount.Size.Y / 2 + 1.2, 0)
	head.Parent = model

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.8, 0.8, 4)
	barrel.Color = Color3.fromRGB(40, 40, 40)
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.CFrame = head.CFrame * CFrame.new(0, 0, -2)
	barrel.Parent = model

	model.PrimaryPart = head
	model.Parent = mount.Parent
	return model, barrel
end

function TurretSystem.tryBuild(match: Match.Match, side: string, slot: number): boolean
	if match.status ~= "Active" then
		return false
	end
	local s = match.sides[side]
	if slot < 1 or slot > GameConfig.TURRET_SLOTS or s.turrets[slot] ~= nil then
		return false
	end
	local def = Turrets[s.age]
	if s.gold < def.cost then
		return false
	end
	s.gold -= def.cost
	local mount = match.map.bases[side].turretMounts[slot]
	local model, muzzle = buildTurretModel(def, mount)
	s.turrets[slot] = { def = def, model = model, muzzle = muzzle, nextFireAt = 0 }
	return true
end

function TurretSystem.trySell(match: Match.Match, side: string, slot: number): boolean
	local s = match.sides[side]
	local rec = s.turrets[slot]
	if not rec then
		return false
	end
	s.gold += math.floor(rec.def.cost * GameConfig.TURRET_SELL_REFUND)
	rec.model:Destroy()
	s.turrets[slot] = nil
	return true
end

local function aimAndFire(match: Match.Match, side: string, rec: Match.TurretRecord, now: number)
	if now < rec.nextFireAt then
		return
	end
	local enemySide = Match.enemyOf(side)
	local muzzlePos = rec.muzzle.Position
	local best: Match.UnitRecord? = nil
	local bestDist = rec.def.range

	for _, unit in match.sides[enemySide].units do
		if not unit.dead then
			local d = (unit.body.Position - muzzlePos).Magnitude
			if d < bestDist then
				bestDist = d
				best = unit
			end
		end
	end
	if not best then
		return
	end
	local target = best :: Match.UnitRecord
	rec.nextFireAt = now + rec.def.attackSpeed

	-- rotate turret head toward target
	local head = rec.model.PrimaryPart
	if head then
		local look = Vector3.new(target.body.Position.X, head.Position.Y, target.body.Position.Z)
		head.CFrame = CFrame.lookAt(head.Position, look)
		rec.muzzle.CFrame = head.CFrame * CFrame.new(0, 0, -2)
	end

	Remotes.FX:FireAllClients("Tracer", {
		from = rec.muzzle.Position,
		to = target.body.Position,
		color = Color3.fromRGB(255, 220, 120),
	})
	UnitSim.damageUnit(match, target, rec.def.damage, side, false)
end

function TurretSystem.tick(match: Match.Match)
	if match.status ~= "Active" then
		return
	end
	local now = os.clock()
	for side, s in match.sides do
		for _, rec in s.turrets do
			if rec then
				aimAndFire(match, side, rec, now)
			end
		end
	end
end

function TurretSystem.clearAll(match: Match.Match)
	for _, s in match.sides do
		for slot, rec in s.turrets do
			if rec then
				rec.model:Destroy()
			end
		end
		table.clear(s.turrets)
	end
end

return TurretSystem
