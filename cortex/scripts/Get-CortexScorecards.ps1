#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists scorecards and scores from Cortex.
.DESCRIPTION
    Fetches scorecard information and optionally scores for a specific scorecard.
.PARAMETER ScorecardTag
    Optional. Specific scorecard tag to get scores for.
.EXAMPLE
    .\Get-CortexScorecards.ps1
    Lists all scorecards.
.EXAMPLE
    .\Get-CortexScorecards.ps1 -ScorecardTag "production-readiness"
    Gets scores for the production-readiness scorecard.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ScorecardTag
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($env:CORTEX_API_KEY)) {
    Write-Error "CORTEX_API_KEY environment variable is not set!"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $env:CORTEX_API_KEY"
    "Content-Type"  = "application/json"
}

try {
    if ($ScorecardTag) {
        # Get scores for specific scorecard
        $uri = "https://api.getcortexapp.com/api/v1/scorecards/$ScorecardTag/scores"
        Write-Host "Fetching scores for scorecard: $ScorecardTag" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        Write-Host "`nScores for $ScorecardTag :" -ForegroundColor Green
        
        # Group by level (Gold, Silver, Bronze, etc.)
        $byLevel = @{}
        foreach ($score in $response.scores) {
            $level = if ($score.level) { $score.level } else { "No Level" }
            if (-not $byLevel[$level]) {
                $byLevel[$level] = @()
            }
            $byLevel[$level] += $score
        }
        
        foreach ($level in @("Gold", "Silver", "Bronze", "No Level") | Where-Object { $byLevel[$_] }) {
            $color = switch ($level) {
                "Gold" { "Yellow" }
                "Silver" { "Gray" }
                "Bronze" { "DarkYellow" }
                default { "White" }
            }
            
            Write-Host "`n=== $level ===" -ForegroundColor $color
            Write-Host "Count: $($byLevel[$level].Count)"
            
            foreach ($score in $byLevel[$level] | Sort-Object { $_.entityTag }) {
                Write-Host "  - $($score.entityTag): $($score.score)% ($($score.level))"
            }
        }
    }
    else {
        # List all scorecards
        $uri = "https://api.getcortexapp.com/api/v1/scorecards"
        Write-Host "Fetching all scorecards..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        Write-Host "`nFound $($response.scorecards.Count) scorecards:" -ForegroundColor Green
        
        foreach ($scorecard in $response.scorecards | Sort-Object { $_.name }) {
            Write-Host "`n=== $($scorecard.name) ===" -ForegroundColor Yellow
            Write-Host "  Tag: $($scorecard.tag)"
            
            if ($scorecard.description) {
                Write-Host "  Description: $($scorecard.description)"
            }
            
            if ($scorecard.levels -and $scorecard.levels.Count -gt 0) {
                Write-Host "  Levels:" -ForegroundColor Cyan
                foreach ($level in $scorecard.levels) {
                    Write-Host "    - $($level.name): $($level.rank)"
                }
            }
        }
    }
}
catch {
    Write-Error "Failed to fetch scorecards: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
