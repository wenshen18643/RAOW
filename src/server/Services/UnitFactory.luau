--!strict
-- Builds rigged character models for all 15 units: low-poly stylized, distinct
-- per age + role. Body = invisible anchored hitbox (PrimaryPart); visible parts
-- hang off Motor6D joints so the client can animate limbs via Motor6D.Transform
-- (Transform is not replicated => zero network cost). Moving the unit is still
-- a single Body.CFrame write; jointed parts follow kinematically.
--
-- Joint names driven by the client UnitAnimator controller:
--   infantry:  RootJoint, Neck, ShoulderL, ShoulderR, HipL, HipR
--   quadruped: RootJoint, Neck, QLegFL, QLegFR, QLegBL, QLegBR
--   catapult:  ThrowArm, WheelFL, WheelFR, WheelBL, WheelBR
--   tank:      Barrel
--   mech:      RootJoint, MechHipL, MechHipR, CannonL, CannonR
--
-- The Body carries attributes the animator reads: Rig, Role, Age, MoveSpeed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ages = require(ReplicatedStorage.Shared.Config.Ages)

local UnitFactory = {}

local ROLE_SIZE = {
	melee = Vector3.new(2.4, 5, 1.6),
	ranged = Vector3.new(2.4, 5, 1.6),
	heavy = Vector3.new(5, 6, 7),
	super_heavy = Vector3.new(5, 7, 7),
}

-- palette
local SKIN = Color3.fromRGB(224, 178, 130)
local WOOD = Color3.fromRGB(110, 76, 42)
local DARKWOOD = Color3.fromRGB(80, 55, 32)
local STONE = Color3.fromRGB(140, 140, 135)
local BRONZE = Color3.fromRGB(190, 140, 60)
local STEEL = Color3.fromRGB(170, 175, 185)
local DARKSTEEL = Color3.fromRGB(70, 72, 78)
local ARMY = Color3.fromRGB(88, 106, 68)
local DARKARMY = Color3.fromRGB(60, 72, 48)
local FUTURE = Color3.fromRGB(230, 235, 240)
local NEON = Color3.fromRGB(80, 220, 235)
local FUR = Color3.fromRGB(120, 85, 50)
local GREY = Color3.fromRGB(130, 128, 122)
local EYE = Color3.fromRGB(35, 32, 30)
local IVORY = Color3.fromRGB(238, 228, 205)

type PartOpts = { shape: Enum.PartType?, material: Enum.Material?, transparency: number? }

type Ctx = {
	model: Model,
	body: BasePart,
}

local function newPart(model: Model, name: string, size: Vector3, color: Color3, opts: PartOpts?): BasePart
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
	p.CastShadow = true
	p.Anchored = false
	p.Massless = true
	p.Parent = model
	return p
end

-- Creates a part rigidly welded to `parent` at `offset` (parent-space).
local function weldTo(ctx: Ctx, parent: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, opts: PartOpts?): BasePart
	local p = newPart(ctx.model, name, size, color, opts)
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- Creates a part joined to `parent` by a Motor6D so the client can animate it.
-- pivotInParent: joint pivot in parent-space. pivotInChild: same pivot in the
-- new part's space. Rotating Motor6D.Transform rotates the part around that pivot.
local function jointTo(ctx: Ctx, parent: BasePart, jointName: string, name: string, size: Vector3, color: Color3, pivotInParent: CFrame, pivotInChild: CFrame, opts: PartOpts?): BasePart
	local p = newPart(ctx.model, name, size, color, opts)
	p.CFrame = parent.CFrame * pivotInParent * pivotInChild:Inverse()
	local m = Instance.new("Motor6D")
	m.Name = jointName
	m.Part0 = parent
	m.Part1 = p
	m.C0 = pivotInParent
	m.C1 = pivotInChild
	m.Parent = p
	return p
end

--------------------------------------------------------------------------------
-- Infantry (melee + ranged): rigged biped with feet, hands, eyes.
-- Layout (body-space): torso center (0,0.35,0), head (0,1.9,0),
-- shoulders (±1.15,1.2,0), hips (±0.45,-0.6,0).
--------------------------------------------------------------------------------

type InfantryRig = {
	torso: BasePart,
	head: BasePart,
	armL: BasePart,
	armR: BasePart,
	legL: BasePart,
	legR: BasePart,
}

local function infantryBase(ctx: Ctx, outfit: Color3, legColor: Color3, armColor: Color3): InfantryRig
	-- torso: root of the visible rig, jointed to the hitbox
	local torso = jointTo(ctx, ctx.body, "RootJoint", "Torso", Vector3.new(1.7, 1.9, 1), outfit,
		CFrame.new(0, 0.35, 0), CFrame.new())

	-- head on a neck joint (pivot at top of torso)
	local head = jointTo(ctx, torso, "Neck", "Head", Vector3.new(1.15, 1.15, 1.15), SKIN,
		CFrame.new(0, 0.95, 0), CFrame.new(0, -0.6, 0), { shape = Enum.PartType.Ball })
	-- eyes give the low-poly figures character
	weldTo(ctx, head, "EyeL", Vector3.new(0.16, 0.22, 0.08), EYE, CFrame.new(-0.22, 0.06, -0.52))
	weldTo(ctx, head, "EyeR", Vector3.new(0.16, 0.22, 0.08), EYE, CFrame.new(0.22, 0.06, -0.52))

	-- arms on shoulder joints (pivot at top of arm), with hands
	local armL = jointTo(ctx, torso, "ShoulderL", "ArmL", Vector3.new(0.5, 1.7, 0.5), armColor,
		CFrame.new(-1.15, 0.85, 0), CFrame.new(0, 0.85, 0))
	local armR = jointTo(ctx, torso, "ShoulderR", "ArmR", Vector3.new(0.5, 1.7, 0.5), armColor,
		CFrame.new(1.15, 0.85, 0), CFrame.new(0, 0.85, 0))
	weldTo(ctx, armL, "HandL", Vector3.new(0.55, 0.4, 0.55), SKIN, CFrame.new(0, -0.95, 0))
	weldTo(ctx, armR, "HandR", Vector3.new(0.55, 0.4, 0.55), SKIN, CFrame.new(0, -0.95, 0))

	-- legs on hip joints (pivot at top of leg), with feet
	local legL = jointTo(ctx, torso, "HipL", "LegL", Vector3.new(0.7, 1.9, 0.75), legColor,
		CFrame.new(-0.45, -0.95, 0), CFrame.new(0, 0.95, 0))
	local legR = jointTo(ctx, torso, "HipR", "LegR", Vector3.new(0.7, 1.9, 0.75), legColor,
		CFrame.new(0.45, -0.95, 0), CFrame.new(0, 0.95, 0))
	weldTo(ctx, legL, "FootL", Vector3.new(0.72, 0.35, 1.05), EYE, CFrame.new(0, -1.05, -0.15))
	weldTo(ctx, legR, "FootR", Vector3.new(0.72, 0.35, 1.05), EYE, CFrame.new(0, -1.05, -0.15))

	return { torso = torso, head = head, armL = armL, armR = armR, legL = legL, legR = legR }
end

-- Weapons attach to the right arm so they follow swings.
-- Offsets are arm-space; the hand sits at (0, -0.85, 0), forward is -Z.
local HAND = CFrame.new(0, -0.85, 0)

local WEAPONS: { [string]: (Ctx, InfantryRig) -> () }
WEAPONS = {
	club = function(ctx, rig)
		weldTo(ctx, rig.armR, "Club", Vector3.new(0.42, 2.0, 0.42), WOOD,
			HAND * CFrame.Angles(math.rad(65), 0, 0) * CFrame.new(0, 0.6, 0), { material = Enum.Material.Wood })
		weldTo(ctx, rig.armR, "ClubHead", Vector3.new(0.78, 0.78, 0.78), DARKWOOD,
			HAND * CFrame.Angles(math.rad(65), 0, 0) * CFrame.new(0, 1.5, 0), { shape = Enum.PartType.Ball, material = Enum.Material.Wood })
	end,
	sling = function(ctx, rig)
		weldTo(ctx, rig.armR, "SlingStone", Vector3.new(0.6, 0.6, 0.6), STONE,
			HAND * CFrame.new(0, -0.1, -0.3), { shape = Enum.PartType.Ball, material = Enum.Material.Rock })
	end,
	spear = function(ctx, rig)
		local tilt = CFrame.Angles(math.rad(78), 0, 0)
		weldTo(ctx, rig.armR, "SpearPole", Vector3.new(0.18, 3.4, 0.18), WOOD,
			HAND * tilt * CFrame.new(0, 0.5, 0), { material = Enum.Material.Wood })
		weldTo(ctx, rig.armR, "SpearTip", Vector3.new(0.32, 0.65, 0.32), BRONZE,
			HAND * tilt * CFrame.new(0, 2.5, 0), { material = Enum.Material.Metal })
	end,
	bow = function(ctx, rig)
		weldTo(ctx, rig.armR, "Bow", Vector3.new(0.2, 2.4, 0.35), DARKWOOD,
			HAND * CFrame.new(0, 0.1, -0.35), { material = Enum.Material.Wood })
		weldTo(ctx, rig.armR, "BowString", Vector3.new(0.05, 2.2, 0.05), IVORY,
			HAND * CFrame.new(0, 0.1, -0.05))
	end,
	sword = function(ctx, rig)
		weldTo(ctx, rig.armR, "Blade", Vector3.new(0.22, 1.9, 0.5), STEEL,
			HAND * CFrame.new(0, 1.25, 0), { material = Enum.Material.Metal })
		weldTo(ctx, rig.armR, "Guard", Vector3.new(0.85, 0.18, 0.5), DARKSTEEL,
			HAND * CFrame.new(0, 0.28, 0), { material = Enum.Material.Metal })
	end,
	crossbow = function(ctx, rig)
		weldTo(ctx, rig.armR, "CrossbowBody", Vector3.new(0.3, 0.3, 1.5), DARKWOOD,
			HAND * CFrame.new(0, 0, -0.6), { material = Enum.Material.Wood })
		weldTo(ctx, rig.armR, "CrossbowArms", Vector3.new(1.4, 0.18, 0.22), WOOD,
			HAND * CFrame.new(0, 0, -1.2), { material = Enum.Material.Wood })
	end,
	rifle = function(ctx, rig)
		weldTo(ctx, rig.armR, "Rifle", Vector3.new(0.3, 0.45, 1.9), DARKSTEEL,
			HAND * CFrame.new(0, 0.1, -0.6), { material = Enum.Material.Metal })
		weldTo(ctx, rig.armR, "RifleStock", Vector3.new(0.28, 0.4, 0.5), DARKWOOD,
			HAND * CFrame.new(0, -0.02, 0.35), { material = Enum.Material.Wood })
	end,
	sniper = function(ctx, rig)
		weldTo(ctx, rig.armR, "Sniper", Vector3.new(0.28, 0.4, 2.7), DARKSTEEL,
			HAND * CFrame.new(0, 0.1, -0.8), { material = Enum.Material.Metal })
		weldTo(ctx, rig.armR, "Scope", Vector3.new(0.28, 0.28, 0.6), EYE,
			HAND * CFrame.new(0, 0.42, -0.7))
	end,
	energyBlade = function(ctx, rig)
		weldTo(ctx, rig.armR, "BladeHilt", Vector3.new(0.32, 0.55, 0.32), DARKSTEEL,
			HAND, { material = Enum.Material.Metal })
		weldTo(ctx, rig.armR, "EnergyBlade", Vector3.new(0.18, 2.0, 0.4), NEON,
			HAND * CFrame.new(0, 1.3, 0), { material = Enum.Material.Neon })
	end,
	laserRifle = function(ctx, rig)
		weldTo(ctx, rig.armR, "LaserRifle", Vector3.new(0.36, 0.45, 2.0), FUTURE,
			HAND * CFrame.new(0, 0.1, -0.6), { material = Enum.Material.Metal })
		weldTo(ctx, rig.armR, "LaserGlow", Vector3.new(0.14, 0.18, 1.5), NEON,
			HAND * CFrame.new(0, 0.36, -0.6), { material = Enum.Material.Neon })
	end,
}

-- Off-hand shields for melee units in ages 2/3.
local SHIELDS: { [number]: (Ctx, InfantryRig) -> () } = {
	[2] = function(ctx, rig)
		-- round wooden shield (cylinder flat faces outward on the left arm)
		weldTo(ctx, rig.armL, "Shield", Vector3.new(0.25, 1.6, 1.6), DARKWOOD,
			CFrame.new(-0.4, -0.3, 0), { shape = Enum.PartType.Cylinder, material = Enum.Material.Wood })
		weldTo(ctx, rig.armL, "ShieldBoss", Vector3.new(0.15, 0.5, 0.5), BRONZE,
			CFrame.new(-0.55, -0.3, 0), { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal })
	end,
	[3] = function(ctx, rig)
		-- steel kite shield
		weldTo(ctx, rig.armL, "Shield", Vector3.new(0.22, 1.9, 1.2), STEEL,
			CFrame.new(-0.4, -0.35, 0), { material = Enum.Material.Metal })
		weldTo(ctx, rig.armL, "ShieldTrim", Vector3.new(0.24, 0.35, 1.25), Color3.fromRGB(180, 50, 40),
			CFrame.new(-0.4, 0.45, 0), { material = Enum.Material.Metal })
	end,
}

-- Headgear welds to the Head so it follows the neck joint. Offsets are
-- head-space (head center = body-space (0, 1.9, 0)).
local HEADGEAR: { [number]: (Ctx, InfantryRig) -> () } = {
	[1] = function(ctx, rig)
		weldTo(ctx, rig.head, "Headband", Vector3.new(1.25, 0.3, 1.25), FUR, CFrame.new(0, 0.35, 0), { material = Enum.Material.Fabric })
	end,
	[2] = function(ctx, rig)
		weldTo(ctx, rig.head, "Helmet", Vector3.new(1.25, 0.55, 1.25), BRONZE, CFrame.new(0, 0.4, 0), { material = Enum.Material.Metal })
		weldTo(ctx, rig.head, "Crest", Vector3.new(0.25, 0.45, 1.1), Color3.fromRGB(180, 50, 40), CFrame.new(0, 0.8, 0))
	end,
	[3] = function(ctx, rig)
		weldTo(ctx, rig.head, "Helmet", Vector3.new(1.3, 0.9, 1.3), STEEL, CFrame.new(0, 0.35, 0), { material = Enum.Material.Metal })
		weldTo(ctx, rig.head, "Visor", Vector3.new(1.0, 0.25, 0.2), DARKSTEEL, CFrame.new(0, 0.05, -0.6), { material = Enum.Material.Metal })
	end,
	[4] = function(ctx, rig)
		weldTo(ctx, rig.head, "Helmet", Vector3.new(1.3, 0.6, 1.35), DARKARMY, CFrame.new(0, 0.4, 0))
	end,
	[5] = function(ctx, rig)
		weldTo(ctx, rig.head, "Helmet", Vector3.new(1.3, 0.7, 1.3), FUTURE, CFrame.new(0, 0.4, 0), { material = Enum.Material.Metal })
		weldTo(ctx, rig.head, "Visor", Vector3.new(1.05, 0.3, 0.15), NEON, CFrame.new(0, 0.15, -0.62), { material = Enum.Material.Neon })
	end,
}

-- outfit colors per age: { torso, legs, arms }
local OUTFITS: { [number]: { Color3 } } = {
	[1] = { FUR, SKIN, SKIN },
	[2] = { BRONZE, Color3.fromRGB(160, 130, 90), SKIN },
	[3] = { STEEL, DARKSTEEL, STEEL },
	[4] = { ARMY, DARKARMY, ARMY },
	[5] = { FUTURE, Color3.fromRGB(180, 190, 200), FUTURE },
}

local INFANTRY_WEAPON: { [number]: { melee: string, ranged: string } } = {
	[1] = { melee = "club", ranged = "sling" },
	[2] = { melee = "spear", ranged = "bow" },
	[3] = { melee = "sword", ranged = "crossbow" },
	[4] = { melee = "rifle", ranged = "sniper" },
	[5] = { melee = "energyBlade", ranged = "laserRifle" },
}

--------------------------------------------------------------------------------
-- Heavies: one bespoke rig per age. Each returns the Rig attribute value.
--------------------------------------------------------------------------------

-- Shared quadruped builder for mammoth/elephant: jointed legs + neck.
local function quadruped(ctx: Ctx, bodyColor: Color3, mat: Enum.Material, headSize: Vector3, headOffset: Vector3, legSize: Vector3): (BasePart, BasePart)
	local trunk = weldTo(ctx, ctx.body, "Chassis", Vector3.new(4.2, 3.2, 5), bodyColor, CFrame.new(0, -0.4, 0.3), { material = mat })

	-- head on a neck joint (pivot at rear of head, where it meets the body)
	local head = jointTo(ctx, ctx.body, "Neck", "QHead", headSize, bodyColor,
		CFrame.new(headOffset.X, headOffset.Y, headOffset.Z + headSize.Z / 2),
		CFrame.new(0, 0, headSize.Z / 2), { material = mat })

	-- four legs on hip joints (pivot at leg top)
	local legTopY = -2.1 + legSize.Y / 2
	for _, xs in { -1, 1 } do
		local sideTag = xs < 0 and "L" or "R"
		jointTo(ctx, ctx.body, "QLegF" .. sideTag, "LegF" .. sideTag, legSize, bodyColor,
			CFrame.new(xs * 1.45, legTopY, -1.5), CFrame.new(0, legSize.Y / 2, 0), { material = mat })
		jointTo(ctx, ctx.body, "QLegB" .. sideTag, "LegB" .. sideTag, legSize, bodyColor,
			CFrame.new(xs * 1.45, legTopY, 1.8), CFrame.new(0, legSize.Y / 2, 0), { material = mat })
	end
	return trunk, head
end

local function heavyMammoth(ctx: Ctx): string -- age 1: Mammoth Rider
	local _, head = quadruped(ctx, FUR, Enum.Material.Fabric, Vector3.new(2.4, 2.2, 1.8), Vector3.new(0, 0.2, -2.6), Vector3.new(0.9, 2.2, 0.9))
	-- tusks + trunk hang off the head so they sway with it
	for _, xs in { -1, 1 } do
		weldTo(ctx, head, "Tusk", Vector3.new(0.32, 0.32, 1.9), IVORY,
			CFrame.new(xs * 0.75, -0.7, -0.9) * CFrame.Angles(math.rad(-18), 0, 0))
	end
	weldTo(ctx, head, "TrunkUpper", Vector3.new(0.55, 1.4, 0.55), FUR,
		CFrame.new(0, -0.9, -0.85) * CFrame.Angles(math.rad(12), 0, 0), { material = Enum.Material.Fabric })
	weldTo(ctx, head, "TrunkLower", Vector3.new(0.45, 1.1, 0.45), FUR,
		CFrame.new(0, -1.9, -0.65) * CFrame.Angles(math.rad(-8), 0, 0), { material = Enum.Material.Fabric })
	weldTo(ctx, head, "EyeQL", Vector3.new(0.14, 0.2, 0.08), EYE, CFrame.new(-0.7, 0.35, -0.92))
	weldTo(ctx, head, "EyeQR", Vector3.new(0.14, 0.2, 0.08), EYE, CFrame.new(0.7, 0.35, -0.92))
	-- rider
	weldTo(ctx, ctx.body, "Rider", Vector3.new(1, 1.3, 0.8), FUR, CFrame.new(0, 1.6, 0.5), { material = Enum.Material.Fabric })
	weldTo(ctx, ctx.body, "RiderHead", Vector3.new(0.8, 0.8, 0.8), SKIN, CFrame.new(0, 2.6, 0.5), { shape = Enum.PartType.Ball })
	return "quadruped"
end

local function heavyElephant(ctx: Ctx): string -- age 2: War Elephant
	local _, head = quadruped(ctx, GREY, Enum.Material.SmoothPlastic, Vector3.new(2.6, 2.4, 1.8), Vector3.new(0, 0.3, -2.7), Vector3.new(1, 2.3, 1))
	weldTo(ctx, head, "HeadPlate", Vector3.new(2, 1.8, 0.3), BRONZE, CFrame.new(0, 0.2, -0.95), { material = Enum.Material.Metal })
	for _, xs in { -1, 1 } do
		weldTo(ctx, head, "Tusk", Vector3.new(0.32, 0.32, 2.1), IVORY,
			CFrame.new(xs * 0.85, -0.85, -1.0) * CFrame.Angles(math.rad(-15), 0, 0))
	end
	weldTo(ctx, head, "TrunkUpper", Vector3.new(0.6, 1.5, 0.6), GREY,
		CFrame.new(0, -1.0, -0.95) * CFrame.Angles(math.rad(12), 0, 0))
	weldTo(ctx, head, "TrunkLower", Vector3.new(0.5, 1.2, 0.5), GREY,
		CFrame.new(0, -2.1, -0.75) * CFrame.Angles(math.rad(-8), 0, 0))
	-- howdah (war platform)
	weldTo(ctx, ctx.body, "Howdah", Vector3.new(2.4, 1, 2.4), DARKWOOD, CFrame.new(0, 1.8, 0.4), { material = Enum.Material.Wood })
	weldTo(ctx, ctx.body, "HowdahRail", Vector3.new(2.6, 0.3, 2.6), WOOD, CFrame.new(0, 2.35, 0.4), { material = Enum.Material.Wood })
	return "quadruped"
end

local function heavyCatapult(ctx: Ctx): string -- age 3: Catapult
	weldTo(ctx, ctx.body, "Frame", Vector3.new(3.2, 0.8, 5), DARKWOOD, CFrame.new(0, -1.6, 0), { material = Enum.Material.Wood })
	weldTo(ctx, ctx.body, "Upright", Vector3.new(2.6, 1.4, 0.6), DARKWOOD, CFrame.new(0, -0.7, -1.2), { material = Enum.Material.Wood })
	-- wheels on motors so they roll while moving (cylinder axis X = axle)
	for _, xs in { -1, 1 } do
		for _, zs in { -1, 1 } do
			local name = "Wheel" .. (zs < 0 and "F" or "B") .. (xs < 0 and "L" or "R")
			jointTo(ctx, ctx.body, name, name .. "Part", Vector3.new(0.5, 1.6, 1.6), WOOD,
				CFrame.new(xs * 1.85, -2.2, zs * 1.7), CFrame.new(),
				{ shape = Enum.PartType.Cylinder, material = Enum.Material.Wood })
		end
	end
	-- throw arm on a motor (pivot at its base, rear of frame); rest pose tilted back
	local arm = jointTo(ctx, ctx.body, "ThrowArm", "ThrowArmPart", Vector3.new(0.45, 4.2, 0.45), WOOD,
		CFrame.new(0, -1.1, 1.3) * CFrame.Angles(math.rad(-32), 0, 0), CFrame.new(0, -1.9, 0), { material = Enum.Material.Wood })
	weldTo(ctx, arm, "Bucket", Vector3.new(1.2, 0.6, 1.2), DARKWOOD, CFrame.new(0, 1.95, -0.35), { material = Enum.Material.Wood })
	weldTo(ctx, arm, "Boulder", Vector3.new(0.9, 0.9, 0.9), STONE, CFrame.new(0, 2.35, -0.35), { shape = Enum.PartType.Ball, material = Enum.Material.Rock })
	return "catapult"
end

local function heavyTank(ctx: Ctx): string -- age 4: Tank
	weldTo(ctx, ctx.body, "Hull", Vector3.new(3.6, 1.5, 5.5), ARMY, CFrame.new(0, -1.2, 0), { material = Enum.Material.Metal })
	for _, xs in { -1, 1 } do
		weldTo(ctx, ctx.body, "Tread", Vector3.new(1, 1.3, 5.8), DARKSTEEL, CFrame.new(xs * 2.1, -1.9, 0), { material = Enum.Material.Metal })
	end
	weldTo(ctx, ctx.body, "Turret", Vector3.new(2.4, 1.1, 2.6), DARKARMY, CFrame.new(0, 0.1, 0.3), { material = Enum.Material.Metal })
	weldTo(ctx, ctx.body, "Hatch", Vector3.new(0.9, 0.25, 0.9), DARKSTEEL, CFrame.new(0, 0.75, 0.5), { material = Enum.Material.Metal })
	-- barrel on a motor for recoil (pivot at turret face; recoil = +Z translate)
	jointTo(ctx, ctx.body, "Barrel", "BarrelPart", Vector3.new(0.45, 0.45, 3.6), DARKSTEEL,
		CFrame.new(0, 0.2, -0.8), CFrame.new(0, 0, 1.8), { material = Enum.Material.Metal })
	return "tank"
end

local function heavyMech(ctx: Ctx): string -- age 5: War Mech
	for _, xs in { -1, 1 } do
		local sideTag = xs < 0 and "L" or "R"
		-- legs on hip joints for a stompy strut
		jointTo(ctx, ctx.body, "MechHip" .. sideTag, "MechLeg" .. sideTag, Vector3.new(1.2, 3, 1.5), Color3.fromRGB(190, 198, 205),
			CFrame.new(xs * 1.2, 0, 0), CFrame.new(0, 1.5, 0), { material = Enum.Material.Metal })
		weldTo(ctx, ctx.body, "MechShoulder" .. sideTag, Vector3.new(1.1, 1.1, 1.1), FUTURE, CFrame.new(xs * 2.1, 1.6, 0), { material = Enum.Material.Metal })
		-- cannons on motors for alternating recoil
		local cannon = jointTo(ctx, ctx.body, "Cannon" .. sideTag, "MechCannon" .. sideTag, Vector3.new(0.5, 0.5, 2.6), DARKSTEEL,
			CFrame.new(xs * 2.1, 1.6, -0.1), CFrame.new(0, 0, 1.3), { material = Enum.Material.Metal })
		weldTo(ctx, cannon, "CannonGlow", Vector3.new(0.25, 0.25, 0.3), NEON, CFrame.new(0, 0, -1.35), { material = Enum.Material.Neon })
	end
	weldTo(ctx, ctx.body, "MechTorso", Vector3.new(3, 2.4, 2.4), FUTURE, CFrame.new(0, 1.2, 0), { material = Enum.Material.Metal })
	weldTo(ctx, ctx.body, "MechCore", Vector3.new(0.8, 0.8, 0.2), NEON, CFrame.new(0, 1.2, -1.25), { material = Enum.Material.Neon })
	weldTo(ctx, ctx.body, "MechHead", Vector3.new(1.2, 0.9, 1.2), Color3.fromRGB(190, 198, 205), CFrame.new(0, 2.85, 0), { material = Enum.Material.Metal })
	weldTo(ctx, ctx.body, "MechVisor", Vector3.new(0.9, 0.25, 0.15), Color3.fromRGB(255, 80, 70), CFrame.new(0, 2.85, -0.62), { material = Enum.Material.Neon })
	return "mech"
end

local HEAVIES: { [number]: (Ctx) -> string } = {
	[1] = heavyMammoth,
	[2] = heavyElephant,
	[3] = heavyCatapult,
	[4] = heavyTank,
	[5] = heavyMech,
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- Builds the unit model at spawnCf (cf of hitbox bottom center on ground handled by caller).
function UnitFactory.build(def: any, side: string, spawnCf: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = def.id

	local size = ROLE_SIZE[def.role]
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = spawnCf * CFrame.new(0, size.Y / 2, 0)
	body.Parent = model
	model.PrimaryPart = body
	body:SetAttribute("EntityType", "Unit")
	body:SetAttribute("Side", side)
	-- animator hints (read by the client UnitAnimator controller)
	body:SetAttribute("Role", def.role)
	body:SetAttribute("Age", def.age)
	body:SetAttribute("MoveSpeed", def.moveSpeed)
	body:SetAttribute("AnimState", "walk")
	body:SetAttribute("AttackCount", 0)

	local ctx: Ctx = { model = model, body = body }

	local rigKind: string
	if def.role == "heavy" or def.role == "super_heavy" then
		rigKind = HEAVIES[def.age](ctx)
	else
		rigKind = "infantry"
		local outfit = OUTFITS[def.age]
		local rig = infantryBase(ctx, outfit[1], outfit[2], outfit[3])
		HEADGEAR[def.age](ctx, rig)
		local weaponKey = INFANTRY_WEAPON[def.age][def.role]
		WEAPONS[weaponKey](ctx, rig)
		if def.role == "melee" then
			local shield = SHIELDS[def.age]
			if shield then
				shield(ctx, rig)
			end
		end
	end
	body:SetAttribute("Rig", rigKind)

	-- team stripe under the feet
	local stripeSize = def.role == "heavy" and Vector3.new(size.X + 0.4, 0.35, size.Z + 0.4) or Vector3.new(2.6, 0.35, 2)
	weldTo(ctx, body, "Stripe", stripeSize, side == "A" and Color3.fromRGB(52, 120, 200) or Color3.fromRGB(200, 70, 60),
		CFrame.new(0, -size.Y / 2 + 0.2, 0), { material = Enum.Material.Neon, transparency = 0.2 })

	return model, body
end

return UnitFactory
