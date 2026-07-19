--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameUI = require(script.Parent.GameUI)

local TutorialController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.GothamBold
local GOLD = Color3.fromRGB(240, 200, 80)
local PANEL = Color3.fromRGB(18, 18, 24)

local tutorialDone = true
local currentStep = 1
local isActive = false
local stepTwoStartXp = 0

local gui: ScreenGui? = nil
local hintFrame: Frame? = nil
local hintLabel: TextLabel? = nil
local currentTween: Tween? = nil
local dismissed = false -- player closed the tutorial for this session

-- bouncing arrow + gold highlight pointing at the button for the current step
local arrow: TextLabel? = nil
local highlightStroke: UIStroke? = nil
local pointTarget: GuiObject? = nil
local skipStepButton: TextButton? = nil

local function pointAt(target: GuiObject?)
	if pointTarget == target then return end
	pointTarget = target
	if highlightStroke then
		highlightStroke:Destroy()
		highlightStroke = nil
	end
	if target then
		local s = Instance.new("UIStroke")
		s.Color = GOLD
		s.Thickness = 3
		s.Parent = target
		highlightStroke = s
	end
	if arrow then
		arrow.Visible = target ~= nil
	end
end

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

local hideTutorialRef: () -> () = function() end
local setStepRef: (number) -> () = function() end

local function createUI()
	if gui then return end

	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.82, 0)
	frame.Size = UDim2.new(0.9, 0, 0, 64)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(280, 64)
	sizeConstraint.MaxSize = Vector2.new(420, 80)
	sizeConstraint.Parent = frame
	corner(frame, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Transparency = 0.3
	stroke.Thickness = 2
	stroke.Parent = frame

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 28, 38)),
	})
	grad.Rotation = 45
	grad.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 15)
	pad.PaddingRight = UDim.new(0, 15)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = frame

	local l = label(frame, {
		Size = UDim2.new(1, -94, 1, 0),
		Text = "",
		TextSize = 15,
		TextScaled = false,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	local skipStep = Instance.new("TextButton")
	skipStep.AnchorPoint = Vector2.new(1, 0.5)
	skipStep.Position = UDim2.fromScale(1, 0.5)
	skipStep.Size = UDim2.fromOffset(86, 34)
	skipStep.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
	skipStep.Text = "SKIP STEP"
	skipStep.Font = FONT
	skipStep.TextSize = 12
	skipStep.TextColor3 = Color3.fromRGB(220, 220, 230)
	skipStep.Parent = frame
	corner(skipStep, 8)
	skipStepButton = skipStep

	-- dismiss button (tutorials must always be skippable)
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 6, 0, -14)
	close.Size = UDim2.new(0, 22, 0, 22)
	close.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	close.Text = "X"
	close.Font = FONT
	close.TextSize = 13
	close.TextColor3 = Color3.fromRGB(220, 220, 230)
	close.Parent = frame
	corner(close, 11)
	close.Activated:Connect(function()
		dismissed = true
		pointAt(nil)
		hideTutorialRef()
	end)
	skipStep.Activated:Connect(function()
		if not isActive then return end
		if currentStep < 5 then
			setStepRef(currentStep + 1)
		else
			dismissed = true
			pointAt(nil)
			hideTutorialRef()
		end
	end)

	-- arrow that bounces above whichever button the current step points at
	local a = Instance.new("TextLabel")
	a.BackgroundTransparency = 1
	a.Size = UDim2.new(0, 40, 0, 40)
	a.AnchorPoint = Vector2.new(0.5, 1)
	a.Font = FONT
	a.Text = "▼"
	a.TextSize = 30
	a.TextColor3 = GOLD
	a.Visible = false
	a.ZIndex = 50
	a.Parent = gui
	arrow = a

	hintFrame = frame
	hintLabel = l
end

local function setStep(step: number)
	currentStep = step

	if not hintLabel then return end
	if step == 1 then
		hintLabel.Text = if UserInputService.TouchEnabled then "Tap the first unit card to recruit a Club Man"
			elseif UserInputService.GamepadEnabled then "Press D-pad Up to recruit a Club Man"
			else "Press 1 to recruit a Club Man"
		pointAt(GameUI.getSlotButton(1))
	elseif step == 2 then
		hintLabel.Text = "Damage the enemy base or defeat an enemy to earn XP"
		pointAt(nil)
	elseif step == 3 then
		hintLabel.Text = "Build a turret with your hotbar"
		pointAt(GameUI.getSlotButton(5))
	elseif step == 4 then
		hintLabel.Text = "Evolve to the next Age when your XP is full"
		pointAt(nil) -- points at the Evolve button once canEvolve is true
	elseif step == 5 then
		hintLabel.Text = "Destroy the enemy base to win! First win grants bonus XP -> Level 2"
		pointAt(nil)
	end
	if skipStepButton then
		skipStepButton.Text = if step == 5 then "FINISH" else "SKIP STEP"
	end
end
setStepRef = setStep

local function showTutorial()
	if not tutorialDone and not isActive and not dismissed then
		isActive = true
		createUI()
		if hintFrame then
			if currentTween then currentTween:Cancel() end
			hintFrame.BackgroundTransparency = 1
			hintFrame.Visible = true

			local stroke = hintFrame:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Transparency = 1 end

			if hintLabel then hintLabel.TextTransparency = 1 end

			currentTween = TweenService:Create(hintFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0.1
			})
			currentTween:Play()

			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0.3
				}):Play()
			end

			if hintLabel then
				TweenService:Create(hintLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0
				}):Play()
			end
		end
		setStep(1)
	end
end

local function hideTutorial()
	if not isActive then return end
	isActive = false
	pointAt(nil)
	if hintFrame and hintFrame.Visible then
		if currentTween then currentTween:Cancel() end

		local stroke = hintFrame:FindFirstChildOfClass("UIStroke")

		currentTween = TweenService:Create(hintFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1
		})
		currentTween:Play()

		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1
			}):Play()
		end

		if hintLabel then
			TweenService:Create(hintLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1
			}):Play()
		end

		task.delay(0.25, function()
			if not isActive and hintFrame then
				hintFrame.Visible = false
			end
		end)
	end
end
hideTutorialRef = hideTutorial

function TutorialController.start()
	Remotes.ProfileSync.OnClientEvent:Connect(function(profile)
		if typeof(profile) == "table" then
			tutorialDone = profile.tutorialDone == true
			if tutorialDone then
				hideTutorial()
			end
		end
	end)

	Remotes.RequestProfile:FireServer()

	Remotes.StateUpdate.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" then
			if state.status == "Active" and state.mode == "PvE" and not tutorialDone then
				if not isActive then
					showTutorial()
				end

				if currentStep == 1 and typeof(state.unitCount) == "number" and state.unitCount > 0 then
					stepTwoStartXp = typeof(state.xp) == "number" and state.xp or 0
					setStep(2)
				end

				if currentStep == 2 and typeof(state.xp) == "number" and state.xp > stepTwoStartXp then
					setStep(3)
				end

				if currentStep == 3 and state.turrets then
					local hasTurret = false
					for _, v in state.turrets do
						if v ~= false and v ~= nil then
							hasTurret = true
							break
						end
					end
					if hasTurret then
						setStep(4)
					end
				end

				-- step 4: point at the Evolve button only once evolving is possible
				if currentStep == 4 then
					if state.canEvolve == true then
						pointAt(GameUI.getEvolveButton())
					else
						pointAt(nil)
					end
				end
			else
				hideTutorial()
			end
		end
	end)

	Remotes.MatchEvent.OnClientEvent:Connect(function(event, data)
		if event == "AgeUp" and currentStep == 4 then
			local side = player:GetAttribute("Side")
			if data and data.side == side then
				setStep(5)
			end
		elseif event == "Victory" or event == "Defeat" or event == "ReturnToMenu" then
			hideTutorial()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not isActive or tutorialDone then return end

		local now = os.clock()

		-- keep the arrow bouncing above its target button
		if arrow and arrow.Visible and pointTarget then
			local pos = pointTarget.AbsolutePosition
			local size = pointTarget.AbsoluteSize
			local bounce = math.sin(now * 4) * 6
			arrow.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 6 + bounce)
		end
	end)
end

return TutorialController
