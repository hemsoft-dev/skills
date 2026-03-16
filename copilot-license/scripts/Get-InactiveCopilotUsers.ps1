<#
.SYNOPSIS
    Find Copilot license holders who haven't used Copilot recently
    or who have zero premium request consumption.

.DESCRIPTION
    Queries the organization's Copilot seat assignments and identifies users
    who have not had any Copilot activity in the current billing month (or
    within a configurable number of days). These are candidates for license
    removal to save costs.

    When -Enterprise is provided, also cross-references the enterprise
    premium request billing API to find users who show activity (tab
    completions) but have consumed zero premium requests in the current
    month. These "tab-only" users can switch to Copilot Free or a free
    alternative like Windsurf/Codeium without losing functionality.

.PARAMETER Org
    The GitHub organization name (case-insensitive).

.PARAMETER Enterprise
    The GitHub enterprise slug (e.g. "hemsoft-corp"). When provided,
    queries the premium request billing API to identify active users
    with zero premium request consumption.

.PARAMETER InactiveDays
    Number of days without activity to consider a user inactive.
    Default: 0 (meaning "no activity in the current calendar month").
    When set to a positive value, overrides the current-month logic
    and uses a rolling window instead.

.PARAMETER ExportCsv
    Export results to a CSV file in the current directory.

.PARAMETER IncludePendingCancellation
    Include users who already have pending cancellation dates.

.EXAMPLE
    .\Get-InactiveCopilotUsers.ps1 -Org fhemmer

.EXAMPLE
    .\Get-InactiveCopilotUsers.ps1 -Org fhemmer -Enterprise hemsoft-corp

.EXAMPLE
    .\Get-InactiveCopilotUsers.ps1 -Org fhemmer -InactiveDays 30

.EXAMPLE
    .\Get-InactiveCopilotUsers.ps1 -Org fhemmer -ExportCsv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Org,

    [string]$Enterprise,

    [int]$InactiveDays = 0,

    [switch]$ExportCsv,

    [switch]$IncludePendingCancellation
)

$InformationPreference = 'Continue'

function Get-AllSeatData {
    param([string]$OrgName)

    $allSeats = @()
    $page = 1
    $perPage = 100

    do {
        $response = gh api "/orgs/$OrgName/copilot/billing/seats?page=$page&per_page=$perPage" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to fetch seats (page $page): $response"
            return $null
        }

        $data = $response | ConvertFrom-Json
        if ($data.seats) {
            $allSeats += $data.seats
        }

        $totalSeats = $data.total_seats
        $page++
    } while ($allSeats.Count -lt $totalSeats)

    return [PSCustomObject]@{
        TotalSeats = $totalSeats
        Seats      = $allSeats
    }
}

Write-Information "`e[36mFetching Copilot seats for org: $Org...`e[0m"

$result = Get-AllSeatData -OrgName $Org
if (-not $result) { exit 1 }

$now = Get-Date

# Determine the cutoff date
if ($InactiveDays -gt 0) {
    $cutoffDate = $now.AddDays(-$InactiveDays)
    $cutoffLabel = "last $InactiveDays days"
} else {
    $cutoffDate = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
    $cutoffLabel = "current month (since $($cutoffDate.ToString('yyyy-MM-dd')))"
}

Write-Information "`e[36mAnalyzing activity — inactive = no usage in $cutoffLabel`e[0m"
Write-Information ""

# Identify inactive users
$inactiveCandidates = $result.Seats | Where-Object {
    # Skip users already pending cancellation unless requested
    if (-not $IncludePendingCancellation -and $_.pending_cancellation_date) {
        return $false
    }

    # No activity ever recorded
    if (-not $_.last_activity_at) {
        return $true
    }

    # Activity before the cutoff
    $lastActivity = [datetime]$_.last_activity_at
    return $lastActivity -lt $cutoffDate
} | ForEach-Object {
    $lastActivity = if ($_.last_activity_at) { [datetime]$_.last_activity_at } else { $null }
    $daysSince = if ($lastActivity) { [math]::Floor(($now - $lastActivity).TotalDays) } else { -1 }

    [PSCustomObject]@{
        Login               = $_.assignee.login
        LastActivity        = if ($lastActivity) { $lastActivity.ToString('yyyy-MM-dd') } else { 'Never' }
        DaysInactive        = if ($daysSince -ge 0) { $daysSince } else { 'N/A' }
        LastEditor          = if ($_.last_activity_editor) { $_.last_activity_editor.Split('/')[0] } else { '-' }
        PlanType            = if ($_.plan_type) { $_.plan_type } else { '-' }
        Reason              = 'Inactive'
    }
}

# Cross-reference premium request consumption if Enterprise is provided
$zeroPremiumCandidates = @()
if ($Enterprise) {
    $inactiveLogins = @($inactiveCandidates | Select-Object -ExpandProperty Login)
    $activeSeats = $result.Seats | Where-Object {
        $_.assignee.login -notin $inactiveLogins -and
        (-not $_.pending_cancellation_date -or $IncludePendingCancellation)
    }

    if ($activeSeats.Count -gt 0) {
        $year = $now.Year
        $month = $now.Month
        Write-Information "`e[36mChecking premium request usage for $($activeSeats.Count) active users ($year-$('{0:D2}' -f $month))...`e[0m"

        foreach ($seat in $activeSeats) {
            $login = $seat.assignee.login
            $apiUrl = "/enterprises/$Enterprise/settings/billing/premium_request/usage"
            $apiUrl += "?year=$year&month=$month&user=$login&product=Copilot"
            $premiumResponse = gh api $apiUrl 2>&1

            if ($LASTEXITCODE -eq 0) {
                $premiumData = $premiumResponse | ConvertFrom-Json

                # Handle response: could be array or object with nested items
                $items = @()
                if ($premiumData -is [array]) {
                    $items = $premiumData
                } elseif ($premiumData.usageItems) {
                    $items = $premiumData.usageItems
                } elseif ($premiumData.usage_items) {
                    $items = $premiumData.usage_items
                }

                $totalNet = 0
                foreach ($item in $items) {
                    $qty = if ($null -ne $item.netQuantity) { $item.netQuantity }
                           elseif ($null -ne $item.net_quantity) { $item.net_quantity }
                           else { 0 }
                    $totalNet += $qty
                }

                if ($totalNet -eq 0) {
                    $lastActivity = if ($seat.last_activity_at) { [datetime]$seat.last_activity_at } else { $null }
                    $daysSince = if ($lastActivity) { [math]::Floor(($now - $lastActivity).TotalDays) } else { -1 }

                    $zeroPremiumCandidates += [PSCustomObject]@{
                        Login               = $login
                        LastActivity        = if ($lastActivity) { $lastActivity.ToString('yyyy-MM-dd') } else { 'Never' }
                        DaysInactive        = if ($daysSince -ge 0) { $daysSince } else { 'N/A' }
                        LastEditor          = if ($seat.last_activity_editor) { $seat.last_activity_editor.Split('/')[0] } else { '-' }
                        PlanType            = if ($seat.plan_type) { $seat.plan_type } else { '-' }
                        Reason              = 'Zero Premium Requests'
                    }
                }
            } else {
                Write-Warning "Could not check premium requests for $($login): $premiumResponse"
            }
        }
    }
}

# Combine all candidates
$candidates = @($inactiveCandidates) + @($zeroPremiumCandidates) |
    Sort-Object -Property @{Expression = { if ($_.Reason -eq 'Inactive') { 0 } else { 1 } }},
                          @{Expression = { if ($_.DaysInactive -eq 'N/A') { 9999 } else { [int]$_.DaysInactive } }; Descending = $true }

# Display results
$activeCount = $result.TotalSeats - $candidates.Count

if ($candidates.Count -eq 0) {
    Write-Information "`e[32m✓ All $($result.TotalSeats) seat holders have been active in the $cutoffLabel.`e[0m"
    if ($Enterprise) {
        Write-Information "`e[32m  All active users have premium request consumption.`e[0m"
    }
    exit 0
}

Write-Information "`e[33m╔═══════════════════════════════════════════════════════════════╗`e[0m"
Write-Information "`e[33m║  Copilot License Review — $Org`e[0m"
Write-Information "`e[33m║  Candidates for removal: $($candidates.Count) of $($result.TotalSeats) seats`e[0m"
if ($inactiveCandidates.Count -gt 0) {
    Write-Information "`e[33m║    Inactive:             $($inactiveCandidates.Count)`e[0m"
}
if ($zeroPremiumCandidates.Count -gt 0) {
    Write-Information "`e[33m║    Zero Premium Requests: $($zeroPremiumCandidates.Count) (tab-only users)`e[0m"
}
Write-Information "`e[33m╚═══════════════════════════════════════════════════════════════╝`e[0m"
Write-Information ""

$candidates | Format-Table -AutoSize

# Cost estimate
$billingResponse = gh api "/orgs/$Org/copilot/billing" 2>&1
$monthlyCostPerSeat = 19  # Business default
if ($LASTEXITCODE -eq 0) {
    $billing = $billingResponse | ConvertFrom-Json
    if ($billing.seat_management_setting -eq 'assign_all') {
        # Enterprise is $39/seat, Business is $19/seat — keep default
    }
}

$potentialSavings = $candidates.Count * $monthlyCostPerSeat
$annualSavings = $potentialSavings * 12

Write-Information "`e[36mSummary:`e[0m"
Write-Information "  Total seats:             $($result.TotalSeats)"
Write-Information "  Active (using premium):  `e[32m$activeCount`e[0m"
Write-Information "  Inactive:                `e[33m$($inactiveCandidates.Count)`e[0m"
if ($Enterprise) {
    Write-Information "  Zero Premium Requests:   `e[33m$($zeroPremiumCandidates.Count)`e[0m"
}
Write-Information "  Total candidates:        `e[33m$($candidates.Count)`e[0m"
Write-Information ""
Write-Information "`e[36mPotential savings (at `$$monthlyCostPerSeat/seat/month):`e[0m"
Write-Information "  Monthly:  `e[32m`$$potentialSavings`e[0m"
Write-Information "  Annual:   `e[32m`$$annualSavings`e[0m"
Write-Information ""

if ($zeroPremiumCandidates.Count -gt 0) {
    Write-Information "`e[90mNote: 'Zero Premium Requests' users only use tab completions (free).`e[0m"
    Write-Information "`e[90mThey can switch to Copilot Free (2,000 completions/mo) or Windsurf (unlimited, free).`e[0m"
    Write-Information ""
}

# Provide removal command
$usernames = ($candidates | Select-Object -ExpandProperty Login) -join '","'
Write-Information "`e[90mTo remove these users, run:`e[0m"
Write-Information "`e[97m  .\Set-CopilotLicense.ps1 -Org $Org -Action Remove -Users `"$usernames`"`e[0m"
Write-Information ""

# CSV export
if ($ExportCsv) {
    $csvPath = "copilot-inactive-$Org-$(Get-Date -Format 'yyyy-MM-dd').csv"
    $candidates | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Information "`e[32mExported to: $csvPath`e[0m"
}
