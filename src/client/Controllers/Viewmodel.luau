--!strict
-- First-person hero weapon viewmodel: age-specific weapon + arms, procedural
-- sway (camera delta), walk bob (character velocity), idle breathing, and
-- per-weapon attack animations (melee slash, spear thrust, gun recoil).
-- Visible only to the local player (parented to CurrentCamera).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroWeapons = require(ReplicatedStorage.Shared.Config.HeroWeapons)
local Settings = require(script.Parent.Settings)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)

local Viewmodel = {}

local player = Players.LocalPlayer
local camera: Camera? = nil
local currentAge = 1
local vmModel: Model? = nil
local vmRoot: BasePart? = nil
local holdOffset: CFrame = CFrame.new(0.5, -0.5, -1)
local muzzleOffset: CFrame = CFrame.new(0, 0, -1.5)

-- animation state
local recoilStrength = 0
local RECOIL_RECOVERY = 14
local swingStart: number? = nil
local swingKind: "slash" | "thrust" = "slash"
local SWING_DURATION = 0.32
local bobPhase = 0
local swayPitch, swayYaw = 0, 0
local lastCamCf: CFrame? = nil
local hitstopEnd: number? = nil
local hitstopOffset: CFrame = CFrame.new()

local WOOD = Color3.fromRGB(110, 76, 42)
local STONE = Color3.fromRGB(140, 140, 135)
local BRONZE = Color3.fromRGB(190, 140, 60)
local STEEL = Color3.fromRGB(170, 175, 185)
local DARKSTEEL = Color3.fromRGB(70, 72, 78)
local FUTURE = Color3.fromRGB(230, 235, 240)
local NEON = Color3.fromRGB(80, 220, 235)
local SKIN = Color3.fromRGB(224, 178, 130)

-- sleeve color per age (matches unit outfits)
local SLEEVES: { [number]: Color3 } = {
	[1] = Color3.fromRGB(120, 85, 50),
	[2] = BRONZE,
	[3] = STEEL,
	[4] = Color3.fromRGB(88, 106, 68),
	[5] = FUTURE,
}

type DecoOpts = { shape: Enum.PartType?, material: Enum.Material?, transparency: number? }

local function deco(parent: Model, part0: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, opts: DecoOpts?): BasePart
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = o.shape or Enum.PartType.Block
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Anchored = false
	p.Massless = true
	p.CFrame = part0.CFrame * offset
	p.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function newRoot(): (Model, BasePart)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "ViewmodelRoot"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

-- First-person arms: forearm + hand reaching from the screen edges to the grip.
-- twoHanded adds a support arm from the left.
local function addArms(model: Model, root: BasePart, age: number, twoHanded: boolean)
	local sleeve = SLEEVES[age] or SKIN
	-- right forearm angles in from bottom-right toward the grip
	deco(model, root, "ArmR", Vector3.new(0.34, 0.34, 1.5), sleeve,
		CFrame.new(0.35, -0.32, 0.65) * CFrame.Angles(math.rad(-18), math.rad(14), 0))
	deco(model, root, "HandR", Vector3.new(0.4, 0.4, 0.45), SKIN, CFrame.new(0.06, -0.06, 0.06))
	if twoHanded then
		-- left support arm reaches to the front grip
		deco(model, root, "ArmL", Vector3.new(0.34, 0.34, 1.7), sleeve,
			CFrame.new(-0.5, -0.42, -0.15) * CFrame.Angles(math.rad(-14), math.rad(-24), 0))
		deco(model, root, "HandL", Vector3.new(0.4, 0.4, 0.45), SKIN, CFrame.new(-0.12, -0.12, -0.85))
	end
end

type BuildResult = {
	model: Model,
	root: BasePart,
	hold: CFrame,
	muzzle: CFrame,
}

local builders: { [number]: () -> BuildResult } = {
	[1] = function()
		local model, root = newRoot()
		model.Name = "ClubVM"
		deco(model, root, "Handle", Vector3.new(0.32, 2, 0.32), WOOD, CFrame.Angles(math.rad(90), 0, 0), {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Wood,
		})
		deco(model, root, "Grip", Vector3.new(0.38, 0.5, 0.38), DARKSTEEL:Lerp(WOOD, 0.6), CFrame.new(0, 0, 0.7) * CFrame.Angles(math.rad(90), 0, 0), {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Fabric,
		})
		deco(model, root, "Head", Vector3.new(0.9, 0.9, 0.9), STONE, CFrame.new(0, 0.05, -1), {
			shape = Enum.PartType.Ball,
			material = Enum.Material.Rock,
		})
		deco(model, root, "Spike", Vector3.new(0.25, 0.55, 0.25), STONE, CFrame.new(0, 0.5, -1), { material = Enum.Material.Rock })
		addArms(model, root, 1, false)
		return { model = model, root = root, hold = CFrame.new(0.45, -0.4, -0.9), muzzle = CFrame.new(0, 0, -1.35) }
	end,
	[2] = function()
		local model, root = newRoot()
		model.Name = "SpearVM"
		deco(model, root, "Pole", Vector3.new(0.2, 3.8, 0.2), WOOD, CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(90), 0, 0), {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Wood,
		})
		deco(model, root, "Binding", Vector3.new(0.26, 0.4, 0.26), BRONZE, CFrame.new(0, 0, -1.85) * CFrame.Angles(math.rad(90), 0, 0), {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Metal,
		})
		deco(model, root, "Tip", Vector3.new(0.35, 0.8, 0.35), BRONZE, CFrame.new(0, 0, -2.35) * CFrame.Angles(math.rad(90), 0, 0), {
			material = Enum.Material.Metal,
		})
		addArms(model, root, 2, true)
		return { model = model, root = root, hold = CFrame.new(0.55, -0.45, -1.1), muzzle = CFrame.new(0, 0, -2.4) }
	end,
	[3] = function()
		local model, root = newRoot()
		model.Name = "SwordVM"
		deco(model, root, "Blade", Vector3.new(0.28, 0.5, 2.3), STEEL, CFrame.new(0, 0, -1.15), { material = Enum.Material.Metal })
		deco(model, root, "BladeTip", Vector3.new(0.28, 0.35, 0.4), STEEL, CFrame.new(0, 0, -2.4), { material = Enum.Material.Metal })
		deco(model, root, "Fuller", Vector3.new(0.3, 0.12, 1.9), DARKSTEEL:Lerp(STEEL, 0.5), CFrame.new(0, 0, -1.05), { material = Enum.Material.Metal })
		deco(model, root, "Guard", Vector3.new(0.9, 0.22, 0.3), BRONZE, CFrame.new(0, 0, 0.05), { material = Enum.Material.Metal })
		deco(model, root, "Hilt", Vector3.new(0.28, 0.28, 0.7), DARKSTEEL, CFrame.new(0, 0, 0.5), { material = Enum.Material.Fabric })
		deco(model, root, "Pommel", Vector3.new(0.4, 0.4, 0.4), BRONZE, CFrame.new(0, 0, 0.9), { shape = Enum.PartType.Ball, material = Enum.Material.Metal })
		addArms(model, root, 3, false)
		return { model = model, root = root, hold = CFrame.new(0.5, -0.45, -1), muzzle = CFrame.new(0, 0, -2.4) }
	end,
	[4] = function()
		local model, root = newRoot()
		model.Name = "RifleVM"
		deco(model, root, "Body", Vector3.new(0.35, 0.55, 2.1), DARKSTEEL, CFrame.new(0, 0, -0.9), { material = Enum.Material.Metal })
		deco(model, root, "Barrel", Vector3.new(0.18, 0.18, 0.7), DARKSTEEL, CFrame.new(0, 0.08, -2.2), {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Metal,
		})
		deco(model, root, "Sight", Vector3.new(0.12, 0.3, 0.5), Color3.fromRGB(30, 30, 30), CFrame.new(0, 0.4, -0.9))
		deco(model, root, "Mag", Vector3.new(0.25, 0.6, 0.45), DARKSTEEL, CFrame.new(0, -0.35, -0.4), { material = Enum.Material.Metal })
		deco(model, root, "Stock", Vector3.new(0.3, 0.45, 0.9), WOOD, CFrame.new(0, 0.05, 0.55), { material = Enum.Material.Wood })
		deco(model, root, "ForeGrip", Vector3.new(0.28, 0.4, 0.35), WOOD, CFrame.new(0, -0.3, -1.3), { material = Enum.Material.Wood })
		addArms(model, root, 4, true)
		return { model = model, root = root, hold = CFrame.new(0.6, -0.5, -1.2), muzzle = CFrame.new(0, 0.08, -2.6) }
	end,
	[5] = function()
		local model, root = newRoot()
		model.Name = "LaserVM"
		deco(model, root, "Body", Vector3.new(0.45, 0.6, 2.2), FUTURE, CFrame.new(0, 0, -0.9), { material = Enum.Material.Metal })
		deco(model, root, "Glow", Vector3.new(0.18, 0.25, 1.7), NEON, CFrame.new(0, 0.12, -0.9), { material = Enum.Material.Neon })
		deco(model, root, "SideGlowL", Vector3.new(0.05, 0.18, 1.2), NEON, CFrame.new(-0.24, 0, -0.9), { material = Enum.Material.Neon })
		deco(model, root, "SideGlowR", Vector3.new(0.05, 0.18, 1.2), NEON, CFrame.new(0.24, 0, -0.9), { material = Enum.Material.Neon })
		deco(model, root, "Emitter", Vector3.new(0.3, 0.3, 0.25), NEON, CFrame.new(0, 0.05, -2.05), { material = Enum.Material.Neon })
		deco(model, root, "EnergyCell", Vector3.new(0.35, 0.35, 0.8), Color3.fromRGB(40, 45, 50), CFrame.new(0, -0.1, 0.5))
		addArms(model, root, 5, true)
		return { model = model, root = root, hold = CFrame.new(0.6, -0.5, -1.25), muzzle = CFrame.new(0, 0.05, -2.2) }
	end,
}

local function getCamera(): Camera?
	if camera and camera.Parent then
		return camera
	end
	camera = workspace.CurrentCamera
	return camera
end

local function destroyModel()
	if vmModel then
		vmModel:Destroy()
		vmModel = nil
		vmRoot = nil
	end
end

function Viewmodel.setAge(age: number)
	if age == currentAge and vmModel then
		return
	end
	currentAge = age
	destroyModel()
	local builder = builders[age]
	if not builder then
		return
	end
	local result = builder()
	vmModel = result.model
	vmRoot = result.root
	holdOffset = result.hold
	muzzleOffset = result.muzzle
	local cam = getCamera()
	if cam then
		vmModel.Parent = cam
	end
	-- brief age-up tint unless reduced effects is enabled
	if not Settings.get("reducedEffects") then
		for _, p in vmModel:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 0.9 then
				local orig = p.Color
				p.Color = Ages[age].color:Lerp(Color3.new(1, 1, 1), 0.5)
				TweenService:Create(p, TweenInfo.new(0.25), { Color = orig }):Play()
			end
		end
	end
end

function Viewmodel.playFire()
	local cam = getCamera()
	if not cam or not vmRoot then
		return
	end
	local weapon = HeroWeapons[currentAge]
	if weapon and weapon.kind == "melee" then
		swingStart = os.clock()
		swingKind = currentAge == 2 and "thrust" or "slash"
		return
	end
	recoilStrength = 1
	-- muzzle flash + light for guns
	if currentAge >= 4 and not Settings.get("reducedEffects") then
		local flash = Instance.new("Part")
		flash.Shape = Enum.PartType.Ball
		flash.Size = Vector3.one * (currentAge == 5 and 0.5 or 0.35)
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanQuery = false
		flash.Material = Enum.Material.Neon
		flash.Color = currentAge == 5 and Color3.fromRGB(120, 255, 220) or Color3.fromRGB(255, 240, 160)
		flash.CFrame = vmRoot.CFrame * muzzleOffset
		flash.Parent = workspace

		local light = Instance.new("PointLight")
		light.Color = flash.Color
		light.Brightness = 3
		light.Range = 14
		light.Parent = flash

		TweenService:Create(flash, TweenInfo.new(0.08), { Transparency = 1, Size = Vector3.one * 0.05 }):Play()
		TweenService:Create(light, TweenInfo.new(0.08), { Brightness = 0 }):Play()
		Debris:AddItem(flash, 0.12)
	end
end

-- Attack animation offset for the current frame.
local function swingOffset(now: number): CFrame
	if hitstopEnd and now < hitstopEnd then
		return hitstopOffset
	end
	if not swingStart then
		return CFrame.new()
	end
	local p = (now - swingStart) / SWING_DURATION
	if p >= 1 then
		swingStart = nil
		return CFrame.new()
	end
	if hitstopEnd and now >= hitstopEnd then
		hitstopEnd = nil
		hitstopOffset = CFrame.new()
	end
	if swingKind == "thrust" then
		-- pull back briefly, then drive forward
		local z: number
		if p < 0.3 then
			z = 0.45 * (p / 0.3)
		else
			local q = (p - 0.3) / 0.7
			z = 0.45 - 1.7 * math.sin(q * math.pi)
		end
		return CFrame.new(0, 0, z)
	end
	-- slash: raise up-right, sweep down-left across the screen, recover
	if p < 0.28 then
		local q = p / 0.28
		return CFrame.new(0.15 * q, 0.2 * q, 0.1 * q) * CFrame.Angles(math.rad(25 * q), 0, math.rad(-20 * q))
	elseif p < 0.6 then
		local q = (p - 0.28) / 0.32
		local e = 1 - (1 - q) * (1 - q) -- ease out
		return CFrame.new(0.15 - 0.75 * e, 0.2 - 0.7 * e, 0.1 - 0.45 * e)
			* CFrame.Angles(math.rad(25 - 95 * e), math.rad(-25 * e), math.rad(-20 + 55 * e))
	else
		local q = (p - 0.6) / 0.4
		local e = q * q * (3 - 2 * q) -- smoothstep back to rest
		return CFrame.new(-0.6 * (1 - e), -0.5 * (1 - e), -0.35 * (1 - e))
			* CFrame.Angles(math.rad(-70 * (1 - e)), math.rad(-25 * (1 - e)), math.rad(35 * (1 - e)))
	end
end

-- Briefly freeze the viewmodel swing on impact (melee hit-stop).
function Viewmodel.hitstop()
	if not swingStart then
		return
	end
	local weapon = HeroWeapons[currentAge]
	if not weapon or weapon.kind ~= "melee" then
		return
	end
	hitstopOffset = swingOffset(os.clock())
	hitstopEnd = os.clock() + 0.06
end

function Viewmodel.start()
	-- keep viewmodel parented to current camera
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
		if vmModel and camera then
			vmModel.Parent = camera
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local cam = getCamera()
		if not cam or not vmRoot then
			return
		end
		local now = os.clock()

		-- camera-delta sway (weapon lags behind the view)
		local camCf = cam.CFrame
		if lastCamCf then
			local delta = camCf:ToObjectSpace(lastCamCf)
			local dPitch, dYaw = delta:ToEulerAnglesYXZ()
			swayPitch = math.clamp(swayPitch + dPitch * 0.6, -0.06, 0.06)
			swayYaw = math.clamp(swayYaw + dYaw * 0.6, -0.08, 0.08)
		end
		lastCamCf = camCf
		local decay = math.exp(-dt * 10)
		swayPitch *= decay
		swayYaw *= decay

		-- walk bob from character speed
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local speed = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
		local bobAmp = math.clamp(speed / 16, 0, 1)
		if speed > 0.5 then
			bobPhase += dt * math.clamp(speed, 6, 22) * 0.9
		end
		local bob = CFrame.new(
			math.sin(bobPhase) * 0.035 * bobAmp,
			-math.abs(math.cos(bobPhase)) * 0.045 * bobAmp + math.sin(now * 1.4) * 0.012,
			0
		)

		-- recoil
		if recoilStrength > 0 then
			recoilStrength = math.max(0, recoilStrength - dt * RECOIL_RECOVERY)
		end
		local s = recoilStrength
		local recoil = CFrame.new(0, 0, 0.18 * s) * CFrame.Angles(math.rad(5 * s), 0, 0)

		local sway = CFrame.new(swayYaw * 2.2, swayPitch * 1.6, 0) * CFrame.Angles(swayPitch, swayYaw, 0)

		vmRoot.CFrame = camCf * holdOffset * sway * bob * recoil * swingOffset(now)
	end)
end

return Viewmodel
