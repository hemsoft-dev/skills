#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Gets team members from Cortex API.
.DESCRIPTION
    Fetches team member information from the Cortex Teams API endpoint.
    Shows member names, emails, roles, and notification settings.
.PARAMETER TeamTag
    Required. Team tag to query (e.g., 'productivity-engineering').
.EXAMPLE
    .\Get-TeamMembers.ps1 -TeamTag "productivity-engineering"
    Gets all members of the Productivity Engineering team.
#>

param(
    [Parameter(Mandatory = $true)]
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
    $uri = "https://api.getcortexapp.com/api/v1/teams/$TeamTag"
    Write-Host "Fetching team members for: $TeamTag" -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    
    $team = $response.cortexTeam
    $teamName = if ($team.metadata.name) { $team.metadata.name } else { $TeamTag }
    $teamDescription = if ($team.metadata.description) { $team.metadata.description } else { "N/A" }
    
    Write-Host "`n=== $teamName ===" -ForegroundColor Green
    Write-Host "Tag: $($team.teamTag)"
    Write-Host "Description: $teamDescription"
    Write-Host "Total Members: $($team.members.Count)`n" -ForegroundColor Yellow
    
    if ($team.members.Count -eq 0) {
        Write-Host "No members found in this team." -ForegroundColor Gray
        exit 0
    }
    
    Write-Host "Team Members:" -ForegroundColor Yellow
    Write-Host ("{0,-30} {1,-40} {2,-30} {3}" -f "Name", "Email", "Roles", "Notifications") -ForegroundColor Cyan
    Write-Host ("-" * 130) -ForegroundColor Gray
    
    foreach ($member in $team.members) {
        $roles = if ($member.roles -and $member.roles.Count -gt 0) { 
            ($member.roles | ForEach-Object { $_.tag }) -join ", "
        } else { 
            "none" 
        }
        
        $notifications = if ($member.notificationsEnabled) { "Enabled" } else { "Disabled" }
        
        Write-Host ("{0,-30} {1,-40} {2,-30} {3}" -f 
            $member.name, 
            $member.email, 
            $roles,
            $notifications
        )
    }
    
    Write-Host "`n" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to fetch team members: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
