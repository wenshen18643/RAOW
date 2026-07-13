--!strict
-- Single access point for RemoteEvents. Server creates, client waits.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = {
	-- client -> server
	"SpawnUnit", -- (unitId: string)
	"BuildTurret", -- (slot: number)
	"SellTurret", -- (slot: number)
	"UseSpecial", -- ()
	"Evolve", -- ()
	"FireWeapon", -- (origin: Vector3, direction: Vector3)
	"FireWeaponSecondary", -- (origin: Vector3, direction: Vector3)
	"BuyUpgrade", -- (stat: string)
	"SelectDifficulty", -- (difficultyName: string)
	"SelectMode", -- (mode: "pve" | "pvp", difficultyName: string?)
	"LeaveMatch", -- return to a public matchmaking lobby after a result
	"RequestProfile", -- () client asks for a ProfileSync once its listener is ready
	"RequestLeaderboard", -- () client asks for the current top-rating board
	-- server -> client
	"StateUpdate", -- (state: table) periodic HUD snapshot
	"ProfileSync", -- (profile: table) latest PlayerProfile data
	"LeaderboardData", -- (rows: {{name: string, rating: number}}) top-rating board
	"MatchEvent", -- (event: string, data: table?) "MatchStart"|"Victory"|"Defeat"|"AgeUp"|"SpecialFired"|"HeroRespawn"
	"FX", -- (kind: string, data: table) visual effects broadcast
	"DifficultySelected", -- (difficultyName: string) broadcasts chosen difficulty
	"HitConfirm", -- () server-confirmed hit for the attacking player only
}

local Remotes: { [string]: RemoteEvent } = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
		Remotes[name] = ev
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return Remotes
