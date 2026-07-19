--!strict
-- Central source of player-facing control prompts. Prompts follow the last
-- input device used so hybrid devices can switch without reopening the UI.

local UserInputService = game:GetService("UserInputService")

local InputPrompts = {}

export type InputMode = "KeyboardMouse" | "Gamepad" | "Touch"

local changed = Instance.new("BindableEvent")

local keyboardPrompts: { [string]: string } = {
	slot1 = "1",
	slot2 = "2",
	slot3 = "3",
	slot4 = "4",
	slot5 = "5",
	slot6 = "6",
	upgrades = "E",
	guide = "G",
	turrets = "B",
	evolve = "Q",
	primaryAttack = "LMB",
	secondaryAttack = "RMB",
	settings = "P",
}

local gamepadPrompts: { [string]: string } = {
	slot1 = "D-PAD UP",
	slot2 = "D-PAD RIGHT",
	slot3 = "D-PAD DOWN",
	slot4 = "B",
	slot5 = "D-PAD LEFT",
	slot6 = "X",
	upgrades = "RB",
	guide = "VIEW",
	turrets = "LB",
	evolve = "Y",
	primaryAttack = "RT",
	secondaryAttack = "LT",
	settings = "MENU",
}

local function modeFor(inputType: Enum.UserInputType): InputMode?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	if inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
	then
		return "KeyboardMouse"
	end
	return nil
end

local function initialMode(): InputMode
	local lastMode = modeFor(UserInputService:GetLastInputType())
	if lastMode then return lastMode end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

local currentMode: InputMode = initialMode()

function InputPrompts.getMode(): InputMode
	return currentMode
end

function InputPrompts.get(action: string): string
	if currentMode == "KeyboardMouse" then
		return keyboardPrompts[action] or ""
	elseif currentMode == "Gamepad" then
		return gamepadPrompts[action] or ""
	end
	return ""
end

function InputPrompts.withPrompt(text: string, action: string): string
	local prompt = InputPrompts.get(action)
	return if prompt == "" then text else `{text} [{prompt}]`
end

function InputPrompts.instruction(action: string, keyboardOrGamepadText: string, touchText: string): string
	if currentMode == "Touch" then
		return touchText
	end
	return `Press {InputPrompts.get(action)} to {keyboardOrGamepadText}`
end

function InputPrompts.onChanged(callback: (InputMode) -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	local nextMode = modeFor(inputType)
	if nextMode and nextMode ~= currentMode then
		currentMode = nextMode
		changed:Fire(currentMode)
	end
end)

return InputPrompts
