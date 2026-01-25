#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists services owned by a specific team from Cortex Catalog API.
.DESCRIPTION
    Fetches service entities owned by a specific team using the Cortex Catalog API.
    Uses the 'groups' parameter to filter by team ownership.
.PARAMETER TeamTag
    Required. The team tag to query services for (e.g., 'productivity-engineering').
.PARAMETER PageSize
    Number of results per page (default: 100, max: 1000).
.EXAMPLE
    .\Get-TeamServices.ps1 -TeamTag "productivity-engineering"
    Lists all services owned by the Productivity Engineering team.
.EXAMPLE
    .\Get-TeamServices.ps1 -TeamTag "frontier" -PageSize 250
    Lists all services owned by the Frontier team with custom page size.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TeamTag,

    [Parameter(Mandatory = $false)]
    [int]$PageSize = 100
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
    $allServices = @()
    $page = 0
    
    Write-Host "Fetching all services and filtering by team ownership..." -ForegroundColor Cyan
    Write-Host "Team: $TeamTag" -ForegroundColor Cyan
    
    # Note: The Cortex Catalog API doesn't support filtering by team ownership via query parameters.
    # We must fetch all services and filter client-side by checking the ownersV2.teams field.
    do {
        $uri = "https://api.getcortexapp.com/api/v1/catalog?types=service&pageSize=$PageSize&page=$page"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        if ($response.entities) {
            # Filter services owned by the specified team
            $teamServices = $response.entities | Where-Object {
                $entity = $_
                # Get detailed entity info to check ownership
                try {
                    $detailUri = "https://api.getcortexapp.com/api/v1/catalog/$($entity.tag)"
                    $detail = Invoke-RestMethod -Uri $detailUri -Headers $headers -Method Get
                    
                    # Check if this team owns the service (via ownersV2.teams)
                    if ($detail.ownersV2 -and $detail.ownersV2.teams) {
                        $isOwner = $detail.ownersV2.teams | Where-Object { $_.tag -eq $TeamTag }
                        return $null -ne $isOwner
                    }
                    
                    # Fallback: check owners.groups
                    if ($detail.owners -and $detail.owners.groups) {
                        return $detail.owners.groups -contains $TeamTag
                    }
                    
                    return $false
                }
                catch {
                    Write-Warning "Failed to get details for $($entity.tag): $($_.Exception.Message)"
                    return $false
                }
            }
            
            if ($teamServices) {
                $allServices += $teamServices
            }
        }
        
        $page++
        $hasMore = $response.entities -and $response.entities.Count -eq $PageSize
    } while ($hasMore)
    
    if ($allServices.Count -eq 0) {
        Write-Host "`nNo services found owned by team: $TeamTag" -ForegroundColor Yellow
        Write-Host "This could mean:" -ForegroundColor Gray
        Write-Host "  1. The team doesn't own any services" -ForegroundColor Gray
        Write-Host "  2. The team tag '$TeamTag' doesn't exist" -ForegroundColor Gray
        Write-Host "  3. Services aren't properly tagged with this team as owner" -ForegroundColor Gray
        exit 0
    }
    
    Write-Host "`nFound $($allServices.Count) service(s) owned by team '$TeamTag':" -ForegroundColor Green
    
    foreach ($service in $allServices | Sort-Object { $_.name }) {
        # Get full details for display
        $detailUri = "https://api.getcortexapp.com/api/v1/catalog/$($service.tag)"
        $detail = Invoke-RestMethod -Uri $detailUri -Headers $headers -Method Get
        
        Write-Host "`n=== $($detail.name) ===" -ForegroundColor Yellow
        Write-Host "  Tag: $($detail.tag)"
        Write-Host "  Type: $($detail.type)"
        
        if ($detail.description) {
            Write-Host "  Description: $($detail.description)"
        }
        
        # Show team ownership from ownersV2
        if ($detail.ownersV2 -and $detail.ownersV2.teams -and $detail.ownersV2.teams.Count -gt 0) {
            Write-Host "  Owner Teams:" -ForegroundColor Cyan
            foreach ($team in $detail.ownersV2.teams) {
                Write-Host "    - $($team.name) ($($team.tag))"
            }
        }
        
        # Show groups/tags if available
        if ($detail.groups -and $detail.groups.Count -gt 0) {
            Write-Host "  Groups:" -ForegroundColor Cyan
            foreach ($group in $detail.groups) {
                Write-Host "    - $group"
            }
        }
        
        # Show repository if available
        if ($detail.git -and $detail.git.repository) {
            Write-Host "  Repository: $($detail.git.repository)" -ForegroundColor Cyan
        }
    }
}
catch {
    Write-Error "Failed to fetch services for team '$TeamTag': $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
