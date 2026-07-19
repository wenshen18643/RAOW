--!strict
-- Long-form audio is deliberately separate from one-shot SoundConfig entries.
--
-- Track IDs stay empty until the experience owner supplies approved audio. This
-- keeps unpublished/test places from depending on guessed marketplace assets.
-- Adding a track is a data-only change: use an rbxassetid:// URI owned or shared
-- with the experience, then validate it in a published test place.

export type TrackDef = {
	id: string,
	volume: number,
	looped: boolean,
}

export type MixDef = {
	lowGain: number,
	midGain: number,
	highGain: number,
	playbackSpeed: number,
}

export type SceneDef = {
	music: string,
	ambience: string,
}

local function track(volume: number, looped: boolean?): TrackDef
	return {
		id = "",
		volume = volume,
		looped = looped ~= false,
	}
end

local MusicConfig = {
	FADE_SECONDS = 1.25,

	-- Populate only with audio approved for this experience.
	Tracks = {
		lobbyMusic = track(0.34),
		lobbyAmbience = track(0.22),
		matchMusic = track(0.38),
		matchAmbience = track(0.18),
		victoryMusic = track(0.4),
		defeatMusic = track(0.32),
	} :: { [string]: TrackDef },

	Scenes = {
		lobby = { music = "lobbyMusic", ambience = "lobbyAmbience" },
		match = { music = "matchMusic", ambience = "matchAmbience" },
		victory = { music = "victoryMusic", ambience = "" },
		defeat = { music = "defeatMusic", ambience = "" },
	} :: { [string]: SceneDef },

	-- A shared match track still changes character as the player advances.
	-- Distinct age tracks can be introduced later without changing the runtime.
	AgeMix = {
		[1] = { lowGain = 1, midGain = 0, highGain = -3, playbackSpeed = 0.94 },
		[2] = { lowGain = 0, midGain = 1, highGain = -2, playbackSpeed = 0.97 },
		[3] = { lowGain = 1, midGain = 0, highGain = 0, playbackSpeed = 1 },
		[4] = { lowGain = 2, midGain = -1, highGain = 1, playbackSpeed = 1.03 },
		[5] = { lowGain = -1, midGain = 0, highGain = 3, playbackSpeed = 1.06 },
	} :: { [number]: MixDef },
}

return MusicConfig
