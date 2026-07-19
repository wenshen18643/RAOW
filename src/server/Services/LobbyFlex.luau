--!strict
-- Lobby-only flex layer: overhead stat billboards and the leaderboard wall.
-- attachBillboard takes plain strings so NPC/fake-player models can reuse it.

local PlayerData = require(script.Parent.PlayerData)
local Leaderboard = require(script.Parent.Leaderboard)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

local LobbyFlex = {}

local GOLD = Color3.fromRGB(240, 200, 80)
local GREY = Color3.fromRGB(150, 155, 165)
local WALL_REFRESH = 120

local MODE_ORDER = { "Impossible", "Hard", "Normal" }
local MODE_COLORS: { [string]: Color3 } = {
	Impossible = Color3.fromRGB(220, 90, 220),
	Hard = Color3.fromRGB(255, 140, 40),
	Normal = Color3.fromRGB(60, 200, 180),
}

local function billboardLine(parent: Instance, text: string, color: Color3, yPos: number): TextLabel
	local line = Instance.new("TextLabel")
	line.Size = UDim2.fromScale(1, 0.5)
	line.Position = UDim2.fromScale(0, yPos)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.GothamBlack
	line.TextScaled = true
	line.TextColor3 = color
	line.TextStrokeTransparency = 0.4
	line.Text = text
	line.Parent = parent
	return line
end

function LobbyFlex.flexTextFor(profile: PlayerData.PlayerProfile): (string, Color3)
	for _, mode in MODE_ORDER do
		local level = (profile.pveProgress :: { [string]: number })[mode] or 0
		if level > 0 then
			return `{string.upper(mode)} {level}`, MODE_COLORS[mode]
		end
	end
	return "ROOKIE", GREY
end

function LobbyFlex.attachBillboard(character: Model, ratingText: string, flexText: string, flexColor: Color3)
	task.spawn(function()
		local head = character:WaitForChild("Head", 5)
		if not head or not head:IsA("BasePart") then return end
		local existing = head:FindFirstChild("FlexBillboard")
		if existing then existing:Destroy() end
		local gui = Instance.new("BillboardGui")
		gui.Name = "FlexBillboard"
		gui.Size = UDim2.fromOffset(130, 44)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 40
		gui.Adornee = head
		billboardLine(gui, ratingText, GOLD, 0)
		billboardLine(gui, flexText, flexColor, 0.5)
		gui.Parent = head
	end)
end

function LobbyFlex.bindPlayer(player: Player)
	local function attach(character: Model)
		local profile = PlayerData.get(player)
		local flexText, flexColor = LobbyFlex.flexTextFor(profile)
		LobbyFlex.attachBillboard(character, `ELO {math.round(profile.rating)}`, flexText, flexColor)
	end
	player.CharacterAdded:Connect(attach)
	if player.Character then attach(player.Character) end
end

local function wallPanel(wall: BasePart, face: Enum.NormalId, title: string): { TextLabel }
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = wall
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 0.12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = GOLD
	titleLabel.Text = title
	titleLabel.Parent = gui
	local rows: { TextLabel } = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(0.9, 0.075)
		row.Position = UDim2.fromScale(0.05, 0.14 + (i - 1) * 0.082)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(225, 230, 240)
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end
	return rows
end

local function refreshPanel(rows: { TextLabel }, isPve: boolean)
	local ok, top = pcall(function() return Leaderboard.getTop(isPve) end)
	if not ok then
		rows[1].Text = "UNAVAILABLE"
		return
	end
	for i = 1, 10 do
		local entry = top[i]
		rows[i].Text = entry and `{i}. {entry.name} — {entry.rating}` or ""
	end
	if #top == 0 then rows[1].Text = "UNAVAILABLE" end
end

function LobbyFlex.buildLeaderboardWall()
	local folder = workspace:FindFirstChild("MatchmakingLobby")
	if not folder or folder:FindFirstChild("LeaderboardWall") then return end
	local wall = Instance.new("Part")
	wall.Name = "LeaderboardWall"
	wall.Size = Vector3.new(26, 14, 1.5)
	-- Corner placement clears the four portal pads (at ±38 on the axes) and the spawn pad.
	local origin = LobbyBuilder.ORIGIN
	wall.CFrame = CFrame.lookAt(origin + Vector3.new(-42, 7, 42), origin + Vector3.new(0, 7, 0))
	wall.Color = Color3.fromRGB(24, 28, 38)
	wall.Material = Enum.Material.Slate
	wall.Anchored = true
	wall.Parent = folder

	local pvpRows = wallPanel(wall, Enum.NormalId.Front, "TOP COMMANDERS — PVP RATING")
	local pveRows = wallPanel(wall, Enum.NormalId.Back, "TOP CAMPAIGNERS — TOTAL CLEARS")

	task.spawn(function()
		while wall.Parent do
			refreshPanel(pvpRows, false)
			refreshPanel(pveRows, true)
			task.wait(WALL_REFRESH)
		end
	end)
end

return LobbyFlex
