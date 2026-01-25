<#
.SYNOPSIS
    Get documents from AI Engineering Chapter or AI Foundation Chapter folders
.DESCRIPTION
    Lists all documents (files) from either AI Engineering Chapter or AI Foundation Chapter folder.
    Recursively searches subfolders. Reuses existing connections to avoid repeated authentication.
.PARAMETER Chapter
    Which chapter to list: 'Engineering', 'Foundation', or 'Both' (default: 'Both')
.EXAMPLE
    .\Get-AIChapterDocuments.ps1
    .\Get-AIChapterDocuments.ps1 -Chapter Engineering
    .\Get-AIChapterDocuments.ps1 -Chapter Foundation
#>

param(
    [ValidateSet('Engineering', 'Foundation', 'Both')]
    [string]$Chapter = 'Both'
)

$InformationPreference = 'Continue'

# Productivity Engineering SharePoint site URL
$peSiteUrl = "https://reliaslearning.sharepoint.com/sites/ProductivityEngineering"

Write-Host ""
Write-Host "=== AI Chapter Documents ===" -ForegroundColor Cyan

try {
    Import-Module PnP.PowerShell -ErrorAction Stop
    
    # Check for existing connection FIRST - this is critical to avoid re-authentication
    $existingConnection = $null
    try {
        $existingConnection = Get-PnPConnection -ErrorAction SilentlyContinue
        if ($existingConnection -and $existingConnection.Url -eq $peSiteUrl) {
            Write-Host "Using existing connection to Productivity Engineering site" -ForegroundColor Green
        } else {
            $existingConnection = $null
        }
    } catch {
        $existingConnection = $null
    }
    
    # Only connect if NOT already connected to the correct site
    if (-not $existingConnection) {
        $clientId = $env:GRAPH_WORK_CLIENT_ID
        if (-not $clientId) {
            $clientId = $env:GRAPH_CLIENT_ID
        }
        if (-not $clientId) {
            $clientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"
        }
        
        Write-Host "Connecting to: $peSiteUrl" -ForegroundColor Yellow
        Write-Host "(Using -PersistLogin to cache credentials for future sessions)" -ForegroundColor Gray
        # -PersistLogin stores refresh token in %LOCALAPPDATA%\.m365pnppowershell for reuse
        # First run will prompt for authentication, subsequent runs will reuse cached token
        Connect-PnPOnline -Url $peSiteUrl -Interactive -ClientId $clientId -PersistLogin -ErrorAction Stop
        Write-Host "Connected successfully! Token cached for future use." -ForegroundColor Green
    }
    
    # Function to recursively get all files from a folder
    function Get-AllFilesFromFolder {
        param(
            [string]$FolderPath,
            [string]$FolderName
        )
        
        $allFiles = @()
        
        try {
            # Get folder
            $folder = Get-PnPFolder -Url $FolderPath -ErrorAction SilentlyContinue
            if (-not $folder) {
                Write-Host "  Folder not found: $FolderName" -ForegroundColor Yellow
                return $allFiles
            }
            
            # Get items in folder
            $items = Get-PnPListItem -List "Documents" -FolderServerRelativeUrl $folder.ServerRelativeUrl -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                $contentTypeId = $item.FieldValues.ContentTypeId
                $name = if ($item.FieldValues.FileLeafRef) { $item.FieldValues.FileLeafRef } else { $item.FieldValues.Title }
                
                if ($contentTypeId) {
                    $contentTypeIdStr = $contentTypeId.ToString()
                    $isFolder = $contentTypeIdStr.StartsWith('0x0120')
                    
                    if ($isFolder) {
                        # Recursively search subfolder
                        $subfolderPath = "$FolderPath/$name"
                        $subFiles = Get-AllFilesFromFolder -FolderPath $subfolderPath -FolderName "$FolderName/$name"
                        $allFiles += $subFiles
                    } else {
                        # It's a file
                        $fileInfo = [PSCustomObject]@{
                            Name = $name
                            Path = $item.FieldValues.FileRef
                            Size = if ($item.FieldValues.'File_x0020_Size') { 
                                [math]::Round($item.FieldValues.'File_x0020_Size' / 1KB, 2) 
                            } else { 0 }
                            Modified = $item.FieldValues.Modified
                            ModifiedBy = if ($item.FieldValues.'Editor') {
                                if ($item.FieldValues.'Editor'.LookupValue) { $item.FieldValues.'Editor'.LookupValue }
                                else { $item.FieldValues.'Editor'.ToString() }
                            } else { 'N/A' }
                            Chapter = $FolderName
                        }
                        $allFiles += $fileInfo
                    }
                }
            }
        } catch {
            Write-Host "  Error accessing $FolderName : $_" -ForegroundColor Red
        }
        
        return $allFiles
    }
    
    # Get files from requested chapter(s)
    $allFiles = @()
    
    if ($Chapter -eq 'Both' -or $Chapter -eq 'Engineering') {
        Write-Host ""
        Write-Host "=== AI Engineering Chapter ===" -ForegroundColor Cyan
        $engFiles = Get-AllFilesFromFolder -FolderPath "Shared Documents/AI Engineering Chapter" -FolderName "AI Engineering Chapter"
        $allFiles += $engFiles
        Write-Host "Found $($engFiles.Count) files" -ForegroundColor Green
    }
    
    if ($Chapter -eq 'Both' -or $Chapter -eq 'Foundation') {
        Write-Host ""
        Write-Host "=== AI Foundation Chapter ===" -ForegroundColor Cyan
        $foundationFiles = Get-AllFilesFromFolder -FolderPath "Shared Documents/AI Foundation Chapter" -FolderName "AI Foundation Chapter"
        $allFiles += $foundationFiles
        Write-Host "Found $($foundationFiles.Count) files" -ForegroundColor Green
    }
    
    # Display results
    if ($allFiles) {
        Write-Host ""
        Write-Host "=== All Documents ($($allFiles.Count) total) ===" -ForegroundColor Cyan
        $allFiles | Select-Object Chapter, Name, 
                                  @{Name='Size (KB)';Expression={$_.Size}},
                                  Modified, ModifiedBy | 
                     Format-Table -AutoSize -Wrap
        
        Write-Host ""
        Write-Host "=== Document URLs ===" -ForegroundColor Cyan
        foreach ($file in $allFiles) {
            $fileUrl = "https://reliaslearning.sharepoint.com$($file.Path)"
            Write-Host "  [$($file.Name)]($fileUrl)" -ForegroundColor White
        }
    } else {
        Write-Host ""
        Write-Host "No documents found" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Failed to access SharePoint: $_"
    exit 1
} finally {
    # Keep connection alive - don't disconnect
    Write-Host ""
    Write-Host "Note: Connection kept alive. Run this script again without re-authentication." -ForegroundColor Gray
}
