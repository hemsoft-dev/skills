$InformationPreference = 'Continue'

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Check OpenRouter API credit balance
.DESCRIPTION
    Queries OpenRouter API to retrieve current credit balance
.EXAMPLE
    .\Get-OpenRouterBalance.ps1
#>

param()

# Check for API key
if (-not $env:OPENROUTER_API_KEY) {
    Write-Error "OPENROUTER_API_KEY environment variable not set"
    exit 1
}

try {
    $headers = @{
        "Authorization" = "Bearer $env:OPENROUTER_API_KEY"
        "Content-Type" = "application/json"
    }

    # OpenRouter credits endpoint
    $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/credits" -Headers $headers -Method Get

    if ($response.data) {
        $totalCredits = $response.data.total_credits
        $totalUsage = [math]::Round($response.data.total_usage, 2)
        $remaining = [math]::Round($totalCredits - $totalUsage, 2)
        $percentUsed = [math]::Round(($totalUsage / $totalCredits) * 100, 2)
        
        Write-Information "[36m`n💰 OpenRouter Credit Balance`e[0m"
        Write-Information "[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`e[0m"
        Write-Information "[97mTotal:     `$$totalCredits`e[0m"
        Write-Information "[33mUsed:      `$$totalUsage ($percentUsed%)`e[0m"
        Write-Information "[32mRemaining: `$$remaining`e[0m"
        Write-Information "[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n`e[0m"

        return @{
            Total = $totalCredits
            Used = $totalUsage
            Remaining = $remaining
            PercentUsed = $percentUsed
        }
    }
} catch {
    Write-Error "Failed to retrieve balance: $_"
    exit 1
}
