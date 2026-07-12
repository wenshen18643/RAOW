--!strict
-- Builds character models for all 15 units: low-poly stylized, distinct per age + role.
-- Pattern: invisible anchored Body hitbox (PrimaryPart), unanchored decorative parts
-- welded to it — moving the unit is a single Body.CFrame write.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ages = require(ReplicatedStorage.Shared.Config.Ages)

local UnitFactory = {}

local ROLE_SIZE = {
	melee = Vector3.new(2.4, 5, 1.6),
	ranged = Vector3.new(2.4, 5, 1.6),
	heavy = Vector3.new(5, 6, 7),
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

type Ctx = {
	model: Model,
	body: BasePart,
}

-- Creates a decorative part welded to the body. offset is relative to body center.
local function deco(ctx: Ctx, name: string, size: Vector3, color: Color3, offset: CFrame, opts: { shape: Enum.PartType?, material: Enum.Material?, transparency: number? }?): BasePart
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = o.shape or Enum.PartType.Block
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.CanCollide = false
	p.Anchored = false
	p.Massless = true
	p.CFrame = ctx.body.CFrame * offset
	p.Parent = ctx.model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.body
	weld.Part1 = p
	weld.Parent = p
	return p
end

--------------------------------------------------------------------------------
-- Infantry (melee + ranged): legs, torso, arms, head, age headgear, weapon
--------------------------------------------------------------------------------

local function infantryBase(ctx: Ctx, outfit: Color3, legColor: Color3, armColor: Color3)
	-- legs
	deco(ctx, "LegL", Vector3.new(0.7, 1.9, 0.75), legColor, CFrame.new(-0.45, -1.55, 0))
	deco(ctx, "LegR", Vector3.new(0.7, 1.9, 0.75), legColor, CFrame.new(0.45, -1.55, 0))
	-- torso
	deco(ctx, "Torso", Vector3.new(1.7, 1.9, 1), outfit, CFrame.new(0, 0.35, 0))
	-- arms
	deco(ctx, "ArmL", Vector3.new(0.5, 1.7, 0.5), armColor, CFrame.new(-1.15, 0.35, 0))
	deco(ctx, "ArmR", Vector3.new(0.5, 1.7, 0.5), armColor, CFrame.new(1.15, 0.35, 0))
	-- head
	deco(ctx, "Head", Vector3.new(1.15, 1.15, 1.15), SKIN, CFrame.new(0, 1.9, 0), { shape = Enum.PartType.Ball })
end

-- Right-hand weapon offsets: hand sits near (1.15, 0.35, 0); weapon forward is -Z.
local WEAPONS: { [string]: (Ctx) -> () }
WEAPONS = {
	club = function(ctx)
		deco(ctx, "Club", Vector3.new(0.5, 2.1, 0.5), WOOD, CFrame.new(1.2, 1.1, -0.4) * CFrame.Angles(math.rad(35), 0, 0), { shape = Enum.PartType.Cylinder, material = Enum.Material.Wood })
	end,
	sling = function(ctx)
		deco(ctx, "SlingStone", Vector3.new(0.7, 0.7, 0.7), STONE, CFrame.new(1.2, 1.2, -0.3), { shape = Enum.PartType.Ball, material = Enum.Material.Rock })
	end,
	spear = function(ctx)
		deco(ctx, "SpearPole", Vector3.new(0.2, 3.6, 0.2), WOOD, CFrame.new(1.2, 0.6, -0.2) * CFrame.Angles(math.rad(15), 0, 0), { material = Enum.Material.Wood })
		deco(ctx, "SpearTip", Vector3.new(0.35, 0.7, 0.35), BRONZE, CFrame.new(1.2, 2.45, -0.7) * CFrame.Angles(math.rad(15), 0, 0), { material = Enum.Material.Metal })
	end,
	bow = function(ctx)
		deco(ctx, "Bow", Vector3.new(0.22, 2.5, 0.35), DARKWOOD, CFrame.new(1.25, 0.5, -0.5) * CFrame.Angles(0, 0, math.rad(8)), { material = Enum.Material.Wood })
	end,
	sword = function(ctx)
		deco(ctx, "Blade", Vector3.new(0.25, 2, 0.5), STEEL, CFrame.new(1.2, 1.55, -0.3), { material = Enum.Material.Metal })
		deco(ctx, "Hilt", Vector3.new(0.8, 0.2, 0.5), DARKSTEEL, CFrame.new(1.2, 0.5, -0.3), { material = Enum.Material.Metal })
	end,
	crossbow = function(ctx)
		deco(ctx, "CrossbowBody", Vector3.new(0.35, 0.3, 1.6), DARKWOOD, CFrame.new(1.2, 0.9, -0.6), { material = Enum.Material.Wood })
		deco(ctx, "CrossbowArms", Vector3.new(1.5, 0.2, 0.25), WOOD, CFrame.new(1.2, 0.9, -1.2), { material = Enum.Material.Wood })
	end,
	rifle = function(ctx)
		deco(ctx, "Rifle", Vector3.new(0.35, 0.5, 2), DARKSTEEL, CFrame.new(1.2, 0.9, -0.6), { material = Enum.Material.Metal })
	end,
	sniper = function(ctx)
		deco(ctx, "Sniper", Vector3.new(0.3, 0.4, 2.9), DARKSTEEL, CFrame.new(1.2, 0.9, -0.8), { material = Enum.Material.Metal })
		deco(ctx, "Scope", Vector3.new(0.3, 0.3, 0.7), Color3.fromRGB(30, 30, 30), CFrame.new(1.2, 1.2, -0.7))
	end,
	energyBlade = function(ctx)
		deco(ctx, "EnergyBlade", Vector3.new(0.2, 2.2, 0.45), NEON, CFrame.new(1.2, 1.6, -0.3), { material = Enum.Material.Neon })
		deco(ctx, "BladeHilt", Vector3.new(0.35, 0.6, 0.35), DARKSTEEL, CFrame.new(1.2, 0.35, -0.3), { material = Enum.Material.Metal })
	end,
	laserRifle = function(ctx)
		deco(ctx, "LaserRifle", Vector3.new(0.4, 0.5, 2.1), FUTURE, CFrame.new(1.2, 0.9, -0.6), { material = Enum.Material.Metal })
		deco(ctx, "LaserGlow", Vector3.new(0.15, 0.2, 1.6), NEON, CFrame.new(1.2, 1.05, -0.6), { material = Enum.Material.Neon })
	end,
}

local HEADGEAR: { [number]: (Ctx) -> () } = {
	[1] = function(ctx)
		-- fur headband
		deco(ctx, "Headband", Vector3.new(1.25, 0.3, 1.25), FUR, CFrame.new(0, 2.25, 0))
	end,
	[2] = function(ctx)
		-- bronze helmet with crest
		deco(ctx, "Helmet", Vector3.new(1.25, 0.55, 1.25), BRONZE, CFrame.new(0, 2.3, 0), { material = Enum.Material.Metal })
		deco(ctx, "Crest", Vector3.new(0.25, 0.45, 1.1), Color3.fromRGB(180, 50, 40), CFrame.new(0, 2.7, 0))
	end,
	[3] = function(ctx)
		-- full steel helm
		deco(ctx, "Helmet", Vector3.new(1.3, 0.9, 1.3), STEEL, CFrame.new(0, 2.25, 0), { material = Enum.Material.Metal })
		deco(ctx, "Visor", Vector3.new(1.0, 0.25, 0.2), DARKSTEEL, CFrame.new(0, 1.95, -0.6), { material = Enum.Material.Metal })
	end,
	[4] = function(ctx)
		-- combat helmet
		deco(ctx, "Helmet", Vector3.new(1.3, 0.6, 1.35), DARKARMY, CFrame.new(0, 2.3, 0))
	end,
	[5] = function(ctx)
		-- sleek visor helmet
		deco(ctx, "Helmet", Vector3.new(1.3, 0.7, 1.3), FUTURE, CFrame.new(0, 2.3, 0), { material = Enum.Material.Metal })
		deco(ctx, "Visor", Vector3.new(1.05, 0.3, 0.15), NEON, CFrame.new(0, 2.05, -0.62), { material = Enum.Material.Neon })
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
-- Heavies: one bespoke build per age
--------------------------------------------------------------------------------

local function heavyMammoth(ctx: Ctx) -- age 1: Mammoth Rider
	deco(ctx, "MammothBody", Vector3.new(4, 3, 5), FUR, CFrame.new(0, -0.5, 0.3), { material = Enum.Material.Fabric })
	deco(ctx, "MammothHead", Vector3.new(2.4, 2.2, 1.8), FUR, CFrame.new(0, 0.2, -2.6), { material = Enum.Material.Fabric })
	for _, xs in { -1, 1 } do
		deco(ctx, "Tusk", Vector3.new(0.35, 0.35, 2), Color3.fromRGB(235, 225, 200), CFrame.new(xs * 0.8, -0.5, -3.6) * CFrame.Angles(math.rad(-15), 0, 0))
		deco(ctx, "LegF", Vector3.new(0.9, 2.2, 0.9), FUR, CFrame.new(xs * 1.4, -2.1, -1.5), { material = Enum.Material.Fabric })
		deco(ctx, "LegB", Vector3.new(0.9, 2.2, 0.9), FUR, CFrame.new(xs * 1.4, -2.1, 1.8), { material = Enum.Material.Fabric })
	end
	-- rider
	deco(ctx, "Rider", Vector3.new(1, 1.3, 0.8), FUR, CFrame.new(0, 1.6, 0.5))
	deco(ctx, "RiderHead", Vector3.new(0.8, 0.8, 0.8), SKIN, CFrame.new(0, 2.6, 0.5), { shape = Enum.PartType.Ball })
end

local function heavyElephant(ctx: Ctx) -- age 2: War Elephant
	deco(ctx, "EleBody", Vector3.new(4.2, 3.2, 5), GREY, CFrame.new(0, -0.4, 0.3))
	deco(ctx, "EleHead", Vector3.new(2.6, 2.4, 1.8), GREY, CFrame.new(0, 0.3, -2.7))
	deco(ctx, "HeadPlate", Vector3.new(2, 1.8, 0.3), BRONZE, CFrame.new(0, 0.5, -3.6), { material = Enum.Material.Metal })
	for _, xs in { -1, 1 } do
		deco(ctx, "Tusk", Vector3.new(0.35, 0.35, 2.2), Color3.fromRGB(240, 232, 210), CFrame.new(xs * 0.9, -0.6, -3.7) * CFrame.Angles(math.rad(-12), 0, 0))
		deco(ctx, "LegF", Vector3.new(1, 2.3, 1), GREY, CFrame.new(xs * 1.5, -2.1, -1.5))
		deco(ctx, "LegB", Vector3.new(1, 2.3, 1), GREY, CFrame.new(xs * 1.5, -2.1, 1.8))
	end
	-- howdah (war platform)
	deco(ctx, "Howdah", Vector3.new(2.4, 1, 2.4), DARKWOOD, CFrame.new(0, 1.8, 0.4), { material = Enum.Material.Wood })
end

local function heavyCatapult(ctx: Ctx) -- age 3: Catapult
	deco(ctx, "Frame", Vector3.new(3.2, 0.8, 5), DARKWOOD, CFrame.new(0, -1.6, 0), { material = Enum.Material.Wood })
	for _, xs in { -1, 1 } do
		for _, zs in { -1, 1 } do
			deco(ctx, "Wheel", Vector3.new(0.5, 1.6, 1.6), WOOD, CFrame.new(xs * 1.8, -2.2, zs * 1.7) * CFrame.Angles(0, 0, math.rad(90)), { shape = Enum.PartType.Cylinder, material = Enum.Material.Wood })
		end
	end
	deco(ctx, "Upright", Vector3.new(2.6, 1.4, 0.6), DARKWOOD, CFrame.new(0, -0.7, -1.2), { material = Enum.Material.Wood })
	deco(ctx, "ThrowArm", Vector3.new(0.5, 4.2, 0.5), WOOD, CFrame.new(0, 0.6, 0.6) * CFrame.Angles(math.rad(-35), 0, 0), { material = Enum.Material.Wood })
	deco(ctx, "Bucket", Vector3.new(1.2, 0.7, 1.2), DARKWOOD, CFrame.new(0, 2.3, 1.9), { material = Enum.Material.Wood })
	deco(ctx, "Boulder", Vector3.new(0.9, 0.9, 0.9), STONE, CFrame.new(0, 2.9, 1.9), { shape = Enum.PartType.Ball, material = Enum.Material.Rock })
end

local function heavyTank(ctx: Ctx) -- age 4: Tank
	deco(ctx, "Hull", Vector3.new(3.6, 1.5, 5.5), ARMY, CFrame.new(0, -1.2, 0), { material = Enum.Material.Metal })
	for _, xs in { -1, 1 } do
		deco(ctx, "Tread", Vector3.new(1, 1.3, 5.8), DARKSTEEL, CFrame.new(xs * 2.1, -1.9, 0), { material = Enum.Material.Metal })
	end
	deco(ctx, "Turret", Vector3.new(2.4, 1.1, 2.6), DARKARMY, CFrame.new(0, 0.1, 0.3), { material = Enum.Material.Metal })
	deco(ctx, "Barrel", Vector3.new(0.45, 0.45, 3.6), DARKSTEEL, CFrame.new(0, 0.2, -2.6), { material = Enum.Material.Metal })
end

local function heavyMech(ctx: Ctx) -- age 5: War Mech
	for _, xs in { -1, 1 } do
		deco(ctx, "MechLeg", Vector3.new(1.2, 3, 1.5), Color3.fromRGB(190, 198, 205), CFrame.new(xs * 1.2, -1.5, 0), { material = Enum.Material.Metal })
		deco(ctx, "MechShoulder", Vector3.new(1.1, 1.1, 1.1), FUTURE, CFrame.new(xs * 2.1, 1.6, 0), { material = Enum.Material.Metal })
		deco(ctx, "MechCannon", Vector3.new(0.5, 0.5, 2.6), DARKSTEEL, CFrame.new(xs * 2.1, 1.6, -1.4), { material = Enum.Material.Metal })
		deco(ctx, "CannonGlow", Vector3.new(0.25, 0.25, 0.3), NEON, CFrame.new(xs * 2.1, 1.6, -2.75), { material = Enum.Material.Neon })
	end
	deco(ctx, "MechTorso", Vector3.new(3, 2.4, 2.4), FUTURE, CFrame.new(0, 1.2, 0), { material = Enum.Material.Metal })
	deco(ctx, "MechCore", Vector3.new(0.8, 0.8, 0.2), NEON, CFrame.new(0, 1.2, -1.25), { material = Enum.Material.Neon })
	deco(ctx, "MechHead", Vector3.new(1.2, 0.9, 1.2), Color3.fromRGB(190, 198, 205), CFrame.new(0, 2.85, 0), { material = Enum.Material.Metal })
	deco(ctx, "MechVisor", Vector3.new(0.9, 0.25, 0.15), Color3.fromRGB(255, 80, 70), CFrame.new(0, 2.85, -0.62), { material = Enum.Material.Neon })
end

local HEAVIES: { [number]: (Ctx) -> () } = {
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

	local ctx: Ctx = { model = model, body = body }

	if def.role == "heavy" then
		HEAVIES[def.age](ctx)
	else
		local outfit = OUTFITS[def.age]
		infantryBase(ctx, outfit[1], outfit[2], outfit[3])
		HEADGEAR[def.age](ctx)
		local weaponKey = INFANTRY_WEAPON[def.age][def.role]
		WEAPONS[weaponKey](ctx)
	end

	-- team stripe under the feet
	local stripeSize = def.role == "heavy" and Vector3.new(size.X + 0.4, 0.35, size.Z + 0.4) or Vector3.new(2.6, 0.35, 2)
	deco(ctx, "Stripe", stripeSize, side == "A" and Color3.fromRGB(52, 120, 200) or Color3.fromRGB(200, 70, 60),
		CFrame.new(0, -size.Y / 2 + 0.2, 0), { material = Enum.Material.Neon, transparency = 0.2 })

	return model, body
end

return UnitFactory
