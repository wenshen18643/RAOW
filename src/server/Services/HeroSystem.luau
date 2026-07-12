--!strict
-- Player hero: spawning at base, escalating respawn timer, age-scaled HP,
-- server-validated weapon fire (hitscan/melee raycast).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local HeroWeapons = require(ReplicatedStorage.Shared.Config.HeroWeapons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)

local HeroSystem = {}

local lastFireAt: { [Player]: number } = {}

local function applyAgeStats(match: Match.Match, char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		local age = match.sides[match.playerSide].age
		local maxHp = Ages[age].heroMaxHp
		local frac = hum.Health / hum.MaxHealth
		hum.MaxHealth = maxHp
		hum.Health = math.max(hum.Health, maxHp * frac)
	end
end

local function placeAtSpawn(match: Match.Match, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root then
		char:PivotTo(match.map.bases[match.playerSide].heroSpawn)
	end
end

function HeroSystem.onAgeUp(match: Match.Match, player: Player)
	if player.Character then
		applyAgeStats(match, player.Character)
	end
end

-- Hook character lifecycle for the (single) player.
-- Takes a getter so the binding survives match restarts.
function HeroSystem.bindPlayer(getMatch: () -> Match.Match, player: Player)
	local function onCharacter(char: Model)
		local match = getMatch()
		placeAtSpawn(match, char)
		applyAgeStats(match, char)
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.Died:Once(function()
				local match = getMatch()
				local s = match.sides[match.playerSide]
				s.heroDeaths += 1
				local delay = math.min(
					GameConfig.HERO_RESPAWN_BASE + (s.heroDeaths - 1) * GameConfig.HERO_RESPAWN_STEP,
					GameConfig.HERO_RESPAWN_MAX
				)
				Remotes.MatchEvent:FireClient(player, "HeroRespawn", { delay = delay })
				task.delay(delay, function()
					if player.Parent and getMatch().status == "Active" then
						player:LoadCharacter()
					end
				end)
			end)
		end
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

-- Validate and apply a weapon shot from the client.
function HeroSystem.handleFire(match: Match.Match, player: Player, origin: Vector3, direction: Vector3)
	if match.status ~= "Active" then
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not char or not hum or hum.Health <= 0 or not head then
		return
	end

	local s = match.sides[match.playerSide]
	local weapon = HeroWeapons[s.age]

	-- rate limit
	local now = os.clock()
	local last = lastFireAt[player] or 0
	if now - last < weapon.fireCooldown * 0.9 then
		return
	end
	lastFireAt[player] = now

	-- origin sanity: must come from near the head
	if (origin - head.Position).Magnitude > 12 then
		return
	end
	if direction.Magnitude < 0.01 then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local result = workspace:Raycast(origin, direction.Unit * weapon.range, params)
	local hitPos = result and result.Position or (origin + direction.Unit * weapon.range)

	Remotes.FX:FireAllClients("Tracer", {
		from = origin,
		to = hitPos,
		color = s.age >= 5 and Color3.fromRGB(120, 255, 220) or Color3.fromRGB(255, 240, 180),
	})

	if not result then
		return
	end
	local part = result.Instance
	local entityType = part:GetAttribute("EntityType")
	local model = part:FindFirstAncestorOfClass("Model")
	if not entityType and model and model.PrimaryPart then
		entityType = model.PrimaryPart:GetAttribute("EntityType")
		part = model.PrimaryPart
	end

	if entityType == "Unit" then
		local side = part:GetAttribute("Side")
		if side ~= match.playerSide then
			local rec = UnitSim.findRecordByPart(match, part)
			if rec then
				UnitSim.damageUnit(match, rec, weapon.damage, match.playerSide, true)
			end
		end
	elseif entityType == "Base" then
		local side = part:GetAttribute("Side")
		if side ~= match.playerSide and typeof(side) == "string" then
			Match.damageBase(match, side, weapon.damage * 0.5, match.playerSide, true)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastFireAt[player] = nil
end)

return HeroSystem
