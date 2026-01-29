<#
.SYNOPSIS
    Retrieves OpenRouter credit balance and usage information.

.DESCRIPTION
    Calls the OpenRouter /api/v1/credits endpoint to get current credit balance,
    total usage, and calculates remaining credits with percentage used.

.EXAMPLE
    .\Get-OpenRouterBalance.ps1
    Displays credit balance information in a formatted table.
#>

[CmdletBinding()]
param()

# Check for API key
$apiKey = $env:OPENROUTER_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Error "OPENROUTER_API_KEY environment variable is not set."
    Write-Error "Get your API key at: https://openrouter.ai/keys"
    exit 1
}

# Call the API
$headers = @{
    "Authorization" = "Bearer $apiKey"
}

try {
    $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/credits" -Headers $headers -Method GET
    
    $totalCredits = $response.data.total_credits
    $totalUsage = $response.data.total_usage
    $remaining = $totalCredits - $totalUsage
    $percentUsed = [math]::Round(($totalUsage / $totalCredits) * 100, 2)
    
    Write-Host ""
    Write-Host "💰 OpenRouter Credit Balance" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ("Total:     ${0:N2}" -f $totalCredits) -ForegroundColor White
    Write-Host ("Used:      ${0:N2} ({1}%)" -f $totalUsage, $percentUsed) -ForegroundColor Yellow
    Write-Host ("Remaining: ${0:N2}" -f $remaining) -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Error "Failed to retrieve OpenRouter balance: $_"
    exit 1
}
