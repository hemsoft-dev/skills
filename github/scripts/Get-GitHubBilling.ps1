<#
.SYNOPSIS
    Get GitHub billing usage summary for a user account.

.DESCRIPTION
    Fetches billing usage data from GitHub API including Actions minutes,
    storage, and Copilot premium requests.

.PARAMETER Username
    GitHub username. Defaults to authenticated user.

.PARAMETER Year
    Year to query (default: current year)

.PARAMETER Month
    Month to query (default: current month)

.PARAMETER Product
    Filter by product: Actions, Copilot, Packages, etc.

.EXAMPLE
    .\Get-GitHubBilling.ps1
    # Get current month's billing for authenticated user

.EXAMPLE
    .\Get-GitHubBilling.ps1 -Month 11 -Year 2025
    # Get November 2025 billing

.EXAMPLE
    .\Get-GitHubBilling.ps1 -Product Copilot
    # Get only Copilot usage
#>

[CmdletBinding()]
param(
    [string]$Username,
    [int]$Year = (Get-Date).Year,
    [int]$Month = (Get-Date).Month,
    [ValidateSet('Actions', 'Copilot', 'Packages', 'Codespaces', '')]
    [string]$Product = ''
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
if ($Product) {
    $queryParams += "&product=$Product"
}

Write-Host "Fetching billing for @$Username ($Month/$Year)..." -ForegroundColor Cyan

# Fetch usage summary
$response = gh api "/users/$Username/settings/billing/usage/summary?$queryParams" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch billing data: $response"
    exit 1
}

$data = $response | ConvertFrom-Json

# Display results
Write-Host "`nBilling Period: $($data.timePeriod.month)/$($data.timePeriod.year)" -ForegroundColor Green
Write-Host "User: $($data.user)`n" -ForegroundColor Green

if ($data.usageItems.Count -eq 0) {
    Write-Host "No usage data found for this period." -ForegroundColor Yellow
    exit 0
}

# Format as table
$results = $data.usageItems | ForEach-Object {
    [PSCustomObject]@{
        Product      = $_.product
        SKU          = $_.sku
        Quantity     = "{0:N2} {1}" -f $_.grossQuantity, $_.unitType
        'Gross ($)'  = "{0:C2}" -f $_.grossAmount
        'Discount ($)' = "{0:C2}" -f $_.discountAmount
        'Net ($)'    = "{0:C2}" -f $_.netAmount
    }
}

$results | Format-Table -AutoSize

# Summary
$totalGross = ($data.usageItems | Measure-Object -Property grossAmount -Sum).Sum
$totalDiscount = ($data.usageItems | Measure-Object -Property discountAmount -Sum).Sum
$totalNet = ($data.usageItems | Measure-Object -Property netAmount -Sum).Sum

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Gross Total:    $("{0:C2}" -f $totalGross)"
Write-Host "  Discounts:     -$("{0:C2}" -f $totalDiscount)" -ForegroundColor Green
Write-Host "  Net Total:      $("{0:C2}" -f $totalNet)" -ForegroundColor Yellow
