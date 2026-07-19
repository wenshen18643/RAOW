--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PvELevels = require(ReplicatedStorage.Shared.Config.PvELevels)
local UISelection = require(script.Parent.UISelection)

local LobbyPortals = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local FONT = Enum.Font.GothamBold
local FONT_BLACK = Enum.Font.GothamBlack
local GOLD = Color3.fromRGB(240, 200, 80)

local currentProfile: any = nil
local cancelledPad: BasePart? = nil
local confirmPanel: Frame? = nil
local activePad: BasePart? = nil
local selectedLevel: number = 1

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
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
	corner(btn, 8)
	
	local baseSize = size
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {
			Size = UDim2.new(baseSize.X.Scale * 1.05, baseSize.X.Offset * 1.05, baseSize.Y.Scale * 1.05, baseSize.Y.Offset * 1.05),
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15),
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { Size = baseSize, BackgroundColor3 = color }):Play()
	end)
	btn.Activated:Connect(onClick)
	return btn
end

-- Roblox re-locks the cursor to screen center every frame while the camera is
-- in (or zoomed into) first person, so a one-time MouseBehavior write is not
-- enough — we must override it after each camera update while the panel is up.
local CURSOR_UNLOCK_BINDING = "LobbyPortalCursorUnlock"
local cursorUnlockBound = false

local function setCursorUnlocked(unlocked: boolean)
	if unlocked == cursorUnlockBound then return end
	cursorUnlockBound = unlocked
	if unlocked then
		RunService:BindToRenderStep(CURSOR_UNLOCK_BINDING, Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
	else
		RunService:UnbindFromRenderStep(CURSOR_UNLOCK_BINDING)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function closeConfirmPanel()
	if confirmPanel then
		confirmPanel:Destroy()
		confirmPanel = nil
	end
	activePad = nil
	setCursorUnlocked(false)
end

local function openConfirmPanel(pad: BasePart)
	closeConfirmPanel()
	activePad = pad
	setCursorUnlocked(true)
	
	local mode = pad:GetAttribute("Mode") :: string
	local pveMode = pad:GetAttribute("PveMode") :: string?
	local portalColor = pad.Color
	
	local gui = playerGui:FindFirstChild("LobbyPortalGui") :: ScreenGui?
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "LobbyPortalGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.Parent = playerGui
	end
	
	local panelFrame = Instance.new("Frame")
	panelFrame.Name = "ConfirmPanel"
	panelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	panelFrame.Position = UDim2.fromScale(0.5, 0.5)
	panelFrame.Size = UDim2.fromScale(0.82, 0.72)
	panelFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	panelFrame.BorderSizePixel = 0
	panelFrame.ZIndex = 100
	panelFrame.Parent = gui
	confirmPanel = panelFrame
	corner(panelFrame, 14)
	UISelection.bind(panelFrame, nil, closeConfirmPanel)

	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MinSize = Vector2.new(260, 220)
	panelSize.MaxSize = Vector2.new(700, 600)
	panelSize.Parent = panelFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = portalColor
	stroke.Thickness = 2.5
	stroke.Parent = panelFrame
	
	-- Title
	local titleText = if mode == "pvp" then "RANKED 1v1" else `{string.upper(pveMode or "NORMAL")} CAMPAIGN`
	label(panelFrame, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.8, 0.08),
		Text = titleText,
		Font = FONT_BLACK,
		TextColor3 = portalColor,
	})
	
	if mode == "pvp" then
		-- Show PvP Rating
		local ratingVal = currentProfile and currentProfile.rating or 1000
		label(panelFrame, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.8, 0.08),
			Text = `YOUR RATING: {ratingVal}`,
			TextColor3 = Color3.new(1, 1, 1),
		})
		label(panelFrame, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.35),
			Size = UDim2.fromScale(0.8, 0.06),
			Text = "Queue for matchmaking against another player.",
			TextColor3 = Color3.fromRGB(170, 170, 180),
		})
		
		-- Buttons
		button(panelFrame, "QUEUE BATTLE", UDim2.fromScale(0.28, 0.8), UDim2.fromScale(0.36, 0.075), Color3.fromRGB(50, 150, 80), function()
			Remotes.SelectMode:FireServer("pvp")
			cancelledPad = pad
			closeConfirmPanel()
		end)
		
		button(panelFrame, "CANCEL", UDim2.fromScale(0.72, 0.8), UDim2.fromScale(0.36, 0.075), Color3.fromRGB(120, 60, 60), function()
			cancelledPad = pad
			closeConfirmPanel()
		end)
		
	elseif mode == "pve" and pveMode then
		-- Show PvE levels picker
		local prog = 0
		if currentProfile and currentProfile.pveProgress then
			prog = currentProfile.pveProgress[pveMode] or 0
		end
		
		-- Default selected level is prog + 1
		selectedLevel = prog + 1
		
		label(panelFrame, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.14),
			Size = UDim2.fromScale(0.8, 0.05),
			Text = "Select a level to start your assault",
			TextColor3 = Color3.fromRGB(180, 190, 200),
		})
		
		local scroll = Instance.new("ScrollingFrame")
		scroll.AnchorPoint = Vector2.new(0.5, 0)
		scroll.Position = UDim2.fromScale(0.5, 0.22)
		scroll.Size = UDim2.fromScale(0.88, 0.48)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.ZIndex = 101
		scroll.Parent = panelFrame
		
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.25, -6, 0, 72)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll
		
		local goBtn: TextButton
		local function updateGoText()
			goBtn.Text = `GO — LEVEL {selectedLevel}`
		end
		
		local totalLevelsToShow = math.max(20, prog + 4)
		local levelButtons: { [number]: { btn: TextButton, stroke: UIStroke } } = {}
		
		local function refreshGridHighlights()
			for lvl, data in levelButtons do
				data.stroke.Enabled = (lvl == selectedLevel)
			end
		end
		
		for lvl = 1, totalLevelsToShow do
			local isLocked = lvl > prog + 1
			local isNext = lvl == prog + 1
			local isBoss = PvELevels.isBossLevel(lvl)
			
			local btnColor = if isLocked then Color3.fromRGB(40, 40, 45)
				elseif isNext then Color3.fromRGB(150, 110, 40)
				elseif isBoss then Color3.fromRGB(180, 50, 50)
				else Color3.fromRGB(60, 100, 140)
				
			local btn = Instance.new("TextButton")
			btn.BackgroundColor3 = btnColor
			btn.BorderSizePixel = 0
			btn.LayoutOrder = lvl
			btn.ZIndex = 102
			btn.Parent = scroll
			corner(btn, 8)
			
			local innerStroke = Instance.new("UIStroke")
			innerStroke.Color = GOLD
			innerStroke.Thickness = 2.5
			innerStroke.Enabled = (lvl == selectedLevel)
			innerStroke.Parent = btn
			levelButtons[lvl] = { btn = btn, stroke = innerStroke }
			
			label(btn, {
				Position = UDim2.fromScale(0, 0.1),
				Size = UDim2.fromScale(1, 0.35),
				Text = `Lv {lvl}`,
				TextColor3 = if isLocked then Color3.fromRGB(120, 120, 120) else Color3.new(1, 1, 1),
				ZIndex = 103,
			})
			
			if isLocked then
				label(btn, {
					Position = UDim2.fromScale(0, 0.55),
					Size = UDim2.fromScale(1, 0.3),
					Text = "LOCKED",
					TextColor3 = Color3.fromRGB(180, 60, 60),
					ZIndex = 103,
				})
			elseif isBoss then
				label(btn, {
					Position = UDim2.fromScale(0, 0.55),
					Size = UDim2.fromScale(1, 0.3),
					Text = "BOSS",
					TextColor3 = Color3.fromRGB(255, 200, 200),
					ZIndex = 103,
				})
			end
			
			btn.Activated:Connect(function()
				if not isLocked then
					selectedLevel = lvl
					updateGoText()
					refreshGridHighlights()
				end
			end)
		end
		
		scroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil(totalLevelsToShow / 4) * 80)
		
		-- Buttons
		goBtn = button(panelFrame, `GO — LEVEL {selectedLevel}`, UDim2.fromScale(0.28, 0.82), UDim2.fromScale(0.36, 0.075), Color3.fromRGB(50, 150, 80), function()
			Remotes.StartPveLevel:FireServer(pveMode, selectedLevel)
			cancelledPad = pad
			closeConfirmPanel()
		end)
		
		button(panelFrame, "CANCEL", UDim2.fromScale(0.72, 0.82), UDim2.fromScale(0.36, 0.075), Color3.fromRGB(120, 60, 60), function()
			cancelledPad = pad
			closeConfirmPanel()
		end)
	end
end

local function onStandingPadChanged(prev: BasePart?, curr: BasePart?)
	if not curr then
		cancelledPad = nil
		closeConfirmPanel()
	else
		if curr ~= cancelledPad then
			openConfirmPanel(curr)
		end
	end
end

function LobbyPortals.start()
	local serverType = workspace:GetAttribute("ServerType")
	if not serverType then
		workspace:GetAttributeChangedSignal("ServerType"):Wait()
		serverType = workspace:GetAttribute("ServerType")
	end
	
	if serverType ~= "lobby" then return end

	Remotes.ProfileSync.OnClientEvent:Connect(function(profile)
		currentProfile = profile
	end)

	-- Client-side ambience: animates the anchored crystal/ring above the island
	-- so the server never replicates per-frame CFrame writes.
	task.spawn(function()
		local RunService = game:GetService("RunService")
		local folder = workspace:WaitForChild("MatchmakingLobby", 30)
		if not folder then return end
		local crystal = folder:WaitForChild("LobbyCrystal", 10)
		if not crystal or not crystal:IsA("BasePart") then return end
		local origin = crystal.Position - Vector3.new(0, 20, 0)
		local ringParts: { BasePart } = {}
		for i = 1, 4 do
			local p = folder:FindFirstChild(`LobbyRingPart_{i}`)
			if p and p:IsA("BasePart") then table.insert(ringParts, p) end
		end
		local rot = 0
		RunService.RenderStepped:Connect(function(dt)
			rot += dt * 48
			local t = os.clock()
			local yOffset = 20 + math.sin(t * 1.5) * 1.5
			crystal.CFrame = CFrame.new(origin + Vector3.new(0, yOffset, 0)) * CFrame.Angles(0, math.rad(rot), 0)
			for i, p in ringParts do
				local angle = math.rad(-rot * 1.2) + (i - 1) * math.pi / 2
				local offset = Vector3.new(math.cos(angle) * 8, yOffset, math.sin(angle) * 8)
				p.CFrame = CFrame.new(origin + offset) * CFrame.Angles(0, -angle + math.pi / 2, 0.3 * math.sin(t * 2))
			end
		end)
	end)
	
	task.spawn(function()
		while true do
			task.wait(0.1)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			
			local foundPad: BasePart? = nil
			if hrp then
				local hrpPos = hrp.Position
				for _, pad in CollectionService:GetTagged("ModePortal") do
					if pad:IsA("BasePart") then
						local offset = hrpPos - pad.Position
						local horizontalDist = Vector2.new(offset.X, offset.Z).Magnitude
						local verticalDist = math.abs(offset.Y)
						if horizontalDist <= 7.5 and verticalDist <= 5 then
							foundPad = pad
							break
						end
					end
				end
			end
			
			if foundPad ~= activePad then
				local prevPad = activePad
				activePad = foundPad
				onStandingPadChanged(prevPad, foundPad)
			end
		end
	end)
end

return LobbyPortals
