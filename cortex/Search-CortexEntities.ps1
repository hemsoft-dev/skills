#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Searches Cortex entities by query.
.DESCRIPTION
    Searches across entity properties using Cortex Catalog API.
.PARAMETER Query
    Required. The search query string.
.PARAMETER Types
    Optional. Filter by entity types (comma-separated). Default: all types.
.EXAMPLE
    .\Search-CortexEntities.ps1 -Query "api"
    Searches all entities for "api".
.EXAMPLE
    .\Search-CortexEntities.ps1 -Query "payment" -Types "service"
    Searches services for "payment".
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Query,
    
    [Parameter(Mandatory = $false)]
    [string]$Types
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
    $uri = "https://api.getcortexapp.com/api/v1/catalog?query=$([uri]::EscapeDataString($Query))&pageSize=100&includeOwners=true"
    
    if ($Types) {
        $uri += "&types=$Types"
    }
    
    Write-Host "Searching for: $Query" -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    
    if (-not $response.entities -or $response.entities.Count -eq 0) {
        Write-Host "No entities found matching '$Query'" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`nFound $($response.entities.Count) matching entities:" -ForegroundColor Green
    
    foreach ($entity in $response.entities | Sort-Object { $_.type, $_.name }) {
        Write-Host "`n=== $($entity.name) ===" -ForegroundColor Yellow
        Write-Host "  Tag: $($entity.tag)"
        Write-Host "  Type: $($entity.type)"
        
        if ($entity.description) {
            Write-Host "  Description: $($entity.description)"
        }
        
        if ($entity.owners -and $entity.owners.Count -gt 0) {
            $ownerNames = ($entity.owners | ForEach-Object { 
                if ($_.name) { $_.name } elseif ($_.email) { $_.email } 
            }) -join ", "
            Write-Host "  Owners: $ownerNames"
        }
    }
}
catch {
    Write-Error "Failed to search entities: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
