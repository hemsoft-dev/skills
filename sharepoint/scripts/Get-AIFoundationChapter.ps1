<#
.SYNOPSIS
    List contents of AI Foundation Chapter folder in Productivity Engineering SharePoint site
.DESCRIPTION
    Connects to Productivity Engineering SharePoint site and lists all files and folders in the AI Foundation Chapter folder
.EXAMPLE
    .\Get-AIFoundationChapter.ps1
#>

$InformationPreference = 'Continue'

# Productivity Engineering SharePoint site URL
$peSiteUrl = "https://reliaslearning.sharepoint.com/sites/ProductivityEngineering"
$folderName = "AI Foundation Chapter"
$folderPath = "Shared Documents/$folderName"

Write-Host ""
Write-Host "=== AI Foundation Chapter Folder Contents ===" -ForegroundColor Cyan
Write-Host "Connecting to: $peSiteUrl" -ForegroundColor Yellow

try {
    Import-Module PnP.PowerShell -ErrorAction Stop
    
    # Check if already connected to this site
    $existingConnection = $null
    try {
        $existingConnection = Get-PnPConnection -ErrorAction SilentlyContinue
        if ($existingConnection -and $existingConnection.Url -eq $peSiteUrl) {
            Write-Host "Already connected to Productivity Engineering site!" -ForegroundColor Green
        } else {
            $existingConnection = $null
        }
    } catch {
        $existingConnection = $null
    }
    
    # Only connect if not already connected
    if (-not $existingConnection) {
        $clientId = $env:GRAPH_WORK_CLIENT_ID
        if (-not $clientId) {
            $clientId = $env:GRAPH_CLIENT_ID
        }
        if (-not $clientId) {
            $clientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"
        }
        
        Write-Host "Connecting (using -PersistLogin to cache credentials)..." -ForegroundColor Yellow
        # -PersistLogin stores refresh token for reuse between sessions (PnP PowerShell v3.0+)
        Connect-PnPOnline -Url $peSiteUrl -Interactive -ClientId $clientId -PersistLogin -ErrorAction Stop
        Write-Host "Connected successfully! Token cached for future use." -ForegroundColor Green
    }
    
    # Get site information
    $web = Get-PnPWeb
    Write-Host ""
    Write-Host "Site: $($web.Title)" -ForegroundColor White
    Write-Host "Folder: $folderName" -ForegroundColor White
    
    # Get folder contents
    Write-Host ""
    Write-Host "=== Contents of '$folderName' ===" -ForegroundColor Cyan
    
    try {
        # Get the folder
        $folder = Get-PnPFolder -Url $folderPath -ErrorAction Stop
        Write-Host "Folder found: $($folder.ServerRelativeUrl)" -ForegroundColor Gray
        
        # Get all items in the folder (files and subfolders)
        $items = Get-PnPListItem -List "Documents" -FolderServerRelativeUrl $folder.ServerRelativeUrl
        
        if ($items) {
            Write-Host ""
            Write-Host "Found $($items.Count) items:" -ForegroundColor Green
            
            # Separate files and folders
            # ContentTypeId starting with 0x0120 indicates folders, 0x0101 indicates files
            $files = $items | Where-Object { 
                $contentTypeId = $_.FieldValues.ContentTypeId
                $name = if ($_.FieldValues.FileLeafRef) { $_.FieldValues.FileLeafRef } else { $_.FieldValues.Title }
                
                if ($contentTypeId) {
                    $contentTypeIdStr = $contentTypeId.ToString()
                    -not $contentTypeIdStr.StartsWith('0x0120')
                } else {
                    # Fallback: check if it has a file extension
                    $name -match '\.[a-zA-Z0-9]+$'
                }
            }
            $subfolders = $items | Where-Object { 
                $contentTypeId = $_.FieldValues.ContentTypeId
                $name = if ($_.FieldValues.FileLeafRef) { $_.FieldValues.FileLeafRef } else { $_.FieldValues.Title }
                
                if ($contentTypeId) {
                    $contentTypeIdStr = $contentTypeId.ToString()
                    $contentTypeIdStr.StartsWith('0x0120')
                } else {
                    # Fallback: check if it doesn't have a file extension
                    -not ($name -match '\.[a-zA-Z0-9]+$')
                }
            }
            
            if ($subfolders) {
                Write-Host ""
                Write-Host "--- Subfolders ($($subfolders.Count)) ---" -ForegroundColor Yellow
                $subfolders | Select-Object @{Name='Folder Name';Expression={
                    if ($_.FieldValues.Title) { $_.FieldValues.Title } 
                    else { $_.FieldValues.FileLeafRef }
                }},
                @{Name='Modified';Expression={$_.FieldValues.Modified}},
                @{Name='Modified By';Expression={
                    if ($_.FieldValues.'Editor') { 
                        if ($_.FieldValues.'Editor'.LookupValue) { $_.FieldValues.'Editor'.LookupValue }
                        else { $_.FieldValues.'Editor' }
                    } else { 'N/A' }
                }} | Format-Table -AutoSize -Wrap
            }
            
            if ($files) {
                Write-Host ""
                Write-Host "--- Files ($($files.Count)) ---" -ForegroundColor Yellow
                $files | Select-Object @{Name='File Name';Expression={
                    if ($_.FieldValues.Title) { $_.FieldValues.Title }
                    else { $_.FieldValues.FileLeafRef }
                }},
                @{Name='Size';Expression={
                    if ($_.FieldValues.'File_x0020_Size') { 
                        "$([math]::Round($_.FieldValues.'File_x0020_Size' / 1KB, 2)) KB" 
                    } elseif ($_.FieldValues.FileSizeDisplay) {
                        $_.FieldValues.FileSizeDisplay
                    } else { 
                        'N/A' 
                    }
                }},
                @{Name='Modified';Expression={$_.FieldValues.Modified}},
                @{Name='Modified By';Expression={
                    if ($_.FieldValues.'Editor') {
                        if ($_.FieldValues.'Editor'.LookupValue) { $_.FieldValues.'Editor'.LookupValue }
                        else { $_.FieldValues.'Editor' }
                    } else { 'N/A' }
                }} | Format-Table -AutoSize -Wrap
                
                # Show file URLs
                Write-Host ""
                Write-Host "File URLs:" -ForegroundColor Cyan
                foreach ($file in $files) {
                    $filePath = $file.FieldValues.FileRef
                    if (-not $filePath) { $filePath = $file.FieldValues.FileRef }
                    $fileUrl = "https://reliaslearning.sharepoint.com$filePath"
                    $fileName = if ($file.FieldValues.Title) { $file.FieldValues.Title } else { $file.FieldValues.FileLeafRef }
                    Write-Host "  $fileName : $fileUrl" -ForegroundColor White
                }
            }
            
            if (-not $files -and -not $subfolders) {
                Write-Host ""
                Write-Host "No files or folders detected. Showing raw item data:" -ForegroundColor Yellow
                $items | Format-List FieldValues
            }
        } else {
            Write-Host "No items found in folder" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "Error accessing folder: $_" -ForegroundColor Red
        Write-Host "Trying alternative method..." -ForegroundColor Yellow
        
        # Alternative: Try using Get-PnPFolderItem
        try {
            $folderItems = Get-PnPFolderItem -FolderServerRelativeUrl $folder.ServerRelativeUrl -ErrorAction SilentlyContinue
            if ($folderItems) {
                Write-Host "Found items via alternative method:" -ForegroundColor Green
                $folderItems | Select-Object Name, ServerRelativeUrl, TimeLastModified | Format-Table -AutoSize
            }
        } catch {
            Write-Host "Alternative method also failed: $_" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Error "Failed to access Productivity Engineering site: $_"
    exit 1
} finally {
    Write-Host ""
    Write-Host "Note: Connection kept alive for future operations" -ForegroundColor Gray
}
