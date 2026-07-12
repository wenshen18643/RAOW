# Age of War FP — Design Document

Roblox game replicating [Age of War](https://ageofwargame.io/) with two twists: **first-person** gameplay and both **PVE campaign** + **PVP**.

## Core Concept

Player is a **hero fighter + commander**: walks the battlefield in first person, fights with own age-appropriate weapons, and spawns/commands AI troops via hotbar. Win by destroying the enemy base.

## Match Rules (shared by PVE and PVP)

- **Format:** 1v1, single wide lane (~300 studs base-to-base) with light cover, side ridges, and a hero-only flank path. Units path down the main lane. Kill-zone walls bound the map.
- **Win condition:** destroy enemy base. Target match length 10–15 min. After 20 min, passive income surges to force endgame. No draws.
- **Ages:** full 5-age in-match evolution — Caveman → Spear/Ancient → Medieval → Modern → Future. XP from kills evolves you mid-match. Each age transforms base visuals, unit roster, turrets, special ability, and hero weapon (club → spear → sword → rifle → laser).
- **Economy:** gold + XP from any kill (units, turrets, hero). Hero kills give bonus. Small passive gold trickle prevents stalemates.
- **Units:** 3 per age × 5 ages = 15 units (cheap melee / ranged / expensive heavy). One shared AI brain, re-skinned per age. **Cap ~20 alive per side**; spawn queue holds overflow. Custom controllers (no Humanoids) for perf.
- **Turrets:** 2–3 auto-aim slots on base, buy/sell, more slots via base upgrades.
- **Special ability:** one per age (e.g. meteor rain), big lane AoE, ~60s+ cooldown.
- **Hero:** ≈ strength of 3–4 current-age units. Death → respawn at base with **escalating timer** (10s/20s/30s…). Base destruction is the only match end.
- **Hero combat:** hitscan raycast for guns, swing arc for melee. Client fires, server validates (distance/angle/rate).
- **Command UI:** hotbar usable anywhere — keys 1–5 spawn units, extra keys for turrets/special.

## PVE — Story Campaign

- 10 missions across 5 chapters (one chapter per age), 2 missions each, chapter ends in boss fight.
- Story via short NPC dialogue + environment. Ori-style tone/atmosphere, not platforming.
- Missions = lane battles vs AI with unique twists/modifiers.

## PVP

- Lobby place (social area, shop, campaign select) → queue → TeleportService to reserved server running the match place.

## Meta & Monetization

- Persists: campaign progress, hero/weapon skins per age, titles.
- **No gameplay power for money.** Monetize via cosmetic shop; battle-pass-style rewards later.

## Platform & Style

- **PC only** for v1.
- Low-poly stylized art: bold colors, distinct silhouette per age.

## Tech

- **Rojo + git** in this folder (.luau source files), Studio MCP for map building and playtesting.
- Server-authoritative combat and economy.

## Build Order

1. **Core match engine** vs simple AI opponent — all 5 ages, units, turrets, hero, economy. Playable solo early.
2. **PVE campaign** — wrap engine into 10 missions + bosses.
3. **PVP** — lobby, queue, reserved-server matches.
