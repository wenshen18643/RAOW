--!strict
-- Base turrets: buy/sell on mounts, auto-fire at nearest enemy in range.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

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

function TurretSystem.tryBuild(match: Match.Match, side: string, slot: number, bypassCost: boolean?): boolean
	if match.status ~= "Active" then
		return false
	end
	local s = match.sides[side]
	if slot < 1 or slot > GameConfig.TURRET_SLOTS then
		return false
	end
	local def = Turrets[s.age]
	local oldRec = s.turrets[slot]
	if oldRec and oldRec.def.age >= def.age then
		return false
	end
	local upgradeCredit = oldRec and math.floor(oldRec.def.cost * GameConfig.TURRET_SELL_REFUND) or 0
	local purchaseCost = math.max(0, def.cost - upgradeCredit)
	if not bypassCost then
		if s.gold < purchaseCost then
			return false
		end
		s.gold -= purchaseCost
	end
	
	-- Replacing an obsolete turret automatically applies its normal sell credit.
	if oldRec and oldRec.model then
		oldRec.model:Destroy()
	end
	
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

local function aimAndFire(match: Match.Match, side: string, rec: Match.TurretRecord, now: number, params: RaycastParams)
	if now < rec.nextFireAt then
		return
	end
	local enemySide = Match.enemyOf(side)
	local muzzlePos = rec.muzzle.Position
	local best: Match.UnitRecord? = nil
	local bestDist = rec.def.range

	local mapFolder = match.map.folder

	for _, unit in match.sides[enemySide].units do
		if not unit.dead then
			local d = (unit.body.Position - muzzlePos).Magnitude
			if d < bestDist then
				-- Check Line of Sight
				local hasLOS = true
				if mapFolder.Parent then
					local res = workspace:Raycast(muzzlePos, unit.body.Position - muzzlePos, params)
					if res and res.Instance.Name == "Rock" then
						hasLOS = false
					end
				end
				
				if hasLOS then
					bestDist = d
					best = unit
				end
			end
		end
	end

	local targetPos = nil
	local targetHum = nil
	local targetIsHero = false
	
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Side") == enemySide and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - muzzlePos).Magnitude
				if d < bestDist then
					local hasLOS = true
					if mapFolder.Parent then
						local res = workspace:Raycast(muzzlePos, hrp.Position - muzzlePos, params)
						if res and res.Instance.Name == "Rock" then
							hasLOS = false
						end
					end
					
					if hasLOS then
						bestDist = d
						best = nil
						targetPos = hrp.Position
						targetHum = hum
						targetIsHero = true
					end
				end
			end
		end
	end

	if not best and not targetIsHero then
		return
	end
	
	rec.nextFireAt = now + rec.def.attackSpeed

	local aimPos = targetIsHero and (targetPos :: Vector3) or (best :: Match.UnitRecord).body.Position
	
	-- rotate turret head toward target
	local head = rec.model.PrimaryPart
	if head and aimPos then
		local look = Vector3.new(aimPos.X, head.Position.Y, aimPos.Z)
		head.CFrame = CFrame.lookAt(head.Position, look)
		rec.muzzle.CFrame = head.CFrame * CFrame.new(0, 0, -2)
	end

	Remotes.FX:FireAllClients("Tracer", {
		from = rec.muzzle.Position,
		to = aimPos,
		color = Color3.fromRGB(255, 220, 120),
	})
	
	if targetIsHero and targetHum then
		targetHum:TakeDamage(Match.reduceHeroDamage(match, enemySide, rec.def.damage))
		Remotes.FX:FireAllClients("Damage", {
			pos = aimPos,
			amount = rec.def.damage,
			hero = true,
		})
	elseif best then
		UnitSim.damageUnit(match, best, rec.def.damage, side, false)
		Remotes.FX:FireAllClients("Damage", {
			pos = best.body.Position,
			amount = rec.def.damage,
			hero = false,
		})
	end
end

function TurretSystem.tick(match: Match.Match)
	if match.status ~= "Active" then
		return
	end
	local now = os.clock()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { match.map.folder }
	for side, s in match.sides do
		for _, rec in s.turrets do
			if rec then
				aimAndFire(match, side, rec, now, params)
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

function TurretSystem.remountTurrets(match: Match.Match, side: string)
	local s = match.sides[side]
	local mounts = match.map.bases[side].turretMounts
	for slot = 1, GameConfig.TURRET_SLOTS do
		local rec = s.turrets[slot]
		if rec then
			-- Rebuild the turret model on the new mount
			rec.model:Destroy()
			local newModel, newMuzzle = buildTurretModel(rec.def, mounts[slot])
			rec.model = newModel
			rec.muzzle = newMuzzle
		end
	end
end

return TurretSystem
