--!strict
-- HUD + hotbar: gold, XP/age, base HP bars, unit/turret/special buttons, messages, crosshair.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Units = require(ReplicatedStorage.Shared.Config.Units)
local Turrets = require(ReplicatedStorage.Shared.Config.Turrets)
local Specials = require(ReplicatedStorage.Shared.Config.Specials)
local HeroWeapons = require(ReplicatedStorage.Shared.Config.HeroWeapons)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Synergies = require(ReplicatedStorage.Shared.Config.Synergies)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Audio = require(script.Parent.Audio)
local Accessibility = require(script.Parent.Accessibility)
local Settings = require(script.Parent.Settings)
local UISelection = require(script.Parent.UISelection)
local InputPrompts = require(script.Parent.InputPrompts)

local GameUI = {}
local lastState: { [string]: any } = {}
local showMessage: (text: string, color: Color3, duration: number?) -> ()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.GothamBold
local function settingsOpen(): boolean
	return player:GetAttribute("SettingsOpen") == true
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

local function bar(parent: Instance, pos: UDim2, size: UDim2, color: Color3): (Frame, Frame)
	local bg = Instance.new("Frame")
	bg.Position = pos
	bg.Size = size
	bg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	bg.BorderSizePixel = 0
	bg.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = bg
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 4)
	corner2.Parent = fill
	return bg, fill
end

local gui = Instance.new("ScreenGui")
gui.Name = "GameHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.ClipToDeviceSafeArea = true
gui.Parent = playerGui

-- Crosshair
local cross = Instance.new("Frame")
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(6, 6)
cross.BackgroundColor3 = Color3.new(1, 1, 1)
cross.BorderSizePixel = 0
cross.Parent = gui
local crossCorner = Instance.new("UICorner")
crossCorner.CornerRadius = UDim.new(1, 0)
crossCorner.Parent = cross
local crossStroke = Instance.new("UIStroke")
crossStroke.Color = Color3.new(0, 0, 0)
crossStroke.Thickness = 2
crossStroke.Enabled = false
crossStroke.Parent = cross

local function refreshCrosshair()
	local normalized = math.clamp(Settings.get("crosshairSize") or 0.25, 0, 1)
	local pixels = math.floor(4 + normalized * 14 + 0.5)
	cross.Size = UDim2.fromOffset(pixels, pixels)
	cross.Visible = Settings.get("crosshairVisible") ~= false
	crossStroke.Enabled = Settings.get("crosshairHighContrast") == true
end
refreshCrosshair()
Settings.onChanged(function(key)
	if key == "crosshairSize" or key == "crosshairVisible" or key == "crosshairHighContrast" then
		refreshCrosshair()
	end
end)

-- Hitmarker: brief X that flashes on hero hit
local hitmarker = Instance.new("Frame")
hitmarker.AnchorPoint = Vector2.new(0.5, 0.5)
hitmarker.Position = UDim2.fromScale(0.5, 0.5)
hitmarker.Size = UDim2.fromOffset(24, 24)
hitmarker.BackgroundTransparency = 1
hitmarker.Visible = false
hitmarker.Parent = gui
local hmStroke = Instance.new("UIStroke")
hmStroke.Color = Color3.fromRGB(255, 80, 60)
hmStroke.Thickness = 2
hmStroke.Parent = hitmarker
for _, rot in { 45, -45 } do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(0, 16, 0, 3)
	line.BackgroundColor3 = Color3.fromRGB(255, 80, 60)
	line.BorderSizePixel = 0
	line.Rotation = rot
	line.Parent = hitmarker
end

-- Base HP bars
local myBaseBg, myBaseFill = bar(gui, UDim2.new(0.02, 0, 0.03, 0), UDim2.new(0.25, 0, 0.03, 0), Color3.fromRGB(70, 140, 230))
local myBaseLabel = label(myBaseBg, { Size = UDim2.fromScale(1, 1), Text = "YOUR BASE", ZIndex = 3, TextTransparency = 0.15 })
local enBaseBg, enBaseFill = bar(gui, UDim2.new(0.73, 0, 0.03, 0), UDim2.new(0.25, 0, 0.03, 0), Color3.fromRGB(220, 80, 70))
local enBaseLabel = label(enBaseBg, { Size = UDim2.fromScale(1, 1), Text = "ENEMY BASE", ZIndex = 3, TextTransparency = 0.15 })

-- Dedicated hero health is kept separate from base health so first-person
-- players never have to rely on the platform CoreGui during combat.
local heroHpBg, heroHpFill = bar(gui, UDim2.new(0.02, 0, 0.105, 0), UDim2.new(0.2, 0, 0.022, 0), Color3.fromRGB(75, 205, 105))
local heroHpLabel = label(heroHpBg, { Size = UDim2.fromScale(1, 1), Text = "HERO 100 / 100", ZIndex = 3, TextTransparency = 0.08 })

-- Age + XP (top center)
local ageLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.02, 0),
	Size = UDim2.new(0.2, 0, 0.035, 0),
	Text = "Stone Age",
})
local xpBg, xpFill = bar(gui, UDim2.new(0.4, 0, 0.06, 0), UDim2.new(0.2, 0, 0.018, 0), Color3.fromRGB(240, 200, 80))
local xpLabel = label(xpBg, { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3 })

local objectiveFrame = Instance.new("Frame")
objectiveFrame.AnchorPoint = Vector2.new(0.5, 0)
objectiveFrame.Position = UDim2.new(0.5, 0, 0.135, 0)
objectiveFrame.Size = UDim2.new(0.48, 0, 0.07, 0)
objectiveFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
objectiveFrame.BackgroundTransparency = 0.16
objectiveFrame.BorderSizePixel = 0
objectiveFrame.Visible = false -- shown for 10s at match start
objectiveFrame.Parent = gui
local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 8)
objectiveCorner.Parent = objectiveFrame
local objectiveTitle = label(objectiveFrame, {
	Size = UDim2.fromScale(1, 0.46), Text = "GOAL: DESTROY THE ENEMY BASE",
	TextColor3 = Color3.fromRGB(255, 125, 110), ZIndex = 3,
})
local evolveHint = label(objectiveFrame, {
	Position = UDim2.fromScale(0.02, 0.47), Size = UDim2.fromScale(0.96, 0.42),
	Text = "Kills grant XP • Evolve to unlock stronger armies", TextColor3 = Color3.fromRGB(205, 205, 220), ZIndex = 3,
})

-- Show the goal banner for 10 seconds, then hide it.
local objectiveShownAt = 0
local function showObjective()
	objectiveShownAt = os.clock()
	objectiveFrame.Visible = true
	task.delay(10, function()
		if os.clock() - objectiveShownAt >= 10 then
			objectiveFrame.Visible = false
		end
	end)
end

-- Difficulty Label (top right)
local diffLabel = label(gui, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(0.98, 0, 0.02, 0),
	Size = UDim2.new(0.15, 0, 0.03, 0),
	Text = "Mode: 1v1 PvP",
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(150, 200, 150),
})

local paceLabel = label(gui, {
	Position = UDim2.new(0.02, 0, 0.07, 0),
	Size = UDim2.new(0.28, 0, 0.026, 0),
	Text = "00:00 • STANDARD",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(190, 200, 215),
})

-- Evolve button
local evolveBtn = Instance.new("TextButton")
evolveBtn.AnchorPoint = Vector2.new(0.5, 0)
evolveBtn.Position = UDim2.new(0.5, 0, 0.09, 0)
evolveBtn.Size = UDim2.new(0.12, 0, 0.035, 0)
evolveBtn.Font = FONT
evolveBtn.TextScaled = true
evolveBtn.Text = "EVOLVE [Q]"
evolveBtn.TextColor3 = Color3.new(1, 1, 1)
evolveBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
evolveBtn.Visible = false
evolveBtn.Parent = gui
local evCorner = Instance.new("UICorner")
evCorner.CornerRadius = UDim.new(0, 6)
evCorner.Parent = evolveBtn

-- Keep the crosshair in device-safe camera coordinates, but move only the
-- informational widgets below Roblox's dynamic top bar.
local topHudPositions: { [GuiObject]: UDim2 } = {
	[myBaseBg] = myBaseBg.Position,
	[enBaseBg] = enBaseBg.Position,
	[heroHpBg] = heroHpBg.Position,
	[ageLabel] = ageLabel.Position,
	[xpBg] = xpBg.Position,
	[objectiveFrame] = objectiveFrame.Position,
	[diffLabel] = diffLabel.Position,
	[paceLabel] = paceLabel.Position,
	[evolveBtn] = evolveBtn.Position,
}
local function applyTopbarInset()
	local offset = math.max(GuiService.TopbarInset.Height, 0)
	for widget, basePosition in topHudPositions do
		widget.Position = basePosition + UDim2.fromOffset(0, offset)
	end
end
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(applyTopbarInset)
applyTopbarInset()

-- Gold display (large, easy to read above hotbar)
local goldFrame = Instance.new("Frame")
goldFrame.Name = "GoldFrame"
goldFrame.AnchorPoint = Vector2.new(0.5, 1)
goldFrame.Position = UDim2.new(0.5, 0, 0.875, 0)
goldFrame.Size = UDim2.new(0.24, 0, 0.06, 0)
goldFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
goldFrame.BackgroundTransparency = 0.15
goldFrame.BorderSizePixel = 0
goldFrame.Parent = gui
local goldFrameCorner = Instance.new("UICorner")
goldFrameCorner.CornerRadius = UDim.new(0, 10)
goldFrameCorner.Parent = goldFrame

local goldIcon = Instance.new("TextLabel")
goldIcon.Name = "GoldIcon"
goldIcon.BackgroundTransparency = 1
goldIcon.Font = Enum.Font.GothamBlack
goldIcon.Text = "G"
goldIcon.TextColor3 = Color3.fromRGB(255, 220, 80)
goldIcon.TextScaled = true
goldIcon.Position = UDim2.new(0, 10, 0.5, -13)
goldIcon.Size = UDim2.new(0, 26, 0, 26)
goldIcon.Parent = goldFrame

local goldLabel = label(goldFrame, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 40, 0.5, 0),
	Size = UDim2.new(1, -45, 0.75, 0),
	Text = "0 g",
	TextColor3 = Color3.fromRGB(255, 220, 100),
	TextXAlignment = Enum.TextXAlignment.Left,
})

-- Upgrades Toggle Button
local upgradesToggle = Instance.new("TextButton")
upgradesToggle.AnchorPoint = Vector2.new(0, 1)
upgradesToggle.Position = UDim2.new(0.02, 0, 0.875, 0)
upgradesToggle.Size = UDim2.new(0.12, 0, 0.05, 0)
upgradesToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
upgradesToggle.TextColor3 = Color3.new(1, 1, 1)
upgradesToggle.Font = FONT
upgradesToggle.TextScaled = true
upgradesToggle.Text = "UPGRADES [E]"
upgradesToggle.Parent = gui
local ugCorner = Instance.new("UICorner")
ugCorner.CornerRadius = UDim.new(0, 6)
ugCorner.Parent = upgradesToggle

local upgradesPanel = Instance.new("Frame")
upgradesPanel.AnchorPoint = Vector2.new(0, 1)
upgradesPanel.Position = UDim2.new(0.02, 0, 0.82, 0)
upgradesPanel.Size = UDim2.new(0.15, 0, 0.25, 0)
upgradesPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
upgradesPanel.BackgroundTransparency = 0.1
upgradesPanel.Visible = false
upgradesPanel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = upgradesPanel

local upgList = Instance.new("UIListLayout")
upgList.FillDirection = Enum.FillDirection.Vertical
upgList.Padding = UDim.new(0.05, 0)
upgList.HorizontalAlignment = Enum.HorizontalAlignment.Center
upgList.VerticalAlignment = Enum.VerticalAlignment.Center
upgList.Parent = upgradesPanel

-- Combination guide: doctrines are intentionally mutually exclusive.
local guideButton = Instance.new("TextButton")
guideButton.AnchorPoint = Vector2.new(0, 0)
guideButton.Position = UDim2.new(0.02, 0, 0.09, 0)
guideButton.Size = UDim2.new(0.14, 0, 0.045, 0)
guideButton.BackgroundColor3 = Color3.fromRGB(65, 52, 92)
guideButton.TextColor3 = Color3.new(1, 1, 1)
guideButton.Font = FONT
guideButton.TextScaled = true
guideButton.Text = "COMBO GUIDE [G]"
guideButton.Parent = gui
local guideButtonCorner = Instance.new("UICorner")
guideButtonCorner.CornerRadius = UDim.new(0, 7)
guideButtonCorner.Parent = guideButton

local guidePanel = Instance.new("Frame")
guidePanel.AnchorPoint = Vector2.new(0.5, 0.5)
guidePanel.Position = UDim2.fromScale(0.5, 0.48)
guidePanel.Size = UDim2.new(0.52, 0, 0.58, 0)
guidePanel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
guidePanel.BackgroundTransparency = 0.04
guidePanel.BorderSizePixel = 0
guidePanel.Visible = false
guidePanel.ZIndex = 20
guidePanel.Parent = gui
local guideCorner = Instance.new("UICorner")
guideCorner.CornerRadius = UDim.new(0, 12)
guideCorner.Parent = guidePanel
local guideStroke = Instance.new("UIStroke")
guideStroke.Color = Color3.fromRGB(170, 140, 230)
guideStroke.Thickness = 2
guideStroke.Parent = guidePanel

label(guidePanel, {
	Position = UDim2.fromScale(0.06, 0.04), Size = UDim2.fromScale(0.88, 0.09),
	Text = "ARMY COMBINATION GUIDE", ZIndex = 21,
})
label(guidePanel, {
	Position = UDim2.fromScale(0.07, 0.13), Size = UDim2.fromScale(0.86, 0.08),
	Text = "The first formation you complete locks your doctrine for this battle. Choose carefully.",
	TextWrapped = true, TextColor3 = Color3.fromRGB(195, 195, 210), ZIndex = 21,
})
local guideStatus = label(guidePanel, {
	Position = UDim2.fromScale(0.12, 0.86), Size = UDim2.fromScale(0.76, 0.07),
	Text = "Current doctrine: Not chosen", TextColor3 = Color3.fromRGB(245, 210, 110), ZIndex = 21,
})
local guideProgressLabels: { [string]: TextLabel } = {}
for i, doctrine in Synergies.list do
	local card = Instance.new("Frame")
	card.Position = UDim2.fromScale(0.07, 0.22 + (i - 1) * 0.205)
	card.Size = UDim2.fromScale(0.86, 0.17)
	card.BackgroundColor3 = doctrine.color:Lerp(Color3.fromRGB(20, 20, 28), 0.72)
	card.BorderSizePixel = 0
	card.ZIndex = 21
	card.Parent = guidePanel
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card
	label(card, {
		Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.32),
		Text = doctrine.name, TextColor3 = doctrine.color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	})
	label(card, {
		Position = UDim2.fromScale(0.03, 0.38), Size = UDim2.fromScale(0.94, 0.36),
		Text = doctrine.description, TextWrapped = true, TextScaled = false, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(225, 225, 235), ZIndex = 22,
	})
	guideProgressLabels[doctrine.id] = label(card, {
		Position = UDim2.fromScale(0.03, 0.76), Size = UDim2.fromScale(0.94, 0.18),
		Text = "Progress: 0", TextScaled = false, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 200, 215), ZIndex = 22,
	})
end

-- Turret manager: quick-build remains on hotbar slot 5; this panel exposes
-- the four individual mounts so obsolete turrets can be upgraded or sold.
local turretButton = Instance.new("TextButton")
turretButton.Position = UDim2.new(0.02, 0, 0.145, 0)
turretButton.Size = UDim2.new(0.14, 0, 0.045, 0)
turretButton.BackgroundColor3 = Color3.fromRGB(52, 72, 92)
turretButton.TextColor3 = Color3.new(1, 1, 1)
turretButton.Font = FONT
turretButton.TextScaled = true
turretButton.Text = "TURRETS [B]"
turretButton.Parent = gui
local turretButtonCorner = Instance.new("UICorner")
turretButtonCorner.CornerRadius = UDim.new(0, 7)
turretButtonCorner.Parent = turretButton

local turretPanel = Instance.new("Frame")
turretPanel.AnchorPoint = Vector2.new(0.5, 0.5)
turretPanel.Position = UDim2.fromScale(0.5, 0.48)
turretPanel.Size = UDim2.new(0.48, 0, 0.58, 0)
turretPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
turretPanel.BackgroundTransparency = 0.04
turretPanel.BorderSizePixel = 0
turretPanel.Visible = false
turretPanel.ZIndex = 20
turretPanel.Parent = gui
local turretCorner = Instance.new("UICorner")
turretCorner.CornerRadius = UDim.new(0, 12)
turretCorner.Parent = turretPanel
local turretStroke = Instance.new("UIStroke")
turretStroke.Color = Color3.fromRGB(105, 175, 225)
turretStroke.Thickness = 2
turretStroke.Parent = turretPanel

label(turretPanel, {
	Position = UDim2.fromScale(0.08, 0.04), Size = UDim2.fromScale(0.84, 0.09),
	Text = "TURRET MANAGER", TextColor3 = Color3.fromRGB(140, 205, 245), ZIndex = 21,
})
label(turretPanel, {
	Position = UDim2.fromScale(0.08, 0.12), Size = UDim2.fromScale(0.84, 0.055),
	Text = "Upgrades automatically include the old turret's 50% sell credit.",
	TextColor3 = Color3.fromRGB(185, 195, 210), ZIndex = 21,
})

local function turretActionButton(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3, callback: () -> ()): TextButton
	local item = Instance.new("TextButton")
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = position
	item.Size = size
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	item.Text = text
	item.TextColor3 = Color3.new(1, 1, 1)
	item.Font = FONT
	item.TextScaled = true
	item.ZIndex = 22
	item.Parent = parent
	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, 6)
	itemCorner.Parent = item
	item.Activated:Connect(function()
		if settingsOpen() then return end
		callback()
	end)
	return item
end

type TurretManagerRow = { status: TextLabel, primary: TextButton, sell: TextButton }
local turretRows: { TurretManagerRow } = {}
for slot = 1, GameConfig.TURRET_SLOTS do
	local row = Instance.new("Frame")
	row.Position = UDim2.fromScale(0.07, 0.19 + (slot - 1) * 0.145)
	row.Size = UDim2.fromScale(0.86, 0.115)
	row.BackgroundColor3 = Color3.fromRGB(30, 35, 44)
	row.BorderSizePixel = 0
	row.ZIndex = 21
	row.Parent = turretPanel
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 7)
	rowCorner.Parent = row
	local status = label(row, {
		Position = UDim2.fromScale(0.03, 0.12), Size = UDim2.fromScale(0.42, 0.76),
		Text = `SLOT {slot} • EMPTY`, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	})
	local primary = turretActionButton(row, "BUILD", UDim2.fromScale(0.64, 0.5), UDim2.fromScale(0.3, 0.68), Color3.fromRGB(55, 115, 80), function()
		local age = lastState.age or 1
		local info = (lastState.turrets or {})[slot]
		local current = Turrets[age]
		local credit = typeof(info) == "table" and (info.sellValue or 0) or 0
		local cost = math.max(0, current.cost - credit)
		if typeof(info) == "table" and (info.age or age) >= age then return end
		if (lastState.gold or 0) < cost then
			showMessage(`NEED {cost - math.floor(lastState.gold or 0)} MORE GOLD`, Color3.fromRGB(255, 150, 120), 1.5)
			return
		end
		Audio.play("buy")
		Remotes.BuildTurret:FireServer(slot)
	end)
	local sell = turretActionButton(row, "SELL", UDim2.fromScale(0.88, 0.5), UDim2.fromScale(0.16, 0.68), Color3.fromRGB(115, 70, 55), function()
		if typeof((lastState.turrets or {})[slot]) ~= "table" then return end
		Audio.play("click")
		Remotes.SellTurret:FireServer(slot)
	end)
	table.insert(turretRows, { status = status, primary = primary, sell = sell })
end

local closeTurrets = turretActionButton(turretPanel, "CLOSE", UDim2.fromScale(0.5, 0.91), UDim2.fromScale(0.22, 0.07), Color3.fromRGB(60, 65, 75), function()
	turretPanel.Visible = false
end)
closeTurrets.ZIndex = 22
UISelection.bind(turretPanel, turretRows[1] and turretRows[1].primary or closeTurrets, function()
	turretPanel.Visible = false
end)

local function toggleTurrets()
	if settingsOpen() then return end
	Audio.play("click")
	turretPanel.Visible = not turretPanel.Visible
	guidePanel.Visible = false
	upgradesPanel.Visible = false
end
turretButton.Activated:Connect(toggleTurrets)

local function toggleGuide()
	if settingsOpen() then return end
	Audio.play("click")
	guidePanel.Visible = not guidePanel.Visible
	upgradesPanel.Visible = false
	turretPanel.Visible = false
end
guideButton.Activated:Connect(toggleGuide)

local upgButtons = {}
local function makeUpgBtn(stat: string, text: string)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.9, 0, 0.25, 0)
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	b.Text = ""
	b.Parent = upgradesPanel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = b
	local t = label(b, { Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.1), Text = text })
	local costL = label(b, { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.6), Text = "500 g", TextColor3 = Color3.fromRGB(255, 220, 80) })
	upgButtons[stat] = { btn = b, title = t, cost = costL, text = text }
	b.Activated:Connect(function()
		if settingsOpen() then return end
		Audio.play("click")
		Remotes.BuyUpgrade:FireServer(stat)
	end)
end

makeUpgBtn("dmg", "DAMAGE +15%")
makeUpgBtn("health", "HEALTH +15%")
makeUpgBtn("def", "DEFENSE +10%")
UISelection.bind(upgradesPanel, upgButtons.dmg.btn, function()
	upgradesPanel.Visible = false
end)

upgradesToggle.Activated:Connect(function()
	if settingsOpen() then return end
	Audio.play("click")
	upgradesPanel.Visible = not upgradesPanel.Visible
	guidePanel.Visible = false
	turretPanel.Visible = false
end)

-- Unit / queue count (small, below hotbar)
local countLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.995, 0),
	Size = UDim2.new(0.3, 0, 0.02, 0),
	Text = "",
	TextColor3 = Color3.fromRGB(180, 180, 180),
})

-- Center message
local msgLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.35),
	Size = UDim2.new(0.5, 0, 0.08, 0),
	Text = "",
	TextStrokeTransparency = 0.5,
})

local cancelQueueButton = Instance.new("TextButton")
cancelQueueButton.AnchorPoint = Vector2.new(0.5, 0.5)
cancelQueueButton.Position = UDim2.fromScale(0.5, 0.44)
cancelQueueButton.Size = UDim2.new(0.22, 0, 0, 48)
cancelQueueButton.BackgroundColor3 = Color3.fromRGB(125, 55, 55)
cancelQueueButton.TextColor3 = Color3.new(1, 1, 1)
cancelQueueButton.Font = FONT
cancelQueueButton.TextScaled = true
cancelQueueButton.Text = "CANCEL MATCHMAKING"
cancelQueueButton.Visible = false
cancelQueueButton.Parent = gui
local cancelQueueCorner = Instance.new("UICorner")
cancelQueueCorner.CornerRadius = UDim.new(0, 8)
cancelQueueCorner.Parent = cancelQueueButton
cancelQueueButton.Activated:Connect(function()
	if not cancelQueueButton.Active then return end
	cancelQueueButton.Active = false
	cancelQueueButton.Text = "CANCELLING..."
	Remotes.CancelQueue:FireServer()
end)

-- Hotbar
local hotbar = Instance.new("Frame")
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 0.98, 0)
hotbar.Size = UDim2.new(0.6, 0, 0.1, 0)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0.01, 0)
layout.Parent = hotbar

type Slot = { btn: TextButton, name: TextLabel, cost: TextLabel, key: TextLabel }
local slots: { Slot } = {}

local function makeSlot(keyText: string): Slot
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.15, 0, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	btn.BackgroundTransparency = 0.15
	btn.Text = ""
	btn.Parent = hotbar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = btn
	local key = label(btn, { Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.2, 0.3), Text = keyText, TextColor3 = Color3.fromRGB(180, 180, 190) })
	local name = label(btn, { Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.38), Text = "" })
	local cost = label(btn, { Position = UDim2.fromScale(0, 0.68), Size = UDim2.fromScale(1, 0.3), Text = "", TextColor3 = Color3.fromRGB(255, 220, 100) })
	local slot = { btn = btn, name = name, cost = cost, key = key }
	table.insert(slots, slot)
	return slot
end

for i = 1, 6 do
	makeSlot(tostring(i))
end

local function refreshInputPrompts()
	upgradesToggle.Text = InputPrompts.withPrompt("UPGRADES", "upgrades")
	guideButton.Text = InputPrompts.withPrompt("COMBO GUIDE", "guide")
	turretButton.Text = InputPrompts.withPrompt("TURRETS", "turrets")

	for index, slot in slots do
		local prompt = InputPrompts.get(`slot{index}`)
		slot.key.Text = prompt
		slot.key.Visible = prompt ~= ""
	end

	local upgradeActions = { dmg = "slot1", health = "slot2", def = "slot3" }
	for stat, ui in upgButtons do
		ui.title.Text = InputPrompts.withPrompt(ui.text, upgradeActions[stat])
	end

	local age = lastState.age
	if age and lastState.nextAgeXp ~= nil then
		local text = if lastState.canEvolve then `EVOLVE TO AGE {age + 1}` else `AGE {age + 1} LOCKED`
		evolveBtn.Text = InputPrompts.withPrompt(text, "evolve")
	else
		evolveBtn.Text = InputPrompts.withPrompt("EVOLVE", "evolve")
	end
end

local function applyTouchLayout()
	if not UserInputService.TouchEnabled then return end

	-- Keep Roblox's movement and jump zones clear: command cards occupy a
	-- compact two-row block in the lower centre, while attacks sit above jump.
	layout.Parent = nil
	hotbar.AnchorPoint = Vector2.new(0.5, 0.5)
	hotbar.Position = UDim2.fromScale(0.51, 0.84)
	hotbar.Size = UDim2.fromScale(0.48, 0.19)
	for index, slot in slots do
		local column = (index - 1) % 3
		local row = math.floor((index - 1) / 3)
		slot.btn.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.btn.Position = UDim2.fromScale(0.17 + column * 0.33, 0.24 + row * 0.52)
		slot.btn.Size = UDim2.fromScale(0.31, 0.46)
		slot.key.Visible = false
		slot.name.Position = UDim2.fromScale(0, 0.08)
		slot.name.Size = UDim2.fromScale(1, 0.5)
		slot.cost.Position = UDim2.fromScale(0, 0.58)
		slot.cost.Size = UDim2.fromScale(1, 0.34)
	end

	goldFrame.Position = UDim2.fromScale(0.51, 0.73)
	goldFrame.Size = UDim2.fromScale(0.34, 0.065)
	countLabel.Position = UDim2.fromScale(0.51, 0.95)
	countLabel.Size = UDim2.fromScale(0.48, 0.025)
	upgradesToggle.Position = UDim2.fromScale(0.02, 0.78)
	upgradesToggle.Size = UDim2.fromScale(0.18, 0.055)
	upgradesPanel.Position = UDim2.fromScale(0.02, 0.72)
	upgradesPanel.Size = UDim2.fromScale(0.26, 0.28)

	guideButton.Size = UDim2.fromScale(0.2, 0.05)
	turretButton.Position = UDim2.fromScale(0.02, 0.155)
	turretButton.Size = UDim2.fromScale(0.2, 0.05)
	guidePanel.Size = UDim2.fromScale(0.9, 0.72)
	turretPanel.Size = UDim2.fromScale(0.9, 0.72)
	objectiveFrame.Size = UDim2.fromScale(0.7, 0.08)
	diffLabel.Visible = false
end
applyTouchLayout()
refreshInputPrompts()
InputPrompts.onChanged(refreshInputPrompts)

local function rejectAction(reason: string)
	Audio.play("hover")
	showMessage(reason, Color3.fromRGB(255, 150, 120), 1.5)
end

local function slotAction(i: number)
	if settingsOpen() then return end
	local age = lastState.age or 1
	if i <= 4 then
		local def = Units.byAge[age][i]
		if def then
			if (lastState.queueCount or 0) >= (lastState.queueCap or 10) then
				rejectAction("UNIT QUEUE FULL")
				return
			elseif (lastState.gold or 0) < def.cost then
				rejectAction(`NEED {def.cost - math.floor(lastState.gold or 0)} MORE GOLD`)
				return
			end
			Audio.play("click")
			Remotes.SpawnUnit:FireServer(def.id)
		end
	elseif i == 5 then
		local tdef = Turrets[age]
		if (lastState.gold or 0) < tdef.cost then
			rejectAction(`NEED {tdef.cost - math.floor(lastState.gold or 0)} MORE GOLD`)
			return
		end
		-- build in first empty slot
		local turrets = lastState.turrets or {}
		for slotIdx = 1, 4 do
			if turrets[slotIdx] == false or turrets[slotIdx] == nil then
				Audio.play("click")
				Remotes.BuildTurret:FireServer(slotIdx)
				return
			end
		end
		rejectAction(InputPrompts.withPrompt("ALL SLOTS FULL • OPEN TURRETS TO UPGRADE OR SELL", "turrets"))
	elseif i == 6 then
		if (lastState.specialCd or 0) > 0 then
			rejectAction(`SPECIAL READY IN {math.ceil(lastState.specialCd)}s`)
			return
		end
		Audio.play("click")
		Remotes.UseSpecial:FireServer()
	end
end

for i, slot in slots do
	slot.btn.Activated:Connect(function()
		slotAction(i)
	end)
end
evolveBtn.Activated:Connect(function()
	if settingsOpen() then return end
	if not lastState.canEvolve then
		if lastState.nextAgeXp then
			rejectAction(`NEED {math.max(0, math.ceil(lastState.nextAgeXp - (lastState.xp or 0)))} MORE XP TO EVOLVE`)
		end
		return
	end
	Audio.play("buy")
	Remotes.Evolve:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or settingsOpen() then
		return
	end
	local key = input.KeyCode
	local map = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.DPadUp] = 1,
		[Enum.KeyCode.DPadRight] = 2,
		[Enum.KeyCode.DPadDown] = 3,
		[Enum.KeyCode.DPadLeft] = 5,
		[Enum.KeyCode.ButtonX] = 6,
		[Enum.KeyCode.ButtonB] = 4,
	}
	if key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonR1 then
		Audio.play("click")
		upgradesPanel.Visible = not upgradesPanel.Visible
		guidePanel.Visible = false
		turretPanel.Visible = false
	elseif key == Enum.KeyCode.G or key == Enum.KeyCode.ButtonSelect then
		toggleGuide()
	elseif key == Enum.KeyCode.B or key == Enum.KeyCode.ButtonL1 then
		toggleTurrets()
	elseif map[key] then
		local num = map[key]
		if upgradesPanel.Visible and num <= 3 then
			Audio.play("click")
			local stats = { "dmg", "health", "def" }
			Remotes.BuyUpgrade:FireServer(stats[num])
		else
			slotAction(num)
		end
	elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonY then
		if lastState.canEvolve then
			Audio.play("buy")
			Remotes.Evolve:FireServer()
		elseif lastState.nextAgeXp then
			rejectAction(`NEED {math.max(0, math.ceil(lastState.nextAgeXp - (lastState.xp or 0)))} MORE XP TO EVOLVE`)
		end
	end
end)

-- State-driven refresh
local function refresh(state: { [string]: any })
	lastState = state
	local age = state.age :: number
	local gold = state.gold :: number
	guideStatus.Text = state.doctrine and `Current doctrine: {state.doctrine} (LOCKED)` or "Current doctrine: Not chosen"
	local roleCounts = state.roleCounts or {}
	for _, doctrine in Synergies.list do
		local progress = guideProgressLabels[doctrine.id]
		if state.doctrine then
			progress.Text = state.doctrine == doctrine.id and "ACTIVE FOR THIS BATTLE" or "LOCKED OUT THIS BATTLE"
			progress.TextColor3 = state.doctrine == doctrine.id and doctrine.color or Color3.fromRGB(125, 125, 135)
		else
			local parts = {}
			for _, role in { "melee", "ranged", "heavy", "super_heavy" } do
				local required = doctrine.requirements[role]
				if required then
					local displayRole = string.upper(string.gsub(role, "_", " "))
					table.insert(parts, `{displayRole} {math.min(roleCounts[role] or 0, required)}/{required}`)
				end
			end
			progress.Text = `Progress: {table.concat(parts, " • ")}`
			progress.TextColor3 = doctrine.color
		end
	end

	local currentTurret = Turrets[age]
	for slot, row in turretRows do
		local info = (state.turrets or {})[slot]
		if typeof(info) == "table" then
			row.status.Text = `SLOT {slot} • {string.upper(info.name or "TURRET")}  (AGE {info.age or age})`
			row.sell.Visible = true
			row.sell.Text = `SELL +{info.sellValue or 0}`
			if (info.age or age) < age then
				local upgradeCost = math.max(0, currentTurret.cost - (info.sellValue or 0))
				row.primary.Text = `UPGRADE {upgradeCost}g`
				row.primary.Active = gold >= upgradeCost
				row.primary.BackgroundColor3 = gold >= upgradeCost and Color3.fromRGB(55, 115, 80) or Color3.fromRGB(75, 55, 55)
			else
				row.primary.Text = "CURRENT"
				row.primary.Active = false
				row.primary.BackgroundColor3 = Color3.fromRGB(55, 65, 70)
			end
		else
			row.status.Text = `SLOT {slot} • EMPTY`
			row.sell.Visible = false
			row.primary.Text = `BUILD {currentTurret.cost}g`
			row.primary.Active = gold >= currentTurret.cost
			row.primary.BackgroundColor3 = gold >= currentTurret.cost and Color3.fromRGB(55, 115, 80) or Color3.fromRGB(75, 55, 55)
		end
	end

	goldLabel.Text = `{math.floor(gold)} g  (+{string.format("%.1f", state.incomeRate or 0)}/s)`
	countLabel.Text = `units {state.unitCount}/20  queue {state.queueCount}`
	ageLabel.Text = `AGE {age} / {#Ages}  •  {string.upper(state.ageName)}`
	ageLabel.TextColor3 = Ages[age].color:Lerp(Color3.new(1, 1, 1), 0.5)
	local elapsed = math.max(0, state.matchElapsed or 0)
	local mins = math.floor(elapsed / 60)
	local secs = math.floor(elapsed % 60)
	if state.mode == "PvE" and state.objectiveRemaining ~= nil then
		paceLabel.Text = `{mins}:{secs < 10 and "0" or ""}{secs} • HOLD FOR {math.ceil(state.objectiveRemaining)}s`
		paceLabel.TextColor3 = Color3.fromRGB(125, 210, 255)
	elseif state.pacePhase == "Sudden Death" then
		paceLabel.Text = `{mins}:{secs < 10 and "0" or ""}{secs} • SUDDEN DEATH • 3x BASE DAMAGE`
		paceLabel.TextColor3 = Color3.fromRGB(255, 105, 90)
	elseif state.pacePhase == "Escalation" then
		local remaining = math.max(0, GameConfig.SUDDEN_DEATH_START - elapsed)
		paceLabel.Text = `{mins}:{secs < 10 and "0" or ""}{secs} • ESCALATION • SUDDEN DEATH IN {math.ceil(remaining)}s`
		paceLabel.TextColor3 = Color3.fromRGB(255, 205, 105)
	else
		local remaining = math.max(0, GameConfig.ESCALATION_START - elapsed)
		paceLabel.Text = `{mins}:{secs < 10 and "0" or ""}{secs} • ESCALATION IN {math.ceil(remaining)}s`
		paceLabel.TextColor3 = Color3.fromRGB(190, 200, 215)
	end

	if state.nextAgeXp then
		local prevReq = Ages[age].xpRequired
		local frac = math.clamp((state.xp - prevReq) / (state.nextAgeXp - prevReq), 0, 1)
		xpFill.Size = UDim2.fromScale(frac, 1)
		xpLabel.Text = `XP {math.floor(state.xp)} / {state.nextAgeXp}`
		local nextAge = age + 1
		local nextUnits = Units.byAge[nextAge]
		evolveHint.Text = `EVOLVE → {string.upper(Ages[nextAge].name)} • {#nextUnits} NEW UNITS • {HeroWeapons[nextAge].name} • {Turrets[nextAge].name} • {Specials[nextAge].name} • INCOME {GameConfig.PASSIVE_INCOME_BY_AGE[age]}→{GameConfig.PASSIVE_INCOME_BY_AGE[nextAge]}g/s • BASE HP ×2`
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = "MAX AGE"
		evolveHint.Text = "FINAL AGE REACHED • Lead your army to destroy the enemy base"
	end

	if state.difficulty then
		if state.mode == "PvE" then
			if state.stageName and state.stageObjective then
				diffLabel.Text = `{string.upper(state.pveMode or "Normal")} • LV {state.pveLevel or 1} • {string.upper(state.stageName)} • {state.stageObjective}`
			else
				diffLabel.Text = `{string.upper(state.pveMode or "Normal")} • LEVEL {state.pveLevel or 1}`
			end
		elseif state.opponentName then
			diffLabel.Text = `VS {state.opponentName}`
		else
			diffLabel.Text = "Mode: 1v1 PvP"
		end
		local colors = { Normal = Color3.fromRGB(150, 200, 150), Hard = Color3.fromRGB(200, 180, 120), Impossible = Color3.fromRGB(220, 120, 120) }
		diffLabel.TextColor3 = colors[state.pveMode or state.difficulty] or Color3.new(1, 1, 1)
	end

	if objectiveFrame.Visible and state.stageObjective then
		objectiveTitle.Text = `GOAL: {state.stageObjective} • {string.upper(state.stageName or "")}`
		evolveHint.Text = `{state.stageObjectiveDescription or ""} • {state.stageModifier or ""}: {state.stageModifierDescription or ""}`
	end

	evolveBtn.Visible = state.nextAgeXp ~= nil
	evolveBtn.Text = InputPrompts.withPrompt(
		if state.canEvolve then `EVOLVE TO AGE {age + 1}` else `AGE {age + 1} LOCKED`,
		"evolve"
	)
	evolveBtn.BackgroundColor3 = state.canEvolve and Color3.fromRGB(90, 180, 90) or Color3.fromRGB(65, 65, 72)

	-- updates upgrades buttons
	local u = state.heroUpgrades or { dmg = 0, health = 0, def = 0 }
	for stat, ui in upgButtons do
		local lvl = u[stat] or 0
		if lvl >= GameConfig.HERO_UPGRADE_MAX_TIER then
			ui.cost.Text = "MAX"
			ui.btn.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
		else
			local cost = 500 * (2 ^ lvl)
			ui.cost.Text = `{cost} g (Lv{lvl})`
			ui.btn.BackgroundColor3 = gold >= cost and Color3.fromRGB(45, 60, 45) or Color3.fromRGB(60, 30, 30)
		end
	end

	myBaseFill.Size = UDim2.fromScale(math.clamp(state.baseHpSelf / state.baseMaxHpSelf, 0, 1), 1)
	enBaseFill.Size = UDim2.fromScale(math.clamp(state.baseHpEnemy / state.baseMaxHpEnemy, 0, 1), 1)
	myBaseLabel.Text = `YOUR BASE  •  {math.ceil(state.baseHpSelf)} / {math.ceil(state.baseMaxHpSelf)}`
	enBaseLabel.Text = `ENEMY BASE  •  {math.ceil(state.baseHpEnemy)} / {math.ceil(state.baseMaxHpEnemy)}`

	-- hotbar slots 1-4: units of current age
	for i = 1, 4 do
		local def = Units.byAge[age][i]
		local slot = slots[i]
		if def then
			slot.btn.Visible = true
			slot.name.Text = def.name
			slot.cost.Text = `{def.cost} g`
			slot.btn.BackgroundColor3 = gold >= def.cost and Color3.fromRGB(35, 45, 60) or Color3.fromRGB(45, 30, 30)
		else
			slot.btn.Visible = false
		end
	end
	-- slot 5: turret
	local tdef = Turrets[age]
	local builtCount = 0
	for _, v in state.turrets or {} do
		if v then
			builtCount += 1
		end
	end
	slots[5].btn.Visible = true
	slots[5].name.Text = tdef.name
	slots[5].cost.Text = builtCount >= 4 and "FULL" or `{tdef.cost} g`
	slots[5].btn.BackgroundColor3 = (gold >= tdef.cost and builtCount < 4) and Color3.fromRGB(35, 45, 60) or Color3.fromRGB(45, 30, 30)
	-- slot 6: special
	local sdef = Specials[age]
	slots[6].btn.Visible = true
	slots[6].name.Text = sdef.name
	if state.specialCd > 0 then
		slots[6].cost.Text = `{math.ceil(state.specialCd)}s`
		slots[6].btn.BackgroundColor3 = Color3.fromRGB(45, 30, 30)
	else
		slots[6].cost.Text = "READY"
		slots[6].btn.BackgroundColor3 = Color3.fromRGB(60, 45, 80)
	end
end

showMessage = function(text: string, color: Color3, duration: number?)
	msgLabel.Text = text
	msgLabel.TextColor3 = color
	if duration then
		task.delay(duration, function()
			if msgLabel.Text == text then
				msgLabel.Text = ""
			end
		end)
	end
end

local function setQueueMode(enabled: boolean)
	for _, widget in {
		cross, myBaseBg, enBaseBg, heroHpBg, ageLabel, xpBg, diffLabel, paceLabel,
		goldFrame, upgradesToggle, countLabel, hotbar, guideButton, turretButton,
	} do
		widget.Visible = not enabled
	end
	-- The goal banner is only shown by showObjective() (10s at match start),
	-- never force-shown here; queue mode still hides it.
	if enabled then
		objectiveFrame.Visible = false
	end
	upgradesPanel.Visible = false
	guidePanel.Visible = false
	turretPanel.Visible = false
	evolveBtn.Visible = not enabled and lastState.nextAgeXp ~= nil
end

-- Show/hide the in-match HUD (hidden while the main menu is open).
function GameUI.setHudVisible(visible: boolean)
	gui.Enabled = visible
end

function GameUI.setQueueMode(enabled: boolean)
	setQueueMode(enabled)
end

-- Expose HUD elements so the tutorial can point at them.
function GameUI.getSlotButton(i: number): TextButton?
	local slot = slots[i]
	return slot and slot.btn or nil
end

function GameUI.getEvolveButton(): TextButton
	return evolveBtn
end

local lastHitmarker = 0
function GameUI.showHitmarker()
	lastHitmarker = os.clock()
	hitmarker.Visible = true
	hitmarker.Size = UDim2.fromOffset(18, 18)
	TweenService:Create(hitmarker, TweenInfo.new(0.08), { Size = UDim2.fromOffset(24, 24) }):Play()
	task.delay(0.12, function()
		if os.clock() - lastHitmarker >= 0.1 then
			hitmarker.Visible = false
		end
	end)
end

local lastBaseAlarm = 0
local function baseAlarm()
	local now = os.clock()
	if now - lastBaseAlarm < 1.5 then
		return
	end
	lastBaseAlarm = now
	Audio.play("baseAlarm")
	Accessibility.caption("YOUR BASE IS UNDER ATTACK", 2.2)
	local orig = myBaseFill.BackgroundColor3
	myBaseFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	TweenService:Create(myBaseFill, TweenInfo.new(0.35), { BackgroundColor3 = orig }):Play()
end

function GameUI.start()
	local healthConnections: { RBXScriptConnection } = {}
	local function disconnectHealth()
		for _, connection in healthConnections do connection:Disconnect() end
		table.clear(healthConnections)
	end
	local function bindHero(character: Model)
		disconnectHealth()
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if not humanoid then return end
		local function updateHealth()
			local maximum = math.max(humanoid.MaxHealth, 1)
			local health = math.max(humanoid.Health, 0)
			local ratio = math.clamp(health / maximum, 0, 1)
			heroHpFill.Size = UDim2.fromScale(ratio, 1)
			heroHpFill.BackgroundColor3 = if ratio > 0.5 then Color3.fromRGB(75, 205, 105)
				elseif ratio > 0.25 then Color3.fromRGB(235, 190, 65)
				else Color3.fromRGB(225, 70, 65)
			heroHpLabel.Text = `HERO  •  {math.ceil(health)} / {math.ceil(maximum)}`
		end
		table.insert(healthConnections, humanoid.HealthChanged:Connect(updateHealth))
		table.insert(healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth))
		updateHealth()
	end
	player.CharacterAdded:Connect(bindHero)
	if player.Character then task.spawn(bindHero, player.Character) end

	Remotes.StateUpdate.OnClientEvent:Connect(refresh)

	Remotes.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		-- Victory/Defeat are handled by the MainMenu results screen
		if event == "MatchStart" then
			setQueueMode(false)
			if data and data.stageObjective then
				objectiveTitle.Text = `GOAL: {data.stageObjective} • {string.upper(data.stageName or "")}`
				evolveHint.Text = `{data.stageObjectiveDescription or ""} • {data.stageModifier or ""}: {data.stageModifierDescription or ""}`
			else
				objectiveTitle.Text = "GOAL: DESTROY THE ENEMY BASE"
				evolveHint.Text = "Kills grant XP • Evolve to unlock stronger armies"
			end
			showObjective()
			local mode = data and data.mode
			if mode == "PvP" then
				showMessage("1v1 BATTLE START", Color3.new(1, 1, 1), 2.5)
			else
				local diffText = (data and data.difficulty) and data.difficulty:upper() or "NORMAL"
				showMessage(`BATTLE START — {diffText} MODE`, Color3.new(1, 1, 1), 2.5)
			end
		elseif event == "AgeUp" and data then
			if data.side == lastState.playerSide then
				showMessage(`ADVANCED TO {Ages[data.age].name:upper()}!`, Ages[data.age].color:Lerp(Color3.new(1, 1, 1), 0.4), 3)
			else
				showMessage("Enemy advanced an age!", Color3.fromRGB(255, 160, 140), 3)
			end
		elseif event == "HeroRespawn" and data then
			task.spawn(function()
				for t = data.delay, 1, -1 do
					showMessage(`Respawn in {t}...`, Color3.fromRGB(220, 220, 220))
					task.wait(1)
				end
				msgLabel.Text = ""
			end)
		elseif event == "SpecialFired" and data then
			if data.side ~= lastState.playerSide then
				showMessage(`Enemy {data.name}! Take cover!`, Color3.fromRGB(255, 140, 120), 2.5)
				Accessibility.caption(`ENEMY {string.upper(data.name)} — TAKE COVER`, 2.5)
			end
		elseif event == "BaseUnderAttack" then
			baseAlarm()
		elseif event == "SynergyUnlocked" and data then
			if data.side == lastState.playerSide then
				showMessage(`{string.upper(data.name)} DOCTRINE LOCKED IN!`, Color3.fromRGB(245, 210, 110), 4)
			else
				showMessage(`Enemy formed {data.name}`, Color3.fromRGB(255, 140, 120), 3)
			end
		elseif event == "WaitingForOpponent" then
			showMessage("WAITING FOR AN OPPONENT TO JOIN...", Color3.fromRGB(245, 210, 110))
		elseif event == "QueueStatus" and data then
			setQueueMode(true)
			cancelQueueButton.Active = true
			cancelQueueButton.Text = "CANCEL MATCHMAKING"
			cancelQueueButton.Visible = true
			showMessage(`MATCHMAKING • QUEUE POSITION {data.position}`, Color3.fromRGB(130, 205, 255))
		elseif event == "MatchFound" then
			setQueueMode(true)
			cancelQueueButton.Visible = false
			showMessage("OPPONENT FOUND • CREATING MATCH SERVER...", Color3.fromRGB(120, 235, 150))
		elseif event == "QueueCancelled" then
			cancelQueueButton.Visible = false
			showMessage("MATCHMAKING CANCELLED", Color3.fromRGB(210, 210, 220), 3)
		elseif event == "QueueError" and data then
			cancelQueueButton.Visible = false
			showMessage(data.message or "MATCHMAKING RETRYING...", Color3.fromRGB(255, 150, 120), 5)
		elseif event == "OpponentJoinFailed" then
			showMessage("OPPONENT FAILED TO JOIN • RETURNING TO LOBBY", Color3.fromRGB(255, 150, 120))
		end
	end)
end

return GameUI
