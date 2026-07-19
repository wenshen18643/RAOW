--!strict
-- Client audio: sound groups, positional + local playback, and subscriptions
-- to game events (FX remotes, match events, unit animation hooks).
-- All sound definitions live in Shared/Config/SoundConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)
local MusicConfig = require(ReplicatedStorage.Shared.Config.MusicConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UnitAnimator = require(script.Parent.UnitAnimator)

local Audio = {}

local rng = Random.new()
local groups: { [string]: SoundGroup } = {}
local lastPlayed: { [string]: number } = {} -- throttle per sound name

local THROTTLE = 0.04 -- min seconds between plays of the same sound
local MAX_DISTANCE = 220
local MAX_POSITIONAL_SOUNDS = 18
local activePositionalSounds = 0
local activeLoops: { [string]: Sound } = {}
local musicEqualizer: EqualizerSoundEffect? = nil
local currentScene = ""
local currentAge = 1

local function getGroup(name: string): SoundGroup
	local g = groups[name]
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = 1
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
	if activePositionalSounds >= MAX_POSITIONAL_SOUNDS then return end
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
	activePositionalSounds += 1
	local released = false
	local function release()
		if released then return end
		released = true
		activePositionalSounds = math.max(0, activePositionalSounds - 1)
	end
	holder.Destroying:Connect(release)
	s:Play()
	s.Ended:Once(function()
		release()
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

-- Music and ambient beds share one player-facing volume while retaining
-- separate SoundGroups for future routing and mix effects.
function Audio.setMusicVolume(volume: number)
	local clamped = math.clamp(volume, 0, 1)
	getGroup("Music").Volume = clamped
	getGroup("Ambience").Volume = clamped
end

local function fadeOut(sound: Sound)
	TweenService:Create(sound, TweenInfo.new(MusicConfig.FADE_SECONDS), { Volume = 0 }):Play()
	task.delay(MusicConfig.FADE_SECONDS + 0.1, function()
		if sound.Parent then sound:Destroy() end
	end)
end

local function transitionLoop(bus: "music" | "ambience", trackName: string, playbackSpeed: number)
	local old = activeLoops[bus]
	local track = MusicConfig.Tracks[trackName]
	if track and track.id ~= "" and old
		and old:GetAttribute("TrackName") == trackName then
		old.PlaybackSpeed = playbackSpeed
		return
	end

	if old then
		activeLoops[bus] = nil
		fadeOut(old)
	end
	if not track or track.id == "" then return end

	local sound = Instance.new("Sound")
	sound.Name = if bus == "music" then "CurrentMusic" else "CurrentAmbience"
	sound:SetAttribute("TrackName", trackName)
	sound.SoundId = track.id
	sound.Volume = 0
	sound.Looped = track.looped
	sound.PlaybackSpeed = playbackSpeed
	sound.SoundGroup = getGroup(if bus == "music" then "Music" else "Ambience")
	sound.Parent = SoundService
	activeLoops[bus] = sound
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(MusicConfig.FADE_SECONDS), { Volume = track.volume }):Play()
end

local function applyAgeMix(age: number)
	local mix = MusicConfig.AgeMix[math.clamp(age, 1, 5)] or MusicConfig.AgeMix[1]
	if musicEqualizer then
		TweenService:Create(musicEqualizer, TweenInfo.new(MusicConfig.FADE_SECONDS), {
			LowGain = mix.lowGain,
			MidGain = mix.midGain,
			HighGain = mix.highGain,
		}):Play()
	end
	local activeMusic = activeLoops.music
	if activeMusic then
		TweenService:Create(activeMusic, TweenInfo.new(MusicConfig.FADE_SECONDS), {
			PlaybackSpeed = mix.playbackSpeed,
		}):Play()
	end
end

-- Scene transitions are idempotent and crossfade both long-form buses. Track
-- slots may intentionally be empty until approved experience-owned audio ships.
function Audio.setScene(scene: "lobby" | "match" | "victory" | "defeat", age: number?)
	local nextAge = math.clamp(age or currentAge, 1, 5)
	if scene == currentScene and (scene ~= "match" or nextAge == currentAge) then return end
	currentScene = scene
	currentAge = nextAge

	local sceneDef = MusicConfig.Scenes[scene]
	local mix = if scene == "match" then MusicConfig.AgeMix[nextAge] else MusicConfig.AgeMix[3]
	transitionLoop("music", sceneDef.music, mix.playbackSpeed)
	transitionLoop("ambience", sceneDef.ambience, 1)
	applyAgeMix(if scene == "match" then nextAge else 3)
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
	local musicGroup = getGroup("Music")
	getGroup("Ambience")
	musicEqualizer = Instance.new("EqualizerSoundEffect")
	musicEqualizer.Name = "AgeIdentity"
	musicEqualizer.Parent = musicGroup

	local serverType = workspace:GetAttribute("ServerType")
	Audio.setScene(if serverType == "match" then "match" else "lobby", 1)

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
	local localSide: string? = nil
	Remotes.StateUpdate.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" then
			localSide = state.playerSide
			if state.status == "Active" and typeof(state.age) == "number" then
				Audio.setScene("match", state.age)
			end
		end
	end)
	Remotes.MatchEvent.OnClientEvent:Connect(function(event: string, data: { [string]: any }?)
		if event == "MatchStart" then
			Audio.setScene("match", 1)
		elseif event == "AgeUp" then
			-- only fanfare for the local player's side
			if data and data.side == localSide then
				Audio.play("evolve")
				Audio.setScene("match", data.age)
			end
		elseif event == "Victory" then
			Audio.play("victory")
			Audio.setScene("victory")
		elseif event == "Defeat" then
			Audio.play("defeat")
			Audio.setScene("defeat")
		elseif event == "ReturnToMenu" then
			Audio.setScene("lobby")
		end
	end)
end

return Audio
