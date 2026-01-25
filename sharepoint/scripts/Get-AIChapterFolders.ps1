<#
.SYNOPSIS
    Get AI Chapter folders from Productivity Engineering SharePoint site
.DESCRIPTION
    Connects directly to Productivity Engineering SharePoint site and lists AI Chapter folders.
    Uses Azure.Identity token cache which persists credentials between sessions.
    Token cache location: $env:LOCALAPPDATA\.IdentityService\AzureStorage
.EXAMPLE
    .\Get-AIChapterFolders.ps1
    .\Get-AIChapterFolders.ps1 -AuthMethod DeviceLogin
.NOTES
    First run will require authentication. Subsequent runs will reuse cached tokens automatically.
    Requires PnP PowerShell v3.0+ and -PersistLogin parameter (included in script).
    Token cache location: %LOCALAPPDATA%\.m365pnppowershell
    
    If authentication is required every time, check that:
    1. PnP PowerShell version is 3.0+: Get-Module PnP.PowerShell | Select-Object Version
    2. Token cache directory exists: $env:LOCALAPPDATA\.m365pnppowershell
    3. Your organization allows token caching
#>

$InformationPreference = 'Continue'

# Productivity Engineering SharePoint site URL
$peSiteUrl = "https://reliaslearning.sharepoint.com/sites/ProductivityEngineering"

# Authentication method: 'Interactive' (default) or 'DeviceLogin' (may have better token persistence)
param(
    [ValidateSet('Interactive', 'DeviceLogin')]
    [string]$AuthMethod = 'Interactive'
)

Write-Host ""
Write-Host "=== Productivity Engineering - AI Chapter Folders ===" -ForegroundColor Cyan
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
        # Use consistent client ID for better token caching
        # PnP PowerShell uses Azure.Identity which caches tokens to:
        # Windows: %LOCALAPPDATA%\.IdentityService\AzureStorage
        # The cache is keyed by client ID and site URL
        $clientId = $env:GRAPH_WORK_CLIENT_ID
        if (-not $clientId) {
            $clientId = $env:GRAPH_CLIENT_ID
        }
        if (-not $clientId) {
            $clientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"
        }
        
        # Connect using specified authentication method
        # Azure.Identity token cache location: $env:LOCALAPPDATA\.IdentityService\AzureStorage
        Write-Host "Connecting using $AuthMethod method (checking for cached credentials)..." -ForegroundColor Yellow
        
        if ($AuthMethod -eq 'DeviceLogin') {
            # DeviceLogin with -PersistLogin stores refresh token for reuse
            Write-Host "Using device code flow - follow the instructions to authenticate" -ForegroundColor Cyan
            Connect-PnPOnline -Url $peSiteUrl -DeviceLogin -ClientId $clientId -PersistLogin -ErrorAction Stop
        } else {
            # -PersistLogin stores refresh token in %LOCALAPPDATA%\.m365pnppowershell (PnP PowerShell v3.0+)
            # First run will prompt for login, subsequent runs will reuse cached token automatically
            Write-Host "Token cache location: $env:LOCALAPPDATA\.m365pnppowershell" -ForegroundColor Gray
            Connect-PnPOnline -Url $peSiteUrl -Interactive -ClientId $clientId -PersistLogin -ErrorAction Stop
        }
        
        Write-Host "Connected successfully!" -ForegroundColor Green
        
        # Verify token cache location exists
        $tokenCachePath = Join-Path $env:LOCALAPPDATA ".m365pnppowershell"
        if (Test-Path $tokenCachePath) {
            Write-Host "Token cache directory exists: $tokenCachePath" -ForegroundColor Gray
            Write-Host "Note: Token cached. Future runs will reuse cached credentials automatically." -ForegroundColor Gray
        } else {
            Write-Host "Warning: Token cache directory not found. Tokens may not persist." -ForegroundColor Yellow
            Write-Host "Ensure PnP PowerShell v3.0+ is installed: Get-Module PnP.PowerShell | Select-Object Version" -ForegroundColor Yellow
        }
    }
    
    # Get site information
    $web = Get-PnPWeb
    Write-Host ""
    Write-Host "Site: $($web.Title)" -ForegroundColor White
    Write-Host "URL: $($web.Url)" -ForegroundColor White
    
    # Get folders using Get-PnPFolder (more reliable for folders)
    Write-Host ""
    Write-Host "=== AI Chapter Folders in Documents Library ===" -ForegroundColor Cyan
    try {
        $docLibrary = Get-PnPList -Identity "Documents"
        $folders = Get-PnPFolder -List "Documents" -ErrorAction Stop
        
        Write-Host "Found $($folders.Count) folders in Documents library" -ForegroundColor Gray
        
        # Filter for AI Chapter related folders
        $aiFolders = $folders | Where-Object { 
            $name = $_.Name
            ($name -like '*AI*' -and $name -like '*Chapter*') -or
            $name -like '*AI*Tutorial*' -or
            $name -like '*AI*Foundation*' -or
            $name -like '*AI*Engineering*'
        }
        
        if ($aiFolders) {
            Write-Host ""
            Write-Host "Found $($aiFolders.Count) AI Chapter folders:" -ForegroundColor Green
            $aiFolders | Select-Object Name, ServerRelativeUrl, TimeLastModified | Format-Table -AutoSize -Wrap
            
            # Show folder URLs
            Write-Host ""
            Write-Host "Folder URLs:" -ForegroundColor Cyan
            foreach ($folder in $aiFolders) {
                # ServerRelativeUrl already includes the site path, just prepend the tenant URL
                $folderUrl = "https://reliaslearning.sharepoint.com$($folder.ServerRelativeUrl)"
                Write-Host "  $($folder.Name): $folderUrl" -ForegroundColor White
            }
        } else {
            Write-Host ""
            Write-Host "No AI Chapter folders found. Listing all folders:" -ForegroundColor Yellow
            $folders | Select-Object Name, ServerRelativeUrl | Format-Table -AutoSize -Wrap
        }
    } catch {
        Write-Host "Error accessing folders: $_" -ForegroundColor Red
        Write-Host "Trying alternative method with list items..." -ForegroundColor Yellow
        
        # Fallback: try list items
        try {
            $docItems = Get-PnPListItem -List "Documents" -PageSize 200
            Write-Host "Retrieved $($docItems.Count) items" -ForegroundColor Gray
            
            # Show first few items to debug
            Write-Host ""
            Write-Host "First 10 items (for debugging):" -ForegroundColor Cyan
            $docItems | Select-Object -First 10 | ForEach-Object {
                $title = $_.FieldValues.Title
                $type = $_.FieldValues.FileSystemObjectType
                Write-Host "  Title: $title | Type: $type" -ForegroundColor White
            }
        } catch {
            Write-Host "Alternative method also failed: $_" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Error "Failed to access Productivity Engineering site: $_"
    exit 1
} finally {
    # Don't disconnect - keep connection alive for future use
    Write-Host ""
    Write-Host "Note: Connection kept alive for future operations" -ForegroundColor Gray
}
