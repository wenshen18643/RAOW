--!strict
-- StatusEffectSystem: manages active status effects (DoT, ArmorMelt) on units.
-- Each effect is tracked in a module-level table and processed every tick.
-- Effects of the same type on the same target refresh rather than stack.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Match = require(script.Parent.Match)
local UnitSim = require(script.Parent.UnitSim)

local StatusEffectSystem = {}

-- Type alias for the config definition (mirrors StatusEffects module export)
type StatusEffectDef = StatusEffects.StatusEffectDef

-- An active effect instance attached to a specific unit
type ActiveEffect = {
	effectDef: StatusEffectDef, -- the config definition for this effect
	targetRec: Match.UnitRecord, -- the unit record being affected
	attackerSide: string, -- side that applied the effect (for kill credit)
	baseDamage: number, -- attacker's damage used to compute tick damage
	endsAt: number, -- os.clock() timestamp when the effect expires
	nextTickAt: number, -- os.clock() timestamp for the next DoT tick
	applied: boolean, -- whether the initial on-apply logic has run
}

-- Module-level table of all currently active effects
local activeEffects: { ActiveEffect } = {}

type ActiveHeroEffect = {
	effectDef: StatusEffectDef,
	humanoid: Humanoid,
	baseDamage: number,
	endsAt: number,
	nextTickAt: number,
}

-- Hero effects use the same refresh-not-stack rule as unit effects. Keeping
-- them in the simulation avoids creating an unbounded task for every hit.
local activeHeroEffects: { ActiveHeroEffect } = {}

-- ────────────────────────────────────────────────────────────────────────
-- apply: attach a status effect to a unit record
-- ────────────────────────────────────────────────────────────────────────
-- If the same effectId is already active on the target, the timer is
-- refreshed instead of stacking a second instance.
function StatusEffectSystem.apply(
	match: Match.Match,
	targetRec: Match.UnitRecord,
	effectId: string,
	attackerDamage: number,
	attackerSide: string
)
	local def = StatusEffects.byId[effectId]
	if not def then
		warn("[StatusEffectSystem] Unknown effect id:", effectId)
		return
	end

	local now = os.clock()

	-- Check for an existing instance of the same effect on the same target
	for _, existing in activeEffects do
		if existing.effectDef.id == effectId and existing.targetRec == targetRec then
			-- Refresh timers rather than stacking
			existing.endsAt = now + def.duration
			existing.nextTickAt = now + (def.interval or def.duration)
			existing.baseDamage = attackerDamage
			return
		end
	end

	-- Create a new active effect entry
	local entry: ActiveEffect = {
		effectDef = def,
		targetRec = targetRec,
		attackerSide = attackerSide,
		baseDamage = attackerDamage,
		endsAt = now + def.duration,
		nextTickAt = now + (def.interval or def.duration),
		applied = true,
	}

	-- Immediate on-apply behaviour per kind
	if def.kind == "amp" then
		-- ArmorMelt: increase damage taken by the target immediately
		(targetRec :: any).damageAmp = def.damageRatio
	end

	table.insert(activeEffects, entry)

	-- Fire VFX to all clients so they can show the status particle/highlight
	Remotes.FX:FireAllClients("StatusVFX", {
		pos = targetRec.body.Position,
		effectId = effectId,
		color = def.color,
	})
end

-- ────────────────────────────────────────────────────────────────────────
-- applyToHero: simplified version that ticks damage directly on a Humanoid
-- ────────────────────────────────────────────────────────────────────────
-- Only DoT effects are meaningful for the hero; amp effects are skipped
-- because the hero has no damageAmp field. Spawns a self-contained task
-- that handles its own ticking and expiry.
function StatusEffectSystem.applyToHero(
	humanoid: Humanoid,
	effectId: string,
	attackerDamage: number
)
	local def = StatusEffects.byId[effectId]
	if not def then
		warn("[StatusEffectSystem] Unknown effect id for hero:", effectId)
		return
	end

	-- Amp effects don't apply to the hero
	if def.kind == "amp" then
		return
	end

	-- Fire VFX at the hero's position
	local rootPart = (humanoid.Parent :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		Remotes.FX:FireAllClients("StatusVFX", {
			pos = rootPart.Position,
			effectId = effectId,
			color = def.color,
		})
	end

	local now = os.clock()
	for _, existing in activeHeroEffects do
		if existing.humanoid == humanoid and existing.effectDef.id == effectId then
			existing.baseDamage = attackerDamage
			existing.endsAt = now + def.duration
			existing.nextTickAt = now + (def.interval or def.duration)
			return
		end
	end
	table.insert(activeHeroEffects, {
		effectDef = def,
		humanoid = humanoid,
		baseDamage = attackerDamage,
		endsAt = now + def.duration,
		nextTickAt = now + (def.interval or def.duration),
	})
end

-- ────────────────────────────────────────────────────────────────────────
-- tick: process all active effects each frame
-- ────────────────────────────────────────────────────────────────────────
-- Deals DoT damage, resets expired amp effects, and prunes the list.
function StatusEffectSystem.tick(match: Match.Match, _dt: number)
	local now = os.clock()

	-- Iterate backwards so we can remove entries in-place
	local i = #activeEffects
	while i >= 1 do
		local entry = activeEffects[i]
		local remove = false

		-- Remove if the target unit is dead
		if entry.targetRec.dead then
			remove = true
		-- Remove if the effect has expired
		elseif now >= entry.endsAt then
			-- If this was an amp effect, reset the target's damageAmp
			if entry.effectDef.kind == "amp" then
				(entry.targetRec :: any).damageAmp = 0
			end
			remove = true
		else
			-- Effect is still active – process ticks
			if entry.effectDef.kind == "dot" then
				-- DoT: apply periodic damage when the next tick time is reached
				if now >= entry.nextTickAt and not entry.targetRec.dead then
					local tickDamage = entry.baseDamage * entry.effectDef.damageRatio
					UnitSim.damageUnit(match, entry.targetRec, tickDamage, entry.attackerSide, false)
					entry.nextTickAt = now + entry.effectDef.interval
				end
			end
			-- Amp effects are passive (already applied on creation); nothing to
			-- do per-tick except wait for expiry handled above.
		end

		if remove then
			-- Swap-remove for O(1) deletion (order doesn't matter)
			activeEffects[i] = activeEffects[#activeEffects]
			activeEffects[#activeEffects] = nil
		end

		i -= 1
	end

	local heroIndex = #activeHeroEffects
	while heroIndex >= 1 do
		local entry = activeHeroEffects[heroIndex]
		local humanoid = entry.humanoid
		local remove = humanoid.Parent == nil or humanoid.Health <= 0 or now >= entry.endsAt
		if not remove and now >= entry.nextTickAt then
			humanoid:TakeDamage(entry.baseDamage * entry.effectDef.damageRatio)
			entry.nextTickAt = now + (entry.effectDef.interval or entry.effectDef.duration)
		end
		if remove then
			activeHeroEffects[heroIndex] = activeHeroEffects[#activeHeroEffects]
			activeHeroEffects[#activeHeroEffects] = nil
		end
		heroIndex -= 1
	end
end

-- ────────────────────────────────────────────────────────────────────────
-- clearAll: wipe every active effect and reset damageAmp on living units
-- ────────────────────────────────────────────────────────────────────────
function StatusEffectSystem.clearAll(match: Match.Match)
	-- Reset damageAmp on all living units before clearing
	for _, sideState in match.sides do
		for _, rec in sideState.units do
			if not rec.dead then
				(rec :: any).damageAmp = 0
			end
		end
	end

	table.clear(activeEffects)
	table.clear(activeHeroEffects)
end

return StatusEffectSystem
