<#
.SYNOPSIS
    Search for AI Chapter section in SharePoint
.DESCRIPTION
    Connects to Relias SharePoint and searches for AI Chapter related lists, libraries, subsites, and files
.EXAMPLE
    .\Find-AIChapter.ps1
#>

$InformationPreference = 'Continue'

Write-Host ""
Write-Host "=== Searching for AI Chapter in SharePoint ===" -ForegroundColor Cyan
Write-Host "Connecting to Relias SharePoint..." -ForegroundColor Yellow

try {
    # Import PnP PowerShell module
    Import-Module PnP.PowerShell -ErrorAction Stop
    
    # Connect to SharePoint
    $siteUrl = "https://reliaslearning.sharepoint.com/"
    $clientId = $env:GRAPH_WORK_CLIENT_ID
    if (-not $clientId) {
        $clientId = $env:GRAPH_CLIENT_ID
    }
    if (-not $clientId) {
        $clientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"  # Default Microsoft client ID
    }
    
    Connect-PnPOnline -Url $siteUrl -Interactive -ClientId $clientId -ErrorAction Stop
    Write-Host "Connected successfully!" -ForegroundColor Green
    
    # Search for lists/libraries with AI Chapter in the name
    Write-Host ""
    Write-Host "=== Searching Lists/Libraries ===" -ForegroundColor Cyan
    $allLists = Get-PnPList | Where-Object { $_.Hidden -eq $false }
    $matchingLists = $allLists | Where-Object { 
        $_.Title -like '*AI*' -or 
        $_.Title -like '*Chapter*' -or
        $_.Title -like '*AIPE*'
    }
    
    if ($matchingLists) {
        Write-Host ""
        Write-Host "Found matching Lists/Libraries:" -ForegroundColor Green
        $matchingLists | Select-Object Title, ItemCount, BaseTemplate, Id | Format-Table -AutoSize
        
        # Search for files in matching lists
        foreach ($list in $matchingLists) {
            Write-Host ""
            Write-Host "--- Files in '$($list.Title)' ---" -ForegroundColor Yellow
            try {
                $items = Get-PnPListItem -List $list.Title -PageSize 10 -ErrorAction SilentlyContinue
                if ($items) {
                    $items | Select-Object -First 5 Title, FileSystemObjectType, Created | Format-Table -AutoSize
                }
            } catch {
                Write-Host "  (Could not retrieve items from this list)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No matching lists/libraries found" -ForegroundColor Yellow
    }
    
    # Search for subsites
    Write-Host ""
    Write-Host "=== Searching Subsites ===" -ForegroundColor Cyan
    try {
        $subsites = Get-PnPSubWeb -Recurse -ErrorAction SilentlyContinue | Where-Object { 
            $_.Title -like '*AI*' -or 
            $_.Title -like '*Chapter*' -or
            $_.Title -like '*AIPE*'
        }
        
        if ($subsites) {
            Write-Host ""
            Write-Host "Found matching Subsites:" -ForegroundColor Green
            $subsites | Select-Object Title, Url, Description | Format-Table -AutoSize
        } else {
            Write-Host "No matching subsites found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not search subsites: $_" -ForegroundColor Yellow
    }
    
    # Search for files using Find-PnPFile
    Write-Host ""
    Write-Host "=== Searching Files ===" -ForegroundColor Cyan
    try {
        $files = Find-PnPFile -Match "AI Chapter" -ErrorAction SilentlyContinue
        if ($files) {
            Write-Host ""
            Write-Host "Found matching files:" -ForegroundColor Green
            $files | Select-Object -First 10 Name, ServerRelativeUrl, Length | Format-Table -AutoSize
        } else {
            Write-Host "No files found matching 'AI Chapter'" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not search files: $_" -ForegroundColor Yellow
    }
    
    # List all lists to help identify potential locations
    Write-Host ""
    Write-Host "=== All Available Lists (for reference) ===" -ForegroundColor Cyan
    $allLists | Select-Object -First 20 Title, ItemCount | Format-Table -AutoSize
    
} catch {
    Write-Error "Failed to search SharePoint: $_"
    exit 1
} finally {
    # Disconnect
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
