# AgeOfWarFP

A Roblox first-person tower-war game built with [Rojo](https://rojo.space/).

## Project Layout

```
.
├── src/
│   ├── client/          # StarterPlayerScripts.Client
│   ├── server/          # ServerScriptService.Server
│   └── shared/          # ReplicatedStorage.Shared
├── default.project.json # Rojo project file
├── tools/               # Optional bundled tools (e.g. rojo.exe)
├── reload.ps1           # One-click rebuild + open in Studio (PowerShell)
├── reload.sh            # One-click rebuild + open in Studio (Git Bash)
└── build.rbxl           # Generated place file (ignored by git)
```

## Requirements

- [Rojo](https://rojo.space/) 7.x
- Roblox Studio

You can either:

1. Install Rojo globally so `rojo` is on your PATH, **or**
2. Download `rojo.exe` and place it in `tools/rojo.exe` inside this repo.

> The reload scripts prefer a `rojo` binary on PATH and fall back to `tools/rojo.exe`.

## Quick Start

1. Clone the repo.
2. Install or place Rojo as described above.
3. Run the reload script for your shell:

   **PowerShell:**
   ```powershell
   .\reload.ps1
   ```

   **Git Bash:**
   ```bash
   ./reload.sh
   ```

This builds `build.rbxl` from `default.project.json` and opens it in Roblox Studio.

## Manual Build

```bash
rojo build default.project.json -o build.rbxl
```

Then open `build.rbxl` in Roblox Studio.

## Notes

- `build.rbxl` is generated and should not be committed.
- `tools/rojo.exe` is optional. If you commit it, other Windows devs can build without installing Rojo globally.
