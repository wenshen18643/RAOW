--!strict
-- Applies accessibility preferences that span multiple UI/controllers.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(script.Parent.Settings)
local Localization = require(ReplicatedStorage.Shared.Localization)

local Accessibility = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local SCALE_NAME = "AccessibilityUIScale"
local captionLabel: TextLabel? = nil
local captionRevision = 0
local lastCamera: Camera? = nil
local lastCameraType: Enum.CameraType? = nil

local function uiScale(): number
	return 0.85 + math.clamp(Settings.get("uiScale") or 0.5, 0, 1) * 0.3
end

local function isFullScreenContainer(item: GuiObject): boolean
	return item.Size.X.Scale >= 0.98
		and item.Size.Y.Scale >= 0.98
		and item.Size.X.Offset == 0
		and item.Size.Y.Offset == 0
end

local function shouldScale(item: GuiObject): boolean
	local parent = item.Parent
	if parent and parent:IsA("ScreenGui") then
		return not isFullScreenContainer(item)
	end
	return parent ~= nil
		and parent:IsA("GuiObject")
		and parent:GetAttribute("AccessibilityScaleChildren") == true
end

local function applyScale(item: Instance)
	if not item:IsA("GuiObject") or not shouldScale(item) then return end
	local scale = item:FindFirstChild(SCALE_NAME)
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = SCALE_NAME
		scale.Parent = item
	end
	(scale :: UIScale).Scale = uiScale()
end

local function refreshScale()
	for _, item in playerGui:GetDescendants() do applyScale(item) end
end

local function applyFov()
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType == Enum.CameraType.Scriptable then return end
	camera.FieldOfView = math.clamp(Settings.get("fieldOfView") or 70, 60, 100)
end

local function createCaptions()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AccessibilityCaptions"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 120
	gui.Parent = playerGui

	local text = Instance.new("TextLabel")
	text.Name = "CriticalCue"
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Position = UDim2.fromScale(0.5, 0.78)
	text.Size = UDim2.new(0.72, 0, 0, 44)
	text.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	text.BackgroundTransparency = 0.18
	text.BorderSizePixel = 0
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextSize = 20
	text.TextWrapped = true
	text.Text = ""
	text.Visible = false
	text.ZIndex = 120
	text.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(240, 200, 80)
	stroke.Transparency = 0.2
	stroke.Thickness = 1.5
	stroke.Parent = text
	captionLabel = text
end

function Accessibility.caption(text: string, duration: number?)
	if not Settings.get("criticalCaptions") or not captionLabel then return end
	captionRevision += 1
	local expected = captionRevision
	captionLabel.Text = Localization.t("caption.sound", { text = text })
	captionLabel.Visible = true
	task.delay(duration or 2.5, function()
		if expected == captionRevision and captionLabel then
			captionLabel.Visible = false
		end
	end)
end

function Accessibility.start()
	createCaptions()
	refreshScale()
	applyFov()

	playerGui.DescendantAdded:Connect(function(item)
		task.defer(applyScale, item)
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		task.defer(applyFov)
	end)
	Settings.onChanged(function(key)
		if key == "uiScale" then
			refreshScale()
		elseif key == "fieldOfView" then
			applyFov()
		elseif key == "criticalCaptions" and not Settings.get("criticalCaptions") and captionLabel then
			captionRevision += 1
			captionLabel.Visible = false
		end
	end)

	-- Camera controllers replace CameraType while entering/leaving matches.
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and (camera ~= lastCamera or camera.CameraType ~= lastCameraType) then
			lastCamera = camera
			lastCameraType = camera.CameraType
			applyFov()
		end
	end)
end

return Accessibility
