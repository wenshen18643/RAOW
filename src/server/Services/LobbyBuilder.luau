--!strict
-- Lightweight public matchmaking lobby. Match simulation is never loaded here.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local LobbyBuilder = {}

-- The lobby lives far from the match arena (which is centered at the world
-- origin) so the two never overlap when both exist, e.g. in Studio.
LobbyBuilder.ORIGIN = Vector3.new(0, 0, 1200)
local ORIGIN = LobbyBuilder.ORIGIN

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.Parent = parent
	return p
end

local function buildRock(folder: Folder, size: Vector3, cf: CFrame)
	local r = part(folder, "LobbyRock", size, cf, Color3.fromRGB(90, 95, 105), Enum.Material.Slate)
	r.CanCollide = true
end

local function buildTree(folder: Folder, pos: Vector3)
	-- Trunk
	local trunk = part(folder, "LobbyTreeTrunk", Vector3.new(1.8, 10, 1.8), CFrame.new(pos + Vector3.new(0, 5, 0)), Color3.fromRGB(100, 75, 55), Enum.Material.WoodPlanks)
	trunk.CanCollide = true

	-- Low-poly leaves layers
	local leaf1 = part(folder, "LobbyTreeLeaves1", Vector3.new(7, 5, 7), CFrame.new(pos + Vector3.new(0, 9, 0)), Color3.fromRGB(50, 110, 60), Enum.Material.Grass)
	leaf1.CanCollide = false
	
	local leaf2 = part(folder, "LobbyTreeLeaves2", Vector3.new(5, 4, 5), CFrame.new(pos + Vector3.new(0, 12.5, 0)), Color3.fromRGB(60, 125, 70), Enum.Material.Grass)
	leaf2.CanCollide = false
	
	local leaf3 = part(folder, "LobbyTreeLeaves3", Vector3.new(3, 3, 3), CFrame.new(pos + Vector3.new(0, 15, 0)), Color3.fromRGB(70, 140, 80), Enum.Material.Grass)
	leaf3.CanCollide = false
end

local function worldLabel(adornee: BasePart, text: string, color: Color3, offset: Vector3, size: Vector2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 300
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.35
	label.Text = text
	label.Parent = gui
end

local function buildPortal(folder: Folder, name: string, mode: string, pveMode: string?, color: Color3, pos: Vector3)
	-- Face the center of the island
	local center = Vector3.new(ORIGIN.X, pos.Y, ORIGIN.Z)
	local cf = CFrame.lookAt(pos, center)
	
	-- Base pad
	local pad = part(folder, name, Vector3.new(14, 1.2, 14), cf, color, Enum.Material.Neon)
	pad.Transparency = 0.3
	CollectionService:AddTag(pad, "ModePortal")
	pad:SetAttribute("Mode", mode)
	if pveMode then
		pad:SetAttribute("PveMode", pveMode)
	end
	
	-- Core part (offset slightly back so it looks like a gateway)
	local coreCF = cf * CFrame.new(0, 5, -4)
	local core = part(folder, name .. "_Core", Vector3.new(8, 10, 1.5), coreCF, color, Enum.Material.Neon)
	core.CanCollide = false
	core.Transparency = 0.25

	-- PointLight to project warm color around the portal
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2.5
	light.Range = 25
	light.Shadows = true
	light.Parent = pad
	
	-- Labels
	if mode == "pvp" then
		worldLabel(core, "RANKED 1v1\nPVP ARENA", Color3.fromRGB(255, 245, 200), Vector3.new(0, 7, 0), Vector2.new(200, 60))
		worldLabel(pad, "Enter portal to queue", Color3.fromRGB(255, 235, 170), Vector3.new(0, 3, 0), Vector2.new(200, 30))
	else
		worldLabel(core, `{pveMode:upper()} MODE\nPVE CAMPAIGN`, Color3.fromRGB(225, 245, 255), Vector3.new(0, 7, 0), Vector2.new(200, 60))
		worldLabel(pad, "Enter portal to play", Color3.fromRGB(215, 235, 255), Vector3.new(0, 3, 0), Vector2.new(200, 30))
	end
end

function LobbyBuilder.build()
	if workspace:FindFirstChild("MatchmakingLobby") then return end
	local folder = Instance.new("Folder")
	folder.Name = "MatchmakingLobby"
	folder.Parent = workspace

	part(folder, "Island", Vector3.new(150, 4, 150), CFrame.new(ORIGIN + Vector3.new(0, -2, 0)), Color3.fromRGB(38, 45, 58), Enum.Material.Slate)
	part(folder, "InnerFloor", Vector3.new(92, 1, 92), CFrame.new(ORIGIN + Vector3.new(0, 0.5, 0)), Color3.fromRGB(60, 68, 82), Enum.Material.Concrete)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(ORIGIN + Vector3.new(0, 1.5, 30))
	spawn.Color = Color3.fromRGB(70, 150, 220)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.25
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	-- Build the 4 portals around the island
	buildPortal(folder, "Portal_Normal", "pve", "Normal", Color3.fromRGB(0, 180, 160), ORIGIN + Vector3.new(-38, 1, 0))
	buildPortal(folder, "Portal_Hard", "pve", "Hard", Color3.fromRGB(255, 120, 0), ORIGIN + Vector3.new(0, 1, -38))
	buildPortal(folder, "Portal_Impossible", "pve", "Impossible", Color3.fromRGB(180, 0, 180), ORIGIN + Vector3.new(38, 1, 0))
	buildPortal(folder, "Portal_PvP", "pvp", nil, Color3.fromRGB(255, 200, 0), ORIGIN + Vector3.new(0, 1, 38))

	-- Layered island edge trim (3-stud step down below the main island)
	part(folder, "IslandTrim", Vector3.new(156, 3, 156), CFrame.new(ORIGIN + Vector3.new(0, -4.5, 0)), Color3.fromRGB(24, 28, 36), Enum.Material.Slate)

	-- Subtle grass-green accent areas at the corners
	part(folder, "GrassCorner1", Vector3.new(28, 0.2, 28), CFrame.new(ORIGIN + Vector3.new(-60, 0.1, -60)), Color3.fromRGB(76, 127, 72), Enum.Material.Grass)
	part(folder, "GrassCorner2", Vector3.new(28, 0.2, 28), CFrame.new(ORIGIN + Vector3.new(60, 0.1, -60)), Color3.fromRGB(76, 127, 72), Enum.Material.Grass)
	part(folder, "GrassCorner3", Vector3.new(28, 0.2, 28), CFrame.new(ORIGIN + Vector3.new(-60, 0.1, 60)), Color3.fromRGB(76, 127, 72), Enum.Material.Grass)
	part(folder, "GrassCorner4", Vector3.new(28, 0.2, 28), CFrame.new(ORIGIN + Vector3.new(60, 0.1, 60)), Color3.fromRGB(76, 127, 72), Enum.Material.Grass)

	-- Soft path strips from spawn/center to each portal pad (pebble style)
	part(folder, "Path_Normal", Vector3.new(38, 0.2, 6), CFrame.new(ORIGIN + Vector3.new(-19, 0.51, 0)), Color3.fromRGB(160, 155, 145), Enum.Material.Pebble)
	part(folder, "Path_Hard", Vector3.new(6, 0.2, 38), CFrame.new(ORIGIN + Vector3.new(0, 0.51, -19)), Color3.fromRGB(160, 155, 145), Enum.Material.Pebble)
	part(folder, "Path_Impossible", Vector3.new(38, 0.2, 6), CFrame.new(ORIGIN + Vector3.new(19, 0.51, 0)), Color3.fromRGB(160, 155, 145), Enum.Material.Pebble)
	part(folder, "Path_PvP", Vector3.new(6, 0.2, 38), CFrame.new(ORIGIN + Vector3.new(0, 0.51, 19)), Color3.fromRGB(160, 155, 145), Enum.Material.Pebble)

	-- Rocks and trees in the grass corners
	buildRock(folder, Vector3.new(6, 8, 6), CFrame.new(ORIGIN + Vector3.new(-65, 3, -65)) * CFrame.Angles(0.2, 0.4, 0.1))
	buildRock(folder, Vector3.new(4, 5, 4), CFrame.new(ORIGIN + Vector3.new(-61, 1.5, -67)) * CFrame.Angles(-0.1, 0.2, 0.3))
	buildRock(folder, Vector3.new(7, 9, 6), CFrame.new(ORIGIN + Vector3.new(64, 3.5, -63)) * CFrame.Angles(0.3, -0.2, 0.1))
	buildRock(folder, Vector3.new(5, 6, 5), CFrame.new(ORIGIN + Vector3.new(62, 2, 62)) * CFrame.Angles(-0.2, 0.1, -0.4))

	buildTree(folder, ORIGIN + Vector3.new(-58, 0, -58))
	buildTree(folder, ORIGIN + Vector3.new(58, 0, -58))
	buildTree(folder, ORIGIN + Vector3.new(-58, 0, 58))
	buildTree(folder, ORIGIN + Vector3.new(58, 0, 58))

	-- Floating rotating crystal and ring above the island center
	local crystal = part(folder, "LobbyCrystal", Vector3.new(5, 8, 5), CFrame.new(ORIGIN + Vector3.new(0, 20, 0)), Color3.fromRGB(255, 215, 0), Enum.Material.Neon)
	crystal.CanCollide = false

	-- The crystal/ring animation runs on each client (LobbyPortals): a server
	-- loop would replicate five CFrame writes per frame to every player.
	for i = 1, 4 do
		local p = part(folder, `LobbyRingPart_{i}`, Vector3.new(8, 0.5, 0.5), CFrame.new(ORIGIN + Vector3.new(0, 20, 0)), Color3.fromRGB(240, 200, 80), Enum.Material.Neon)
		p.CanCollide = false
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Color = Color3.fromRGB(170, 195, 230)
	atmosphere.Decay = Color3.fromRGB(70, 80, 110)
	atmosphere.Parent = Lighting
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(90, 95, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 132, 140)
	print("[AgeOfWarFP] Matchmaking lobby environment built with 4 portals")
end

return LobbyBuilder
