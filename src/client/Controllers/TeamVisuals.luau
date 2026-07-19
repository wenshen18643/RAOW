--!strict
-- Applies local-perspective ally/enemy colors to replicated unit models.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(script.Parent.Settings)
local TeamVisuals = {}
local localSide: string? = nil
local ALLY = Color3.fromRGB(65, 155, 255)
local ENEMY = Color3.fromRGB(255, 75, 65)
local ACCESSIBLE_ALLY = Color3.fromRGB(0, 170, 230)
local ACCESSIBLE_ENEMY = Color3.fromRGB(255, 145, 0)

local function allyColor(): Color3
	if Settings.get("colorblindTeams") then return ACCESSIBLE_ALLY end
	local themeId = Players.LocalPlayer:GetAttribute("ArmyTheme")
	local theme = typeof(themeId) == "string" and MonetizationConfig.themeById(themeId) or nil
	return theme and theme.color or ALLY
end

local function updateBody(body: BasePart)
	local side = body:GetAttribute("Side")
	if not localSide or typeof(side) ~= "string" then return end
	local allied = side == localSide
	local color = allied and allyColor() or (Settings.get("colorblindTeams") and ACCESSIBLE_ENEMY or ENEMY)
	local model = body:FindFirstAncestorOfClass("Model")
	if model then
		local stripe = model:FindFirstChild("Stripe", true)
		if stripe and stripe:IsA("BasePart") then
			stripe.Color = color
			stripe.Material = if allied then Enum.Material.SmoothPlastic else Enum.Material.Neon
		end
	end
	local highlight = model and model:FindFirstChild("TeamOutline") :: Highlight?
	if highlight then
		highlight.FillColor = color
		highlight.OutlineColor = color
	end
	local hpBar = body:FindFirstChild("HpBar")
	local teamLabel = hpBar and hpBar:FindFirstChild("TeamLabel", true) :: TextLabel?
	if teamLabel then
		local role = string.upper((body:GetAttribute("Role") :: string?) or "UNIT")
		local commanderTitle = body:GetAttribute("CommanderTitle")
		local titleText = typeof(commanderTitle) == "string" and commanderTitle ~= "" and `  [{string.upper(commanderTitle)}]` or ""
		teamLabel.Text = (allied and `[A] ALLY{titleText}  {role}` or `[E] ENEMY{titleText}  {role}`)
		teamLabel.TextColor3 = color
	end
	local fill = hpBar and hpBar:FindFirstChild("Fill", true) :: Frame?
	if fill then fill.BackgroundColor3 = color end
end

local function updateBase(core: BasePart)
	local side = core:GetAttribute("Side")
	if not localSide or typeof(side) ~= "string" then return end
	local allied = side == localSide
	local model = core:FindFirstAncestorOfClass("Model")
	if model then
		local highlight = model:FindFirstChild("LocalBaseOutline") :: Highlight?
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "LocalBaseOutline"
			highlight.Adornee = model
			highlight.FillTransparency = 1
			highlight.OutlineTransparency = 0.35
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = model
		end
		highlight.OutlineColor = allied and allyColor()
			or (Settings.get("colorblindTeams") and ACCESSIBLE_ENEMY or ENEMY)
	end
	local marker = core:FindFirstChild("LocalBaseMarker") :: BillboardGui?
	if not marker then
		marker = Instance.new("BillboardGui")
		marker.Name = "LocalBaseMarker"
		marker.Size = UDim2.fromOffset(150, 30)
		marker.StudsOffsetWorldSpace = Vector3.new(0, 18, 0)
		marker.AlwaysOnTop = false
		marker.MaxDistance = 350
		marker.Adornee = core
		marker.Parent = core
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextStrokeTransparency = 0.35
		text.Parent = marker
	end
	local text = marker:FindFirstChild("Text") :: TextLabel
	text.Text = allied and "[A] YOUR BASE" or "[E] ENEMY BASE"
	text.TextColor3 = allied and allyColor()
		or (Settings.get("colorblindTeams") and ACCESSIBLE_ENEMY or ENEMY)
end

local function refreshAll()
	local folder = workspace:FindFirstChild("Units")
	if folder then
		for _, item in folder:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("EntityType") == "Unit" then updateBody(item) end
		end
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, item in map:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("EntityType") == "Base" then updateBase(item) end
		end
	end
end

function TeamVisuals.start()
	Players.LocalPlayer:GetAttributeChangedSignal("ArmyTheme"):Connect(refreshAll)
	Settings.onChanged(function(key)
		if key == "colorblindTeams" then refreshAll() end
	end)
	Remotes.StateUpdate.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" and state.playerSide ~= localSide then
			localSide = state.playerSide
			refreshAll()
		end
	end)
	workspace.DescendantAdded:Connect(function(item)
		if item:IsA("BasePart") then
			task.defer(function()
				if item:GetAttribute("EntityType") == "Base" then updateBase(item) else updateBody(item) end
			end)
		end
	end)
end

return TeamVisuals
