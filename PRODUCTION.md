# PvP Production Runbook

## Runtime topology

- Public instances are matchmaking lobbies.
- Pressing **Ready** adds a player to the universe-wide MemoryStore queue.
- Any lobby may atomically coordinate a pair; expiring presence and assignment records recover from crashed servers.
- Each pair is teleported together into a newly reserved instance of the same place.
- Reserved instances validate the server-issued match ticket and run one 1v1 match.
- A disconnect is a forfeit. The remaining player returns to a public lobby after the result screen.
- Studio bypasses teleport routing and runs the match server directly for two-client testing.

## Required Roblox configuration

Before release:

1. Publish the place. TeleportService cannot be tested in Studio.
2. Set the experience's public server capacity high enough to act as a lobby (recommended 20–50).
3. Set place access to **Secure within universe only** so clients cannot enter match instances directly.
4. Enable Studio API access only in a separate test universe; never point local tests at production data.
5. Confirm DataStore and Teleport budgets in the Creator Dashboard.
6. Use a separate universe for staging and production.

## Release gates

- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_balance.ps1` and require a zero exit code.
- Run `tools\rojo.exe build default.project.json -o build.rbxl` and require a zero exit code.
- [ ] Two clients ready in a published public server and arrive in the same reserved server.
- [ ] The first ticket user is side A and the second is side B.
- [ ] A third/unlisted user cannot enter the reserved match.
- [ ] Both perspectives show local troops as allies and opposing troops as enemies.
- [ ] Each remote is spammed and malformed without changing the other player's state.
- [ ] Rejoining or reusing an expired ticket is rejected.
- [ ] A failed teleport retries into the original reserved server.
- [ ] Disconnecting records one loss and one opponent win, then returns the survivor to a lobby.
- [ ] A complete match records exactly one win/loss and supports a rematch.
- [ ] Server shutdown preserves both profiles.
- [ ] Twenty consecutive matches complete without increasing server memory or simulation time.
- [ ] Forty active units plus projectiles remain within the target server frame budget.

## Operational monitoring

Track at minimum:

- queue joins, matches found, reservation failures, teleport retries, and abandoned queues;
- match duration, winner side, age reached, doctrine selected, and disconnect forfeits;
- DataStore load/save failures and shutdown-save duration;
- server simulation time with 20 units per side;
- remote rejection counts by action and player.

Roblox custom analytics and structured `[Telemetry]` JSON logs are emitted for queue joins,
matches found, reservation/teleport failures, retries, match starts/results, and aggregated
remote rejection counters.

Do not treat a successful Rojo build as a release approval. Teleports, DataStores, networking,
device performance, and two-client behavior require published-client verification.
