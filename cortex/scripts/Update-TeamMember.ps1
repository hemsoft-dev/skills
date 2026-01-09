param(
    [Parameter(Mandatory=$true)]
    [string]$TeamTag,
    
    [Parameter(Mandatory=$true)]
    [string]$MemberEmail,
    
    [Parameter(Mandatory=$true)]
    [string]$NewRole
)

# Verify API key is set
if ([string]::IsNullOrEmpty($env:CORTEX_API_KEY)) {
    Write-Host "ERROR: CORTEX_API_KEY environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:CORTEX_API_KEY = 'your-api-key'" -ForegroundColor Yellow
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $env:CORTEX_API_KEY"
    "Content-Type" = "application/json"
}

try {
    # Get current team
    Write-Host "Fetching team: $TeamTag..." -ForegroundColor Cyan
    $team = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/$TeamTag" -Headers $headers -Method Get
    
    Write-Host "Current members:" -ForegroundColor Cyan
    foreach ($member in $team.cortexTeam.members) {
        # roles is an array of objects with .tag property
        $roleTag = if ($member.roles -and $member.roles.Count -gt 0) { 
            ($member.roles | ForEach-Object { $_.tag }) -join ", " 
        } else { "none" }
        $indicator = if ($member.email -eq $MemberEmail) { " <-- Will update" } else { "" }
        Write-Host "  - $($member.name) ($($member.email)) - Role: $roleTag$indicator"
    }
    
    # Transform members, updating target member's role
    $updatedMembers = @()
    foreach ($member in $team.cortexTeam.members) {
        $memberObj = @{
            email = $member.email
            name = $member.name
            notificationsEnabled = $member.notificationsEnabled
        }
        
        # Update target member's role, preserve others
        # Send 'roleTags' as string array, but GET returns 'roles' as object array
        if ($member.email -eq $MemberEmail) {
            $memberObj.roleTags = @($NewRole)
            $oldRoles = if ($member.roles -and $member.roles.Count -gt 0) { 
                ($member.roles | ForEach-Object { $_.tag }) -join ", " 
            } else { "none" }
            Write-Host "`nUpdating $($member.name)'s roles from '$oldRoles' to '$NewRole'" -ForegroundColor Yellow
        } elseif ($member.roles -and $member.roles.Count -gt 0) {
            # Extract just the tags from role objects
            $memberObj.roleTags = $member.roles | ForEach-Object { $_.tag }
        } else {
            # Member has no roles - include empty array
            $memberObj.roleTags = @()
        }
        
        $updatedMembers += $memberObj
    }
    
    # PUT the updated members list
    Write-Host "`nSending update to Cortex..." -ForegroundColor Cyan
    $body = @{
        type = "CORTEX"
        members = $updatedMembers
    } | ConvertTo-Json -Depth 5
    
    $response = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/$TeamTag/members" -Headers $headers -Method Put -Body $body -ContentType "application/json"
    
    Write-Host "`n✓ Update successful!" -ForegroundColor Green
    
    # Verify the update
    Write-Host "`nVerifying update..." -ForegroundColor Cyan
    $verifyTeam = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/$TeamTag" -Headers $headers -Method Get
    $targetMember = $verifyTeam.cortexTeam.members | Where-Object { $_.email -eq $MemberEmail }
    
    Write-Host "`nFinal member list:" -ForegroundColor Cyan
    foreach ($member in $verifyTeam.cortexTeam.members) {
        $roleTag = if ($member.roles -and $member.roles.Count -gt 0) { 
            ($member.roles | ForEach-Object { $_.tag }) -join ", " 
        } else { "none" }
        $indicator = if ($member.email -eq $MemberEmail) { " ✓" } else { "" }
        Write-Host "  - $($member.name) ($($member.email)) - Role: $roleTag$indicator"
    }
    
    $targetRoleTags = $targetMember.roles | ForEach-Object { $_.tag }
    if ($targetRoleTags -contains $NewRole) {
        Write-Host "`n✓ $($targetMember.name)'s role successfully verified as '$NewRole'" -ForegroundColor Green
    } else {
        Write-Host "`n✗ Role verification failed. Expected '$NewRole', got '$($targetRoleTags -join ", ")'" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}
