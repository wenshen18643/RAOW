--!strict
-- Responsive, scroll-safe layout for match rewards and actions.

local Workspace = game:GetService("Workspace")

local ResultsLayout = {}

export type Controls = {
	root: Frame,
	title: TextLabel,
	stats: TextLabel,
	countdown: TextLabel,
	primary: TextButton,
	returnButton: TextButton,
	armory: TextButton,
}

function ResultsLayout.bind(controls: Controls)
	for _, textControl in {
		controls.title,
		controls.countdown,
		controls.primary,
		controls.returnButton,
		controls.armory,
	} do
		textControl.TextWrapped = true
		textControl.TextTruncate = Enum.TextTruncate.None
		if textControl.TextScaled then
			local textConstraint = Instance.new("UITextSizeConstraint")
			textConstraint.MinTextSize = 10
			textConstraint.MaxTextSize = if textControl == controls.title then 48 else 24
			textConstraint.Parent = textControl
		end
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "RewardScroll"
	scroll.AnchorPoint = Vector2.new(0.5, 0)
	scroll.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	scroll.BackgroundTransparency = 0.18
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ZIndex = 9
	scroll.Parent = controls.root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = scroll

	controls.stats.Parent = scroll
	controls.stats.AnchorPoint = Vector2.zero
	controls.stats.Position = UDim2.fromOffset(0, 0)
	controls.stats.Size = UDim2.new(1, 0, 0, 0)
	controls.stats.AutomaticSize = Enum.AutomaticSize.Y
	controls.stats.TextWrapped = true
	controls.stats.TextYAlignment = Enum.TextYAlignment.Top

	local function updateCanvas()
		scroll.CanvasSize = UDim2.fromOffset(0, math.max(controls.stats.AbsoluteSize.Y + 20, scroll.AbsoluteSize.Y))
	end
	controls.stats:GetPropertyChangedSignal("TextBounds"):Connect(updateCanvas)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)

	local function applyLayout()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local narrow = viewport.X < 620
		local short = viewport.Y < 560

		controls.title.Position = UDim2.fromScale(0.5, short and 0.04 or 0.08)
		controls.title.Size = UDim2.new(0.9, 0, 0, short and 52 or 72)
		scroll.Position = UDim2.fromScale(0.5, short and 0.16 or 0.2)
		local scrollHeight = if short then 190 else math.clamp(math.floor(viewport.Y * 0.36), 210, 280)
		scroll.Size = UDim2.new(narrow and 0.9 or 0.68, 0, 0, scrollHeight)
		controls.countdown.Position = UDim2.fromScale(0.5, short and 0.58 or 0.62)
		controls.countdown.Size = UDim2.new(0.9, 0, 0, 34)

		if narrow and not short then
			controls.primary.Position = UDim2.fromScale(0.5, 0.71)
			controls.returnButton.Position = UDim2.fromScale(0.5, 0.8)
			controls.armory.Position = UDim2.fromScale(0.5, 0.89)
			controls.primary.Size = UDim2.new(0.72, 0, 0, 48)
			controls.returnButton.Size = UDim2.new(0.72, 0, 0, 48)
			controls.armory.Size = UDim2.new(0.72, 0, 0, 44)
		else
			controls.primary.Position = UDim2.fromScale(0.27, short and 0.78 or 0.76)
			controls.returnButton.Position = UDim2.fromScale(0.73, short and 0.78 or 0.76)
			controls.armory.Position = UDim2.fromScale(0.5, short and 0.9 or 0.87)
			controls.primary.Size = UDim2.new(0.38, 0, 0, 48)
			controls.returnButton.Size = UDim2.new(0.38, 0, 0, 48)
			controls.armory.Size = UDim2.new(0.34, 0, 0, 44)
		end
		updateCanvas()
	end

	local cameraConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		local camera = Workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
		end
		applyLayout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

return ResultsLayout
