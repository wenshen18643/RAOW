--!strict
-- Client-side visual effects: age-specific impact VFX, tracers, explosions,
-- melee swing arcs, status effect indicators, floating damage/gold numbers,
-- screen shake, and the age-up flash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local GameUI = require(script.Parent.GameUI)
local Viewmodel = require(script.Parent.Viewmodel)

local VFXConfig = nil -- lazy loaded after Shared is ready

local FX = {}
local localSide: string? = nil

local fxRng = Random.new()

local function getVFXConfig()
	if not VFXConfig then
		local ok, result = pcall(function()
			return require(ReplicatedStorage.Shared.Config.VFXConfig)
		end)
		if ok then
			VFXConfig = result
		end
	end
	return VFXConfig
end

-- Generic particle burst: spawns small neon parts flying outward from a point
local function particleBurst(pos: Vector3, color: Color3, secondaryColor: Color3, count: number, size: number)
	local rng = Random.new()
	for i = 1, count do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * rng:NextNumber(size * 0.4, size * 0.8)
		p.Color = i % 2 == 0 and secondaryColor or color
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.Position = pos
		p.Parent = workspace

		-- Fly outward in a random direction
		local dir = Vector3.new(
			rng:NextNumber(-1, 1),
			rng:NextNumber(0.3, 1.2),
			rng:NextNumber(-1, 1)
		).Unit
		local targetPos = pos + dir * rng:NextNumber(2, 5)

		local tween = TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = targetPos,
			Size = Vector3.one * 0.1,
			Transparency = 1,
		})
		tween:Play()
		Debris:AddItem(p, 0.4)
	end
end

-- Tracer: neon beam from point A to B
local function tracer(data: { [string]: any })
	local from = data.from :: Vector3
	local to = data.to :: Vector3
	local color = data.color :: Color3? or Color3.fromRGB(255, 240, 180)

	local dir = to - from
	local mid = from + dir / 2

	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = color :: Color3
	beam.Size = Vector3.new(0.15, 0.15, dir.Magnitude)
	beam.CFrame = CFrame.lookAt(mid, to)
	beam.Parent = workspace

	local tween = TweenService:Create(beam, TweenInfo.new(0.12), { Transparency = 1 })
	tween:Play()
	Debris:AddItem(beam, 0.15)
end

-- Explosion: expanding neon sphere
local function explosion(data: { [string]: any })
	local pos = data.pos :: Vector3
	local color = data.color :: Color3? or Color3.fromRGB(255, 180, 80)

	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.Material = Enum.Material.Neon
	ball.Color = color :: Color3
	ball.Size = Vector3.one * 4
	ball.Position = pos
	ball.Parent = workspace

	local tween = TweenService:Create(ball, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 22,
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ball, 0.5)
end

--------------------------------------------------------------------------------
-- Screen shake: decaying random camera rotation applied after the camera update.
--------------------------------------------------------------------------------

local shakeMag = 0

-- Kicks the camera; magnitude ~0.2 subtle, ~1 heavy.
function FX.shake(magnitude: number)
	shakeMag = math.max(shakeMag, magnitude)
end

RunService:BindToRenderStep("FXShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeMag < 0.01 then
		shakeMag = 0
		return
	end
	local cam = workspace.CurrentCamera
	if cam then
		local m = shakeMag * 0.012
		cam.CFrame = cam.CFrame * CFrame.Angles(
			fxRng:NextNumber(-m, m),
			fxRng:NextNumber(-m, m),
			fxRng:NextNumber(-m, m) * 0.5
		)
	end
	shakeMag *= math.exp(-dt * 7)
end)

--------------------------------------------------------------------------------
-- Floating world-space text (damage numbers, gold rewards)
--------------------------------------------------------------------------------

local function floatingText(pos: Vector3, text: string, color: Color3, size: number, riseStuds: number, duration: number)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end
	-- small random offset so simultaneous numbers don't stack
	local att = Instance.new("Attachment")
	att.Position = pos + Vector3.new(fxRng:NextNumber(-1, 1), fxRng:NextNumber(0, 0.8), fxRng:NextNumber(-1, 1))
	att.Parent = terrain

	local gui = Instance.new("BillboardGui")
	gui.Adornee = att
	gui.Size = UDim2.fromOffset(120, 34)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.Parent = att

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextSize = size
	lbl.TextStrokeTransparency = 0.4
	lbl.Parent = gui

	TweenService:Create(att, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = att.Position + Vector3.new(0, riseStuds, 0),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(att, duration + 0.1)
end

local function damageNumber(data: { [string]: any })
	local amount = data.amount :: number? or 0
	local isHero = data.hero == true
	floatingText(
		data.pos :: Vector3,
		tostring(math.floor(amount)),
		isHero and Color3.fromRGB(255, 235, 130) or Color3.fromRGB(240, 240, 240),
		isHero and 26 or 18,
		3,
		0.65
	)
end

local function rewardPopup(data: { [string]: any })
	local amount = data.amount :: number? or 0
	floatingText(data.pos :: Vector3, `+{math.floor(amount)}g`, Color3.fromRGB(255, 210, 70), 22, 4.5, 1.0)
end

--------------------------------------------------------------------------------
-- Age-up flash: quick white bloom over the whole screen
--------------------------------------------------------------------------------

local function ageUpFlash()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "AgeUpFlash"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui
	TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(gui, 0.55)
	FX.shake(0.5)

	-- Camera FOV kick: brief zoom-out then snap back for a "slow-mo" feel
	local cam = workspace.CurrentCamera
	if cam then
		local baseFov = cam.FieldOfView
		cam.FieldOfView = baseFov + 12
		TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = baseFov }):Play()
	end

	-- Radial shockwave at the local base
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local wave = Instance.new("Part")
		wave.Shape = Enum.PartType.Cylinder
		wave.Anchored = true
		wave.CanCollide = false
		wave.CanQuery = false
		wave.Material = Enum.Material.Neon
		wave.Color = Color3.fromRGB(255, 240, 180)
		wave.Size = Vector3.new(0.4, 8, 8)
		wave.CFrame = CFrame.new(root.Position.X, 0.2, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		wave.Parent = workspace
		TweenService:Create(wave, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, 70, 70),
			Transparency = 1,
		}):Play()
		Debris:AddItem(wave, 0.6)
	end
end

-- Age-specific impact VFX at weapon-to-unit hit point (Phase 1)
local function impactVFX(data: { [string]: any })
	local pos = data.pos :: Vector3
	local age = data.age :: number? or 1

	local config = getVFXConfig()
	if config and config.AGES[age] then
		local vfx = config.AGES[age]
		particleBurst(pos, vfx.impactColor, vfx.secondaryColor, vfx.particleCount, vfx.impactSize)
	else
		-- Fallback: generic white sparks
		particleBurst(pos, Color3.fromRGB(220, 220, 220), Color3.fromRGB(180, 180, 180), 6, 3)
	end
end

-- Melee swing visual: brief arc indicator (Phase 1)
local function meleeSwing(data: { [string]: any })
	local origin = data.origin :: Vector3
	local direction = data.direction :: Vector3
	local range = data.range :: number? or 9
	local age = data.age :: number? or 1

	local config = getVFXConfig()
	local color = Color3.fromRGB(200, 200, 200)
	if config and config.AGES[age] then
		color = config.AGES[age].impactColor
	end

	-- Create a brief semi-transparent arc sweep indicator
	local arc = Instance.new("Part")
	arc.Anchored = true
	arc.CanCollide = false
	arc.Material = Enum.Material.Neon
	arc.Color = color
	arc.Size = Vector3.new(range * 1.5, 0.1, range * 1.5)
	arc.Shape = Enum.PartType.Cylinder
	arc.Transparency = 0.7
	arc.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.Angles(0, 0, math.rad(90))
	arc.Parent = workspace

	local tween = TweenService:Create(arc, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(range * 2, 0.05, range * 2),
	})
	tween:Play()
	Debris:AddItem(arc, 0.3)
end

-- Status effect visual indicator (Phase 4)
local function statusVFX(data: { [string]: any })
	local pos = data.pos :: Vector3
	local color = data.color :: Color3? or Color3.fromRGB(255, 100, 100)
	local effectId = data.effectId :: string? or ""

	-- Small colored burst to indicate status effect applied
	local count = 4
	local size = 1.5

	-- Effect-specific visuals
	if effectId == "Burning" then
		-- Orange/red rising embers
		local rng = Random.new()
		for _ = 1, 5 do
			local ember = Instance.new("Part")
			ember.Shape = Enum.PartType.Ball
			ember.Size = Vector3.one * rng:NextNumber(0.3, 0.6)
			ember.Color = Color3.fromRGB(255, rng:NextInteger(80, 180), 20)
			ember.Material = Enum.Material.Neon
			ember.Anchored = true
			ember.CanCollide = false
			ember.Position = pos + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			ember.Parent = workspace

			TweenService:Create(ember, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = ember.Position + Vector3.new(0, rng:NextNumber(3, 6), 0),
				Transparency = 1,
				Size = Vector3.one * 0.05,
			}):Play()
			Debris:AddItem(ember, 0.9)
		end
	elseif effectId == "Bleed" then
		-- Red droplets falling down
		local rng = Random.new()
		for _ = 1, 4 do
			local drop = Instance.new("Part")
			drop.Shape = Enum.PartType.Ball
			drop.Size = Vector3.one * 0.35
			drop.Color = Color3.fromRGB(180, 30, 30)
			drop.Material = Enum.Material.SmoothPlastic
			drop.Anchored = true
			drop.CanCollide = false
			drop.Position = pos + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.5, 2), rng:NextNumber(-0.8, 0.8))
			drop.Parent = workspace

			TweenService:Create(drop, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = drop.Position - Vector3.new(0, 3, 0),
				Transparency = 1,
			}):Play()
			Debris:AddItem(drop, 0.6)
		end
	elseif effectId == "ArmorMelt" then
		-- Cyan shimmer/crackle
		particleBurst(pos, Color3.fromRGB(80, 220, 235), Color3.fromRGB(160, 240, 255), 6, 2)
	else
		-- Generic colored burst
		particleBurst(pos, color :: Color3, color :: Color3, count, size)
	end
end

function FX.start()
	local RemotesModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) :: any
	RemotesModule.StateUpdate.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" then localSide = state.playerSide end
	end)
	RemotesModule.FX.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "Tracer" then
			tracer(data)
		elseif kind == "Explosion" then
			explosion(data)
			-- shake scaled by distance to the blast
			local cam = workspace.CurrentCamera
			if cam then
				local dist = (cam.CFrame.Position - (data.pos :: Vector3)).Magnitude
				FX.shake(0.9 * math.clamp(1 - dist / 150, 0, 1))
			end
		elseif kind == "ImpactVFX" then
			impactVFX(data)
		elseif kind == "MeleeSwing" then
			meleeSwing(data)
		elseif kind == "StatusVFX" then
			statusVFX(data)
		elseif kind == "Damage" then
			damageNumber(data)
		elseif kind == "Reward" then
			rewardPopup(data)
		end
	end)
	RemotesModule.HitConfirm.OnClientEvent:Connect(function()
		GameUI.showHitmarker()
		Viewmodel.hitstop()
	end)

	RemotesModule.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		if event == "AgeUp" and data and data.side == localSide then
			ageUpFlash()
		end
	end)
end

return FX
