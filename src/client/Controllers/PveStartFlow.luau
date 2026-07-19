--!strict
-- Shared PvE launch overlay. Keeps the originating screen recoverable until the
-- server accepts the request and gives players explicit retry/back controls.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Localization = require(ReplicatedStorage.Shared.Localization)

local PveStartFlow = {}

type Callbacks = {
	onCommitted: (() -> ())?,
	onRestore: (() -> ())?,
}

type Request = {
	id: string,
	mode: string,
	level: number,
	callbacks: Callbacks,
	committed: boolean,
	originVisible: boolean,
	watchdog: number,
	failed: boolean,
}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local active: Request? = nil
local initialized = false
local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local retryButton: TextButton? = nil
local backButton: TextButton? = nil
local cancelButton: TextButton? = nil
local RESPONSE_TIMEOUT = 15
local COMMITTED_TIMEOUT = 35

local function corner(parent: Instance, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

local function makeButton(parent: Instance, text: string, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromScale(0.34, 0.16)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextWrapped = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.ZIndex = 203
	button.Parent = parent
	corner(button, 8)
	return button
end

local function ensureOverlay()
	if panel then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PveStartFlowGui"
	gui.DisplayOrder = 90
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.28
	backdrop.BorderSizePixel = 0
	backdrop.Active = true
	backdrop.Visible = false
	backdrop.ZIndex = 200
	backdrop.Parent = gui
	panel = backdrop

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.72, 0.3)
	card.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
	card.BorderSizePixel = 0
	card.ZIndex = 201
	card.Parent = backdrop
	corner(card, 14)

	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(280, 190)
	size.MaxSize = Vector2.new(560, 260)
	size.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(240, 200, 80)
	stroke.Thickness = 2
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.08, 0.08)
	title.Size = UDim2.fromScale(0.84, 0.18)
	title.Font = Enum.Font.GothamBlack
	title.Text = Localization.t("pve_start.title")
	title.TextWrapped = true
	title.TextColor3 = Color3.fromRGB(240, 200, 80)
	title.TextScaled = true
	title.ZIndex = 202
	title.Parent = card

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0.08, 0.29)
	status.Size = UDim2.fromScale(0.84, 0.25)
	status.Font = Enum.Font.Gotham
	status.Text = Localization.t("pve_start.checking")
	status.TextColor3 = Color3.fromRGB(220, 220, 230)
	status.TextScaled = true
	status.TextWrapped = true
	status.ZIndex = 202
	status.Parent = card
	statusLabel = status

	cancelButton = makeButton(card, Localization.t("common.cancel"), UDim2.fromScale(0.5, 0.76), Color3.fromRGB(120, 65, 65))
	retryButton = makeButton(card, Localization.t("common.retry"), UDim2.fromScale(0.3, 0.76), Color3.fromRGB(50, 145, 80))
	backButton = makeButton(card, Localization.t("common.back"), UDim2.fromScale(0.7, 0.76), Color3.fromRGB(85, 85, 100))
	retryButton.Visible = false
	backButton.Visible = false
end

local function setVisible(visible: boolean)
	ensureOverlay()
	(panel :: Frame).Visible = visible
end

local function restoreOrigin(request: Request)
	if request.originVisible then return end
	request.originVisible = true
	if request.callbacks.onRestore then
		request.callbacks.onRestore()
	end
end

local function showFailure(request: Request, message: string)
	if active ~= request then return end
	restoreOrigin(request)
	statusLabel.Text = message
	cancelButton.Visible = false
	retryButton.Visible = true
	backButton.Visible = true
end

local function armWatchdog(request: Request, timeout: number)
	request.watchdog += 1
	local generation = request.watchdog
	task.delay(timeout, function()
		if active ~= request or request.watchdog ~= generation then return end
		request.failed = true
		request.watchdog += 1
		if not request.committed then
			Remotes.CancelPveStart:FireServer(request.id)
		end
		showFailure(request, Localization.t("pve_start.timeout"))
	end)
end

local function sendRequest(request: Request)
	active = request
	request.failed = false
	request.committed = false
	setVisible(true)
	statusLabel.Text = Localization.t("pve_start.checking")
	cancelButton.Text = Localization.t("common.cancel")
	cancelButton.Active = true
	cancelButton.Visible = true
	retryButton.Visible = false
	backButton.Visible = false
	Remotes.StartPveLevel:FireServer(request.mode, request.level, request.id)
	armWatchdog(request, RESPONSE_TIMEOUT)
end

local function retry()
	local old = active
	if not old then return end
	local request: Request = {
		id = HttpService:GenerateGUID(false),
		mode = old.mode,
		level = old.level,
		callbacks = old.callbacks,
		committed = false,
		originVisible = true,
		watchdog = 0,
		failed = false,
	}
	sendRequest(request)
end

local function goBack()
	local request = active
	if not request then return end
	active = nil
	request.watchdog += 1
	setVisible(false)
	restoreOrigin(request)
end

local function initialize()
	if initialized then return end
	initialized = true
	ensureOverlay()

	cancelButton.Activated:Connect(function()
		local request = active
		if not request or request.committed then return end
		cancelButton.Active = false
		cancelButton.Text = Localization.t("common.cancelling")
		statusLabel.Text = Localization.t("pve_start.cancelling")
		Remotes.CancelPveStart:FireServer(request.id)
	end)
	retryButton.Activated:Connect(retry)
	backButton.Activated:Connect(goBack)

	Remotes.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		local request = active
		if not request then return end
		local requestId = data and data.requestId
		if event ~= "MatchStart" and requestId ~= request.id then return end
		if request.failed and event ~= "MatchStart" then return end

		if event == "PveStartStatus" then
			local stage = data and data.stage
			if stage == "teleporting" or stage == "starting" then
				if not request.committed then
					request.committed = true
					if request.callbacks.onCommitted then request.callbacks.onCommitted() end
					request.originVisible = false
				end
				statusLabel.Text = if stage == "teleporting"
					then Localization.t("pve_start.server_ready")
					else Localization.t("pve_start.starting")
				cancelButton.Visible = false
				armWatchdog(request, COMMITTED_TIMEOUT)
			else
				statusLabel.Text = (data and data.message) or Localization.t("pve_start.preparing")
				armWatchdog(request, RESPONSE_TIMEOUT)
			end
		elseif event == "PveStartError" then
			request.failed = true
			request.watchdog += 1
			showFailure(request, (data and data.message) or Localization.t("pve_start.failed"))
		elseif event == "PveStartCancelled" then
			active = nil
			request.watchdog += 1
			setVisible(false)
			restoreOrigin(request)
		elseif event == "MatchStart" then
			active = nil
			request.watchdog += 1
			setVisible(false)
		end
	end)
end

function PveStartFlow.request(mode: string, level: number, callbacks: Callbacks?): boolean
	initialize()
	if active then return false end
	local request: Request = {
		id = HttpService:GenerateGUID(false),
		mode = mode,
		level = level,
		callbacks = callbacks or {},
		committed = false,
		originVisible = true,
		watchdog = 0,
		failed = false,
	}
	sendRequest(request)
	return true
end

return PveStartFlow
