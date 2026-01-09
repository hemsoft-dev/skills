#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists all services from Cortex Catalog API.
.DESCRIPTION
    Fetches service entities from the Cortex Catalog API with pagination.
.PARAMETER PageSize
    Number of results per page (default: 100, max: 1000).
.EXAMPLE
    .\Get-CortexServices.ps1
    Lists all services.
#>

param(
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
    
    Write-Host "Fetching services from Cortex Catalog..." -ForegroundColor Cyan
    
    do {
        $uri = "https://api.getcortexapp.com/api/v1/catalog?types=service&pageSize=$PageSize&page=$page&includeOwners=true"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        if ($response.entities) {
            $allServices += $response.entities
        }
        
        $page++
        $hasMore = $response.entities -and $response.entities.Count -eq $PageSize
    } while ($hasMore)
    
    Write-Host "`nFound $($allServices.Count) services:" -ForegroundColor Green
    
    foreach ($service in $allServices | Sort-Object { $_.name }) {
        Write-Host "`n=== $($service.name) ===" -ForegroundColor Yellow
        Write-Host "  Tag: $($service.tag)"
        Write-Host "  Type: $($service.type)"
        
        if ($service.description) {
            Write-Host "  Description: $($service.description)"
        }
        
        if ($service.owners -and $service.owners.Count -gt 0) {
            Write-Host "  Owners:" -ForegroundColor Cyan
            foreach ($owner in $service.owners) {
                if ($owner.name) {
                    Write-Host "    - $($owner.name)"
                } elseif ($owner.email) {
                    Write-Host "    - $($owner.email)"
                }
            }
        }
    }
}
catch {
    Write-Error "Failed to fetch services: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
    exit 1
}
