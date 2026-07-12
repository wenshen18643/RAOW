--!strict
-- Per-age special ability: barrage of falling projectiles over the enemy half of the lane.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Specials = require(ReplicatedStorage.Shared.Config.Specials)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)

local SpecialSystem = {}

local IMPACT_RADIUS = 14

local function dropProjectile(match: Match.Match, casterSide: string, def: any, x: number, z: number)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 4
	ball.Color = Ages[def.age].color
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	local groundY = match.map.laneY
	ball.Position = Vector3.new(x, groundY + 90, z)
	ball.Parent = workspace

	local tween = TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = Vector3.new(x, groundY + 2, z),
	})
	tween:Play()
	tween.Completed:Once(function()
		-- impact FX
		Remotes.FX:FireAllClients("Explosion", { pos = ball.Position, color = ball.Color })
		ball:Destroy()
		if match.status ~= "Active" then
			return
		end
		local enemySide = Match.enemyOf(casterSide)
		local impactPos = Vector3.new(x, groundY, z)
		for _, unit in table.clone(match.sides[enemySide].units) do
			if not unit.dead then
				local d = unit.body.Position - impactPos
				if Vector3.new(d.X, 0, d.Z).Magnitude <= IMPACT_RADIUS then
					UnitSim.damageUnit(match, unit, def.damagePerHit, casterSide, false)
				end
			end
		end
		-- can clip the enemy hero too
		if enemySide == match.playerSide then
			local player = game:GetService("Players"):GetPlayers()[1]
			local char = player and player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hum and root and hum.Health > 0 then
				local d = root.Position - impactPos
				if Vector3.new(d.X, 0, d.Z).Magnitude <= IMPACT_RADIUS then
					hum:TakeDamage(def.damagePerHit * 0.6)
				end
			end
		end
	end)
	Debris:AddItem(ball, 2)
end

function SpecialSystem.tryCast(match: Match.Match, side: string): boolean
	if match.status ~= "Active" then
		return false
	end
	local s = match.sides[side]
	local now = os.clock()
	if now < s.specialReadyAt then
		return false
	end
	local def = Specials[s.age]
	s.specialReadyAt = now + def.cooldown

	Remotes.MatchEvent:FireAllClients("SpecialFired", { side = side, name = def.name })

	-- Barrage falls on the enemy half of the lane
	local enemyHalfSign = side == "A" and 1 or -1
	local rng = Random.new()
	task.spawn(function()
		for i = 1, def.hits do
			if match.status ~= "Active" then
				return
			end
			local x = enemyHalfSign * rng:NextNumber(10, GameConfig.LANE_LENGTH / 2)
			local z = rng:NextNumber(-GameConfig.LANE_WIDTH / 2 + 4, GameConfig.LANE_WIDTH / 2 - 4)
			dropProjectile(match, side, def, x, z)
			task.wait(def.duration / def.hits)
		end
	end)
	return true
end

return SpecialSystem
