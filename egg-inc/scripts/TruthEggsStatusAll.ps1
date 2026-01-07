# TruthEggsStatusAll.ps1
# Returns Truth Eggs (Eggs of Virtue) status for all tracked Egg Inc accounts
# Calculates both Earned and Pending EoV using discovered threshold formulas
# Reads from cached JSON files - run FetchAllAccounts.ps1 first to refresh data

$dataDir = Join-Path $PSScriptRoot "..\data"

$accounts = @(
    @{ Name = "King Friday!"; File = "king-friday.json" },
    @{ Name = "King Saturday!"; File = "king-saturday.json" },
    @{ Name = "King Sunday!"; File = "king-sunday.json" },
    @{ Name = "King Monday!"; File = "king-monday.json" }
)

# Virtue path indices: 0=Curiosity, 1=Integrity, 2=Humility, 3=Resilience, 4=Kindness

# Standard thresholds (1-2-5 progression from 500B) for Curiosity, Integrity, Humility, Kindness
$standardThresholds = @(5e11)  # 500B
foreach ($base in @(1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18)) {
    $standardThresholds += $base
    $standardThresholds += $base * 2
    $standardThresholds += $base * 5
}
$standardThresholds = $standardThresholds | Sort-Object -Unique

# Resilience thresholds (linear 1T-7T then 1-2-5 from 20T)
$resilienceThresholds = @(1, 2, 3, 4, 5, 6, 7) | ForEach-Object { $_ * 1e12 }
foreach ($base in @(2e13, 1e14, 1e15, 1e16, 1e17, 1e18)) {
    $resilienceThresholds += $base
    $resilienceThresholds += $base * 2.5
    $resilienceThresholds += $base * 5
}
$resilienceThresholds = $resilienceThresholds | Sort-Object -Unique

function Get-CompletedTiers {
    param([double]$delivered, [double[]]$thresholds)
    $tiers = 0
    foreach ($t in $thresholds) {
        if ($delivered -ge $t) { $tiers++ } else { break }
    }
    return $tiers
}

$results = @()

foreach ($acct in $accounts) {
    $filePath = Join-Path $dataDir $acct.File
    if (-not (Test-Path $filePath)) {
        Write-Warning "Data file not found: $filePath - run FetchAllAccounts.ps1 first"
        continue
    }
    $r = Get-Content $filePath -Raw | ConvertFrom-Json
    
    $earnedPerPath = @(0, 0, 0, 0, 0)
    $pendingPerPath = @(0, 0, 0, 0, 0)
    
    if ($r.virtue.eovEarnedList) {
        $earnedPerPath = $r.virtue.eovEarnedList
    }
    
    if ($r.virtue.eggsDeliveredList) {
        for ($i = 0; $i -lt 5; $i++) {
            $delivered = [double]$r.virtue.eggsDeliveredList[$i]
            $thresholds = if ($i -eq 3) { $resilienceThresholds } else { $standardThresholds }
            $totalTiers = Get-CompletedTiers $delivered $thresholds
            $pendingPerPath[$i] = [Math]::Max(0, $totalTiers - [int]$earnedPerPath[$i])
        }
    }
    
    $totalEarned = ($earnedPerPath | Measure-Object -Sum).Sum
    $totalPending = ($pendingPerPath | Measure-Object -Sum).Sum
    $shifts = [int]$r.virtue.shiftCount
    $resets = [int]$r.virtue.resets
    
    $results += [PSCustomObject]@{
        Account    = $acct.Name
        TE         = [int]$totalEarned
        'Pending TE' = [int]$totalPending
        'Total TE' = [int]($totalEarned + $totalPending)
        Shifts     = $shifts
        Resets     = $resets
    }
}

$results | Format-Table -AutoSize