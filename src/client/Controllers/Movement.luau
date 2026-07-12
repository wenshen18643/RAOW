--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Movement = {}

local player = Players.LocalPlayer
local isCrouching = false
local normalSpeed = 16
local crouchSpeed = 8

local NORMAL_OFFSET = Vector3.new(0, 0, 0)
local CROUCH_OFFSET = Vector3.new(0, -1.5, 0)

function Movement.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
			isCrouching = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
			isCrouching = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		if isCrouching then
			hum.WalkSpeed = crouchSpeed
			hum.CameraOffset = hum.CameraOffset:Lerp(CROUCH_OFFSET, 0.2)
		else
			hum.WalkSpeed = normalSpeed
			hum.CameraOffset = hum.CameraOffset:Lerp(NORMAL_OFFSET, 0.2)
		end
	end)
end

return Movement
