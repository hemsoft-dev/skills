<#
.SYNOPSIS
    Find Copilot license holders who haven't used Copilot recently.

.DESCRIPTION
    Queries the organization's Copilot seat assignments and identifies users
    who have not had any Copilot activity in the current billing month (or
    within a configurable number of days). These are candidates for license
    removal to save costs.

.PARAMETER Org
    The GitHub organization name (case-insensitive).

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
    .\Get-InactiveCopilotUsers.ps1 -Org relias-engineering

.EXAMPLE
    .\Get-InactiveCopilotUsers.ps1 -Org fhemmer -InactiveDays 30

.EXAMPLE
    .\Get-InactiveCopilotUsers.ps1 -Org fhemmer -ExportCsv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Org,

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
$candidates = $result.Seats | Where-Object {
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
        SeatCreated         = if ($_.created_at) { ([datetime]$_.created_at).ToString('yyyy-MM-dd') } else { '-' }
        PendingCancellation = if ($_.pending_cancellation_date) { $_.pending_cancellation_date } else { '-' }
        PlanType            = if ($_.plan_type) { $_.plan_type } else { '-' }
    }
} | Sort-Object -Property @{Expression = { if ($_.DaysInactive -eq 'N/A') { 9999 } else { [int]$_.DaysInactive } }; Descending = $true }

# Display results
$activeCount = $result.TotalSeats - $candidates.Count

if ($candidates.Count -eq 0) {
    Write-Information "`e[32m✓ All $($result.TotalSeats) seat holders have been active in the $cutoffLabel.`e[0m"
    exit 0
}

Write-Information "`e[33m╔═══════════════════════════════════════════════════════════════╗`e[0m"
Write-Information "`e[33m║  Inactive Copilot Users — $Org`e[0m"
Write-Information "`e[33m║  Candidates for removal: $($candidates.Count) of $($result.TotalSeats) seats`e[0m"
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
Write-Information "  Active ($cutoffLabel):   `e[32m$activeCount`e[0m"
Write-Information "  Inactive (candidates):   `e[33m$($candidates.Count)`e[0m"
Write-Information ""
Write-Information "`e[36mPotential savings (at `$$monthlyCostPerSeat/seat/month):`e[0m"
Write-Information "  Monthly:  `e[32m`$$potentialSavings`e[0m"
Write-Information "  Annual:   `e[32m`$$annualSavings`e[0m"
Write-Information ""

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
