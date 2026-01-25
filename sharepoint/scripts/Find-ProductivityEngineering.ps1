<#
.SYNOPSIS
    Find Productivity Engineering SharePoint site and AI Chapter folders
.DESCRIPTION
    Searches for Productivity Engineering SharePoint site and lists AI Chapter related content
#>

$InformationPreference = 'Continue'

Write-Host ""
Write-Host "=== Searching for Productivity Engineering SharePoint Site ===" -ForegroundColor Cyan
Write-Host "Connecting to Relias SharePoint..." -ForegroundColor Yellow

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
    
    # Search for subsites with Productivity Engineering
    Write-Host ""
    Write-Host "=== Searching for Productivity Engineering Subsites ===" -ForegroundColor Cyan
    try {
        $subsites = Get-PnPSubWeb -Recurse -ErrorAction SilentlyContinue | Where-Object { 
            $_.Title -like '*Productivity*' -or 
            $_.Title -like '*Engineering*' -or
            $_.Title -like '*PE*'
        }
        
        if ($subsites) {
            Write-Host ""
            Write-Host "Found matching Subsites:" -ForegroundColor Green
            $subsites | Select-Object Title, Url, Description | Format-Table -AutoSize -Wrap
            
            # For each subsite, search for AI Chapter content
            foreach ($subsite in $subsites) {
                Write-Host ""
                Write-Host "=== Checking '$($subsite.Title)' for AI Chapter content ===" -ForegroundColor Yellow
                Write-Host "URL: $($subsite.Url)" -ForegroundColor Gray
                
                try {
                    # Connect to the subsite
                    Connect-PnPOnline -Url $subsite.Url -Interactive -ClientId $clientId -ErrorAction SilentlyContinue
                    
                    # Get lists
                    $lists = Get-PnPList | Where-Object { $_.Hidden -eq $false }
                    $aiLists = $lists | Where-Object { 
                        $_.Title -like '*AI*' -or 
                        $_.Title -like '*Chapter*'
                    }
                    
                    if ($aiLists) {
                        Write-Host "Found AI Chapter related lists:" -ForegroundColor Green
                        $aiLists | Select-Object Title, ItemCount | Format-Table -AutoSize
                    }
                    
                    # Search Documents library for AI Chapter folders
                    try {
                        $docItems = Get-PnPListItem -List "Documents" -PageSize 50 -ErrorAction SilentlyContinue
                        $aiFolders = $docItems | Where-Object { 
                            $title = $_.FieldValues.Title
                            ($title -like '*AI*' -and $title -like '*Chapter*') -or
                            $title -like '*AIPE*'
                        }
                        
                        if ($aiFolders) {
                            Write-Host "Found AI Chapter folders/files:" -ForegroundColor Green
                            $aiFolders | Select-Object @{Name='Title';Expression={$_.FieldValues.Title}},
                                                       @{Name='Type';Expression={$_.FieldValues.FileSystemObjectType}},
                                                       @{Name='Path';Expression={$_.FieldValues.FileRef}} | 
                                         Format-Table -AutoSize -Wrap
                        }
                    } catch {
                        Write-Host "Could not search Documents library: $_" -ForegroundColor Yellow
                    }
                    
                    # Reconnect to root site
                    Connect-PnPOnline -Url $siteUrl -Interactive -ClientId $clientId -ErrorAction SilentlyContinue
                } catch {
                    Write-Host "Could not access subsite: $_" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "No matching subsites found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not search subsites: $_" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Failed to search SharePoint: $_"
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
