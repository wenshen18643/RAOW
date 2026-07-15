--!strict
-- Central sound event table. Every game sound is defined here so assets can
-- be swapped in one place (e.g. upgrading to marketplace audio later).
--
-- All current ids are engine-shipped rbxasset:// sounds, which are guaranteed
-- to exist and load instantly. `pitch` is the center playback speed; each play
-- randomizes within ±pitchVar so repeated sounds don't machine-gun.

export type SoundDef = {
	id: string,
	volume: number,
	pitch: number,
	pitchVar: number,
	group: "SFX" | "UI",
}

local function def(id: string, volume: number, pitch: number?, pitchVar: number?, group: ("SFX" | "UI")?): SoundDef
	return {
		id = id,
		volume = volume,
		pitch = pitch or 1,
		pitchVar = pitchVar or 0,
		group = group or "SFX",
	}
end

local SoundConfig: { [string]: SoundDef } = {
	-- unit combat (positional)
	meleeSwing = def("rbxasset://sounds/swordslash.wav", 0.45, 1.0, 0.15),
	meleeSwingBig = def("rbxasset://sounds/swordlunge.wav", 0.6, 0.75, 0.1), -- heavies / tusks
	rangedFire = def("rbxasset://sounds/paintball.wav", 0.4, 1.0, 0.12), -- bows/guns
	laserFire = def("rbxasset://sounds/electronicpingshort.wav", 0.35, 0.8, 0.1), -- age 5
	heavyFire = def("rbxasset://sounds/Rocket shot.wav", 0.55, 0.9, 0.1), -- tank/catapult/mech
	impactFlesh = def("rbxasset://sounds/splat.wav", 0.4, 1.0, 0.2),
	unitDeath = def("rbxasset://sounds/uuhhh.mp3", 0.5, 1.0, 0.25),

	-- hero weapon (local, non-positional so it always reads clearly)
	heroMelee = def("rbxasset://sounds/swordslash.wav", 0.6, 0.95, 0.1),
	heroFire = def("rbxasset://sounds/paintball.wav", 0.55, 1.05, 0.08),
	heroLaser = def("rbxasset://sounds/electronicpingshort.wav", 0.5, 0.85, 0.08),

	-- match events (local)
	evolve = def("rbxasset://sounds/bass.wav", 0.7, 1.2, 0, "UI"),
	victory = def("rbxasset://sounds/electronicpingshort.wav", 0.8, 1.3, 0, "UI"),
	defeat = def("rbxasset://sounds/uuhhh.mp3", 0.8, 0.6, 0, "UI"),
	specialCast = def("rbxasset://sounds/Launching rocket.wav", 0.7, 0.8, 0),

	-- UI (local)
	click = def("rbxasset://sounds/clickfast.wav", 0.5, 1.0, 0, "UI"),
	buy = def("rbxasset://sounds/electronicpingshort.wav", 0.45, 1.6, 0, "UI"),
	hover = def("rbxasset://sounds/clickfast.wav", 0.2, 1.4, 0, "UI"),
	baseAlarm = def("rbxasset://sounds/electronicpingshort.wav", 0.55, 1.45, 0, "UI"),
}

return SoundConfig
