--!strict
-- Procedurally builds the 1v1 lane map: ground, walls, ridges/flanks, two bases with turret slots.
-- Lane runs along the X axis. Side A (player) base at -X, side B (AI) at +X.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

export type BaseHandle = {
	side: string,
	model: Model,
	core: BasePart, -- the damageable part
	turretMounts: { BasePart },
	unitSpawn: CFrame, -- where units appear
	heroSpawn: CFrame,
}

export type MapHandle = {
	folder: Folder,
	bases: { [string]: BaseHandle },
	laneY: number, -- ground top surface Y
}

local MapBuilder = {}

local LANE_LEN = GameConfig.LANE_LENGTH
local LANE_WID = GameConfig.LANE_WIDTH
local GROUND_Y = 0 -- top of ground

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function buildBase(side: string, xSign: number, color: Color3, parent: Instance): BaseHandle
	local model = Instance.new("Model")
	model.Name = `Base_{side}`

	local baseX = xSign * (LANE_LEN / 2 + 10)

	-- Core: big damageable monolith
	local core = part({
		Name = "Core",
		Size = Vector3.new(14, 24, 22),
		CFrame = CFrame.new(baseX, GROUND_Y + 12, 0),
		Color = color,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	core:SetAttribute("Side", side)
	core:SetAttribute("Hp", GameConfig.BASE_MAX_HP)
	core:SetAttribute("MaxHp", GameConfig.BASE_MAX_HP)
	core:SetAttribute("EntityType", "Base")

	-- Platform under the base
	part({
		Name = "Platform",
		Size = Vector3.new(30, 2, LANE_WID),
		CFrame = CFrame.new(baseX, GROUND_Y - 1 + 0.01, 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.4),
		Material = Enum.Material.Concrete,
		Parent = model,
	})

	-- Turret mounts: pillars beside/behind the core
	local turretMounts = {}
	for i = 1, GameConfig.TURRET_SLOTS do
		local z = ({ -16, 16, 0 })[i]
		local x = baseX + xSign * (i == 3 and 12 or 2)
		local mount = part({
			Name = `TurretMount{i}`,
			Size = Vector3.new(4, 10, 4),
			CFrame = CFrame.new(x, GROUND_Y + 5, z),
			Color = Color3.fromRGB(60, 60, 60),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		table.insert(turretMounts, mount)
	end

	model.Parent = parent

	local unitSpawn = CFrame.new(baseX - xSign * 14, GROUND_Y + 3, 0) * CFrame.Angles(0, xSign > 0 and math.rad(90) or math.rad(-90), 0)
	local heroSpawn = CFrame.new(baseX - xSign * 20, GROUND_Y + 4, 12) * CFrame.Angles(0, xSign > 0 and math.rad(90) or math.rad(-90), 0)

	return {
		side = side,
		model = model,
		core = core,
		turretMounts = turretMounts,
		unitSpawn = unitSpawn,
		heroSpawn = heroSpawn,
	}
end

function MapBuilder.build(): MapHandle
	local folder = Instance.new("Folder")
	folder.Name = "Map"

	local totalLen = LANE_LEN + 80

	-- Ground
	part({
		Name = "Ground",
		Size = Vector3.new(totalLen, 4, LANE_WID + 60),
		CFrame = CFrame.new(0, GROUND_Y - 2, 0),
		Color = Color3.fromRGB(106, 127, 63),
		Material = Enum.Material.Grass,
		Parent = folder,
	})

	-- Scattered cover rocks along the lane
	local rng = Random.new(7)
	for i = 1, 14 do
		local x = rng:NextNumber(-LANE_LEN / 2 + 30, LANE_LEN / 2 - 30)
		local z = rng:NextNumber(-LANE_WID / 2 + 6, LANE_WID / 2 - 6)
		local s = rng:NextNumber(3, 7)
		part({
			Name = "Rock",
			Size = Vector3.new(s, s * 0.8, s),
			CFrame = CFrame.new(x, GROUND_Y + s * 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = Color3.fromRGB(130, 130, 125),
			Material = Enum.Material.Rock,
			Parent = folder,
		})
	end

	-- Side ridges (hero flank paths, raised walkways along lane edges)
	for _, zSign in { -1, 1 } do
		local z = zSign * (LANE_WID / 2 + 12)
		part({
			Name = "Ridge",
			Size = Vector3.new(LANE_LEN - 40, 6, 16),
			CFrame = CFrame.new(0, GROUND_Y + 3, z),
			Color = Color3.fromRGB(120, 110, 90),
			Material = Enum.Material.Rock,
			Parent = folder,
		})
		-- Ramps up to the ridge at both ends
		for _, xSign in { -1, 1 } do
			part({
				Name = "RidgeRamp",
				Size = Vector3.new(20, 1, 14),
				CFrame = CFrame.new(xSign * (LANE_LEN / 2 - 30), GROUND_Y + 3, z)
					* CFrame.Angles(0, 0, xSign * math.rad(-17)),
				Color = Color3.fromRGB(120, 110, 90),
				Material = Enum.Material.Rock,
				Parent = folder,
			})
		end
	end

	-- Boundary walls (invisible)
	local wallDefs = {
		{ Vector3.new(totalLen, 60, 4), CFrame.new(0, 28, (LANE_WID / 2 + 28)) },
		{ Vector3.new(totalLen, 60, 4), CFrame.new(0, 28, -(LANE_WID / 2 + 28)) },
		{ Vector3.new(4, 60, LANE_WID + 60), CFrame.new(totalLen / 2, 28, 0) },
		{ Vector3.new(4, 60, LANE_WID + 60), CFrame.new(-totalLen / 2, 28, 0) },
	}
	for _, def in wallDefs do
		part({
			Name = "Wall",
			Size = def[1],
			CFrame = def[2],
			Transparency = 1,
			Parent = folder,
		})
	end

	local bases = {
		A = buildBase("A", -1, Color3.fromRGB(52, 120, 200), folder),
		B = buildBase("B", 1, Color3.fromRGB(200, 70, 60), folder),
	}

	folder.Parent = workspace

	return {
		folder = folder,
		bases = bases,
		laneY = GROUND_Y,
	}
end

return MapBuilder
