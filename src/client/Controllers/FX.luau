--!strict
-- Client-side visual effects: tracers and explosions from the FX remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FX = {}

local fxFolder: Folder? = nil

local function getFolder(): Folder
	if not fxFolder or not fxFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "ClientFX"
		f.Parent = workspace
		fxFolder = f
	end
	return fxFolder :: Folder
end

local function tracer(data: { [string]: any })
	local from = data.from :: Vector3
	local to = data.to :: Vector3
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = data.color or Color3.new(1, 1, 1)
	beam.Size = Vector3.new(0.15, 0.15, dist)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	beam.Transparency = 0.2
	beam.Parent = getFolder()
	TweenService:Create(beam, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(beam, 0.15)
end

local function explosion(data: { [string]: any })
	local pos = data.pos :: Vector3
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Material = Enum.Material.Neon
	ball.Color = data.color or Color3.fromRGB(255, 170, 80)
	ball.Size = Vector3.one * 4
	ball.Position = pos
	ball.Transparency = 0.1
	ball.Parent = getFolder()
	TweenService:Create(ball, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 22,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, 0.5)
end

function FX.start()
	Remotes.FX.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "Tracer" then
			tracer(data)
		elseif kind == "Explosion" then
			explosion(data)
		end
	end)
end

return FX
