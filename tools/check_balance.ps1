$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$unitsPath = Join-Path $root 'src/shared/Config/Units.luau'
$agesPath = Join-Path $root 'src/shared/Config/Ages.luau'
$gamePath = Join-Path $root 'src/shared/Config/GameConfig.luau'
$turretsPath = Join-Path $root 'src/shared/Config/Turrets.luau'
$pvePath = Join-Path $root 'src/shared/Config/PvELevels.luau'
$monetizationPath = Join-Path $root 'src/shared/Config/MonetizationConfig.luau'
$progressionPath = Join-Path $root 'src/shared/Config/ProgressionConfig.luau'

$unitPattern = 'id = "age(?<age>\d+)_(?<role>[^"]+)".*cost = (?<cost>\d+), hp = (?<hp>\d+), damage = (?<damage>\d+), range = (?<range>\d+), attackSpeed = (?<speed>[0-9.]+), moveSpeed = (?<move>[0-9.]+)'
$units = Select-String -Path $unitsPath -Pattern $unitPattern | ForEach-Object {
    $m = $_.Matches[0].Groups
    [pscustomobject]@{
        Age = [int]$m['age'].Value
        Role = $m['role'].Value
        Cost = [int]$m['cost'].Value
        HP = [int]$m['hp'].Value
        Damage = [int]$m['damage'].Value
        Range = [int]$m['range'].Value
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
$killRatio = [double](Select-String -Path $gamePath -Pattern 'UNIT_KILL_GOLD_RATIO = (?<value>[0-9.]+)' | Select-Object -First 1).Matches[0].Groups['value'].Value
$heroKillBonus = [double](Select-String -Path $gamePath -Pattern 'HERO_KILL_BONUS_MULT = (?<value>[0-9.]+)' | Select-Object -First 1).Matches[0].Groups['value'].Value
if ($killRatio -le 0 -or $killRatio -ge 1) { throw "Unit kill gold must recycle only part of the defeated unit cost." }
if ($killRatio * $heroKillBonus -ge 1) { throw "Hero kill bonus creates more gold than the defeated unit cost." }
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

$incomeValues = (Select-String -Path $gamePath -Pattern 'PASSIVE_INCOME_BY_AGE = \{ (?<values>[^}]+) \}' | Select-Object -First 1).Matches[0].Groups['values'].Value -split ',' | ForEach-Object { [double]$_.Trim() }
if ($incomeValues.Count -ne 5) { throw "Expected one passive-income value per age." }
$turretPattern = '\[(?<age>\d+)\].*cost = (?<cost>\d+), damage = (?<damage>\d+), range = (?<range>\d+), attackSpeed = (?<speed>[0-9.]+)'
$turrets = Select-String -Path $turretsPath -Pattern $turretPattern | ForEach-Object {
    $m = $_.Matches[0].Groups
    [pscustomobject]@{ Age = [int]$m['age'].Value; Cost = [int]$m['cost'].Value }
}
if ($turrets.Count -ne 5) { throw "Expected one turret per age." }
foreach ($age in 1..5) {
    $income = $incomeValues[$age - 1]
    $melee = $units | Where-Object { $_.Age -eq $age -and $_.Role -eq 'melee' } | Select-Object -First 1
    $heavy = $units | Where-Object { $_.Age -eq $age -and $_.Role -eq 'heavy' } | Select-Object -First 1
    $turret = $turrets | Where-Object Age -eq $age | Select-Object -First 1
    $meleeWait = $melee.Cost / $income
    $heavyWait = $heavy.Cost / $income
    $turretWait = $turret.Cost / $income
    if ($meleeWait -lt 5 -or $meleeWait -gt 15) { throw "Age $age basic unit takes $meleeWait seconds of passive income." }
    if ($heavyWait -lt 35 -or $heavyWait -gt 60) { throw "Age $age heavy takes $heavyWait seconds of passive income." }
    if ($turretWait -lt 40 -or $turretWait -gt 70) { throw "Age $age turret takes $turretWait seconds of passive income." }

    $ranged = $units | Where-Object { $_.Age -eq $age -and $_.Role -eq 'ranged' } | Select-Object -First 1
    $heavyCostRatio = $heavy.Cost / $melee.Cost
    $heavyHpEfficiencyRatio = ($heavy.HP / $heavy.Cost) / ($melee.HP / $melee.Cost)
    $heavyDpsEfficiencyRatio = (($heavy.Damage / $heavy.AttackSpeed) / $heavy.Cost) / (($melee.Damage / $melee.AttackSpeed) / $melee.Cost)
    if ($heavyCostRatio -lt 3.5 -or $heavyCostRatio -gt 6) { throw "Age $age heavy has no coherent commitment cost." }
    if ($heavyHpEfficiencyRatio -lt 0.8 -or $heavyHpEfficiencyRatio -gt 1.25) { throw "Age $age heavy tank efficiency is a trap or dominant." }
    if ($heavyDpsEfficiencyRatio -lt 0.2 -or $heavyDpsEfficiencyRatio -gt 0.5) { throw "Age $age heavy damage efficiency erases its tank tradeoff." }
    if ($ranged.Range -lt $melee.Range * 4 -or ($ranged.HP / $ranged.Cost) -ge ($melee.HP / $melee.Cost)) { throw "Age $age ranged unit lacks a range-for-durability tradeoff." }
}

$super = $units | Where-Object { $_.Age -eq 5 -and $_.Role -eq 'super_heavy' } | Select-Object -First 1
$ageFiveHeavy = $units | Where-Object { $_.Age -eq 5 -and $_.Role -eq 'heavy' } | Select-Object -First 1
if (($super.HP / $super.Cost) -gt 1.05 * ($ageFiveHeavy.HP / $ageFiveHeavy.Cost)) { throw "Super-heavy has dominant health efficiency." }
if ((($super.Damage / $super.AttackSpeed) / $super.Cost) -gt 1.05 * (($ageFiveHeavy.Damage / $ageFiveHeavy.AttackSpeed) / $ageFiveHeavy.Cost)) { throw "Super-heavy has dominant damage efficiency." }

$upgradeCaps = Select-String -Path $pvePath -Pattern 'maxTier = (?<cap>\d+)' | ForEach-Object { [int]$_.Matches[0].Groups['cap'].Value }
if ($upgradeCaps.Count -ne 3) { throw "Expected finite caps on all three PvE upgrade tracks." }
if (($upgradeCaps | Measure-Object -Maximum).Maximum -gt 10) { throw "A PvE upgrade cap exceeds the 10-tier balance ceiling." }
$campaignCap = Select-String -Path $pvePath -Pattern 'MAX_LEVEL = (?<level>\d+)' | Select-Object -First 1
if ([int]$campaignCap.Matches[0].Groups['level'].Value -ne 25) { throw "PvE campaign must have a clear 25-stage endpoint." }

$bossRows = Select-String -Path $pvePath -Pattern '\{ unitId = "(?<id>age(?<age>\d+)_[^"]+)", hpScale = (?<hp>[0-9.]+), damageScale = (?<damage>[0-9.]+) \}' | ForEach-Object {
    $m = $_.Matches[0].Groups
    [pscustomobject]@{ Id = $m['id'].Value; Age = [int]$m['age'].Value; HpScale = [double]$m['hp'].Value; DamageScale = [double]$m['damage'].Value }
}
if ($bossRows.Count -ne 5) { throw "Expected one boss definition for every fifth campaign stage." }
for ($i = 0; $i -lt $bossRows.Count; $i++) {
    if ($bossRows[$i].Age -ne $i + 1) { throw "Boss tier $($i + 1) uses an age-$($bossRows[$i].Age) unit." }
    if ($bossRows[$i].HpScale -gt 8 -or $bossRows[$i].DamageScale -gt 1.5) { throw "Boss tier $($i + 1) exceeds the encounter scaling ceiling." }
}
$slamUnitRatio = [double](Select-String -Path $pvePath -Pattern 'slamMaxUnitHpRatio = (?<value>[0-9.]+)' | Select-Object -First 1).Matches[0].Groups['value'].Value
$slamHeroRatio = [double](Select-String -Path $pvePath -Pattern 'slamMaxHeroHpRatio = (?<value>[0-9.]+)' | Select-Object -First 1).Matches[0].Groups['value'].Value
if ($slamUnitRatio -gt 0.6 -or $slamHeroRatio -gt 0.45) { throw "Boss slam can remove too much health in one telegraphed hit." }

$dailyMatch = Select-String -Path $monetizationPath -Pattern 'DAILY_WAR_BONDS = (?<amount>\d+)' | Select-Object -First 1
$dailyAmount = [int]$dailyMatch.Matches[0].Groups['amount'].Value
$battleAmount = [int](Select-String -Path $monetizationPath -Pattern 'DAILY_BATTLE_BONDS = (?<amount>\d+)' | Select-Object -First 1).Matches[0].Groups['amount'].Value
$winAmount = [int](Select-String -Path $monetizationPath -Pattern 'DAILY_WIN_BONDS = (?<amount>\d+)' | Select-Object -First 1).Matches[0].Groups['amount'].Value
$cosmeticCosts = Select-String -Path $monetizationPath -Pattern 'cost = (?<cost>\d+)' | ForEach-Object { [int]$_.Matches[0].Groups['cost'].Value }
if ($cosmeticCosts.Count -lt 3 -or ($cosmeticCosts | Measure-Object -Minimum).Minimum -lt 3 * ($dailyAmount + $battleAmount + $winAmount)) {
    throw "Cosmetic prices must require at least three fully active free days."
}
$configuredProductIds = Select-String -Path $monetizationPath -Pattern 'productId = (?<id>\d+)' | ForEach-Object { [int]$_.Matches[0].Groups['id'].Value } | Where-Object { $_ -gt 0 }
if (($configuredProductIds | Sort-Object -Unique).Count -ne $configuredProductIds.Count) { throw "Developer product IDs must be unique." }

$finalReward = Select-String -Path $progressionPath -Pattern '^\s*\[50\]\s*=' | Select-Object -First 1
if (-not $finalReward) { throw "The level ladder needs a real level-50 reward." }

Write-Host "Balance checks passed: $($units.Count) units, verified melee/ranged/heavy counter-role tradeoffs, normalized purchase times, non-inflationary kill rewards, five age-matched bosses, finite PvE upgrades, cosmetic-only catalog, and all doctrine requirements ${allDoctrineRequirements}g > ${startingGold}g starting gold."
