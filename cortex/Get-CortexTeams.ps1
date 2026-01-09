#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists all teams from Cortex API.
.DESCRIPTION
    Fetches team information from the Cortex Teams API endpoint.
    Shows team name, description, member count, and member details.
.PARAMETER TeamTag
    Optional. Specific team tag to query (e.g., 'productivity-engineering').
    If not provided, lists all teams.
.EXAMPLE
    .\Get-CortexTeams.ps1
    Lists all teams.
.EXAMPLE
    .\Get-CortexTeams.ps1 -TeamTag "productivity-engineering"
    Gets details for the Productivity Engineering team.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TeamTag
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
    if ($TeamTag) {
        # Get specific team
        $uri = "https://api.getcortexapp.com/api/v1/teams/$TeamTag"
        Write-Host "Fetching team: $TeamTag" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        $team = $response.cortexTeam
        Write-Host "`n=== $($team.metadata.name) ===" -ForegroundColor Green
        Write-Host "Tag: $($team.teamTag)"
        Write-Host "Description: $($team.metadata.description)"
        Write-Host "Member Count: $($team.members.Count)"
        
        if ($team.members.Count -gt 0) {
            Write-Host "`nTeam Members:" -ForegroundColor Yellow
            $team.members | ForEach-Object {
                $roles = if ($_.roles -and $_.roles.Count -gt 0) { 
                    ($_.roles | ForEach-Object { $_.tag }) -join ", "
                } else { "none" }
                Write-Host "  - $($_.name) ($($_.email)) - Role: $roles"
            }
        }
        
        if ($team.slackChannels -and $team.slackChannels.Count -gt 0) {
            Write-Host "`nSlack Channels:" -ForegroundColor Yellow
            $team.slackChannels | ForEach-Object {
                Write-Host "  - #$($_.name)"
            }
        }
    }
    else {
        # Get all teams
        $uri = "https://api.getcortexapp.com/api/v1/teams?includeTeamsWithoutMembers=true"
        Write-Host "Fetching all teams..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        Write-Host "`nFound $($response.teams.Count) teams:" -ForegroundColor Green
        
        foreach ($team in $response.teams) {
            $memberCount = if ($team.members) { $team.members.Count } else { 0 }
            Write-Host "`n=== $($team.metadata.name) ===" -ForegroundColor Yellow
            Write-Host "  Tag: $($team.teamTag)"
            Write-Host "  Description: $($team.metadata.description)"
            Write-Host "  Members: $memberCount"
            
            if ($team.members -and $team.members.Count -gt 0) {
                $team.members | ForEach-Object {
                    $roles = if ($_.roles -and $_.roles.Count -gt 0) { 
                        ($_.roles | ForEach-Object { $_.tag }) -join ", "
                    } else { "none" }
                    Write-Host "    - $($_.name) ($($_.email)) - Role: $roles"
                }
            }
        }
    }
}
catch {
    Write-Error "Failed to fetch teams: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
