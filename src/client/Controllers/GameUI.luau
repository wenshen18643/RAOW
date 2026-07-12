--!strict
-- HUD + hotbar: gold, XP/age, base HP bars, unit/turret/special buttons, messages, crosshair.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Units = require(ReplicatedStorage.Shared.Config.Units)
local Turrets = require(ReplicatedStorage.Shared.Config.Turrets)
local Specials = require(ReplicatedStorage.Shared.Config.Specials)
local Ages = require(ReplicatedStorage.Shared.Config.Ages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Audio = require(script.Parent.Audio)

local GameUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.GothamBold

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
label(myBaseBg, { Size = UDim2.fromScale(1, 1), Text = "YOUR BASE", ZIndex = 3, TextTransparency = 0.25 })
local enBaseBg, enBaseFill = bar(gui, UDim2.new(0.73, 0, 0.03, 0), UDim2.new(0.25, 0, 0.03, 0), Color3.fromRGB(220, 80, 70))
label(enBaseBg, { Size = UDim2.fromScale(1, 1), Text = "ENEMY BASE", ZIndex = 3, TextTransparency = 0.25 })

-- Age + XP (top center)
local ageLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.02, 0),
	Size = UDim2.new(0.2, 0, 0.035, 0),
	Text = "Stone Age",
})
local xpBg, xpFill = bar(gui, UDim2.new(0.4, 0, 0.06, 0), UDim2.new(0.2, 0, 0.018, 0), Color3.fromRGB(240, 200, 80))
local xpLabel = label(xpBg, { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3 })

-- Difficulty Label (top right)
local diffLabel = label(gui, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(0.98, 0, 0.02, 0),
	Size = UDim2.new(0.15, 0, 0.03, 0),
	Text = "Difficulty: Normal",
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(150, 200, 150),
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
	upgButtons[stat] = { btn = b, cost = costL }
	b.Activated:Connect(function()
		Audio.play("click")
		Remotes.BuyUpgrade:FireServer(stat)
	end)
end

makeUpgBtn("dmg", "[1] DAMAGE +15%")
makeUpgBtn("health", "[2] HEALTH +15%")
makeUpgBtn("def", "[3] DEFENSE +10%")

upgradesToggle.Activated:Connect(function()
	Audio.play("click")
	upgradesPanel.Visible = not upgradesPanel.Visible
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

local lastState: { [string]: any } = {}

local function slotAction(i: number)
	Audio.play("click")
	local age = lastState.age or 1
	if i <= 4 then
		local def = Units.byAge[age][i]
		if def then
			Remotes.SpawnUnit:FireServer(def.id)
		end
	elseif i == 5 then
		-- build in first empty slot
		local turrets = lastState.turrets or {}
		for slotIdx = 1, 4 do
			if turrets[slotIdx] == false or turrets[slotIdx] == nil then
				Remotes.BuildTurret:FireServer(slotIdx)
				return
			end
		end
	elseif i == 6 then
		Remotes.UseSpecial:FireServer()
	end
end

for i, slot in slots do
	slot.btn.Activated:Connect(function()
		slotAction(i)
	end)
end
evolveBtn.Activated:Connect(function()
	Audio.play("buy")
	Remotes.Evolve:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
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
	}
	if key == Enum.KeyCode.E then
		Audio.play("click")
		upgradesPanel.Visible = not upgradesPanel.Visible
	elseif map[key] then
		local num = map[key]
		if upgradesPanel.Visible and num <= 3 then
			Audio.play("click")
			local stats = { "dmg", "health", "def" }
			Remotes.BuyUpgrade:FireServer(stats[num])
		else
			slotAction(num)
		end
	elseif key == Enum.KeyCode.Q then
		Remotes.Evolve:FireServer()
	end
end)

-- State-driven refresh
local function refresh(state: { [string]: any })
	lastState = state
	local age = state.age :: number
	local gold = state.gold :: number

	goldLabel.Text = `{math.floor(gold)} g`
	countLabel.Text = `units {state.unitCount}/20  queue {state.queueCount}`
	ageLabel.Text = state.ageName
	ageLabel.TextColor3 = Ages[age].color:Lerp(Color3.new(1, 1, 1), 0.5)

	if state.nextAgeXp then
		local prevReq = Ages[age].xpRequired
		local frac = math.clamp((state.xp - prevReq) / (state.nextAgeXp - prevReq), 0, 1)
		xpFill.Size = UDim2.fromScale(frac, 1)
		xpLabel.Text = `XP {math.floor(state.xp)} / {state.nextAgeXp}`
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = "MAX AGE"
	end

	if state.difficulty then
		diffLabel.Text = `Difficulty: {state.difficulty}`
		local colors = { Normal = Color3.fromRGB(150, 200, 150), Harder = Color3.fromRGB(200, 180, 120), Impossible = Color3.fromRGB(220, 120, 120) }
		diffLabel.TextColor3 = colors[state.difficulty] or Color3.new(1, 1, 1)
	end

	evolveBtn.Visible = state.canEvolve
	evolveBtn.BackgroundColor3 = Color3.fromRGB(90, 180, 90)

	-- updates upgrades buttons
	local u = state.heroUpgrades or { dmg = 0, health = 0, def = 0 }
	for stat, ui in upgButtons do
		local lvl = u[stat] or 0
		if stat == "def" and lvl >= 5 then
			ui.cost.Text = "MAX"
			ui.btn.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
		else
			local cost = 500 * (2 ^ lvl)
			ui.cost.Text = `{cost} g (Lv{lvl})`
			ui.btn.BackgroundColor3 = gold >= cost and Color3.fromRGB(45, 60, 45) or Color3.fromRGB(60, 30, 30)
		end
	end

	myBaseFill.Size = UDim2.fromScale(math.clamp(state.baseHpSelf / state.baseMaxHp, 0, 1), 1)
	enBaseFill.Size = UDim2.fromScale(math.clamp(state.baseHpEnemy / state.baseMaxHp, 0, 1), 1)

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

local function showMessage(text: string, color: Color3, duration: number?)
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

-- Show/hide the in-match HUD (hidden while the main menu is open).
function GameUI.setHudVisible(visible: boolean)
	gui.Enabled = visible
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
	local orig = myBaseFill.BackgroundColor3
	myBaseFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	TweenService:Create(myBaseFill, TweenInfo.new(0.35), { BackgroundColor3 = orig }):Play()
end

function GameUI.start()
	Remotes.StateUpdate.OnClientEvent:Connect(refresh)

	Remotes.DifficultySelected.OnClientEvent:Connect(function(diff: string)
		diffLabel.Text = `Difficulty: {diff}`
	end)

	Remotes.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		-- Victory/Defeat are handled by the MainMenu results screen
		if event == "MatchStart" then
			local diffText = (data and data.difficulty) and data.difficulty:upper() or "NORMAL"
			showMessage(`BATTLE START — {diffText} MODE`, Color3.new(1, 1, 1), 3)
		elseif event == "AgeUp" and data then
			if data.side == "A" then
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
			if data.side ~= "A" then
				showMessage(`Enemy {data.name}! Take cover!`, Color3.fromRGB(255, 140, 120), 2.5)
			end
		elseif event == "BaseUnderAttack" then
			baseAlarm()
		end
	end)
end

return GameUI
