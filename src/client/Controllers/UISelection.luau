--!strict
-- Keeps controller focus inside whichever menu or modal was just opened.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local UISelection = {}
local backHandlers: { { root: GuiObject, callback: () -> () } } = {}

local function isUsable(button: GuiButton): boolean
	if not button.Visible or not button.Active or not button.Selectable then return false end
	local ancestor = button.Parent
	while ancestor and ancestor:IsA("GuiObject") do
		if not ancestor.Visible then return false end
		ancestor = ancestor.Parent
	end
	return true
end

local function firstButton(root: GuiObject): GuiButton?
	if root:IsA("GuiButton") and isUsable(root) then return root end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and isUsable(descendant) then
			return descendant
		end
	end
	return nil
end

function UISelection.focus(root: GuiObject, preferred: GuiButton?)
	if not UserInputService.GamepadEnabled or not root.Visible then return end
	task.defer(function()
		if not root.Visible then return end
		local target = preferred
		if not target or not target:IsDescendantOf(root) or not isUsable(target) then
			target = firstButton(root)
		end
		if target then GuiService.SelectedObject = target end
	end)
end

function UISelection.bind(root: GuiObject, preferred: GuiButton?, onBack: (() -> ())?)
	root.SelectionGroup = true
	if onBack then
		table.insert(backHandlers, { root = root, callback = onBack })
	end
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			UISelection.focus(root, preferred)
		elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
	end)
	root.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") and root.Visible and GuiService.SelectedObject == nil then
			UISelection.focus(root, preferred)
		end
	end)
	if root.Visible then UISelection.focus(root, preferred) end
end

ContextActionService:BindActionAtPriority("CloseFocusedPanel", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local selected = GuiService.SelectedObject
	for index = #backHandlers, 1, -1 do
		local binding = backHandlers[index]
		if binding.root.Parent ~= nil and binding.root.Visible and (selected == nil or selected:IsDescendantOf(binding.root)) then
			binding.callback()
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)

return UISelection
