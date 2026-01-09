#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a new team in Cortex.
.DESCRIPTION
    Creates a new team with specified members. Validates that the team doesn't already exist
    and ensures all member fields are properly populated.
.PARAMETER TeamTag
    Required. The unique tag for the new team (e.g., 'my-new-team').
.PARAMETER TeamName
    Required. The display name for the team.
.PARAMETER Description
    Optional. Description of the team.
.PARAMETER Members
    Required. Array of hashtables containing member information.
    Each member must have: email, name, role, notificationsEnabled
.EXAMPLE
    $members = @(
        @{
            email = "user1@example.com"
            name = "User One"
            role = "developer"
            notificationsEnabled = $true
        },
        @{
            email = "user2@example.com"
            name = "User Two"
            role = "manager"
            notificationsEnabled = $true
        }
    )
    .\New-CortexTeam.ps1 -TeamTag "my-team" -TeamName "My Team" -Description "Team Description" -Members $members
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TeamTag,
    
    [Parameter(Mandatory = $true)]
    [string]$TeamName,
    
    [Parameter(Mandatory = $false)]
    [string]$Description = "",
    
    [Parameter(Mandatory = $true)]
    [hashtable[]]$Members
)

$ErrorActionPreference = 'Stop'

# Validate environment
if ([string]::IsNullOrEmpty($env:CORTEX_API_KEY)) {
    Write-Host "ERROR: CORTEX_API_KEY environment variable is not set!" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $env:CORTEX_API_KEY"
    "Content-Type"  = "application/json"
}

# Valid role tags
$validRoles = @("developer", "manager", "tester", "cloud-engineer", "product-manager", "engineering-manager")

try {
    # Check if team already exists
    Write-Host "Checking if team '$TeamTag' already exists..." -ForegroundColor Cyan
    try {
        $existingTeam = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/$TeamTag" -Headers $headers -Method Get
        Write-Host "ERROR: Team '$TeamTag' already exists!" -ForegroundColor Red
        Write-Host "Team Name: $($existingTeam.metadata.name)" -ForegroundColor Yellow
        Write-Host "Members: $($existingTeam.cortexTeam.members.Count)" -ForegroundColor Yellow
        exit 1
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "✓ Team does not exist, proceeding with creation..." -ForegroundColor Green
        }
        else {
            throw
        }
    }
    
    # Validate members
    Write-Host "`nValidating members..." -ForegroundColor Cyan
    $validatedMembers = @()
    $memberIndex = 0
    
    foreach ($member in $Members) {
        $memberIndex++
        $issues = @()
        
        # Check required fields
        if ([string]::IsNullOrWhiteSpace($member.email)) {
            $issues += "missing email"
        }
        if ([string]::IsNullOrWhiteSpace($member.name)) {
            $issues += "missing name"
        }
        if ([string]::IsNullOrWhiteSpace($member.role)) {
            $issues += "missing role"
        }
        elseif ($member.role -notin $validRoles) {
            $issues += "invalid role '$($member.role)' (valid: $($validRoles -join ', '))"
        }
        if ($null -eq $member.notificationsEnabled) {
            $issues += "missing notificationsEnabled"
        }
        
        if ($issues.Count -gt 0) {
            Write-Host "ERROR: Member #$memberIndex validation failed: $($issues -join '; ')" -ForegroundColor Red
            exit 1
        }
        
        # Build validated member object
        $validatedMember = @{
            email                = $member.email.Trim()
            name                 = $member.name.Trim()
            roleTags             = @($member.role)
            notificationsEnabled = [bool]$member.notificationsEnabled
        }
        
        if ($member.description) {
            $validatedMember.description = $member.description
        }
        
        $validatedMembers += $validatedMember
        Write-Host "  ✓ $($validatedMember.name) ($($validatedMember.email)) - Role: $($member.role)" -ForegroundColor Green
    }
    
    Write-Host "`nCreating team with $($validatedMembers.Count) members..." -ForegroundColor Cyan
    
    # Build team creation payload
    $metadata = @{
        name = $TeamName
    }
    
    if ($Description) {
        $metadata.description = $Description
    }
    
    $teamPayload = @{
        teamTag       = $TeamTag
        metadata      = $metadata
        type          = "CORTEX"
        cortexTeam    = @{
            members = $validatedMembers
        }
        links         = @()  # Empty array required by API
        slackChannels = @()  # Empty array required by API
    }
    
    $body = $teamPayload | ConvertTo-Json -Depth 5
    
    # Create the team
    $response = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    
    Write-Host "`n✓ Team created successfully!" -ForegroundColor Green
    
    # Update members with roles (POST doesn't support roleTags, need to PUT after creation)
    Write-Host "`nSetting member roles..." -ForegroundColor Cyan
    $updateBody = @{
        type = "CORTEX"
        members = $validatedMembers
    } | ConvertTo-Json -Depth 5
    
    $updateResponse = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/$TeamTag/members" -Headers $headers -Method Put -Body $updateBody -ContentType "application/json"
    
    Write-Host "✓ Roles updated successfully!" -ForegroundColor Green
    
    # Verify creation
    Write-Host "`nVerifying team creation..." -ForegroundColor Cyan
    $verifyTeam = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/$TeamTag" -Headers $headers -Method Get
    
    Write-Host "`n=== $($verifyTeam.metadata.name) ===" -ForegroundColor Yellow
    Write-Host "Tag: $($verifyTeam.teamTag)"
    Write-Host "Description: $($verifyTeam.metadata.description)"
    Write-Host "Members: $($verifyTeam.cortexTeam.members.Count)"
    
    Write-Host "`nTeam Members:" -ForegroundColor Yellow
    foreach ($member in $verifyTeam.cortexTeam.members) {
        $roles = if ($member.roles -and $member.roles.Count -gt 0) { 
            ($member.roles | ForEach-Object { $_.tag }) -join ", "
        } else { "none" }
        Write-Host "  - $($member.name) ($($member.email)) - Role: $roles"
    }
    
    Write-Host "`n✓ Team '$TeamTag' created and verified!" -ForegroundColor Green
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}
