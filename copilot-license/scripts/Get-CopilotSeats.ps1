<#
.SYNOPSIS
    List all Copilot seat assignments for an organization.

.DESCRIPTION
    Retrieves all Copilot seat assignments via the GitHub API, showing
    each user's last activity date, editor, plan type, and assignment info.
    Handles pagination automatically.

.PARAMETER Org
    The GitHub organization name (case-insensitive).

.PARAMETER Raw
    Output raw JSON instead of formatted table.

.EXAMPLE
    .\Get-CopilotSeats.ps1 -Org relias-engineering

.EXAMPLE
    .\Get-CopilotSeats.ps1 -Org fhemmer -Raw
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Org,

    [switch]$Raw
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

if ($Raw) {
    $result | ConvertTo-Json -Depth 10
    exit 0
}

# Get billing summary
$billingResponse = gh api "/orgs/$Org/copilot/billing" 2>&1
$billing = if ($LASTEXITCODE -eq 0) { $billingResponse | ConvertFrom-Json } else { $null }

# Header
Write-Information ""
Write-Information "`e[36m╔═══════════════════════════════════════════════════════╗`e[0m"
Write-Information "`e[36m║  Copilot Seats — $Org`e[0m"
Write-Information "`e[36m║  Total Seats: $($result.TotalSeats)`e[0m"
if ($billing) {
    $sb = $billing.seat_breakdown
    Write-Information "`e[36m║  Active: $($sb.active_this_cycle) | Inactive: $($sb.inactive_this_cycle) | Pending: $($sb.added_this_cycle)`e[0m"
}
Write-Information "`e[36m╚═══════════════════════════════════════════════════════╝`e[0m"
Write-Information ""

# Format seats as table
$now = Get-Date
$firstOfMonth = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0

$tableData = $result.Seats | ForEach-Object {
    $login = $_.assignee.login
    $lastActivity = if ($_.last_activity_at) { [datetime]$_.last_activity_at } else { $null }
    $daysSinceActivity = if ($lastActivity) { [math]::Floor(($now - $lastActivity).TotalDays) } else { -1 }
    $activeThisMonth = if ($lastActivity) { $lastActivity -ge $firstOfMonth } else { $false }

    $activityDisplay = if ($lastActivity) {
        "$($lastActivity.ToString('yyyy-MM-dd'))"
    } else {
        "Never"
    }

    $statusIcon = if ($_.pending_cancellation_date) {
        "`e[33m⏳`e[0m"  # Pending cancellation
    } elseif ($activeThisMonth) {
        "`e[32m✓`e[0m"   # Active this month
    } elseif ($daysSinceActivity -gt 30) {
        "`e[31m✗`e[0m"   # Inactive 30+ days
    } elseif ($daysSinceActivity -ge 0) {
        "`e[33m~`e[0m"   # Some activity but not this month
    } else {
        "`e[31m✗`e[0m"   # Never active
    }

    [PSCustomObject]@{
        Status       = $statusIcon
        Login        = $login
        LastActivity = $activityDisplay
        DaysInactive = if ($daysSinceActivity -ge 0) { $daysSinceActivity } else { "N/A" }
        Editor       = if ($_.last_activity_editor) { $_.last_activity_editor.Split('/')[0] } else { "-" }
        PlanType     = if ($_.plan_type) { $_.plan_type } else { "-" }
        PendingCancel = if ($_.pending_cancellation_date) { $_.pending_cancellation_date } else { "-" }
    }
} | Sort-Object -Property @{Expression = { if ($_.DaysInactive -eq "N/A") { 9999 } else { [int]$_.DaysInactive } }; Descending = $true }

$tableData | Format-Table -AutoSize

# Summary
$activeCount = ($result.Seats | Where-Object {
    $_.last_activity_at -and ([datetime]$_.last_activity_at) -ge $firstOfMonth
}).Count
$inactiveCount = $result.TotalSeats - $activeCount

Write-Information "`e[36mSummary:`e[0m"
Write-Information "  Active this month:   `e[32m$activeCount`e[0m"
Write-Information "  Inactive this month: `e[33m$inactiveCount`e[0m"
Write-Information "  Total seats:         $($result.TotalSeats)"
Write-Information ""
