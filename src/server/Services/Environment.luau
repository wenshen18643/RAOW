--!strict
-- Visual environment pass: lighting, atmosphere, post-processing, clouds,
-- and map dressing (trees, banners) around the procedural lane map.
-- Pure visuals — nothing here affects simulation.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MapBuilder = require(script.Parent.MapBuilder)

local Environment = {}

local LANE_LEN = GameConfig.LANE_LENGTH
local LANE_WID = GameConfig.LANE_WIDTH

local function setupLighting()
	-- warm late-afternoon sun, long soft shadows
	Lighting.ClockTime = 15.2
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.05
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.Ambient = Color3.fromRGB(70, 72, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 104, 112)

	-- clear any stale effects from a previous run (Studio re-runs)
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.6
	atmosphere.Color = Color3.fromRGB(199, 175, 166)
	atmosphere.Decay = Color3.fromRGB(92, 80, 98)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 1.35
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Contrast = 0.08
	color.Saturation = 0.15
	color.TintColor = Color3.fromRGB(255, 250, 240)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.7
	rays.Parent = Lighting

	-- gentle far-field blur pulls focus into the lane
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 50
	dof.InFocusRadius = 140
	dof.NearIntensity = 0
	dof.Parent = Lighting

	-- volumetric-ish clouds
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.28
		clouds.Color = Color3.fromRGB(235, 230, 225)
		clouds.Parent = terrain
	end
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function tree(parent: Instance, pos: Vector3, scale: number, rng: Random)
	local trunkH = 6 * scale
	part({
		Name = "TreeTrunk",
		Size = Vector3.new(1.1 * scale, trunkH, 1.1 * scale),
		CFrame = CFrame.new(pos.X, pos.Y + trunkH / 2, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-4, 4))),
		Color = Color3.fromRGB(96, 70, 46),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	-- stacked canopy blobs, slightly varied greens
	local baseGreen = Color3.fromRGB(64 + rng:NextInteger(-10, 10), 118 + rng:NextInteger(-14, 14), 58 + rng:NextInteger(-10, 10))
	for i = 1, 3 do
		local s = (5.4 - i * 1.2) * scale
		part({
			Name = "TreeCanopy",
			Size = Vector3.new(s, s * 0.75, s),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(
				pos.X + rng:NextNumber(-0.8, 0.8) * scale,
				pos.Y + trunkH - 0.5 + (i - 1) * 1.6 * scale,
				pos.Z + rng:NextNumber(-0.8, 0.8) * scale
			),
			Color = baseGreen:Lerp(Color3.fromRGB(150, 190, 90), (i - 1) * 0.18),
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
end

local function banner(parent: Instance, pos: Vector3, facing: number, color: Color3)
	part({
		Name = "BannerPole",
		Size = Vector3.new(0.5, 14, 0.5),
		CFrame = CFrame.new(pos.X, pos.Y + 7, pos.Z),
		Color = Color3.fromRGB(70, 55, 38),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	part({
		Name = "BannerFlag",
		Size = Vector3.new(0.2, 5, 3.4),
		CFrame = CFrame.new(pos.X, pos.Y + 11, pos.Z + facing * 1.95),
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = parent,
	})
	part({
		Name = "BannerTip",
		Size = Vector3.new(0.9, 0.9, 0.9),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(pos.X, pos.Y + 14.2, pos.Z),
		Color = Color3.fromRGB(230, 195, 90),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
end

local function dressMap(map: MapBuilder.MapHandle)
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	folder.Parent = map.folder

	local rng = Random.new(42)

	-- tree lines beyond the ridges on both sides
	for _, zSign in { -1, 1 } do
		local zBase = zSign * (LANE_WID / 2 + 26)
		local x = -LANE_LEN / 2 + 15
		while x < LANE_LEN / 2 - 15 do
			if rng:NextNumber() > 0.25 then
				tree(folder, Vector3.new(x + rng:NextNumber(-6, 6), 0, zBase + rng:NextNumber(-4, 6)), rng:NextNumber(0.8, 1.5), rng)
			end
			x += rng:NextNumber(18, 30)
		end
	end

	-- a few trees on the ridges themselves (sparse, they're hero paths)
	for _, zSign in { -1, 1 } do
		for i = 1, 3 do
			local x = rng:NextNumber(-LANE_LEN / 2 + 40, LANE_LEN / 2 - 40)
			tree(folder, Vector3.new(x, 6, zSign * (LANE_WID / 2 + 12) + rng:NextNumber(-3, 3)), rng:NextNumber(0.6, 0.9), rng)
		end
	end

	-- team banners flanking each base
	for side, base in map.bases do
		local color = side == "A" and Color3.fromRGB(52, 120, 200) or Color3.fromRGB(200, 70, 60)
		local corePos = base.core.Position
		local xSign = side == "A" and -1 or 1
		for _, zOff in { -13, 13 } do
			banner(folder, Vector3.new(corePos.X - xSign * 10, 0, zOff), -xSign, color)
		end
	end
end

function Environment.setup(map: MapBuilder.MapHandle)
	setupLighting()
	dressMap(map)
end

return Environment
