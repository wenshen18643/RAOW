--!strict
-- Client audio: sound groups, positional + local playback, and subscriptions
-- to game events (FX remotes, match events, unit animation hooks).
-- All sound definitions live in Shared/Config/SoundConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UnitAnimator = require(script.Parent.UnitAnimator)

local Audio = {}

local rng = Random.new()
local groups: { [string]: SoundGroup } = {}
local lastPlayed: { [string]: number } = {} -- throttle per sound name

local THROTTLE = 0.04 -- min seconds between plays of the same sound
local MAX_DISTANCE = 220

local function getGroup(name: string): SoundGroup
	local g = groups[name]
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = name == "Music" and 0.5 or 1
		g.Parent = SoundService
		groups[name] = g
	end
	return g
end

local function makeSound(name: string): Sound?
	local sdef = SoundConfig[name]
	if not sdef then
		warn(`[Audio] unknown sound '{name}'`)
		return nil
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < THROTTLE then
		return nil
	end
	lastPlayed[name] = now

	local s = Instance.new("Sound")
	s.SoundId = sdef.id
	s.Volume = sdef.volume
	s.PlaybackSpeed = sdef.pitch + (sdef.pitchVar > 0 and rng:NextNumber(-sdef.pitchVar, sdef.pitchVar) or 0)
	s.SoundGroup = getGroup(sdef.group)
	return s
end

-- Plays a sound non-positionally (UI, match events, hero weapon).
function Audio.play(name: string)
	local s = makeSound(name)
	if not s then
		return
	end
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	Debris:AddItem(s, 6)
end

-- Plays a sound in 3D at a world position.
function Audio.playAt(name: string, pos: Vector3)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - pos).Magnitude > MAX_DISTANCE then
		return
	end
	local s = makeSound(name)
	if not s then
		return
	end
	s.RollOffMaxDistance = MAX_DISTANCE
	s.RollOffMinDistance = 12
	s.RollOffMode = Enum.RollOffMode.InverseTapered

	local holder = Instance.new("Attachment")
	holder.Position = pos
	holder.Parent = workspace.Terrain
	s.Parent = holder
	s:Play()
	s.Ended:Once(function()
		holder:Destroy()
	end)
	Debris:AddItem(holder, 6)
end

-- Volume control for the settings menu (0..1 per group).
function Audio.setGroupVolume(group: string, volume: number)
	getGroup(group).Volume = math.clamp(volume, 0, 1)
end

function Audio.getGroupVolume(group: string): number
	return getGroup(group).Volume
end

--------------------------------------------------------------------------------
-- Event subscriptions
--------------------------------------------------------------------------------

-- Sound for a unit starting an attack, based on its rig/role/age.
local function unitAttackSound(body: BasePart, role: string, age: number, rig: string)
	local pos = body.Position
	if role == "melee" then
		Audio.playAt(age == 5 and "laserFire" or "meleeSwing", pos)
	elseif role == "ranged" then
		Audio.playAt(age == 5 and "laserFire" or "rangedFire", pos)
	else -- heavy
		if rig == "quadruped" then
			Audio.playAt("meleeSwingBig", pos)
		else
			Audio.playAt("heavyFire", pos)
		end
	end
end

function Audio.start()
	-- pre-create groups so the settings UI can read them immediately
	getGroup("SFX")
	getGroup("UI")
	getGroup("Music")

	-- unit animation hooks (fires exactly when the swing anim starts)
	UnitAnimator.onUnitAttack = unitAttackSound
	UnitAnimator.onUnitDeath = function(body: BasePart)
		Audio.playAt("unitDeath", body.Position)
	end

	-- impact/explosion FX already broadcast by the server
	Remotes.FX.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "ImpactVFX" then
			Audio.playAt("impactFlesh", data.pos :: Vector3)
		elseif kind == "Explosion" then
			Audio.playAt("specialCast", data.pos :: Vector3)
		end
	end)

	local player = Players.LocalPlayer
	Remotes.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		if event == "AgeUp" then
			-- only fanfare for the local player's side
			if data and data.side == "A" then
				Audio.play("evolve")
			end
		elseif event == "Victory" then
			Audio.play("victory")
		elseif event == "Defeat" then
			Audio.play("defeat")
		end
	end)
end

return Audio
