--!strict
-- Hero weapon input: hold mouse to fire, rate-limited client-side, validated server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

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
	if player:GetAttribute("SettingsOpen") == true then return end
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
	if player:GetAttribute("SettingsOpen") == true then return end
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

	local function gamepadPrimary(_action: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then firing = true end
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then firing = false end
		return Enum.ContextActionResult.Sink
	end
	local function gamepadSecondary(_action: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then firingSecondary = true end
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then firingSecondary = false end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("HeroPrimaryAttack", gamepadPrimary, false, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("HeroSecondaryAttack", gamepadSecondary, false, Enum.KeyCode.ButtonL2)

	if UserInputService.TouchEnabled then
		local hud = player:WaitForChild("PlayerGui"):WaitForChild("GameHUD")
		local touchButtons: { { button: TextButton, position: UDim2 } } = {}
		local function touchAttack(name: string, caption: string, position: UDim2, secondary: boolean)
			local button = Instance.new("TextButton")
			button.Name = name
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.Position = position
			button.Size = UDim2.fromOffset(68, 68)
			button.BackgroundColor3 = secondary and Color3.fromRGB(95, 60, 120) or Color3.fromRGB(135, 65, 55)
			button.BackgroundTransparency = 0.2
			button.Text = caption
			button.TextColor3 = Color3.new(1, 1, 1)
			button.TextScaled = true
			button.Font = Enum.Font.GothamBold
			button.ZIndex = 12
			button.Parent = hud
			table.insert(touchButtons, { button = button, position = position })
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = button
			button.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Touch then return end
				if secondary then firingSecondary = true else firing = true end
			end)
			button.InputEnded:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Touch then return end
				if secondary then firingSecondary = false else firing = false end
			end)
		end
		touchAttack("TouchPrimary", "ATTACK", UDim2.fromScale(0.87, 0.48), false)
		touchAttack("TouchSecondary", "HEAVY", UDim2.fromScale(0.73, 0.58), true)

		local function layoutTouchAttacks()
			local camera = workspace.CurrentCamera
			if not camera then return end
			local viewport = camera.ViewportSize
			local diameter = math.clamp(math.min(viewport.X, viewport.Y) * 0.16, 56, 78)
			for _, entry in touchButtons do
				entry.button.Size = UDim2.fromOffset(diameter, diameter)
				entry.button.Position = entry.position
			end
		end
		local camera = workspace.CurrentCamera
		if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouchAttacks) end
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(layoutTouchAttacks)
		layoutTouchAttacks()
	end
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
