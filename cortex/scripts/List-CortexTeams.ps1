#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists teams from Cortex API.
.DESCRIPTION
    Fetches team information from the Cortex Teams API endpoint.
    By default, shows only team names, tags, and member count.
    Use -WithMembers to include detailed member information.
.PARAMETER WithMembers
    Optional. When specified, includes team member details (name, email, role).
.EXAMPLE
    .\List-CortexTeams.ps1
    Lists all teams without member details.
.EXAMPLE
    .\List-CortexTeams.ps1 -WithMembers
    Lists all teams with detailed member information.
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$WithMembers
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
    $uri = "https://api.getcortexapp.com/api/v1/teams?includeTeamsWithoutMembers=true"
    Write-Host "Fetching all teams..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    
    Write-Host "`nFound $($response.cortexTeams.Count) teams:`n" -ForegroundColor Green
    
    foreach ($team in $response.cortexTeams) {
        $memberCount = if ($team.cortexTeam.members) { $team.cortexTeam.members.Count } else { 0 }
        $status = if ($team.isArchived) { " [ARCHIVED]" } else { "" }
        
        Write-Host "$($team.metadata.name)$status" -ForegroundColor Yellow
        Write-Host "  Tag: $($team.teamTag)"
        Write-Host "  Members: $memberCount"
        
        if ($WithMembers -and $team.cortexTeam.members -and $team.cortexTeam.members.Count -gt 0) {
            $team.cortexTeam.members | ForEach-Object {
                $roles = if ($_.roles -and $_.roles.Count -gt 0) { 
                    ($_.roles | ForEach-Object { $_.tag }) -join ", "
                } else { "none" }
                Write-Host "    - $($_.name) ($($_.email)) - Role: $roles"
            }
        }
        
        Write-Host ""
    }
}
catch {
    Write-Error "Failed to fetch teams: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
