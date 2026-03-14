#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 2: Enriches the user productivity JSON with per-user premium request consumption.
.DESCRIPTION
    Reads relias-engineering-user-productivity.json produced by Phase 1
    (Get-AllUserProductivityMetrics.ps1) and adds per-user premium request
    totals from the GitHub enterprise billing API.

    Supports incremental enrichment: days that were already collected in a
    previous run are skipped when a CachePath file exists. This dramatically
    reduces API calls on subsequent runs.
.PARAMETER InputPath
    Path to the JSON file produced by Phase 1. Defaults to
    relias-engineering-user-productivity.json in the current directory.
.PARAMETER CachePath
    Path to the premium request cache file. Stores per-user, per-day results
    so subsequent runs skip already-collected days. Defaults to
    relias-engineering-premium-cache.json in the same directory as InputPath.
.PARAMETER SkipCache
    Ignore any existing cache and re-collect all days from scratch.
.EXAMPLE
    .\Get-AllUserPremiumRequestConsumption.ps1
.EXAMPLE
    .\Get-AllUserPremiumRequestConsumption.ps1 -InputPath .\relias-engineering-user-productivity.json
.EXAMPLE
    .\Get-AllUserPremiumRequestConsumption.ps1 -SkipCache
#>

[CmdletBinding()]
param(
    [string]$InputPath,

    [string]$CachePath,

    [switch]$SkipCache
)

$ErrorActionPreference = 'Stop'

$Enterprise = 'bertelsmann'

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path (Get-Location) 'relias-engineering-user-productivity.json'
}

if (-not (Test-Path $InputPath)) {
    throw "Input file not found: $InputPath. Run Get-AllUserProductivityMetrics.ps1 (Phase 1) first."
}

if ([string]::IsNullOrWhiteSpace($CachePath)) {
    $CachePath = Join-Path (Split-Path $InputPath) 'relias-engineering-premium-cache.json'
}

# ── Shared helpers ───────────────────────────────────────────────────

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$Headers,

        [switch]$AllowFailure
    )

    $arguments = @('api')
    if ($null -ne $Headers) {
        foreach ($header in $Headers) {
            $arguments += @('-H', $header)
        }
    }
    $arguments += $Path

    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $output = & gh @arguments 2> $stderrFile
        $stderrOutput = Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue
    }
    finally {
        if ([System.IO.File]::Exists($stderrFile)) {
            [System.IO.File]::Delete($stderrFile)
        }
    }

    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $null
        }

        $errorMessage = $stderrOutput
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = ($output | Out-String).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = "GitHub API call failed for '$Path'."
        }

        throw $errorMessage
    }

    if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Get-CoreRateState {
    $rateLimit = Invoke-GhApiJson -Path '/rate_limit'
    return [PSCustomObject]@{
        Remaining  = [int]$rateLimit.resources.core.remaining
        ResetEpoch = [int64]$rateLimit.resources.core.reset
    }
}

function Wait-ForCoreBudget {
    param(
        [Parameter(Mandatory)]
        [ref]$RemainingCalls,

        [Parameter(Mandatory)]
        [ref]$ResetEpoch,

        [int]$Threshold = 5
    )

    if ($RemainingCalls.Value -gt $Threshold) {
        return
    }

    $rateState = Get-CoreRateState
    $RemainingCalls.Value = $rateState.Remaining
    $ResetEpoch.Value = $rateState.ResetEpoch

    if ($RemainingCalls.Value -gt $Threshold) {
        return
    }

    $resetTime = [DateTimeOffset]::FromUnixTimeSeconds($ResetEpoch.Value).LocalDateTime
    $sleepSeconds = [math]::Ceiling(($resetTime - (Get-Date)).TotalSeconds) + 5
    if ($sleepSeconds -gt 0) {
        Write-Information "Core limit nearly exhausted. Sleeping until $resetTime..." -InformationAction Continue
        Start-Sleep -Seconds $sleepSeconds
    }

    $rateState = Get-CoreRateState
    $RemainingCalls.Value = $rateState.Remaining
    $ResetEpoch.Value = $rateState.ResetEpoch
}

# ── Cache management ─────────────────────────────────────────────────

function Read-PremiumCache {
    if ($SkipCache -or -not (Test-Path $CachePath)) {
        return @{}
    }

    $raw = Get-Content $CachePath -Raw | ConvertFrom-Json
    $cache = @{}
    foreach ($property in $raw.PSObject.Properties) {
        $userDays = @{}
        foreach ($dayProperty in $property.Value.PSObject.Properties) {
            $userDays[$dayProperty.Name] = [double]$dayProperty.Value
        }
        $cache[$property.Name] = $userDays
    }

    return $cache
}

function Save-PremiumCache {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Cache
    )

    $ordered = [ordered]@{}
    foreach ($username in ($Cache.Keys | Sort-Object)) {
        $days = [ordered]@{}
        foreach ($day in ($Cache[$username].Keys | Sort-Object)) {
            $days[$day] = $Cache[$username][$day]
        }
        $ordered[$username] = $days
    }

    $ordered | ConvertTo-Json -Depth 4 | Set-Content -Path $CachePath
}

# ── Main execution ───────────────────────────────────────────────────

try {
    $null = & gh auth status
}
catch {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

$data = Get-Content $InputPath -Raw | ConvertFrom-Json
$startDate = [datetime]::ParseExact($data.StartDate, 'yyyy-MM-dd HH:mm', $null).Date
$endDate = [datetime]::ParseExact($data.EndDate, 'yyyy-MM-dd HH:mm', $null).Date

$premiumCache = Read-PremiumCache
$headers = @('Accept: application/vnd.github+json')
$rateState = Get-CoreRateState
$remainingCalls = $rateState.Remaining
$resetEpoch = $rateState.ResetEpoch

$users = @($data.Users)
$totalUsers = $users.Count
$totalCacheHits = 0
$totalApiCalls = 0
$userIndex = 0

foreach ($user in $users) {
    $userIndex++
    $username = $user.Username
    $percentComplete = [int][math]::Floor((($userIndex - 1) / [math]::Max($totalUsers, 1)) * 100)
    Write-Progress -Activity 'Collecting premium requests' -Status "[$userIndex/$totalUsers] $username | Core remaining: $remainingCalls" -PercentComplete $percentComplete -CurrentOperation 'Querying daily billing usage'
    Write-Information "[Premium $userIndex/$totalUsers] $username" -InformationAction Continue

    if (-not $premiumCache.ContainsKey($username)) {
        $premiumCache[$username] = @{}
    }

    $total = 0.0
    for ($date = $startDate; $date -le $endDate; $date = $date.AddDays(1)) {
        $dayKey = $date.ToString('yyyy-MM-dd')

        if ($premiumCache[$username].ContainsKey($dayKey)) {
            $total += $premiumCache[$username][$dayKey]
            $totalCacheHits++
            continue
        }

        Wait-ForCoreBudget -RemainingCalls ([ref]$remainingCalls) -ResetEpoch ([ref]$resetEpoch)

        $queryString = @(
            "year=$($date.Year)",
            "month=$($date.Month)",
            "day=$($date.Day)",
            "user=$([System.Uri]::EscapeDataString($username))",
            'product=Copilot'
        ) -join '&'

        $path = "/enterprises/$Enterprise/settings/billing/premium_request/usage?$queryString"
        $response = Invoke-GhApiJson -Path $path -Headers $headers -AllowFailure
        $remainingCalls--
        $totalApiCalls++

        $dayTotal = 0.0
        if ($null -ne $response) {
            foreach ($item in @($response.usageItems)) {
                if ($null -ne $item.grossQuantity) {
                    $dayTotal += [double]$item.grossQuantity
                }
            }
        }

        $premiumCache[$username][$dayKey] = $dayTotal
        $total += $dayTotal
    }

    # Update the user record in-place
    if ($null -eq $user.PremiumRequests) {
        $user | Add-Member -NotePropertyName PremiumRequests -NotePropertyValue ([math]::Round($total, 2)) -Force
    }
    else {
        $user.PremiumRequests = [math]::Round($total, 2)
    }

    $completedPercent = [int][math]::Floor(($userIndex / [math]::Max($totalUsers, 1)) * 100)
    Write-Progress -Activity 'Collecting premium requests' -Status "[$userIndex/$totalUsers] $username | Premium: $($user.PremiumRequests) | Core remaining: $remainingCalls" -PercentComplete $completedPercent

    # Save cache periodically (every 10 users) for crash resilience
    if ($userIndex % 10 -eq 0) {
        Save-PremiumCache -Cache $premiumCache
    }
}

Write-Progress -Activity 'Collecting premium requests' -Completed

# Final cache save
Save-PremiumCache -Cache $premiumCache

# Update metadata and write enriched JSON back to input file
$data.PremiumRequestsIncluded = $true
if ($null -eq ($data.PSObject.Properties | Where-Object Name -eq 'PremiumRequestsEnrichedAt')) {
    $data | Add-Member -NotePropertyName PremiumRequestsEnrichedAt -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}
else {
    $data.PremiumRequestsEnrichedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}

$data | ConvertTo-Json -Depth 8 | Set-Content -Path $InputPath

[PSCustomObject]@{
    InputPath      = $InputPath
    CachePath      = $CachePath
    UserCount      = $totalUsers
    DaysInRange    = (($endDate - $startDate).Days + 1)
    CacheHits      = $totalCacheHits
    ApiCalls       = $totalApiCalls
    RateRemaining  = $remainingCalls
} | Format-Table -AutoSize | Out-String | Write-Output
