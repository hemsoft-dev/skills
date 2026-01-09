#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates all Productivity Engineering team member roles in one batch operation.
#>

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($env:CORTEX_API_KEY)) {
    Write-Host "ERROR: CORTEX_API_KEY environment variable is not set!" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $env:CORTEX_API_KEY"
    "Content-Type" = "application/json"
}

# Role mapping for Productivity Engineering team
$roleMap = @{
    "fhemmer@relias.com" = "developer"
    "bhalterman@relias.com" = "developer"
    "smarti@relias.com" = "tester"
    "kmenon@relias.com" = "tester"
    "tdeal@relias.com" = "tester"
    "mapaul@relias.com" = "manager"
    "jomartin@relias.com" = "cloud-engineer"
    "dwilson@relias.com" = "cloud-engineer"
    "mbarry@relias.com" = "manager"
    "npeterson@relias.com" = "developer"
}

try {
    Write-Host "Fetching Productivity Engineering team..." -ForegroundColor Cyan
    $team = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/productivity-engineering" -Headers $headers -Method Get
    
    Write-Host "`nUpdating member roles:" -ForegroundColor Cyan
    $updatedMembers = @()
    foreach ($member in $team.cortexTeam.members) {
        $newRole = $roleMap[$member.email]
        $currentRole = if ($member.roles -and $member.roles.Count -gt 0) { 
            ($member.roles | ForEach-Object { $_.tag }) -join ", " 
        } else { "none" }
        
        $memberObj = @{
            email = $member.email
            name = $member.name
            notificationsEnabled = $member.notificationsEnabled
        }
        
        if ($newRole) {
            $memberObj.roleTags = @($newRole)
            Write-Host "  $($member.name): $currentRole -> $newRole" -ForegroundColor Yellow
        } elseif ($member.roles -and $member.roles.Count -gt 0) {
            $memberObj.roleTags = $member.roles | ForEach-Object { $_.tag }
            Write-Host "  $($member.name): keeping $currentRole" -ForegroundColor Gray
        } else {
            $memberObj.roleTags = @()
            Write-Host "  $($member.name): no role" -ForegroundColor Gray
        }
        
        $updatedMembers += $memberObj
    }
    
    $body = @{
        type = "CORTEX"
        members = $updatedMembers
    } | ConvertTo-Json -Depth 5
    
    Write-Host "`nSending update to Cortex..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/productivity-engineering/members" -Headers $headers -Method Put -Body $body -ContentType "application/json"
    
    Write-Host "`n✓ Update successful! Verifying..." -ForegroundColor Green
    
    # Verify the update
    $verify = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/productivity-engineering" -Headers $headers -Method Get
    
    Write-Host "`nFinal team member roles:" -ForegroundColor Cyan
    $allCorrect = $true
    foreach ($member in $verify.cortexTeam.members) {
        $actualRole = if ($member.roles -and $member.roles.Count -gt 0) { 
            $member.roles[0].tag
        } else { "none" }
        $expectedRole = $roleMap[$member.email]
        
        if ($expectedRole -and $actualRole -ne $expectedRole) {
            Write-Host "  ✗ $($member.name): $actualRole (expected: $expectedRole)" -ForegroundColor Red
            $allCorrect = $false
        } elseif ($expectedRole) {
            Write-Host "  ✓ $($member.name): $actualRole" -ForegroundColor Green
        } else {
            Write-Host "  - $($member.name): $actualRole" -ForegroundColor Gray
        }
    }
    
    if ($allCorrect) {
        Write-Host "`n✓ All roles updated successfully!" -ForegroundColor Green
    } else {
        Write-Host "`n✗ Some roles were not updated correctly" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}
