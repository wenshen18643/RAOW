$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$unitsPath = Join-Path $root 'src/shared/Config/Units.luau'
$agesPath = Join-Path $root 'src/shared/Config/Ages.luau'
$gamePath = Join-Path $root 'src/shared/Config/GameConfig.luau'

$unitPattern = 'id = "age(?<age>\d+)_(?<role>[^"]+)".*cost = (?<cost>\d+), hp = (?<hp>\d+), damage = (?<damage>\d+), range = (?<range>\d+), attackSpeed = (?<speed>[0-9.]+), moveSpeed = (?<move>[0-9.]+)'
$units = Select-String -Path $unitsPath -Pattern $unitPattern | ForEach-Object {
    $m = $_.Matches[0].Groups
    [pscustomobject]@{
        Age = [int]$m['age'].Value
        Role = $m['role'].Value
        Cost = [int]$m['cost'].Value
        HP = [int]$m['hp'].Value
        Damage = [int]$m['damage'].Value
        AttackSpeed = [double]$m['speed'].Value
        MoveSpeed = [double]$m['move'].Value
    }
}

if ($units.Count -ne 16) { throw "Expected 16 units, found $($units.Count)." }
foreach ($age in 1..5) {
    $ageUnits = @($units | Where-Object Age -eq $age)
    foreach ($role in @('melee', 'ranged', 'heavy')) {
        if (-not ($ageUnits | Where-Object Role -eq $role)) { throw "Age $age is missing role '$role'." }
    }
}
foreach ($unit in $units) {
    if ($unit.Cost -le 0 -or $unit.HP -le 0 -or $unit.Damage -le 0) { throw "Non-positive stats in age $($unit.Age) $($unit.Role)." }
    if ($unit.AttackSpeed -lt 0.15 -or $unit.MoveSpeed -gt 30) { throw "Unsafe timing/speed in age $($unit.Age) $($unit.Role)." }
}

$startingGoldMatch = Select-String -Path $gamePath -Pattern 'STARTING_GOLD = (?<value>\d+)' | Select-Object -First 1
$startingGold = [int]$startingGoldMatch.Matches[0].Groups['value'].Value
$ageOne = @{}
$units | Where-Object Age -eq 1 | ForEach-Object { $ageOne[$_.Role] = $_.Cost }
$allDoctrineRequirements = 3 * $ageOne.melee + 3 * $ageOne.ranged + 2 * $ageOne.heavy
if ($allDoctrineRequirements -le $startingGold) {
    throw "Starting gold ($startingGold) can buy all doctrine requirements ($allDoctrineRequirements)."
}

$thresholds = Select-String -Path $agesPath -Pattern 'xpRequired = (?<xp>\d+)' | ForEach-Object { [int]$_.Matches[0].Groups['xp'].Value }
if ($thresholds.Count -ne 5) { throw "Expected five XP thresholds." }
for ($i = 1; $i -lt $thresholds.Count; $i++) {
    if ($thresholds[$i] -le $thresholds[$i - 1]) { throw "XP thresholds are not strictly increasing." }
}

Write-Host "Balance checks passed: $($units.Count) units, five ages, all doctrine requirements ${allDoctrineRequirements}g > ${startingGold}g starting gold."
