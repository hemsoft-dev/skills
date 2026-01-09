#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Gets details for a specific entity from Cortex Catalog.
.DESCRIPTION
    Fetches detailed information about an entity by its tag.
.PARAMETER EntityTag
    Required. The tag of the entity to query.
.EXAMPLE
    .\Get-CortexEntity.ps1 -EntityTag "my-service"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$EntityTag
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
    $uri = "https://api.getcortexapp.com/api/v1/catalog/$EntityTag"
    Write-Host "Fetching entity: $EntityTag" -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    
    Write-Host "`n=== $($response.name) ===" -ForegroundColor Green
    Write-Host "Tag: $($response.tag)"
    Write-Host "Type: $($response.type)"
    
    if ($response.description) {
        Write-Host "Description: $($response.description)"
    }
    
    if ($response.owners -and $response.owners.Count -gt 0) {
        Write-Host "`nOwners:" -ForegroundColor Yellow
        foreach ($owner in $response.owners) {
            if ($owner.name) {
                Write-Host "  - $($owner.name)"
            } elseif ($owner.email) {
                Write-Host "  - $($owner.email)"
            }
        }
    }
    
    if ($response.groups -and $response.groups.Count -gt 0) {
        Write-Host "`nGroups:" -ForegroundColor Yellow
        foreach ($group in $response.groups) {
            Write-Host "  - $group"
        }
    }
    
    if ($response.links -and $response.links.Count -gt 0) {
        Write-Host "`nLinks:" -ForegroundColor Yellow
        foreach ($link in $response.links) {
            Write-Host "  - $($link.name): $($link.url)"
        }
    }
    
    # Output as JSON for detailed view
    Write-Host "`nFull Details (JSON):" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 10
}
catch {
    Write-Error "Failed to fetch entity: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
