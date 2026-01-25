<#
.SYNOPSIS
    Test connection to SharePoint site using PnP PowerShell
.DESCRIPTION
    Connects to a SharePoint site using interactive authentication and displays basic site information
.PARAMETER SiteUrl
    The SharePoint site URL (e.g., https://yourtenant.sharepoint.com/sites/YourSite)
.EXAMPLE
    .\Test-SharePointConnection.ps1 -SiteUrl "https://relias.sharepoint.com/sites/AIChapter"
#>

param(
    [Parameter(Mandatory)]
    [string]$SiteUrl
)

$InformationPreference = 'Continue'

Write-Host "`n=== SharePoint Connection Test ===" -ForegroundColor Cyan
Write-Host "Connecting to: $SiteUrl" -ForegroundColor Yellow

try {
    # Import PnP PowerShell module
    Import-Module PnP.PowerShell -ErrorAction Stop
    
    # Try with default Microsoft client ID (same as used in mail skill)
    $clientId = $env:GRAPH_WORK_CLIENT_ID
    if (-not $clientId) {
        $clientId = $env:GRAPH_CLIENT_ID
    }
    
    if ($clientId) {
        Write-Host "`nUsing Client ID from environment..." -ForegroundColor Cyan
        Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $clientId -PersistLogin -ErrorAction Stop
    } else {
        # Try with well-known Microsoft client ID for SharePoint
        Write-Host "`nUsing default Microsoft client ID..." -ForegroundColor Cyan
        $defaultClientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"  # Microsoft's default SharePoint client ID
        Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $defaultClientId -PersistLogin -ErrorAction Stop
    }
    
    Write-Host "`n✓ Successfully connected!" -ForegroundColor Green
    
    # Get site information
    Write-Host "`n=== Site Information ===" -ForegroundColor Cyan
    $web = Get-PnPWeb
    Write-Host "Title: $($web.Title)" -ForegroundColor White
    Write-Host "URL: $($web.Url)" -ForegroundColor White
    Write-Host "Description: $($web.Description)" -ForegroundColor White
    Write-Host "Created: $($web.Created)" -ForegroundColor White
    
    # List available lists/libraries
    Write-Host "`n=== Available Lists/Libraries ===" -ForegroundColor Cyan
    $lists = Get-PnPList | Where-Object { $_.Hidden -eq $false } | Select-Object -First 10 Title, ItemCount, BaseTemplate
    $lists | Format-Table -AutoSize
    
    # Test REST API call
    Write-Host "`n=== Testing REST API ===" -ForegroundColor Cyan
    $restResult = Invoke-PnPSPRestMethod -Url "/_api/web/title" -Method Get
    Write-Host "REST API Test - Site Title: $($restResult.value)" -ForegroundColor Green
    
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to connect: $_"
    Write-Host "`nCommon issues:" -ForegroundColor Yellow
    Write-Host "- Check that the site URL is correct" -ForegroundColor Yellow
    Write-Host "- Ensure you have access to the site" -ForegroundColor Yellow
    Write-Host "- Verify your account has MFA configured if required" -ForegroundColor Yellow
    exit 1
} finally {
    # Disconnect
    try {
        if (Get-PnPConnection) {
            Disconnect-PnPOnline
            Write-Host "`nDisconnected from SharePoint" -ForegroundColor Gray
        }
    } catch {
        # Ignore disconnect errors
    }
}
