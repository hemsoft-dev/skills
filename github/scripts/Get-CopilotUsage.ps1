<#
.SYNOPSIS
    Get GitHub Copilot premium request usage breakdown by model.

.DESCRIPTION
    Fetches Copilot premium request usage from GitHub API, showing
    usage per AI model (Claude, GPT-4o, o1, etc.) with costs.

.PARAMETER Username
    GitHub username. Defaults to authenticated user.

.PARAMETER Year
    Year to query (default: current year)

.PARAMETER Month
    Month to query (default: current month)

.PARAMETER Model
    Filter by specific model name (e.g., 'claude-sonnet-4', 'gpt-4o')

.PARAMETER Raw
    Output raw JSON instead of formatted table

.EXAMPLE
    .\Get-CopilotUsage.ps1
    # Get current month's Copilot usage

.EXAMPLE
    .\Get-CopilotUsage.ps1 -Model claude
    # Filter to Claude models only

.EXAMPLE
    .\Get-CopilotUsage.ps1 -Raw | ConvertFrom-Json
    # Get raw JSON for further processing
#>

$InformationPreference = 'Continue'

[CmdletBinding()]
param(
    [string]$Username,
    [int]$Year = (Get-Date).Year,
    [int]$Month = (Get-Date).Month,
    [string]$Model = '',
    [switch]$Raw
)

# Get username if not provided
if (-not $Username) {
    $Username = gh api /user --jq '.login'
    if (-not $Username) {
        Write-Error "Could not determine username. Ensure you're authenticated with 'gh auth login'"
        exit 1
    }
}

# Build query parameters
$queryParams = "year=$Year&month=$Month"
if ($Model) {
    $queryParams += "&model=$Model"
}

if (-not $Raw) {
    Write-Information "Fetching Copilot usage for @$Username ($Month/$Year)..." -ForegroundColor Cyan
}

# Fetch premium request usage
$response = gh api "/users/$Username/settings/billing/premium_request/usage?$queryParams" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch Copilot usage: $response"
    exit 1
}

if ($Raw) {
    Write-Output $response
    exit 0
}

$data = $response | ConvertFrom-Json

# Display header
Write-Information "`nCopilot Premium Requests - $($data.timePeriod.month)/$($data.timePeriod.year)" -ForegroundColor Green
Write-Information "User: $($data.user)`n" -ForegroundColor Green

if ($data.usageItems.Count -eq 0) {
    Write-Information "No Copilot usage data found for this period." -ForegroundColor Yellow
    exit 0
}

# Group by SKU type
$byType = $data.usageItems | Group-Object -Property sku

foreach ($group in $byType) {
    Write-Information "$($group.Name):" -ForegroundColor Cyan
    
    $items = $group.Group | ForEach-Object {
        [PSCustomObject]@{
            Model        = $_.model
            Requests     = "{0:N2}" -f $_.grossQuantity
            'Price/Unit' = "{0:C4}" -f $_.pricePerUnit
            'Gross ($)'  = "{0:C2}" -f $_.grossAmount
            'Discount'   = "{0:C2}" -f $_.discountAmount
            'Billed ($)' = "{0:C2}" -f $_.netAmount
        }
    }
    
    $items | Format-Table -AutoSize
}

# Pro+ quota info
$totalGross = ($data.usageItems | Measure-Object -Property grossQuantity -Sum).Sum
$totalDiscount = ($data.usageItems | Measure-Object -Property discountQuantity -Sum).Sum
$totalBilled = ($data.usageItems | Measure-Object -Property netAmount -Sum).Sum

Write-Information "Summary:" -ForegroundColor Cyan
Write-Information "  Total Requests:     $("{0:N0}" -f $totalGross)"
Write-Information "  Included (Pro+):   -$("{0:N0}" -f $totalDiscount)" -ForegroundColor Green
Write-Information "  Billable Requests:  $("{0:N0}" -f ($totalGross - $totalDiscount))"
Write-Information "  Amount Due:         $("{0:C2}" -f $totalBilled)" -ForegroundColor Yellow

# Show Pro+ quota status
$proQuota = 1500
$remaining = [Math]::Max(0, $proQuota - $totalGross)
$percentUsed = [Math]::Min(100, ($totalGross / $proQuota) * 100)

Write-Information "`nPro+ Quota Status:" -ForegroundColor Cyan
$barLength = 30
$filledLength = [Math]::Floor($barLength * $percentUsed / 100)
$bar = ('█' * $filledLength) + ('░' * ($barLength - $filledLength))

$color = if ($percentUsed -ge 100) { 'Red' } elseif ($percentUsed -ge 80) { 'Yellow' } else { 'Green' }
Write-Information "  [$bar] $("{0:N1}%" -f $percentUsed)" -ForegroundColor $color

if ($remaining -gt 0) {
    Write-Information "  $("{0:N0}" -f $remaining) requests remaining in quota" -ForegroundColor Green
} else {
    $over = $totalGross - $proQuota
    Write-Information "  $("{0:N0}" -f $over) requests over quota @ `$0.04/request" -ForegroundColor Yellow
}
