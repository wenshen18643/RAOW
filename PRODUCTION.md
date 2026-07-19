# Production setup

## Match topology

Published public servers are matchmaking lobbies. PvP pairs are issued expiring server-side tickets and teleported into reserved two-player match servers. Studio bypasses cloud matchmaking, so use **Test → Clients and Servers → 2 Players → Start** for local combat testing. Select **PvP 1v1** in both client windows; the local match starts when both are ready.

Before release, verify in a private staging universe that two different Roblox accounts can queue, teleport, complete a match, receive rating/XP, rematch, and return to the lobby. Studio cannot prove MemoryStore or TeleportService behavior.

## Cosmetic monetization

The game deliberately has no paid combat power. War Bonds unlock commander titles and allied-army signal themes only; they cannot purchase units, gold, XP, PvE stat upgrades, doctrine buffs, or matchmaking advantages. Signal themes recolor the local player's allied outlines, labels, health bars, and uniform stripe while enemies always remain red. Players earn five War Bonds at every commander level plus a daily supply, first-battle reward, and first-win reward without Robux; missing a day does not reset anything. The optional Founding Patron pass adds five War Bonds to each claimed daily supply and includes its title.

1. Publish the experience.
2. In Creator Dashboard, create three Developer Products for the 100, 280, and 650 War Bond bundles.
3. Optionally create one Pass for the **Founding Patron** title.
4. Copy their IDs into `src/shared/Config/MonetizationConfig.luau`. Offers with ID `0` remain safely disabled and hidden from players.
5. Set product prices in Creator Dashboard; the in-game UI relies on Roblox's purchase prompt to show the authoritative localized price.
6. Test each receipt in a staging universe. Confirm the grant persists after rejoin and retrying a receipt does not grant twice.

To configure the IDs without editing Luau by hand, run:

```powershell
.\tools\configure_commerce.ps1 -SmallProductId <id> -MediumProductId <id> -LargeProductId <id> -SupporterPassId <id>
```

Omit `-SupporterPassId` to leave the optional pass disabled. Add `-WhatIf` to validate the IDs and preview the target without writing.

Do not add paid random rewards, fake countdowns, restarting “limited” offers, or paid PvP power. If the catalog later adds randomized paid items, integrate `PolicyService` eligibility checks before displaying them.

## Music and ambience

Long-form audio slots live in `src/shared/Config/MusicConfig.luau`. They are
intentionally empty in source control until the experience owner selects audio
they own or that is shared with the experience. Set each required slot to a
numeric `rbxassetid://` URI; do not copy catalog IDs without checking usage
rights. The client crossfades lobby, match, victory, and defeat scenes, routes
music and ambience separately, and changes the match mix across all five ages.

After configuring tracks, test in a published staging place. Confirm every asset
loads for a non-owner account, transitions do not overlap, age changes remain
musically smooth, and the persisted Music Volume slider controls both long-form
buses without muting combat or UI cues.

## Release gates

- Run `powershell -ExecutionPolicy Bypass -File .\tools\check_balance.ps1`.
- Run `tools\rojo.exe build default.project.json -o build.rbxl`.
- Run `tests\ProductionSmokeTest.luau`, `tests\NPCSimulationSmokeTest.luau`, and `tests\SyntaxSmokeTest.luau` through Roblox Studio's `RunScript` task; all must print their `_PASS` marker.
- Test desktop and touch layouts at common viewport sizes.
- Complete one PvE Classic match, one PvE Level first clear and replay, and one two-client PvP match.
- On results, verify Replay starts immediately, Next Stage only appears after a campaign victory, Return exits cleanly, and PvP rematches require both players to opt in.
- Verify daily supply cannot be claimed twice in the same UTC day.
- Verify daily battle and first-win rewards grant once per UTC day across PvE, PvE Levels, PvP, and rematches.
- Verify Founding Patron receives the configured daily bonus even when entitlement resolution finishes after profile loading.
- Verify every Armory title unlocks/equips and appears over newly spawned allied units. Verify each signal theme immediately recolors allied outlines, labels, health bars, and uniform stripes without changing enemy red.
- Verify DataStore, MemoryStore, analytics, product receipts, teleports, disconnect forfeits, and return-to-lobby behavior in a published staging universe.

## Gameplay and analytics targets

The standard economy escalates at 10 minutes. At 14 minutes, sudden death increases income and base damage so stalemates resolve instead of becoming indefinite sessions. The HUD exposes both transitions.

Desktop uses mouse buttons for primary/secondary attacks, gamepad uses R2/L2, and touch devices receive dedicated Attack/Heavy buttons. Validate that touch buttons do not overlap Roblox's movement and jump controls on phone and tablet aspect ratios.

NPCs deploy across five lateral lanes, reacquire targets on staggered intervals, and use obstacle-aware steering. Cannoneer, Tank, War Machine, and Super Soldier attacks are physical projectiles rather than instant long-range hits. On boss stages, verify that the red slam warning remains visible long enough to dodge and that a full-health commander cannot be killed by one slam.

Current-age income keeps basic troops near a ten-second purchase cycle, heavies near 35â€“60 seconds, and turrets near one minute. Melee provides the best damage per gold, ranged sacrifices durability for spacing, and heavy armor/tank value counters ranged fire without matching melee damage efficiency. The final Super Soldier improves slot efficiency but is no more efficient per gold than a War Machine, so melee swarms remain its clean counter. Unit kills recycle only part of their cost, preventing runaway gold creation. Use **B** on keyboard or **L1** on gamepad to manage individual turret slots; replacing an obsolete turret includes its displayed 50% sell credit.

Sensitivity, SFX/UI/music volume, reduced effects, and damage-number preferences persist with the player profile. Reduced effects disables camera shake, full-screen flashes, FOV kicks, excess particles, and decorative muzzle flashes while retaining combat tracers and melee telegraphs. Verify these options after rejoining on a staging server.

Use the custom analytics funnel to compare `session_started` → `mode_selected` → `match_started` → match result. Segment `session_started` by the `returning`, `level`, and `pveLevel` fields. Monetization events are `daily_bonds_claimed`, `cosmetic_unlocked`, and `war_bonds_purchased`. Optimize unclear exits and low-value screens before increasing store exposure.
