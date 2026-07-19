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
local ContextActionService = game:GetService("ContextActionService")

local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Audio = require(script.Parent.Audio)
local GameUI = require(script.Parent.GameUI)
local Storefront = require(script.Parent.Storefront)
local Settings = require(script.Parent.Settings)
local UISelection = require(script.Parent.UISelection)

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
local currentCoins = 0
local currentPveProgress = { Normal = 0, Hard = 0, Impossible = 0 }
local pveUpgradesState = { unitHp = 0, unitDamage = 0, startingGold = 0 }
local pvePerksState: {string} = {}
local lastPveLevelPlayed = 0 -- the PvE level of the match in progress (from StateUpdate)
local selectedPveMode = "Normal"
local sliderId = 0

-- Shows the guaranteed next-level currency plus the next milestone collectible.
local function nextUnlockText(level: number): string?
	if level >= ProgressionConfig.MAX_LEVEL then return nil end
	local bestLevel: number? = nil
	for lvl in ProgressionConfig.Ladder do
		if lvl > level and (bestLevel == nil or lvl < bestLevel) then
			bestLevel = lvl
		end
	end
	if bestLevel then
		local reward = ProgressionConfig.Ladder[bestLevel]
		return `+{ProgressionConfig.WAR_BONDS_PER_LEVEL} Bonds at Lv {level + 1}  •  {reward.name} at Lv {bestLevel}`
	end
	return `+{ProgressionConfig.WAR_BONDS_PER_LEVEL} War Bonds at Lv {level + 1}`
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

	local track = Instance.new("TextButton")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0.4, 0, 0.5, 0)
	track.Size = UDim2.new(0.55, 0, 0.18, 0)
	track.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
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
	local touchInput: InputObject? = nil
	local function updateFromX(x: number)
		local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		setValue(rel)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			if input.UserInputType == Enum.UserInputType.Touch then touchInput = input end
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == touchInput) then
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input == touchInput then
			dragging = false
			touchInput = nil
		end
	end)

	sliderId += 1
	local actionName = `AdjustSettingsSlider{sliderId}`
	track.SelectionGained:Connect(function()
		ContextActionService:BindActionAtPriority(actionName, function(_, inputState, input)
			if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
			local direction = if input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1
			setValue(knob.Position.X.Scale + direction * 0.05)
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1,
			Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	end)
	track.SelectionLost:Connect(function()
		ContextActionService:UnbindAction(actionName)
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
	f.Active = true
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
	local lobbyHud: Frame? = nil
	local serverType = workspace:GetAttribute("ServerType")
	if not serverType then
		workspace:GetAttributeChangedSignal("ServerType"):Wait()
		serverType = workspace:GetAttribute("ServerType")
	end
	local isLobbyServer = (serverType == "lobby")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ClipToDeviceSafeArea = true
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
	local closePanels: () -> ()
	local openStorefront, closeStorefront = Storefront.attach(menuRoot, function()
		if closePanels then closePanels() end
	end)
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
	local levelsPanel = panel(gui, UDim2.new(0.55, 0, 0.65, 0))
	local pveUpgradesPanel = panel(gui, UDim2.new(0.5, 0, 0.65, 0))
	local settingsPanel = panel(gui, UDim2.new(0.5, 0, 0.72, 0))
	local helpPanel = panel(gui, UDim2.new(0.5, 0, 0.66, 0))
	local boardPanel = panel(gui, UDim2.new(0.38, 0, 0.62, 0))

	closePanels = function()
		modePanel.Visible = false
		levelsPanel.Visible = false
		pveUpgradesPanel.Visible = false
		settingsPanel.Visible = false
		helpPanel.Visible = false
		boardPanel.Visible = false
		if closeStorefront then closeStorefront() end
	end

	-- main buttons (direct children of menuRoot so input isn't blocked by an intermediate holder)
	local playButton = button(menuRoot, "PLAY", UDim2.fromScale(0.5, 0.42), UDim2.new(0.22, 0, 0.085, 0), Color3.fromRGB(50, 130, 70), function()
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

	local currentBoardType = "pvp"

	-- left rail: secondary destinations
	button(menuRoot, "LEADERBOARD", UDim2.fromScale(0.09, 0.42), UDim2.new(0.13, 0, 0.055, 0), Color3.fromRGB(55, 65, 90), function()
		closePanels()
		boardPanel.Visible = true
		Remotes.RequestLeaderboard:FireServer(currentBoardType == "pve" and "pve" or nil)
	end)
	
	-- Refresh upgrades panel UI when opened
	local refreshUpgradesUI: () -> ()
	button(menuRoot, "UPGRADES", UDim2.fromScale(0.09, 0.51), UDim2.new(0.13, 0, 0.055, 0), Color3.fromRGB(150, 110, 30), function()
		closePanels()
		refreshUpgradesUI()
		pveUpgradesPanel.Visible = true
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

	local refreshLevelsUI: () -> ()
	local levelsPage = 1 -- 20 levels per page; the campaign is endless
	button(modePanel, "PvE", UDim2.fromScale(0.5, 0.4), UDim2.new(0.6, 0, 0.13, 0), Color3.fromRGB(50, 130, 70), function()
		closePanels()
		levelsPage = math.floor((currentPveProgress[selectedPveMode] or 0) / 20) + 1
		refreshLevelsUI()
		levelsPanel.Visible = true
	end).ZIndex = 11
	label(modePanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.47, 0),
		Size = UDim2.new(0.7, 0, 0.035, 0),
		Text = "Endless stages across three difficulties. Boss every 5 levels.",
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
	-- levels panel
	--------------------------------------------------------------------------------
	label(levelsPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.02, 0),
		Size = UDim2.new(0.8, 0, 0.08, 0),
		Text = "PvE LEVELS",
		ZIndex = 11,
	})
	
	local diffTabsContainer = Instance.new("Frame")
	diffTabsContainer.Position = UDim2.new(0.05, 0, 0.12, 0)
	diffTabsContainer.Size = UDim2.new(0.9, 0, 0.08, 0)
	diffTabsContainer.BackgroundTransparency = 1
	diffTabsContainer.ZIndex = 11
	diffTabsContainer.Parent = levelsPanel
	
	local updateDiffTabs: () -> ()
	
	local diffConfigs = {
		{ id = "Normal", name = "NORMAL", color = Color3.fromRGB(60, 140, 70) },
		{ id = "Hard", name = "HARD", color = Color3.fromRGB(190, 130, 50) },
		{ id = "Impossible", name = "IMPOSSIBLE", color = Color3.fromRGB(170, 60, 60) },
	}
	
	local diffButtons: { [string]: { btn: TextButton, stroke: UIStroke, color: Color3 } } = {}
	for i, d in diffConfigs do
		local w = 0.32
		local x = (i - 1) * 0.34
		local btn = button(diffTabsContainer, d.name, UDim2.fromScale(x + w/2, 0.5), UDim2.fromScale(w, 1), d.color, function()
			selectedPveMode = d.id
			levelsPage = math.floor((currentPveProgress[selectedPveMode] or 0) / 20) + 1
			updateDiffTabs()
			refreshLevelsUI()
		end)
		btn.ZIndex = 12
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = 2
		stroke.Transparency = 1
		stroke.Parent = btn
		diffButtons[d.id] = { btn = btn, stroke = stroke, color = d.color }
	end
	
	updateDiffTabs = function()
		for id, data in diffButtons do
			if id == selectedPveMode then
				data.btn.BackgroundColor3 = data.color
				data.stroke.Transparency = 0
			else
				data.btn.BackgroundColor3 = data.color:Lerp(Color3.new(0,0,0), 0.6)
				data.stroke.Transparency = 1
			end
		end
	end
	
	local levelsScroll = Instance.new("ScrollingFrame")
	levelsScroll.Position = UDim2.new(0.05, 0, 0.22, 0)
	levelsScroll.Size = UDim2.new(0.9, 0, 0.48, 0)
	levelsScroll.BackgroundTransparency = 1
	levelsScroll.ScrollBarThickness = 6
	levelsScroll.ZIndex = 11
	levelsScroll.Parent = levelsPanel

	local levelsLayout = Instance.new("UIGridLayout")
	levelsLayout.CellSize = UDim2.new(0, 100, 0, 100)
	levelsLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	levelsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	levelsLayout.Parent = levelsScroll

	local LEVELS_PER_PAGE = 20

	local function startLevel(lvl: number)
		Remotes.StartPveLevel:FireServer(selectedPveMode, lvl)
		closePanels()
		menuRoot.Visible = false
		menuOpen = false
		stopOrbit()
		GameUI.setHudVisible(true)
	end

	-- pagination row: < [Levels X - Y] >
	local prevPageBtn = button(levelsPanel, "<", UDim2.fromScale(0.28, 0.745), UDim2.new(0.08, 0, 0.06, 0), Color3.fromRGB(60, 60, 70), function()
		if levelsPage > 1 then
			levelsPage -= 1
			refreshLevelsUI()
		end
	end)
	prevPageBtn.ZIndex = 11
	local pageLabel = label(levelsPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.745, 0),
		Size = UDim2.new(0.32, 0, 0.06, 0),
		Text = "Levels 1 - 20",
		ZIndex = 11,
	})
	local nextPageBtn = button(levelsPanel, ">", UDim2.fromScale(0.72, 0.745), UDim2.new(0.08, 0, 0.06, 0), Color3.fromRGB(60, 60, 70), function()
		levelsPage += 1
		refreshLevelsUI()
	end)
	nextPageBtn.ZIndex = 11

	local playNextBtn = button(levelsPanel, "PLAY NEXT — LEVEL 1", UDim2.fromScale(0.5, 0.845), UDim2.new(0.5, 0, 0.07, 0), Color3.fromRGB(150, 110, 40), function()
		startLevel((currentPveProgress[selectedPveMode] or 0) + 1)
	end)
	playNextBtn.ZIndex = 11

	refreshLevelsUI = function()
		updateDiffTabs()
		local prog = currentPveProgress[selectedPveMode] or 0
		for _, child in levelsScroll:GetChildren() do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local firstLevel = (levelsPage - 1) * LEVELS_PER_PAGE + 1
		local lastLevel = levelsPage * LEVELS_PER_PAGE
		pageLabel.Text = `Levels {firstLevel} - {lastLevel}`
		prevPageBtn.Visible = levelsPage > 1
		nextPageBtn.Visible = true
		playNextBtn.Text = `PLAY NEXT — LEVEL {prog + 1}`
		playNextBtn.BackgroundColor3 = Color3.fromRGB(150, 110, 40)
		for lvl = firstLevel, lastLevel do
			local isBoss = PvELevels.isBossLevel(lvl)
			local isLocked = lvl > prog + 1
			local isNext = lvl == prog + 1
			local color = isLocked and Color3.fromRGB(40, 40, 45) 
				or (isNext and Color3.fromRGB(150, 110, 40) or (isBoss and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(60, 100, 140)))
				
			local btn = button(levelsScroll, "", UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), color, function()
				if not isLocked then
					startLevel(lvl)
				end
			end)
			btn.LayoutOrder = lvl
			btn.ZIndex = 12
			
			label(btn, {
				Position = UDim2.new(0, 0, 0.05, 0), Size = UDim2.new(1, 0, 0.25, 0),
				Text = `Lv {lvl}`, TextColor3 = isLocked and Color3.fromRGB(100,100,100) or Color3.new(1,1,1), ZIndex = 13
			})
			if isBoss then
				label(btn, {
					Position = UDim2.new(0, 0, 0.35, 0), Size = UDim2.new(1, 0, 0.2, 0),
					Text = "BOSS", TextColor3 = isLocked and Color3.fromRGB(120,60,60) or Color3.new(1,0.8,0.8), ZIndex = 13
				})
			end
			if isLocked then
				label(btn, {
					Position = UDim2.new(0, 0, 0.65, 0), Size = UDim2.new(1, 0, 0.2, 0),
					Text = "LOCKED", TextColor3 = Color3.fromRGB(150,50,50), ZIndex = 13
				})
			elseif isNext then
				label(btn, {
					Position = UDim2.new(0, 0, 0.65, 0), Size = UDim2.new(1, 0, 0.25, 0),
					Text = `+{PvELevels.coinsForClear(selectedPveMode, lvl, false)}c`, TextColor3 = Color3.fromRGB(240, 200, 80), ZIndex = 13
				})
			end
		end
		levelsScroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil((lastLevel - firstLevel + 1) / 4) * 110)
	end
	
	button(levelsPanel, "BACK", UDim2.fromScale(0.5, 0.93), UDim2.new(0.24, 0, 0.07, 0), Color3.fromRGB(60, 60, 70), function()
		closePanels()
		modePanel.Visible = true
	end).ZIndex = 11

	--------------------------------------------------------------------------------
	-- pve upgrades panel
	--------------------------------------------------------------------------------
	label(pveUpgradesPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.04, 0),
		Size = UDim2.new(0.8, 0, 0.08, 0),
		Text = "PvE UPGRADES & PERKS",
		ZIndex = 11,
	})
	
	local coinsLabel = label(pveUpgradesPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 0),
		Size = UDim2.new(0.8, 0, 0.06, 0),
		Text = "Coins: 0",
		TextColor3 = Color3.fromRGB(255, 220, 80),
		ZIndex = 11,
	})
	
	local upgradesScroll = Instance.new("ScrollingFrame")
	upgradesScroll.Position = UDim2.new(0.05, 0, 0.2, 0)
	upgradesScroll.Size = UDim2.new(0.9, 0, 0.68, 0)
	upgradesScroll.BackgroundTransparency = 1
	upgradesScroll.ScrollBarThickness = 6
	upgradesScroll.ZIndex = 11
	upgradesScroll.Parent = pveUpgradesPanel
	
	local upgList = Instance.new("UIListLayout")
	upgList.SortOrder = Enum.SortOrder.LayoutOrder
	upgList.Padding = UDim.new(0, 8)
	upgList.Parent = upgradesScroll
	
	refreshUpgradesUI = function()
		coinsLabel.Text = `Coins: {currentCoins}`
		for _, child in upgradesScroll:GetChildren() do
			if child:IsA("Frame") then child:Destroy() end
		end
		
		local layoutOrder = 1
		local function createRow(id: string, name: string, isPerk: boolean)
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 50)
			row.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
			row.BorderSizePixel = 0
			row.ZIndex = 12
			row.LayoutOrder = layoutOrder
			layoutOrder += 1
			row.Parent = upgradesScroll
			corner(row, 6)
			
			local currentTier = pveUpgradesState[id] or 0
			local isOwned = isPerk and table.find(pvePerksState, id) ~= nil
			local isMaxed = not isPerk and currentTier >= PvELevels.UPGRADE_TRACKS[id].maxTier
			
			local titleText = name
			if not isPerk then titleText = `{name} (Tier {currentTier})` end
			
			label(row, {
				Position = UDim2.new(0.05, 0, 0.1, 0), Size = UDim2.new(0.6, 0, 0.8, 0),
				Text = titleText, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13
			})
			
			local cost = isPerk and PvELevels.PERKS[id].cost or PvELevels.upgradeCost(currentTier + 1)
			if isOwned then cost = 0 end
			
			local canBuy = currentCoins >= cost and not isOwned and not isMaxed
			
			local btnText = (isOwned or isMaxed) and "MAXED" or `BUY ({cost}c)`
			local btnColor = (isOwned or isMaxed) and Color3.fromRGB(50, 100, 50)
				or (canBuy and Color3.fromRGB(150, 110, 30) or Color3.fromRGB(80, 40, 40))
				
			button(row, btnText, UDim2.new(0.85, 0, 0.5, 0), UDim2.new(0.25, 0, 0.8, 0), btnColor, function()
				if canBuy then
					Remotes.BuyPveUpgrade:FireServer(id)
				end
			end).ZIndex = 13
		end
		
		for id, track in PvELevels.UPGRADE_TRACKS do
			createRow(id, track.name, false)
		end
		for id, perk in PvELevels.PERKS do
			createRow(id, perk.name, true)
		end
		
		upgradesScroll.CanvasSize = UDim2.new(0, 0, 0, layoutOrder * 58)
	end
	
	button(pveUpgradesPanel, isLobbyServer and "CLOSE" or "BACK", UDim2.fromScale(0.5, 0.93), UDim2.new(0.24, 0, 0.07, 0), Color3.fromRGB(60, 60, 70), function()
		closePanels()
	end).ZIndex = 11

	--------------------------------------------------------------------------------
	-- first-battle signpost (new players only): straight into a guided PvE match
	--------------------------------------------------------------------------------
	local firstBattleBtn = button(menuRoot, "FIRST BATTLE  —  WIN FOR 300 XP", UDim2.fromScale(0.5, 0.325), UDim2.new(0.28, 0, 0.06, 0), Color3.fromRGB(170, 130, 30), function()
		selectedPveMode = "Normal"
		startLevel((currentPveProgress.Normal or 0) + 1)
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
		Position = UDim2.new(0.5, 0, 0.04, 0),
		Size = UDim2.new(0.8, 0, 0.06, 0),
		Text = "LEADERBOARD",
		ZIndex = 11,
	})
	
	local boardRows = label(boardPanel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.22, 0),
		Size = UDim2.new(0.84, 0, 0.62, 0),
		Text = "Loading...",
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		ZIndex = 11,
	})
	
	local pvpTab = button(boardPanel, "PVP RATING", UDim2.new(0.3, 0, 0.14, 0), UDim2.new(0.3, 0, 0.06, 0), Color3.fromRGB(80, 120, 180), function()
		currentBoardType = "pvp"
		boardRows.Text = "Loading..."
		Remotes.RequestLeaderboard:FireServer(nil)
	end)
	pvpTab.ZIndex = 11
	
	local pveTab = button(boardPanel, "PVE LEVELS", UDim2.new(0.7, 0, 0.14, 0), UDim2.new(0.3, 0, 0.06, 0), Color3.fromRGB(150, 90, 40), function()
		currentBoardType = "pve"
		boardRows.Text = "Loading..."
		Remotes.RequestLeaderboard:FireServer("pve")
	end)
	pveTab.ZIndex = 11
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
	local applyingSettings = false
	local setSensitivity = slider(settingsPanel, "Mouse Sensitivity", UDim2.new(0.5, 0, 0.16, 0), Settings.get("mouseSensitivity"), function(v)
		-- 0..1 -> 0.2..2.5
		UserInputService.MouseDeltaSensitivity = 0.2 + v * 2.3
		if not applyingSettings then Settings.set("mouseSensitivity", v) end
	end)
	local setSfx = slider(settingsPanel, "SFX Volume", UDim2.new(0.5, 0, 0.31, 0), Settings.get("sfxVolume"), function(v)
		Audio.setGroupVolume("SFX", v)
		if not applyingSettings then Settings.set("sfxVolume", v) end
	end)
	local setUi = slider(settingsPanel, "UI Volume", UDim2.new(0.5, 0, 0.46, 0), Settings.get("uiVolume"), function(v)
		Audio.setGroupVolume("UI", v)
		if not applyingSettings then Settings.set("uiVolume", v) end
	end)
	local reducedBtn: TextButton
	local numbersBtn: TextButton
	local function refreshComfortButtons()
		reducedBtn.Text = Settings.get("reducedEffects") and "REDUCED EFFECTS: ON" or "REDUCED EFFECTS: OFF"
		reducedBtn.BackgroundColor3 = Settings.get("reducedEffects") and Color3.fromRGB(55, 120, 75) or Color3.fromRGB(70, 70, 82)
		numbersBtn.Text = Settings.get("showDamageNumbers") and "DAMAGE NUMBERS: ON" or "DAMAGE NUMBERS: OFF"
		numbersBtn.BackgroundColor3 = Settings.get("showDamageNumbers") and Color3.fromRGB(55, 120, 75) or Color3.fromRGB(70, 70, 82)
	end
	reducedBtn = button(settingsPanel, "", UDim2.fromScale(0.5, 0.64), UDim2.new(0.55, 0, 0.07, 0), Color3.fromRGB(70, 70, 82), function()
		Settings.set("reducedEffects", not Settings.get("reducedEffects"))
		refreshComfortButtons()
	end)
	reducedBtn.ZIndex = 11
	numbersBtn = button(settingsPanel, "", UDim2.fromScale(0.5, 0.75), UDim2.new(0.55, 0, 0.07, 0), Color3.fromRGB(70, 70, 82), function()
		Settings.set("showDamageNumbers", not Settings.get("showDamageNumbers"))
		refreshComfortButtons()
	end)
	numbersBtn.ZIndex = 11
	refreshComfortButtons()
	button(settingsPanel, isLobbyServer and "CLOSE" or "BACK", UDim2.fromScale(0.5, 0.9), UDim2.new(0.24, 0, 0.075, 0), Color3.fromRGB(60, 60, 70), function()
		settingsPanel.Visible = false
	end).ZIndex = 11

	local inMatch = false
	local matchControls = Instance.new("Frame")
	matchControls.AnchorPoint = Vector2.new(1, 0)
	matchControls.Position = UDim2.fromScale(0.985, 0.13)
	matchControls.Size = UDim2.fromOffset(150, 44)
	matchControls.BackgroundTransparency = 1
	matchControls.Visible = false
	matchControls.ZIndex = 30
	matchControls.Parent = gui
	local matchSettingsButton = button(matchControls,
		UserInputService.TouchEnabled and "SETTINGS" or "SETTINGS [P]",
		UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), Color3.fromRGB(55, 65, 90), function()
			settingsPanel.Visible = not settingsPanel.Visible
		end)
	matchSettingsButton.ZIndex = 31

	local settingsCursorBinding = "MatchSettingsCursorUnlock"
	settingsPanel:GetPropertyChangedSignal("Visible"):Connect(function()
		local openDuringMatch = inMatch and settingsPanel.Visible
		player:SetAttribute("SettingsOpen", openDuringMatch)
		if openDuringMatch then
			RunService:BindToRenderStep(settingsCursorBinding, Enum.RenderPriority.Camera.Value + 1, function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end)
			UISelection.focus(settingsPanel)
		else
			RunService:UnbindFromRenderStep(settingsCursorBinding)
		end
	end)
	ContextActionService:BindActionAtPriority("ToggleMatchSettings", function(_, inputState)
		if not inMatch then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then
			settingsPanel.Visible = not settingsPanel.Visible
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonStart, Enum.KeyCode.P)

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
	local controlsText = if UserInputService.TouchEnabled then "Touch — aim, attack, and tap hotbar cards"
		elseif UserInputService.GamepadEnabled then "R2/L2 — attack/heavy  ·  D-pad/B — recruit/build  ·  L1 — turrets  ·  Y — evolve"
		else "WASD — move  ·  Mouse — aim/attack  ·  Right Mouse — heavy attack"
	local helpLines = {
		"You are the HERO — fight in first person AND command your army.",
		"",
		controlsText,
		"1 / 2 / 3 / 4 — recruit available units",
		"5 — build turret  ·  B — manage turrets  ·  6 — special  ·  Q — evolve  ·  E/G — upgrades/guide",
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
		Position = UDim2.new(0.5, 0, 0.35, 0),
		Size = UDim2.new(0.58, 0, 0.3, 0),
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
	local resultCanNextStage = false
	local resultWaitingRematch = false
	local resultRematchReady = 0
	local resultPrimary: TextButton
	resultPrimary = button(results, "PLAY AGAIN", UDim2.fromScale(0.38, 0.75), UDim2.new(0.2, 0, 0.065, 0), Color3.fromRGB(55, 125, 75), function()
		local action = if lastMode == "PvE" and resultCanNextStage then "next" else "replay"
		Remotes.ResultAction:FireServer(action)
		resultWaitingRematch = lastMode == "PvP"
		if resultWaitingRematch then resultRematchReady = math.max(resultRematchReady, 1) end
		resultPrimary.Active = false
		resultPrimary.Text = lastMode == "PvP" and "REMATCH REQUESTED" or "STARTING..."
		resultPrimary.BackgroundColor3 = Color3.fromRGB(55, 60, 65)
	end)
	resultPrimary.ZIndex = 9
	local resultReturn = button(results, "RETURN TO MENU", UDim2.fromScale(0.62, 0.75), UDim2.new(0.2, 0, 0.065, 0), Color3.fromRGB(55, 75, 105), function()
		Remotes.ResultAction:FireServer("menu")
	end)
	resultReturn.ZIndex = 9
	button(results, "ARMORY / REWARDS", UDim2.fromScale(0.5, 0.845), UDim2.new(0.22, 0, 0.055, 0), Color3.fromRGB(105, 75, 145), function()
		openStorefront()
	end).ZIndex = 9

	local function showResults(won: boolean, decisionIn: number, ratingDelta: number?, xpData: any, coins: number?, firstClear: boolean?, dailyWarBonds: number?, canNextStage: boolean?)
		inMatch = false
		matchControls.Visible = false
		settingsPanel.Visible = false
		if lobbyHud then lobbyHud.Visible = false end
		local dur = os.clock() - matchStartAt
		local mins = math.floor(dur / 60)
		local secs = math.floor(dur % 60)
		resultTitle.Text = won and "VICTORY" or "DEFEAT"
		resultTitle.TextColor3 = won and Color3.fromRGB(120, 230, 120) or Color3.fromRGB(230, 90, 80)
		local ratingText = ratingDelta and `\nRating:  {ratingDelta >= 0 and "+" or ""}{ratingDelta}` or ""
		local modeText = lastMode == "PvP" and "1v1 PvP" or `PvE {lastDifficulty:upper()} Level {lastPveLevelPlayed}`
		
		local xpText = ""
		if xpData then
			xpText = `\nXP Earned:  +{xpData.newXp - xpData.oldXp}`
			if xpData.levelups > 0 then
				xpText ..= `\nLevel Up! (+{xpData.levelups})  •  +{xpData.warBondsEarned or 0} War Bonds`
			end
			if xpData.unlocks and #xpData.unlocks > 0 then
				xpText ..= `\nUnlocked: {table.concat(xpData.unlocks, ", ")}`
			end
			local unlock = nextUnlockText(currentLevel)
			if unlock then
				xpText ..= `\nNext unlock: {unlock}`
			end
		end
		
		local coinsText = coins and `\nCoins Earned: +{coins}` or ""
		if firstClear then coinsText ..= " (First Clear Bonus!)" end
		local bondsText = dailyWarBonds and dailyWarBonds > 0 and `\nDaily Orders: +{dailyWarBonds} War Bonds` or ""
		
		resultStats.Text = `Mode:  {modeText}\nAge reached:  {lastAgeName}\nBattle time:  {mins}m {secs}s{ratingText}{xpText}{coinsText}{bondsText}`
		resultCanNextStage = lastMode == "PvE" and won and canNextStage == true
		resultWaitingRematch = false
		resultRematchReady = 0
		resultPrimary.Text = if lastMode == "PvP" then "REQUEST REMATCH"
			elseif resultCanNextStage then `NEXT STAGE  ({lastPveLevelPlayed + 1})`
			elseif lastMode == "PvE" then "REPLAY STAGE"
			else "PLAY AGAIN"
		resultPrimary.Active = true
		resultPrimary.BackgroundColor3 = Color3.fromRGB(55, 125, 75)
		resultReturn.Text = lastMode == "PvP" and "RETURN TO LOBBY" or "RETURN TO MENU"
		results.Visible = true
		task.spawn(function()
			local destination = lastMode == "PvP" and "lobby" or "menu"
			for t = decisionIn, 1, -1 do
				if not results.Visible then
					return
				end
				resultCountdown.Text = if resultWaitingRematch
					then `Rematch ready: {resultRematchReady}/2 • returning to {destination} in {t}s`
					else `Choose an option • returning to {destination} in {t}s`
				task.wait(1)
			end
			if results.Visible then resultCountdown.Text = `Returning to {destination}...` end
		end)
	end

	--------------------------------------------------------------------------------
	-- wiring
	--------------------------------------------------------------------------------
	
	Remotes.ProfileSync.OnClientEvent:Connect(function(profile)
		if typeof(profile) == "table" and typeof(profile.level) == "number" and typeof(profile.xp) == "number" then
			if typeof(profile.settings) == "table" then
				Settings.apply(profile.settings)
				applyingSettings = true
				setSensitivity(Settings.get("mouseSensitivity"))
				setSfx(Settings.get("sfxVolume"))
				setUi(Settings.get("uiVolume"))
				applyingSettings = false
				refreshComfortButtons()
			end
			currentLevel = profile.level
			currentCoins = profile.coins or 0
			currentPveProgress = profile.pveProgress or { Normal = profile.pveLevel or 0, Hard = 0, Impossible = 0 }
			pveUpgradesState = profile.pveUpgrades or { unitHp = 0, unitDamage = 0, startingGold = 0 }
			pvePerksState = profile.pvePerks or {}
			
			if pveUpgradesPanel.Visible then refreshUpgradesUI() end
			if levelsPanel.Visible then refreshLevelsUI() end

			local equippedTitle = MonetizationConfig.cosmeticById(profile.equippedTitle or "")
			levelLabel.Text = equippedTitle and `LEVEL {profile.level}  •  {string.upper(equippedTitle.name)}` or `LEVEL {profile.level}`
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

	Remotes.LeaderboardData.OnClientEvent:Connect(function(boardType, rows)
		if typeof(rows) ~= "table" then return end
		if boardType ~= currentBoardType then return end
		
		if #rows == 0 then
			if boardType == "pvp" then
				boardRows.Text = "No ratings yet. Win a PvP match to get on the board!"
			else
				boardRows.Text = "No levels cleared yet. Beat PvE Level 1 to get on the board!"
			end
			return
		end
		
		local lines = {}
		for i, row in rows do
			if typeof(row) == "table" and typeof(row.name) == "string" and typeof(row.rating) == "number" then
				if boardType == "pvp" then
					table.insert(lines, `{i}.  {row.name}  —  {row.rating}`)
				else
					table.insert(lines, `{i}.  {row.name}  —  Lv {row.rating}`)
				end
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
			if typeof(state.pveMode) == "string" then
				lastDifficulty = state.pveMode
			elseif typeof(state.difficulty) == "string" then
				lastDifficulty = state.difficulty
			end
			if typeof(state.mode) == "string" then
				lastMode = state.mode
			end
			if typeof(state.pveLevel) == "number" then
				lastPveLevelPlayed = state.pveLevel
			end
		end
	end)

	Remotes.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		if event == "Victory" or event == "Defeat" then
			showResults(event == "Victory", (data and data.decisionIn) or 30, data and data.ratingDelta, data and data.xpData, data and data.coins, data and data.firstClear, data and data.dailyWarBonds, data and data.canNextStage)
		elseif event == "MatchStart" then
			inMatch = true
			matchControls.Visible = true
			resultWaitingRematch = false
			matchStartAt = os.clock()
			results.Visible = false
			closePanels()
			menuRoot.Visible = false
			menuOpen = false
			stopOrbit()
			GameUI.setHudVisible(true)
			if lobbyHud then lobbyHud.Visible = false end
		elseif event == "RematchStatus" and data then
			resultRematchReady = data.ready or 0
			resultCountdown.Text = `Rematch ready: {resultRematchReady}/{data.required or 2} players`
		elseif event == "ReturnError" and data then
			resultCountdown.Text = data.message or "Couldn't return to the lobby. Press Return to retry."
		elseif event == "ReturnToMenu" then
			inMatch = false
			matchControls.Visible = false
			settingsPanel.Visible = false
			results.Visible = false
			closePanels()
			if isLobbyServer then
				menuRoot.Visible = false
				menuOpen = false
				stopOrbit()
				GameUI.setHudVisible(true)
				GameUI.setQueueMode(true)
				if lobbyHud then lobbyHud.Visible = true end
			else
				menuRoot.Visible = true
				menuOpen = true
				startOrbit()
				GameUI.setHudVisible(false)
			end
		end
	end)

	for _, modal in { modePanel, levelsPanel, pveUpgradesPanel, settingsPanel, helpPanel, boardPanel } do
		UISelection.bind(modal, nil, function()
			modal.Visible = false
		end)
	end
	UISelection.bind(results)
	UISelection.bind(menuRoot, playButton)

	if isLobbyServer then
		menuOpen = false
		menuRoot.Visible = false
		stopOrbit()
		GameUI.setHudVisible(true)
		GameUI.setQueueMode(true)

		-- Find the storefront panel (with ZIndex 60) for visibility tracking
		local storefrontPanel = nil
		for _, child in gui:GetChildren() do
			if child:IsA("Frame") and child.ZIndex == 60 then
				storefrontPanel = child
				break
			end
		end

		-- Click-sinking background overlay for panels in the lobby
		local lobbyBackdrop = Instance.new("Frame")
		lobbyBackdrop.Name = "LobbyBackdrop"
		lobbyBackdrop.Size = UDim2.fromScale(1, 1)
		lobbyBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
		lobbyBackdrop.BackgroundTransparency = 0.4
		lobbyBackdrop.BorderSizePixel = 0
		lobbyBackdrop.Active = true
		lobbyBackdrop.Visible = false
		lobbyBackdrop.ZIndex = 8
		lobbyBackdrop.Parent = gui

		local function updateBackdrop()
			local storefrontVisible = if storefrontPanel then storefrontPanel.Visible else false
			lobbyBackdrop.Visible = pveUpgradesPanel.Visible or settingsPanel.Visible or storefrontVisible
		end

		pveUpgradesPanel:GetPropertyChangedSignal("Visible"):Connect(updateBackdrop)
		settingsPanel:GetPropertyChangedSignal("Visible"):Connect(updateBackdrop)
		if storefrontPanel then
			storefrontPanel:GetPropertyChangedSignal("Visible"):Connect(updateBackdrop)
		end

		-- Build slim persistent HUD
		local GuiService = game:GetService("GuiService")
		lobbyHud = Instance.new("Frame")
		lobbyHud.Name = "LobbyHUD"
		lobbyHud.Position = UDim2.new(0, 15, 0, 15)
		lobbyHud.Size = UDim2.new(0.9, 0, 0, 48)
		lobbyHud.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
		lobbyHud.BackgroundTransparency = 0.25
		lobbyHud.BorderSizePixel = 0
		lobbyHud.ZIndex = 5
		lobbyHud.Parent = gui
		corner(lobbyHud, 8)

		local lobbyHudSize = Instance.new("UISizeConstraint")
		lobbyHudSize.MinSize = Vector2.new(280, 48)
		lobbyHudSize.MaxSize = Vector2.new(380, 48)
		lobbyHudSize.Parent = lobbyHud

		local lobbyStroke = Instance.new("UIStroke")
		lobbyStroke.Color = GOLD
		lobbyStroke.Thickness = 1.5
		lobbyStroke.Transparency = 0.4
		lobbyStroke.Parent = lobbyHud

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 10)
		layout.Parent = lobbyHud

		-- SHOP button (opens storefront)
		button(lobbyHud, "SHOP", UDim2.new(0, 0, 0.5, 0), UDim2.new(0.29, 0, 0, 32), Color3.fromRGB(110, 70, 160), function()
			closePanels()
			openStorefront()
		end)

		-- UPGRADES button
		button(lobbyHud, "UPGRADES", UDim2.new(0, 0, 0.5, 0), UDim2.new(0.29, 0, 0, 32), Color3.fromRGB(150, 110, 30), function()
			closePanels()
			refreshUpgradesUI()
			pveUpgradesPanel.Visible = true
		end)

		-- SETTINGS button
		button(lobbyHud, "SETTINGS", UDim2.new(0, 0, 0.5, 0), UDim2.new(0.29, 0, 0, 32), Color3.fromRGB(55, 65, 90), function()
			closePanels()
			settingsPanel.Visible = true
		end)
		UISelection.bind(lobbyHud)

		local function adjustLobbyHud()
			local offset = math.max(GuiService.TopbarInset.Height, 0)
			lobbyHud.Position = UDim2.new(0, 15, 0, 15 + offset)
		end
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(adjustLobbyHud)
		adjustLobbyHud()
	else
		menuOpen = true
		menuRoot.Visible = true
		GameUI.setHudVisible(false)
		startOrbit()
	end
end

return MainMenu
