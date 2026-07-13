--!strict
-- Main menu, difficulty select, settings, how-to-play, and match results.
-- The menu floats over a slow cinematic orbit of the live battlefield.
-- Owns the difficulty flow: picking one tells the server to start a fresh
-- match at that difficulty, then drops the player into first person.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Audio = require(script.Parent.Audio)
local GameUI = require(script.Parent.GameUI)

local MainMenu = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.GothamBold
local FONT_BLACK = Enum.Font.GothamBlack
local GOLD = Color3.fromRGB(240, 200, 80)
local PANEL = Color3.fromRGB(18, 18, 24)

local menuOpen = false
local orbitConn: RBXScriptConnection? = nil

-- match stats for the results screen
local matchStartAt = os.clock()
local lastAgeName = "Stone Age"
local lastDifficulty = "Normal"
local lastMode = "PvE"
local currentLevel = 1

-- Returns "reward name (Lv N)" for the next ladder reward above `level`, or nil at the top.
local function nextUnlockText(level: number): string?
	local bestLevel: number? = nil
	for lvl in ProgressionConfig.Ladder do
		if lvl > level and (bestLevel == nil or lvl < bestLevel) then
			bestLevel = lvl
		end
	end
	if bestLevel then
		local reward = ProgressionConfig.Ladder[bestLevel]
		return `{reward.name}  (Lv {bestLevel})`
	end
	return nil
end

--------------------------------------------------------------------------------
-- widget helpers
--------------------------------------------------------------------------------

local function corner(inst: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, pos: UDim2, size: UDim2, color: Color3, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = pos
	btn.Size = size
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.Font = FONT
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Parent = parent
	btn.ZIndex = parent.ZIndex + 1
	corner(btn, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.22, 0)
	pad.PaddingBottom = UDim.new(0.22, 0)
	pad.Parent = btn

	local baseSize = size
	btn.MouseEnter:Connect(function()
		Audio.play("hover")
		TweenService:Create(btn, TweenInfo.new(0.12), {
			Size = UDim2.new(baseSize.X.Scale * 1.05, 0, baseSize.Y.Scale * 1.05, 0),
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15),
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { Size = baseSize, BackgroundColor3 = color }):Play()
	end)
	btn.Activated:Connect(function()
		local ok, err = pcall(function()
			Audio.play("click")
			onClick()
		end)
		if not ok then
			warn(`[MainMenu] button error: {err}`)
		end
	end)
	return btn
end

-- Horizontal slider (0..1). Returns a setter for the initial value.
local function slider(parent: Instance, titleText: string, pos: UDim2, initial: number, onChange: (number) -> ()): (number) -> ()
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = pos
	row.Size = UDim2.new(0.8, 0, 0.13, 0)
	row.BackgroundTransparency = 1
	row.ZIndex = parent.ZIndex + 1
	row.Parent = parent

	label(row, {
		Size = UDim2.new(0.35, 0, 0.6, 0),
		Position = UDim2.new(0, 0, 0.2, 0),
		Text = titleText,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = row.ZIndex,
	})

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0.4, 0, 0.5, 0)
	track.Size = UDim2.new(0.55, 0, 0.18, 0)
	track.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	track.BorderSizePixel = 0
	track.ZIndex = row.ZIndex
	track.Parent = row
	corner(track, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(initial, 1)
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.ZIndex = track.ZIndex + 1
	fill.Parent = track
	corner(fill, 6)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(initial, 0, 0.5, 0)
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.ZIndex = track.ZIndex + 2
	knob.Parent = track
	corner(knob, 9)

	local function setValue(v: number)
		v = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.new(v, 0, 0.5, 0)
		onChange(v)
	end

	local dragging = false
	local function updateFromX(x: number)
		local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		setValue(rel)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	return setValue
end

local function panel(parent: Instance, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = size
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = 10
	f.Parent = parent
	corner(f, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Transparency = 0.65
	stroke.Thickness = 1.5
	stroke.Parent = f
	return f
end

--------------------------------------------------------------------------------
-- cinematic menu camera
--------------------------------------------------------------------------------

local function startOrbit()
	if orbitConn then
		return
	end
	orbitConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable
		local t = os.clock() * 0.045
		local radius = 135
		local pos = Vector3.new(math.cos(t) * radius, 48 + math.sin(t * 0.7) * 6, math.sin(t) * radius)
		cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, 10, 0))
	end)
end

local function stopOrbit()
	if orbitConn then
		orbitConn:Disconnect()
		orbitConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

--------------------------------------------------------------------------------
-- build
--------------------------------------------------------------------------------

function MainMenu.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = playerGui

	-- root menu container (sinks clicks so the hero weapon can't fire through it)
	local menuRoot = Instance.new("Frame")
	menuRoot.Size = UDim2.fromScale(1, 1)
	menuRoot.BackgroundColor3 = Color3.new(0, 0, 0)
	menuRoot.BackgroundTransparency = 0.35
	menuRoot.BorderSizePixel = 0
	menuRoot.Active = true
	menuRoot.ZIndex = 1
	menuRoot.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	grad.Parent = menuRoot

	-- title block
	local title = label(menuRoot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.1, 0),
		Size = UDim2.new(0.62, 0, 0.13, 0),
		Text = "AGE OF WAR",
		Font = FONT_BLACK,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Transparency = 0.25
	stroke.Parent = title
	label(menuRoot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.235, 0),
		Size = UDim2.new(0.34, 0, 0.038, 0),
		Text = "F I R S T   P E R S O N",
		TextColor3 = GOLD,
	})

	label(menuRoot, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.985, 0),
		Size = UDim2.new(0.5, 0, 0.022, 0),
		Text = "Fight through five ages. Command your army. Destroy the enemy base.",
		TextColor3 = Color3.fromRGB(190, 190, 200),
	})

	-- profile block
	local profileBlock = Instance.new("Frame")
	profileBlock.AnchorPoint = Vector2.new(1, 0)
	profileBlock.Position = UDim2.new(0.98, 0, 0.03, 0)
	profileBlock.Size = UDim2.new(0.2, 0, 0.08, 0)
	profileBlock.BackgroundTransparency = 1
	profileBlock.Parent = menuRoot
	
	local levelLabel = label(profileBlock, {
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0.4, 0),
		Text = "LEVEL 1",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
	})
	
	local xpTrack = Instance.new("Frame")
	xpTrack.Position = UDim2.new(0.1, 0, 0.5, 0)
	xpTrack.Size = UDim2.new(0.9, 0, 0.15, 0)
	xpTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	xpTrack.BorderSizePixel = 0
	xpTrack.Parent = profileBlock
	corner(xpTrack, 4)
	
	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpTrack
	corner(xpFill, 4)

	-- next-unlock preview under the XP bar (the roadmap that pulls players back)
	local nextUnlockLabel = label(profileBlock, {
		Position = UDim2.new(0, 0, 0.72, 0),
		Size = UDim2.new(1, 0, 0.28, 0),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(190, 190, 200),
	})

	-- panels
	local modePanel = panel(gui, UDim2.new(0.46, 0, 0.5, 0))
	local diffPanel = panel(gui, UDim2.new(0.46, 0, 0.58, 0))
	local settingsPanel = panel(gui, UDim2.new(0.46, 0, 0.62, 0))
	local helpPanel = panel(gui, UDim2.new(0.5, 0, 0.66, 0))
	local boardPanel = panel(gui, UDim2.new(0.38, 0, 0.62, 0))

	local function closePanels()
		modePanel.Visible = false
		diffPanel.Visible = false
		settingsPanel.Visible = false
		helpPanel.Visible = false
		boardPanel.Visible = false
	end

	-- main buttons (direct children of menuRoot so input isn't blocked by an intermediate holder)
	button(menuRoot, "PLAY", UDim2.fromScale(0.5, 0.42), UDim2.new(0.22, 0, 0.085, 0), Color3.fromRGB(50, 130, 70), function()
		closePanels()
		modePanel.Visible = true
	end)
	button(menuRoot, "SETTINGS", UDim2.fromScale(0.5, 0.55), UDim2.new(0.22, 0, 0.07, 0), Color3.fromRGB(55, 65, 90), function()
		closePanels()
		settingsPanel.Visible = true
	end)
	button(menuRoot, "HOW TO PLAY", UDim2.fromScale(0.5, 0.665), UDim2.new(0.22, 0, 0.07, 0), Color3.fromRGB(55, 65, 90), function()
		closePanels()
		helpPanel.Visible = true
	end)

	-- left rail: secondary destinations (leaderboard, shop placeholder)
	button(menuRoot, "LEADERBOARD", UDim2.fromScale(0.09, 0.42), UDim2.new(0.13, 0, 0.055, 0), Color3.fromRGB(55, 65, 90), function()
		closePanels()
		boardPanel.Visible = true
		Remotes.RequestLeaderboard:FireServer()
	end)
	local shopBtn: TextButton? = nil
	shopBtn = button(menuRoot, "SHOP", UDim2.fromScale(0.09, 0.51), UDim2.new(0.13, 0, 0.055, 0), Color3.fromRGB(60, 60, 70), function()
		if shopBtn then
			shopBtn.Text = "COMING SOON"
			task.delay(1.2, function()
				if shopBtn then shopBtn.Text = "SHOP" end
			end)
		end
	end)

	--------------------------------------------------------------------------------
	-- mode selection panel
	--------------------------------------------------------------------------------
	label(modePanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.06, 0),
		Size = UDim2.new(0.8, 0, 0.14, 0),
		Text = "SELECT MODE",
		ZIndex = 11,
	})

	button(modePanel, "PvE vs AI", UDim2.fromScale(0.5, 0.32), UDim2.new(0.6, 0, 0.13, 0), Color3.fromRGB(50, 130, 70), function()
		closePanels()
		diffPanel.Visible = true
	end).ZIndex = 11
	label(modePanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.39, 0),
		Size = UDim2.new(0.7, 0, 0.035, 0),
		Text = "Fight the AI across five ages.",
		TextColor3 = Color3.fromRGB(170, 170, 180),
		ZIndex = 11,
	})

	button(modePanel, "PvP 1v1", UDim2.fromScale(0.5, 0.62), UDim2.new(0.6, 0, 0.13, 0), Color3.fromRGB(60, 100, 160), function()
		Remotes.SelectMode:FireServer("pvp", "Normal")
		closePanels()
		-- menu stays open so the queue status overlay is visible
	end).ZIndex = 11
	label(modePanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.69, 0),
		Size = UDim2.new(0.7, 0, 0.035, 0),
		Text = "Ranked matchmaking against another player.",
		TextColor3 = Color3.fromRGB(170, 170, 180),
		ZIndex = 11,
	})

	button(modePanel, "BACK", UDim2.fromScale(0.5, 0.92), UDim2.new(0.24, 0, 0.08, 0), Color3.fromRGB(60, 60, 70), function()
		modePanel.Visible = false
	end).ZIndex = 11

	--------------------------------------------------------------------------------
	-- difficulty panel (PvE)
	--------------------------------------------------------------------------------
	label(diffPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.06, 0),
		Size = UDim2.new(0.8, 0, 0.14, 0),
		Text = "PvE DIFFICULTY",
		ZIndex = 11,
	})

	local function startPve(diffId: string)
		Remotes.SelectMode:FireServer("pve", diffId)
		closePanels()
		menuRoot.Visible = false
		menuOpen = false
		stopOrbit()
		GameUI.setHudVisible(true)
	end

	local diffs: { { string | Color3 } } = {
		{ "NORMAL", "Standard AI pacing and stats.", Color3.fromRGB(60, 140, 70), "Normal" },
		{ "HARDER", "Stronger AI with reactive counter-spawns.", Color3.fromRGB(190, 130, 50), "Harder" },
		{ "IMPOSSIBLE", "Max difficulty. The AI plays to win.", Color3.fromRGB(170, 60, 60), "Impossible" },
	}
	for i, d in diffs do
		local y = 0.22 + i * 0.19
		button(diffPanel, d[1] :: string, UDim2.fromScale(0.5, y), UDim2.new(0.55, 0, 0.11, 0), d[3] :: Color3, function()
			startPve(d[4] :: string)
		end).ZIndex = 11
		label(diffPanel, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, y + 0.06, 0),
			Size = UDim2.new(0.7, 0, 0.03, 0),
			Text = d[2] :: string,
			TextColor3 = Color3.fromRGB(170, 170, 180),
			ZIndex = 11,
		})
	end
	button(diffPanel, "BACK", UDim2.fromScale(0.5, 0.92), UDim2.new(0.24, 0, 0.08, 0), Color3.fromRGB(60, 60, 70), function()
		closePanels()
		modePanel.Visible = true
	end).ZIndex = 11

	--------------------------------------------------------------------------------
	-- first-battle signpost (new players only): straight into a guided PvE match
	--------------------------------------------------------------------------------
	local firstBattleBtn = button(menuRoot, "FIRST BATTLE  —  EARN 300 XP", UDim2.fromScale(0.5, 0.325), UDim2.new(0.26, 0, 0.06, 0), Color3.fromRGB(170, 130, 30), function()
		startPve("Normal")
	end)
	firstBattleBtn.Visible = false
	local fbStroke = Instance.new("UIStroke")
	fbStroke.Color = GOLD
	fbStroke.Thickness = 2
	fbStroke.Parent = firstBattleBtn
	task.spawn(function()
		-- gentle pulse to draw the eye without blocking anything
		while firstBattleBtn.Parent do
			if firstBattleBtn.Visible then
				TweenService:Create(fbStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.7 }):Play()
				task.wait(0.8)
				TweenService:Create(fbStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0 }):Play()
			end
			task.wait(0.85)
		end
	end)

	--------------------------------------------------------------------------------
	-- leaderboard panel
	--------------------------------------------------------------------------------
	label(boardPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.05, 0),
		Size = UDim2.new(0.8, 0, 0.1, 0),
		Text = "TOP RATINGS",
		ZIndex = 11,
	})
	local boardRows = label(boardPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.18, 0),
		Size = UDim2.new(0.84, 0, 0.66, 0),
		Text = "Loading...",
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		ZIndex = 11,
	})
	button(boardPanel, "BACK", UDim2.fromScale(0.5, 0.92), UDim2.new(0.24, 0, 0.07, 0), Color3.fromRGB(60, 60, 70), function()
		boardPanel.Visible = false
	end).ZIndex = 11

	--------------------------------------------------------------------------------
	-- settings panel
	--------------------------------------------------------------------------------
	label(settingsPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.05, 0),
		Size = UDim2.new(0.8, 0, 0.11, 0),
		Text = "SETTINGS",
		ZIndex = 11,
	})
	slider(settingsPanel, "Mouse Sensitivity", UDim2.new(0.5, 0, 0.22, 0), 0.35, function(v)
		-- 0..1 -> 0.2..2.5
		UserInputService.MouseDeltaSensitivity = 0.2 + v * 2.3
	end)
	slider(settingsPanel, "SFX Volume", UDim2.new(0.5, 0, 0.4, 0), 1, function(v)
		Audio.setGroupVolume("SFX", v)
	end)
	slider(settingsPanel, "UI Volume", UDim2.new(0.5, 0, 0.58, 0), 1, function(v)
		Audio.setGroupVolume("UI", v)
	end)
	slider(settingsPanel, "Music Volume", UDim2.new(0.5, 0, 0.76, 0), 0.5, function(v)
		Audio.setGroupVolume("Music", v)
	end)
	button(settingsPanel, "BACK", UDim2.fromScale(0.5, 0.93), UDim2.new(0.24, 0, 0.07, 0), Color3.fromRGB(60, 60, 70), function()
		settingsPanel.Visible = false
	end).ZIndex = 11

	--------------------------------------------------------------------------------
	-- how-to-play panel
	--------------------------------------------------------------------------------
	label(helpPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.05, 0),
		Size = UDim2.new(0.8, 0, 0.1, 0),
		Text = "HOW TO PLAY",
		ZIndex = 11,
	})
	local helpLines = {
		"You are the HERO — fight in first person AND command your army.",
		"",
		"WASD — move    ·    Mouse — aim / attack",
		"1 / 2 / 3 — spawn Melee / Ranged / Heavy unit",
		"4 — build turret    ·    5 — special ability    ·    Q — evolve age",
		"",
		"There are 5 stages: Stone, Medieval, Renaissance, Modern, and Future.",
		"Kills earn GOLD for troops and XP for evolution.",
		"Evolving unlocks units, hero weapons, turrets, specials, and a tougher base.",
		"YOUR GOAL: destroy the RED enemy base while protecting your BLUE base.",
	}
	label(helpPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.new(0.86, 0, 0.62, 0),
		Text = table.concat(helpLines, "\n"),
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		ZIndex = 11,
	})
	button(helpPanel, "BACK", UDim2.fromScale(0.5, 0.92), UDim2.new(0.24, 0, 0.07, 0), Color3.fromRGB(60, 60, 70), function()
		helpPanel.Visible = false
	end).ZIndex = 11

	--------------------------------------------------------------------------------
	-- results screen
	--------------------------------------------------------------------------------
	local results = Instance.new("Frame")
	results.Size = UDim2.fromScale(1, 1)
	results.BackgroundColor3 = Color3.new(0, 0, 0)
	results.BackgroundTransparency = 0.4
	results.BorderSizePixel = 0
	results.Active = true
	results.Visible = false
	results.ZIndex = 8
	results.Parent = gui

	local resultTitle = label(results, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.new(0.6, 0, 0.14, 0),
		Text = "VICTORY",
		Font = FONT_BLACK,
		ZIndex = 9,
	})
	local resultStats = label(results, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		Size = UDim2.new(0.5, 0, 0.2, 0),
		Text = "",
		TextScaled = false,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		ZIndex = 9,
	})
	local resultCountdown = label(results, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.66, 0),
		Size = UDim2.new(0.4, 0, 0.035, 0),
		Text = "",
		TextColor3 = Color3.fromRGB(170, 170, 180),
		ZIndex = 9,
	})
	button(results, "RETURN TO LOBBY", UDim2.fromScale(0.5, 0.76), UDim2.new(0.22, 0, 0.065, 0), Color3.fromRGB(55, 75, 105), function()
		Remotes.LeaveMatch:FireServer()
	end).ZIndex = 9

	local function showResults(won: boolean, restartIn: number, ratingDelta: number?, xpData: any)
		local dur = os.clock() - matchStartAt
		local mins = math.floor(dur / 60)
		local secs = math.floor(dur % 60)
		resultTitle.Text = won and "VICTORY" or "DEFEAT"
		resultTitle.TextColor3 = won and Color3.fromRGB(120, 230, 120) or Color3.fromRGB(230, 90, 80)
		local ratingText = ratingDelta and `\nRating:  {ratingDelta >= 0 and "+" or ""}{ratingDelta}` or ""
		local modeText = lastMode == "PvP" and "1v1 PvP" or `PvE • {lastDifficulty:upper()}`
		
		local xpText = ""
		if xpData then
			xpText = `\nXP Earned:  +{xpData.newXp - xpData.oldXp}`
			if xpData.levelups > 0 then
				xpText ..= `\nLevel Up! (+{xpData.levelups})`
			end
			if xpData.unlocks and #xpData.unlocks > 0 then
				xpText ..= `\nUnlocked: {table.concat(xpData.unlocks, ", ")}`
			end
			local unlock = nextUnlockText(currentLevel)
			if unlock then
				xpText ..= `\nNext unlock: {unlock}`
			end
		end
		
		resultStats.Text = `Mode:  {modeText}\nAge reached:  {lastAgeName}\nBattle time:  {mins}m {secs}s{ratingText}{xpText}`
		results.Visible = true
		task.spawn(function()
			for t = restartIn, 1, -1 do
				if not results.Visible then
					return
				end
				resultCountdown.Text = `Next battle in {t}...`
				task.wait(1)
			end
		end)
	end

	--------------------------------------------------------------------------------
	-- wiring
	--------------------------------------------------------------------------------
	
	Remotes.ProfileSync.OnClientEvent:Connect(function(profile)
		if typeof(profile) == "table" and typeof(profile.level) == "number" and typeof(profile.xp) == "number" then
			currentLevel = profile.level
			levelLabel.Text = `LEVEL {profile.level}`
			local nextXp = ProgressionConfig.xpForLevel(profile.level + 1)
			local prevXp = ProgressionConfig.xpForLevel(profile.level)
			local progress = 0
			if nextXp > prevXp then
				progress = math.clamp((profile.xp - prevXp) / (nextXp - prevXp), 0, 1)
			end
			if profile.level >= ProgressionConfig.MAX_LEVEL then progress = 1 end
			xpFill.Size = UDim2.fromScale(progress, 1)
			local unlock = nextUnlockText(profile.level)
			nextUnlockLabel.Text = unlock and `Next: {unlock}` or "All rewards unlocked"
			firstBattleBtn.Visible = profile.tutorialDone ~= true
		end
	end)

	Remotes.LeaderboardData.OnClientEvent:Connect(function(rows)
		if typeof(rows) ~= "table" then return end
		if #rows == 0 then
			boardRows.Text = "No ratings yet. Win a PvP match to get on the board!"
			return
		end
		local lines = {}
		for i, row in rows do
			if typeof(row) == "table" and typeof(row.name) == "string" and typeof(row.rating) == "number" then
				table.insert(lines, `{i}.  {row.name}  —  {row.rating}`)
			end
		end
		boardRows.Text = table.concat(lines, "\n")
	end)
	-- The join-time sync can fire before this listener exists; ask for it again.
	Remotes.RequestProfile:FireServer()

	Remotes.StateUpdate.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" then
			if state.status == "Active" and menuRoot.Visible then
				closePanels()
				menuRoot.Visible = false
				menuOpen = false
				stopOrbit()
				GameUI.setHudVisible(true)
			end
			if typeof(state.ageName) == "string" then
				lastAgeName = state.ageName
			end
			if typeof(state.difficulty) == "string" then
				lastDifficulty = state.difficulty
			end
			if typeof(state.mode) == "string" then
				lastMode = state.mode
			end
		end
	end)

	Remotes.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		if event == "Victory" or event == "Defeat" then
			showResults(event == "Victory", (data and data.restartIn) or 10, data and data.ratingDelta, data and data.xpData)
		elseif event == "MatchStart" then
			matchStartAt = os.clock()
			results.Visible = false
			closePanels()
			menuRoot.Visible = false
			menuOpen = false
			stopOrbit()
			GameUI.setHudVisible(true)
		elseif event == "ReturnToMenu" then
			results.Visible = false
			closePanels()
			menuRoot.Visible = true
			menuOpen = true
			startOrbit()
			GameUI.setHudVisible(false)
		end
	end)

	-- open the menu on join
	menuOpen = true
	GameUI.setHudVisible(false)
	startOrbit()
end

return MainMenu
