--!strict
-- Fake-player identities shared by the PvP bot fallback and lobby ambience NPCs.
-- Names are game-themed handles, deliberately not shaped like real usernames of
-- plausible real people.

local BotIdentity = {}

local NAMES = {
	"Commander_Vex", "IronDune", "NovaStriker", "WarSmith_Kael", "GrimHalcyon",
	"SteelReverie", "AshfallKing", "DreadMarshal", "ObsidianWolf", "RustyBastion",
	"PhantomSarge", "BlitzRunner", "CrimsonWard", "HollowLancer", "StormVanguard",
	"EchoLegion", "ZenithFall", "BrassArbiter", "VoidCadence", "EmberColonel",
	"FrostRampart", "SableCharger", "QuartzRaider", "ThornCaptain", "GaleWarden",
	"OnyxSentinel", "PyreMarauder", "CobaltReaper", "SlateCommando", "AuricTrench",
	"MireGeneral", "FlintOutrider", "TerraJuggernaut", "ShardValkyrie", "DuskBrigadier",
	"HexArtillery", "LoamCrusader", "VaporFusilier", "CinderPaladin", "KryptLancer",
}

local counter = 0

function BotIdentity.pickName(): string
	counter += 1
	local base = NAMES[math.random(1, #NAMES)]
	-- Suffix keeps concurrent bots distinct without looking like an ID dump.
	return math.random() < 0.4 and `{base}{math.random(2, 99)}` or base
end

-- Rating near an anchor (the queuing player) for fair-looking fallback matches.
function BotIdentity.ratingNear(anchor: number): number
	return math.clamp(math.round(anchor + math.random(-100, 100)), 100, 5000)
end

-- Plausible lobby-population rating: mostly mid-ladder, rarely high.
function BotIdentity.ambientRating(): number
	local roll = math.random()
	if roll < 0.75 then
		return math.random(900, 1400)
	elseif roll < 0.95 then
		return math.random(1400, 1900)
	end
	return math.random(1900, 2400)
end

return BotIdentity
