<#
.SYNOPSIS
    Search SharePoint Documents library for AI Chapter content
.DESCRIPTION
    Searches the Documents library for files and folders related to AI Chapter
#>

$InformationPreference = 'Continue'

Write-Host ""
Write-Host "=== Searching Documents Library for AI Chapter ===" -ForegroundColor Cyan

try {
    Import-Module PnP.PowerShell -ErrorAction Stop
    
    $siteUrl = "https://reliaslearning.sharepoint.com/"
    $clientId = $env:GRAPH_WORK_CLIENT_ID
    if (-not $clientId) {
        $clientId = $env:GRAPH_CLIENT_ID
    }
    if (-not $clientId) {
        $clientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"
    }
    
    Connect-PnPOnline -Url $siteUrl -Interactive -ClientId $clientId -ErrorAction Stop
    Write-Host "Connected successfully!" -ForegroundColor Green
    
    # Get all items from Documents library
    Write-Host ""
    Write-Host "=== Searching Documents Library ===" -ForegroundColor Cyan
    $allItems = Get-PnPListItem -List "Documents" -PageSize 100
    
    # Search for items with AI Chapter in title or path
    $matchingItems = $allItems | Where-Object { 
        $item = $_
        $title = $item.FieldValues.Title
        $path = $item.FieldValues.FileRef
        
        ($title -like '*AI*' -and $title -like '*Chapter*') -or
        ($path -like '*AI*' -and $path -like '*Chapter*') -or
        $title -like '*AIPE*' -or
        $path -like '*AIPE*'
    }
    
    if ($matchingItems) {
        Write-Host ""
        Write-Host "Found matching items:" -ForegroundColor Green
        $matchingItems | Select-Object @{Name='Title';Expression={$_.FieldValues.Title}}, 
                                      @{Name='Type';Expression={$_.FieldValues.FileSystemObjectType}},
                                      @{Name='Path';Expression={$_.FieldValues.FileRef}},
                                      @{Name='Created';Expression={$_.FieldValues.Created}} | 
                     Format-Table -AutoSize -Wrap
    } else {
        Write-Host "No matching items found in Documents library" -ForegroundColor Yellow
    }
    
    # Also list folders to see structure
    Write-Host ""
    Write-Host "=== Listing Top-Level Folders ===" -ForegroundColor Cyan
    $folders = $allItems | Where-Object { $_.FieldValues.FileSystemObjectType -eq 'Folder' } | Select-Object -First 20
    if ($folders) {
        $folders | Select-Object @{Name='Folder Name';Expression={$_.FieldValues.Title}},
                                 @{Name='Path';Expression={$_.FieldValues.FileRef}} | 
                     Format-Table -AutoSize -Wrap
    }
    
} catch {
    Write-Error "Failed to search: $_"
    exit 1
} finally {
    try {
        if (Get-PnPConnection) {
            Disconnect-PnPOnline
            Write-Host ""
            Write-Host "Disconnected from SharePoint" -ForegroundColor Gray
        }
    } catch {
        # Ignore disconnect errors
    }
}
