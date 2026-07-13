--!strict
-- Lightweight public matchmaking lobby. Match simulation is never loaded here.

local Lighting = game:GetService("Lighting")
local LobbyBuilder = {}

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

function LobbyBuilder.build()
	if workspace:FindFirstChild("MatchmakingLobby") then return end
	local folder = Instance.new("Folder")
	folder.Name = "MatchmakingLobby"
	folder.Parent = workspace

	part(folder, "Island", Vector3.new(150, 4, 150), CFrame.new(0, -2, 0), Color3.fromRGB(38, 45, 58), Enum.Material.Slate)
	part(folder, "InnerFloor", Vector3.new(92, 1, 92), CFrame.new(0, 0.5, 0), Color3.fromRGB(60, 68, 82), Enum.Material.Concrete)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 1.5, 30)
	spawn.Color = Color3.fromRGB(70, 150, 220)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.25
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	local portalBase = part(folder, "QueuePortal", Vector3.new(24, 2, 24), CFrame.new(0, 1, -12), Color3.fromRGB(80, 180, 230), Enum.Material.Neon)
	local portal = part(folder, "PortalCore", Vector3.new(14, 18, 2), CFrame.new(0, 11, -20), Color3.fromRGB(95, 215, 255), Enum.Material.Neon)
	portal.CanCollide = false
	portal.Transparency = 0.2
	worldLabel(portal, "RANKED 1v1\nPRESS READY TO QUEUE", Color3.fromRGB(225, 245, 255), Vector3.new(0, 13, 0), Vector2.new(300, 90))
	worldLabel(portalBase, "Fair armies • Five ages • One enemy base", Color3.fromRGB(235, 215, 130), Vector3.new(0, 4, 0), Vector2.new(300, 45))

	local ages = {
		{ "STONE", Color3.fromRGB(150, 120, 90) },
		{ "MEDIEVAL", Color3.fromRGB(200, 170, 60) },
		{ "RENAISSANCE", Color3.fromRGB(135, 110, 120) },
		{ "MODERN", Color3.fromRGB(70, 115, 75) },
		{ "FUTURE", Color3.fromRGB(70, 190, 225) },
	}
	for index, age in ages do
		local angle = ((index - 1) / #ages) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 55, 4, math.sin(angle) * 55)
		local pedestal = part(folder, `Age_{index}`, Vector3.new(12, 8 + index * 1.5, 12), CFrame.new(pos), age[2] :: Color3, index == 5 and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		worldLabel(pedestal, `{index}. {age[1]}`, Color3.new(1, 1, 1), Vector3.new(0, pedestal.Size.Y / 2 + 3, 0), Vector2.new(150, 35))
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Color = Color3.fromRGB(170, 195, 230)
	atmosphere.Decay = Color3.fromRGB(70, 80, 110)
	atmosphere.Parent = Lighting
	Lighting.ClockTime = 18.2
	Lighting.Brightness = 2
	print("[AgeOfWarFP] Matchmaking lobby environment built")
end

return LobbyBuilder
