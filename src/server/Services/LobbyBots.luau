--!strict
-- Ambient fake players for the lobby: fill to a population floor, wander
-- between waypoints, occasionally "leave" through a portal. Despawn 1-for-1
-- as real players join. Lobby servers only.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local LobbyFlex = require(script.Parent.LobbyFlex)
local BotIdentity = require(script.Parent.BotIdentity)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

local LobbyBots = {}

local POPULATION_FLOOR = 8
local MAINTAIN_INTERVAL = 5
local WANDER_RADIUS = 45
-- Random real accounts give varied, human-looking avatars; failures fall back
-- to another roll, so no single id is load-bearing.
local AVATAR_ID_MIN = 20_000_000
local AVATAR_ID_MAX = 900_000_000

type Bot = { model: Model, leaving: boolean }
local bots: { Bot } = {}
local started = false

-- Default Roblox locomotion assets. The rig ships with the standard Animate
-- LocalScript, which never runs for a server-owned NPC — without this driver
-- bots glide around in T-pose.
local ANIMS = {
	[Enum.HumanoidRigType.R15] = { idle = 507766388, walk = 507777826, jump = 507765000 },
	[Enum.HumanoidRigType.R6] = { idle = 180435571, walk = 180426354, jump = 125750702 },
}

local function animateBot(humanoid: Humanoid)
	local animateScript = humanoid.Parent and humanoid.Parent:FindFirstChild("Animate")
	if animateScript then animateScript:Destroy() end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local ids = ANIMS[humanoid.RigType] or ANIMS[Enum.HumanoidRigType.R15]
	local function load(id: number): AnimationTrack
		local anim = Instance.new("Animation")
		anim.AnimationId = `rbxassetid://{id}`
		return animator:LoadAnimation(anim)
	end
	local idle = load(ids.idle)
	local walk = load(ids.walk)
	local jump = load(ids.jump)
	idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
				idle:Stop(0.2)
			end
			walk:AdjustSpeed(speed / 16)
		else
			walk:Stop(0.2)
			if not idle.IsPlaying then idle:Play(0.2) end
		end
	end)
	humanoid.Jumping:Connect(function(active)
		if active then jump:Play(0.1) end
	end)
end

local function syntheticFlex(rating: number): (string, Color3)
	if rating >= 1900 then
		return `IMPOSSIBLE {math.random(1, 8)}`, Color3.fromRGB(220, 90, 220)
	elseif rating >= 1400 then
		return `HARD {math.random(5, 25)}`, Color3.fromRGB(255, 140, 40)
	elseif math.random() < 0.15 then
		return "ROOKIE", Color3.fromRGB(150, 155, 165)
	end
	return `NORMAL {math.random(3, 40)}`, Color3.fromRGB(60, 200, 180)
end

local function randomWanderTarget(): Vector3
	local angle = math.random() * math.pi * 2
	local radius = 8 + math.random() * (WANDER_RADIUS - 8)
	return LobbyBuilder.ORIGIN + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
end

-- One web fetch per bot, with a cheap local rig as the fallback: repeated
-- avatar fetches at boot were a measurable source of lobby-load lag.
local function buildBotModel(): Model?
	local userId = math.random(AVATAR_ID_MIN, AVATAR_ID_MAX)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if ok and model then return model end
	local fallbackOk, fallback = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = Color3.fromHSV(math.random(), 0.5, 0.9)
		description.TorsoColor = Color3.fromHSV(math.random(), 0.7, 0.7)
		description.LeftArmColor = description.TorsoColor
		description.RightArmColor = description.TorsoColor
		description.LeftLegColor = Color3.fromHSV(math.random(), 0.6, 0.5)
		description.RightLegColor = description.LeftLegColor
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	return fallbackOk and fallback or nil
end

local function removeBot(bot: Bot)
	local index = table.find(bots, bot)
	if index then table.remove(bots, index) end
	if bot.model.Parent then bot.model:Destroy() end
end

-- Walks the bot to a random portal pad, then despawns it — reads as a player
-- entering a match rather than an entity blinking out.
local function leaveThroughPortal(bot: Bot)
	if bot.leaving then return end
	bot.leaving = true
	task.spawn(function()
		local humanoid = bot.model:FindFirstChildOfClass("Humanoid")
		local pads = CollectionService:GetTagged("ModePortal")
		local pad = pads[math.random(1, math.max(1, #pads))]
		if humanoid and pad and pad:IsA("BasePart") then
			humanoid:MoveTo(pad.Position)
			humanoid.MoveToFinished:Wait()
			task.wait(0.4)
		end
		removeBot(bot)
	end)
end

local function driveBot(bot: Bot)
	task.spawn(function()
		while bot.model.Parent and not bot.leaving do
			local humanoid = bot.model:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then break end
			local roll = math.random()
			if roll < 0.06 then
				-- Rarely "queue up" and leave; the maintain loop respawns later.
				leaveThroughPortal(bot)
				break
			elseif roll < 0.2 then
				humanoid.Jump = true
				task.wait(1 + math.random() * 2)
			elseif roll < 0.55 then
				humanoid:MoveTo(randomWanderTarget())
				humanoid.MoveToFinished:Wait()
			else
				task.wait(2 + math.random() * 5) -- idle, "reading" the lobby
			end
			task.wait(0.5 + math.random() * 1.5)
		end
	end)
end

local function spawnBot()
	task.spawn(function()
		local model = buildBotModel()
		if not model then return end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local name = BotIdentity.pickName()
		model.Name = name
		if humanoid then
			humanoid.DisplayName = name
		end

		local bot: Bot = { model = model, leaving = false }
		if humanoid then
			humanoid.Died:Connect(function()
				task.wait(2)
				removeBot(bot)
			end)
		end
		model:PivotTo(CFrame.new(randomWanderTarget() + Vector3.new(0, 3, 0)))
		model.Parent = workspace
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then part:SetNetworkOwner(nil) end
		end
		if humanoid then animateBot(humanoid) end

		local rating = BotIdentity.ambientRating()
		local flexText, flexColor = syntheticFlex(rating)
		LobbyFlex.attachBillboard(model, `ELO {rating}`, flexText, flexColor)

		table.insert(bots, bot)
		driveBot(bot)
	end)
end

function LobbyBots.start()
	if started then return end
	started = true
	task.spawn(function()
		while true do
			local target = math.max(0, POPULATION_FLOOR - #Players:GetPlayers())
			local active = 0
			for _, bot in bots do
				if not bot.leaving then active += 1 end
			end
			if active < target then
				spawnBot() -- one per tick keeps arrivals staggered
			elseif active > target then
				for _, bot in bots do
					if not bot.leaving then
						leaveThroughPortal(bot)
						break
					end
				end
			end
			task.wait(MAINTAIN_INTERVAL)
		end
	end)
end

return LobbyBots
