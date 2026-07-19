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
	"SelectMode", -- (mode: "pve" | "pvp", difficultyName: string?)
	"CancelQueue", -- () leave PvP matchmaking before an opponent is assigned
	"ResultAction", -- ("replay" | "next" | "menu") explicit post-match choice
	"RequestProfile", -- () client asks for a ProfileSync once its listener is ready
	"RequestLeaderboard", -- (boardType: string?) client asks for the current top-rating board
	"StartPveLevel", -- (mode: string, level: number) client requests level N of a difficulty mode
	"BuyPveUpgrade", -- (trackOrPerkId: string)
	"ClaimDailyBonds", -- () claim the once-per-UTC-day cosmetic allowance
	"BuyCosmetic", -- (cosmeticId: string) spend War Bonds
	"EquipCosmetic", -- (cosmeticId: string) equip an owned commander title
	"PromptProduct", -- (productKey: string) request a Roblox purchase prompt
	"PromptSupporterPass", -- () request the optional cosmetic supporter pass
	"UpdateSettings", -- (key: string, value: number | boolean) persist client preferences
	-- server -> client
	"StateUpdate", -- (state: table) periodic HUD snapshot
	"ProfileSync", -- (profile: table) latest PlayerProfile data
	"LeaderboardData", -- (boardType: string, rows: {{name: string, rating: number}}) top-rating board
	"MatchEvent", -- (event: string, data: table?) "MatchStart"|"Victory"|"Defeat"|"AgeUp"|"SpecialFired"|"HeroRespawn"
	"FX", -- (kind: string, data: table) visual effects broadcast
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
