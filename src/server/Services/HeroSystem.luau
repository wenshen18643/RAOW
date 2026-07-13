--!strict
-- Player hero: spawning at base, escalating respawn timer, age-scaled HP,
-- server-validated weapon fire (hitscan/melee raycast).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local HeroWeapons = require(ReplicatedStorage.Shared.Config.HeroWeapons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)
local VFXConfig = require(ReplicatedStorage.Shared.Config.VFXConfig)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)
local RaycastHitbox = require(script.Parent.RaycastHitbox)
local StatusEffectSystem = require(script.Parent.StatusEffectSystem)
local Telemetry = require(script.Parent.Telemetry)

local HeroSystem = {}

local lastFireAt: { [Player]: number } = {}
local lastFireSecondaryAt: { [Player]: number } = {}
local movementState: { [Player]: { pos: Vector3, at: number } } = {}

local function playerSide(player: Player): string?
	local side = player:GetAttribute("Side")
	return typeof(side) == "string" and side or nil
end

local function finiteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 100000 and math.abs(v.Y) < 100000 and math.abs(v.Z) < 100000
end

local function applyAgeStats(match: Match.Match, player: Player, char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local side = playerSide(player)
	if hum and side then
		local s = match.sides[side]
		local maxHp = Ages[s.age].heroMaxHp * (1 + 0.15 * s.heroUpgrades.health)
		local frac = hum.Health / hum.MaxHealth
		hum.MaxHealth = maxHp
		hum.Health = math.max(hum.Health, maxHp * frac)
	end
end

local function placeAtSpawn(match: Match.Match, player: Player, char: Model)
	-- Defer so the character is fully parented and the engine has finished its
	-- default spawn positioning; then move the root part directly.
	task.defer(function()
		local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if not root then
			return
		end
		-- Wait until the character is in the workspace so CFrame writes stick.
		local timeout = os.clock() + 0.5
		while not char:IsDescendantOf(workspace) and os.clock() < timeout do
			task.wait()
		end
		local side = playerSide(player)
		if not side then return end
		local spawnCf = match.map.bases[side].heroSpawn
		root.CFrame = spawnCf
		movementState[player] = { pos = root.Position, at = os.clock() }
		char:SetAttribute("EntityType", "Hero")
		char:SetAttribute("Side", side)
		root:SetAttribute("EntityType", "Hero")
		root:SetAttribute("Side", side)
		-- Keep the humanoid upright and snap it out of any physics state.
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Sit = false
			hum.PlatformStand = false
		end
	end)
end

function HeroSystem.onAgeUp(match: Match.Match, player: Player)
	if player.Character then
		applyAgeStats(match, player, player.Character)
	end
end

function HeroSystem.buyUpgrade(match: Match.Match, player: Player, stat: string)
	if match.status ~= "Active" then return end
	local side = playerSide(player)
	if not side then return end
	local s = match.sides[side]
	local level = (s.heroUpgrades :: any)[stat]
	if type(level) ~= "number" then return end
	
	local cost = 500 * (2 ^ level)
	if s.gold >= cost then
		s.gold -= cost;
		(s.heroUpgrades :: any)[stat] = level + 1
		if stat == "health" and player.Character then
			applyAgeStats(match, player, player.Character)
		end
	end
end

-- Hook character lifecycle for the (single) player.
-- Takes a getter so the binding survives match restarts.
function HeroSystem.bindPlayer(getMatch: () -> Match.Match, player: Player)
	local function onCharacter(char: Model)
		local match = getMatch()
		placeAtSpawn(match, player, char)
		applyAgeStats(match, player, char)
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.Died:Once(function()
				local match = getMatch()
				local side = playerSide(player)
				if not side then return end
				local s = match.sides[side]
				s.heroDeaths += 1
				
				-- Award Side B (AI) for defeating the player commander
				Match.awardHeroKill(match, Match.enemyOf(side), s.age)
				local delay = math.min(
					GameConfig.HERO_RESPAWN_BASE + (s.heroDeaths - 1) * GameConfig.HERO_RESPAWN_STEP,
					GameConfig.HERO_RESPAWN_MAX
				)
				Remotes.MatchEvent:FireClient(player, "HeroRespawn", { delay = delay })
				task.delay(delay, function()
				if player.Parent and getMatch() == match and match.status == "Active" then
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

-- Process a single hit part for damage and status effects.
-- Shared by both melee and hitscan branches.
local function processHit(
	match: Match.Match,
	part: BasePart,
	finalDamage: number,
	s: Match.SideState
): boolean
	local entityType = part:GetAttribute("EntityType")
	local model = part:FindFirstAncestorOfClass("Model")
	if not entityType and model then entityType = model:GetAttribute("EntityType") end
	if not entityType and model and model.PrimaryPart then
		entityType = model.PrimaryPart:GetAttribute("EntityType")
		part = model.PrimaryPart
	end

	if entityType == "Unit" then
		local side = part:GetAttribute("Side")
		if side ~= s.side then
			local rec = UnitSim.findRecordByPart(match, part)
			if rec then
				UnitSim.damageUnit(match, rec, finalDamage, s.side, true)
				Remotes.FX:FireAllClients("Damage", {
					pos = part.Position + Vector3.new(0, part.Size.Y / 2, 0),
					amount = finalDamage,
					hero = true,
				})
				-- Apply age-specific status effect if one exists
				local effectDef = StatusEffects.byAge[s.age]
				if effectDef then
					StatusEffectSystem.apply(match, rec, effectDef.id, finalDamage, s.side)
				end
				return true
			end
		end
	elseif entityType == "Base" then
		local side = part:GetAttribute("Side")
		if side ~= s.side and typeof(side) == "string" then
			Match.damageBase(match, side, finalDamage * 0.5, s.side, true)
			return true
		end
	elseif entityType == "Hero" and model then
		local targetSide = model:GetAttribute("Side")
		local hum = model:FindFirstChildOfClass("Humanoid")
		if targetSide ~= s.side and hum and hum.Health > 0 then
			local targetState = match.sides[targetSide]
			local defense = targetState and targetState.heroUpgrades.def or 0
			local multiplier = 1 - math.min(0.5, defense * 0.1)
			hum:TakeDamage(finalDamage * multiplier)
			return true
		end
	end
	return false
end

-- Corrects client-owned character physics that exceed the legal movement
-- envelope. Normal movement remains responsive because ownership stays local.
function HeroSystem.tickMovement(match: Match.Match)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local side = playerSide(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not side or not char or not hum or not root or hum.Health <= 0 then continue end
		hum.WalkSpeed = math.min(hum.WalkSpeed, 16)
		hum.JumpPower = math.min(hum.JumpPower, 50)
		hum.JumpHeight = math.min(hum.JumpHeight, 7.2)
		local state = movementState[player]
		if not state then
			movementState[player] = { pos = root.Position, at = now }
			continue
		end
		local pos = root.Position
		local elapsed = math.max(0.05, now - state.at)
		local maxDistance = 22 * elapsed + 6
		local inBounds = math.abs(pos.X) <= GameConfig.LANE_LENGTH / 2 + 38
			and math.abs(pos.Z) <= GameConfig.LANE_WIDTH / 2 + 28
			and pos.Y >= -8 and pos.Y <= 75
		local legalSpeed = (pos - state.pos).Magnitude <= maxDistance
		if not inBounds or not legalSpeed then
			root.CFrame = CFrame.new(state.pos) * (root.CFrame - root.CFrame.Position)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			Telemetry.count("hero_movement_corrected")
		else
			state.pos = pos
		end
		state.at = now
	end
end

-- Handle melee weapon swing via RaycastHitbox arc.
local function handleMelee(
	match: Match.Match,
	origin: Vector3,
	direction: Vector3,
	char: Model,
	weapon: HeroWeapons.WeaponDef,
	finalDamage: number,
	s: Match.SideState,
	isSecondary: boolean
): boolean
	-- Perform arc sweep; returns { { part: BasePart, position: Vector3 } }
	local hits = RaycastHitbox.swingArc(origin, direction.Unit, weapon.range, { char })

	local confirmed = false
	local processed: { [Instance]: boolean } = {}
	for _, hitResult in hits do
		local model = hitResult.part:FindFirstAncestorOfClass("Model")
		local key: Instance = model or hitResult.part
		if not processed[key] then
			processed[key] = true
			local didHit = processHit(match, hitResult.part, finalDamage, s)
			confirmed = didHit or confirmed
			if didHit then
				Remotes.FX:FireAllClients("ImpactVFX", { pos = hitResult.position, age = s.age })
			end
		end
	end

	-- Single swing VFX (arc visual) regardless of how many hits
	Remotes.FX:FireAllClients("MeleeSwing", {
		origin = origin,
		direction = direction.Unit,
		range = weapon.range,
		age = s.age,
		isSecondary = isSecondary,
	})
	return confirmed
end

-- Handle hitscan weapon fire via single workspace raycast.
local function handleHitscan(
	match: Match.Match,
	origin: Vector3,
	direction: Vector3,
	char: Model,
	weapon: HeroWeapons.WeaponDef,
	finalDamage: number,
	s: Match.SideState,
	isSecondary: boolean
): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local result = workspace:Raycast(origin, direction.Unit * weapon.range, params)
	local hitPos = result and result.Position or (origin + direction.Unit * weapon.range)

	-- Age-specific tracer using VFXConfig color
	local vfx = VFXConfig.AGES[s.age]
	Remotes.FX:FireAllClients("Tracer", {
		from = origin,
		to = hitPos,
		color = vfx and vfx.tracerColor or Color3.fromRGB(255, 240, 180),
	})

	if not result then
		return false
	end

	-- Process damage and status on the hit target
	local confirmed = processHit(match, result.Instance, finalDamage, s)

	-- Impact VFX at the hit position
	Remotes.FX:FireAllClients("ImpactVFX", {
		pos = hitPos,
		age = s.age,
	})
	return confirmed
end

-- Validate and apply a weapon shot from the client.
function HeroSystem.handleFire(match: Match.Match, player: Player, origin: Vector3, direction: Vector3, isSecondary: boolean)
	if match.status ~= "Active" then
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if not finiteVector(origin) or not finiteVector(direction) then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not char or not hum or hum.Health <= 0 or not head then
		return
	end

	local side = playerSide(player)
	if not side then return end
	local s = match.sides[side]
	local weapon = HeroWeapons[s.age]

	-- rate limit
	local now = os.clock()
	local cdDict = isSecondary and lastFireSecondaryAt or lastFireAt
	local cdTime = isSecondary and 4.0 or weapon.fireCooldown

	local last = cdDict[player] or 0
	if now - last < cdTime * 0.9 then
		return
	end
	cdDict[player] = now

	-- origin sanity: must come from near the head
	if (origin - head.Position).Magnitude > 12 then
		return
	end
	local movement = movementState[player]
	if movement and (head.Position - movement.pos).Magnitude > 12 then
		Telemetry.count("weapon_rejected_movement_desync")
		return
	end
	if direction.Magnitude < 0.01 then
		return
	end

	local finalDamage = weapon.damage * (1 + 0.15 * s.heroUpgrades.dmg)
	if isSecondary then
		finalDamage *= 2.0
	end

	-- Dispatch based on weapon kind
	local confirmed: boolean
	if weapon.kind == "melee" then
		confirmed = handleMelee(match, origin, direction, char, weapon, finalDamage, s, isSecondary)
	else
		confirmed = handleHitscan(match, origin, direction, char, weapon, finalDamage, s, isSecondary)
	end
	if confirmed then
		Remotes.HitConfirm:FireClient(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastFireAt[player] = nil
	lastFireSecondaryAt[player] = nil
	movementState[player] = nil
end)

return HeroSystem
