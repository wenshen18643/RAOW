--!strict
-- Hero weapon input: hold mouse to fire, rate-limited client-side, validated server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HeroWeapons = require(ReplicatedStorage.Shared.Config.HeroWeapons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Weapon = {}

local player = Players.LocalPlayer
local firing = false
local lastFireAt = 0
local currentAge = 1

function Weapon.setAge(age: number)
	currentAge = age
end

local function tryFire()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return
	end
	local weapon = HeroWeapons[currentAge]
	local now = os.clock()
	if now - lastFireAt < weapon.fireCooldown then
		return
	end
	lastFireAt = now
	local cam = workspace.CurrentCamera
	Remotes.FireWeapon:FireServer(cam.CFrame.Position, cam.CFrame.LookVector)
end

function Weapon.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		if firing then
			tryFire()
		end
	end)

	-- track age from HUD state updates
	Remotes.StateUpdate.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" and typeof(state.age) == "number" then
			Weapon.setAge(state.age)
		end
	end)
end

return Weapon
