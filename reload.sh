#!/usr/bin/env bash
# Reload AgeOfWarFP in Roblox Studio
# Run from Git Bash in this repo: ./reload.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_OUTPUT="$PROJECT_ROOT/build.rbxl"

cd "$PROJECT_ROOT"

# Prefer a Rojo binary on PATH; fall back to the bundled tools/rojo.exe.
if command -v rojo >/dev/null 2>&1; then
    ROJO="rojo"
else
    ROJO="$PROJECT_ROOT/tools/rojo.exe"
    if [ ! -f "$ROJO" ]; then
        echo "Rojo not found." >&2
        echo "Install Rojo from https://rojo.space or place rojo.exe in tools/rojo.exe" >&2
        exit 1
    fi
fi

echo "Building project with $ROJO..."
"$ROJO" build default.project.json -o "$BUILD_OUTPUT"

echo "Closing Roblox Studio..."
cmd //c "taskkill /F /IM RobloxStudioBeta.exe" || true

sleep 2

echo "Opening build.rbxl in Roblox Studio..."
cmd //c "start build.rbxl"

echo "Done."
