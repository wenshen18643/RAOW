# Reload AgeOfWarFP in Roblox Studio
# Run from PowerShell in this repo: .\reload.ps1

$ProjectRoot = $PSScriptRoot
$BuildOutput = Join-Path $ProjectRoot "build.rbxl"

Set-Location $ProjectRoot

# Prefer a Rojo binary on PATH; fall back to the bundled tools/rojo.exe.
$RojoPath = Get-Command rojo -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $RojoPath) {
    $RojoPath = Join-Path $ProjectRoot "tools\rojo.exe"
    if (-not (Test-Path $RojoPath)) {
        Write-Host "Rojo not found." -ForegroundColor Red
        Write-Host "Install Rojo from https://rojo.space or place rojo.exe in tools/rojo.exe" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Building project with $RojoPath..." -ForegroundColor Cyan
& $RojoPath build default.project.json -o $BuildOutput
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    exit 1
}

Write-Host "Closing Roblox Studio..." -ForegroundColor Cyan
Stop-Process -Name "RobloxStudioBeta" -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

Write-Host "Opening build.rbxl in Roblox Studio..." -ForegroundColor Cyan
Start-Process $BuildOutput

Write-Host "Done." -ForegroundColor Green
