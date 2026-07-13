--!strict
-- Procedurally builds the 1v1 lane map: ground, walls, ridges/flanks, two bases with turret slots.
-- Lane runs along the X axis. Side A (player) base at -X, side B (AI) at +X.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

export type BaseHandle = {
	side: string,
	model: Model,
	core: BasePart, -- the damageable part (invisible hitbox)
	visuals: Model, -- holds the current age's visual parts
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

-- Procedurally generates visual parts and turret mounts for a specific age
local function buildAgeVisuals(age: number, baseX: number, xSign: number, color: Color3, parent: Model): { BasePart }
	local visuals = Instance.new("Model")
	visuals.Name = "Visuals"
	
	local mounts = {}
	local baseZ = 0
	
	-- Common platform
	part({
		Name = "Platform",
		Size = Vector3.new(34, 2, LANE_WID),
		CFrame = CFrame.new(baseX, GROUND_Y - 1 + 0.01, baseZ),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.4),
		Material = Enum.Material.Concrete,
		Parent = visuals,
	})

	if age == 1 then
		-- Stone Age: Rocky Cave
		part({ Name = "CaveBody", Size = Vector3.new(16, 20, 26), CFrame = CFrame.new(baseX + xSign*2, GROUND_Y + 10, baseZ), Color = Color3.fromRGB(110, 100, 90), Material = Enum.Material.Rock, Parent = visuals })
		part({ Name = "CaveEntrance", Size = Vector3.new(4, 12, 14), CFrame = CFrame.new(baseX - xSign*7, GROUND_Y + 6, baseZ), Color = Color3.fromRGB(30, 25, 20), Material = Enum.Material.Rock, Parent = visuals })
		for i = 1, 4 do
			local z = (i <= 2) and -10 or 10
			local xOffset = (i % 2 == 0) and 4 or -4
			local mount = part({ Name = `TurretMount{i}`, Size = Vector3.new(4, 8, 4), CFrame = CFrame.new(baseX + xOffset, GROUND_Y + 4, z), Color = Color3.fromRGB(80, 70, 60), Material = Enum.Material.Wood, Parent = visuals })
			table.insert(mounts, mount)
		end

	elseif age == 2 then
		-- Medieval Age: Stone Keep
		part({ Name = "Keep", Size = Vector3.new(18, 24, 22), CFrame = CFrame.new(baseX + xSign*4, GROUND_Y + 12, baseZ), Color = Color3.fromRGB(130, 130, 130), Material = Enum.Material.Cobblestone, Parent = visuals })
		part({ Name = "Gate", Size = Vector3.new(2, 10, 10), CFrame = CFrame.new(baseX - xSign*5.1, GROUND_Y + 5, baseZ), Color = Color3.fromRGB(70, 40, 20), Material = Enum.Material.Wood, Parent = visuals })
		for i = 1, 4 do
			local z = (i <= 2) and -8 or 8
			local h = (i % 2 == 0) and 24 or 12
			local xOffset = (i % 2 == 0) and (xSign * 10) or (-xSign * 2)
			local mount = part({ Name = `TurretMount{i}`, Size = Vector3.new(5, h, 5), CFrame = CFrame.new(baseX + xOffset, GROUND_Y + h/2, z), Color = Color3.fromRGB(110, 110, 110), Material = Enum.Material.Cobblestone, Parent = visuals })
			table.insert(mounts, mount)
		end

	elseif age == 3 then
		-- Renaissance Age: Fortified Brick Fort
		part({ Name = "Fort", Size = Vector3.new(20, 22, 24), CFrame = CFrame.new(baseX + xSign*4, GROUND_Y + 11, baseZ), Color = Color3.fromRGB(160, 90, 70), Material = Enum.Material.Brick, Parent = visuals })
		for i = 1, 4 do
			local z = (i <= 2) and -10 or 10
			local xOffset = (i % 2 == 0) and (xSign * 12) or 0
			local mount = part({ Name = `TurretMount{i}`, Size = Vector3.new(6, 14, 6), CFrame = CFrame.new(baseX + xOffset, GROUND_Y + 7, z), Color = Color3.fromRGB(140, 80, 60), Material = Enum.Material.Brick, Parent = visuals })
			table.insert(mounts, mount)
		end

	elseif age == 4 then
		-- Modern Age: Concrete Bunker
		part({ Name = "Bunker", Size = Vector3.new(22, 16, 28), CFrame = CFrame.new(baseX + xSign*4, GROUND_Y + 8, baseZ), Color = Color3.fromRGB(100, 105, 100), Material = Enum.Material.Concrete, Parent = visuals })
		part({ Name = "Sandbags", Size = Vector3.new(4, 4, 30), CFrame = CFrame.new(baseX - xSign*8, GROUND_Y + 2, baseZ), Color = Color3.fromRGB(150, 140, 110), Material = Enum.Material.Sand, Parent = visuals })
		for i = 1, 4 do
			local z = (i <= 2) and -8 or 8
			local xOffset = (i % 2 == 0) and (xSign * 12) or (-xSign * 2)
			local mount = part({ Name = `TurretMount{i}`, Size = Vector3.new(5, 17, 5), CFrame = CFrame.new(baseX + xOffset, GROUND_Y + 8.5, z), Color = Color3.fromRGB(80, 85, 80), Material = Enum.Material.Metal, Parent = visuals })
			table.insert(mounts, mount)
		end

	elseif age == 5 then
		-- Future Age: Sci-Fi Base
		part({ Name = "SciFiCore", Size = Vector3.new(18, 28, 20), CFrame = CFrame.new(baseX + xSign*4, GROUND_Y + 14, baseZ), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, Parent = visuals })
		part({ Name = "NeonRing", Size = Vector3.new(20, 2, 22), CFrame = CFrame.new(baseX + xSign*4, GROUND_Y + 14, baseZ), Color = Color3.fromRGB(0, 200, 255), Material = Enum.Material.Neon, Parent = visuals })
		for i = 1, 4 do
			local z = (i <= 2) and -9 or 9
			local xOffset = (i % 2 == 0) and (xSign * 10) or (-xSign * 2)
			local mount = part({ Name = `TurretMount{i}`, Size = Vector3.new(4, 18, 4), CFrame = CFrame.new(baseX + xOffset, GROUND_Y + 9, z), Color = Color3.fromRGB(20, 20, 30), Material = Enum.Material.Metal, Parent = visuals })
			part({ Name = "MountNeon", Size = Vector3.new(4.2, 1, 4.2), CFrame = mount.CFrame * CFrame.new(0, 8, 0), Color = Color3.fromRGB(0, 200, 255), Material = Enum.Material.Neon, Parent = visuals })
			table.insert(mounts, mount)
		end
	end

	visuals.Parent = parent
	return mounts
end

local function buildBase(age: number, side: string, xSign: number, color: Color3, parent: Instance): BaseHandle
	local model = Instance.new("Model")
	model.Name = `Base_{side}`

	local baseX = xSign * (LANE_LEN / 2 + 10)

	-- Permanent Hitbox Core (invisible)
	local core = part({
		Name = "Core",
		Size = Vector3.new(24, 28, 30),
		CFrame = CFrame.new(baseX, GROUND_Y + 14, 0),
		Transparency = 1,
		CanCollide = true,
		Parent = model,
	})
	core:SetAttribute("Side", side)
	core:SetAttribute("Hp", GameConfig.BASE_MAX_HP)
	core:SetAttribute("MaxHp", GameConfig.BASE_MAX_HP)
	core:SetAttribute("EntityType", "Base")

	local mounts = buildAgeVisuals(age, baseX, xSign, color, model)

	model.Parent = parent

	local unitSpawn = CFrame.new(baseX - xSign * 14, GROUND_Y, 0) * CFrame.Angles(0, xSign > 0 and math.rad(90) or math.rad(-90), 0)
	local heroSpawn = CFrame.new(baseX - xSign * 20, GROUND_Y + 4, 12) * CFrame.Angles(0, xSign > 0 and math.rad(90) or math.rad(-90), 0)

	return {
		side = side,
		model = model,
		core = core,
		visuals = model.Visuals,
		turretMounts = mounts,
		unitSpawn = unitSpawn,
		heroSpawn = heroSpawn,
	}
end

function MapBuilder.evolveBase(map: MapHandle, side: string, newAge: number, color: Color3)
	local base = map.bases[side]
	if base.visuals then
		base.visuals:Destroy()
	end
	
	local xSign = (side == "B") and 1 or -1
	local baseX = xSign * (LANE_LEN / 2 + 10)
	
	base.turretMounts = buildAgeVisuals(newAge, baseX, xSign, color, base.model)
	base.visuals = base.model:FindFirstChild("Visuals") :: Model
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

	-- Scattered cover rocks (mirrored from midpoint)
	local rng = Random.new()
	for i = 1, 7 do
		-- Generate on Side A (negative X)
		local x = rng:NextNumber(-LANE_LEN / 2 + 30, -15)
		local z = rng:NextNumber(-LANE_WID / 2 + 6, LANE_WID / 2 - 6)
		local s = rng:NextNumber(3, 6)
		local rotY = rng:NextNumber(0, math.pi)
		
		-- Place Side A Rock
		part({
			Name = "Rock",
			Size = Vector3.new(s, s * 0.9, s),
			CFrame = CFrame.new(x, GROUND_Y + s * 0.45, z) * CFrame.Angles(0, rotY, 0),
			Color = Color3.fromRGB(130, 130, 125),
			Material = Enum.Material.Rock,
			Parent = folder,
		})
		
		-- Place Side B Rock (Exact Mirror)
		part({
			Name = "Rock",
			Size = Vector3.new(s, s * 0.9, s),
			CFrame = CFrame.new(-x, GROUND_Y + s * 0.45, -z) * CFrame.Angles(0, rotY, 0),
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
		A = buildBase(1, "A", -1, Color3.fromRGB(52, 120, 200), folder),
		B = buildBase(1, "B", 1, Color3.fromRGB(200, 70, 60), folder),
	}

	folder.Parent = workspace

	return {
		folder = folder,
		bases = bases,
		laneY = GROUND_Y,
	}
end

return MapBuilder
