[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)] [long] $SmallProductId,
    [Parameter(Mandatory = $true)] [long] $MediumProductId,
    [Parameter(Mandatory = $true)] [long] $LargeProductId,
    [long] $SupporterPassId = 0
)

$ErrorActionPreference = 'Stop'

$productIds = @($SmallProductId, $MediumProductId, $LargeProductId)
if ($productIds | Where-Object { $_ -le 0 }) {
    throw 'All three Developer Product IDs must be positive Roblox asset IDs.'
}
if (($productIds | Sort-Object -Unique).Count -ne $productIds.Count) {
    throw 'Developer Product IDs must be unique.'
}
if ($SupporterPassId -lt 0) {
    throw 'SupporterPassId must be a positive Roblox Pass ID, or 0 to keep the optional pass disabled.'
}

$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'src/shared/Config/MonetizationConfig.luau'
$content = [IO.File]::ReadAllText($configPath)
$replacements = @(
    @{ Pattern = '(id = "bonds_small", productId = )\d+'; Value = "`${1}$SmallProductId" },
    @{ Pattern = '(id = "bonds_medium", productId = )\d+'; Value = "`${1}$MediumProductId" },
    @{ Pattern = '(id = "bonds_large", productId = )\d+'; Value = "`${1}$LargeProductId" },
    @{ Pattern = '(MonetizationConfig\.SUPPORTER_PASS_ID = )\d+'; Value = "`${1}$SupporterPassId" }
)

foreach ($replacement in $replacements) {
    $matches = [regex]::Matches($content, $replacement.Pattern)
    if ($matches.Count -ne 1) {
        throw "Expected exactly one configuration target for pattern: $($replacement.Pattern)"
    }
    $content = [regex]::Replace($content, $replacement.Pattern, $replacement.Value)
}

if ($PSCmdlet.ShouldProcess($configPath, 'Configure Roblox commerce IDs')) {
    [IO.File]::WriteAllText($configPath, $content, [Text.UTF8Encoding]::new($false))
    Write-Host 'Commerce IDs configured successfully.'
    Write-Host 'Next: run tools\check_balance.ps1, rebuild build.rbxl, then complete the staging receipt checklist in PRODUCTION.md.'
}
