--!strict
-- Hero weapon input: hold mouse to fire, rate-limited client-side, validated server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HeroWeapons = require(ReplicatedStorage.Shared.Config.HeroWeapons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Viewmodel = require(script.Parent.Viewmodel)
local Audio = require(script.Parent.Audio)

local Weapon = {}

local player = Players.LocalPlayer
local firing = false
local firingSecondary = false
local lastFireAt = 0
local lastFireSecondaryAt = 0
local currentAge = 1

function Weapon.setAge(age: number)
	currentAge = age
	Viewmodel.setAge(age)
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
	Viewmodel.playFire()
	if weapon.kind == "melee" then
		Audio.play("heroMelee")
	else
		Audio.play(currentAge == 5 and "heroLaser" or "heroFire")
	end
end

local function tryFireSecondary()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return
	end
	local weapon = HeroWeapons[currentAge]
	local now = os.clock()
	if now - lastFireSecondaryAt < 4.0 then
		return
	end
	lastFireSecondaryAt = now
	local cam = workspace.CurrentCamera
	Remotes.FireWeaponSecondary:FireServer(cam.CFrame.Position, cam.CFrame.LookVector)
	Viewmodel.playFire()
	if weapon.kind == "melee" then
		Audio.play("heroMelee")
	else
		Audio.play(currentAge == 5 and "heroLaser" or "heroFire")
	end
end

function Weapon.start()
	Viewmodel.start()
	Viewmodel.setAge(currentAge)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			firingSecondary = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			firingSecondary = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		if firing then
			tryFire()
		end
		if firingSecondary then
			tryFireSecondary()
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
