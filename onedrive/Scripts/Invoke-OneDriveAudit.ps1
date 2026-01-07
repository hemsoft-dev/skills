$InformationPreference = 'Continue'

# Invoke-OneDriveAudit.ps1
# Comprehensive OneDrive location and sync status audit

param(
    [string]$PrimaryLocation = "D:\OneDrive"
)

Write-Information "`n=== OneDrive Location Audit ===" -ForegroundColor Cyan
Write-Information "Primary Location: $PrimaryLocation`n" -ForegroundColor Gray

# 1. Process Status
Write-Information "Process Status:" -ForegroundColor Yellow
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($process) {
    Write-Information "  ✅ Running (PID: $($process.Id))" -ForegroundColor Green
    Write-Information "  Path: $($process.Path)" -ForegroundColor Gray
} else {
    Write-Information "  ❌ Not running" -ForegroundColor Red
}

# 2. Registry Configuration
Write-Information "`nRegistry Configuration:" -ForegroundColor Yellow
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
if ($accounts) {
    foreach ($account in $accounts) {
        $folder = $account.UserFolder
        if ($folder -eq $PrimaryLocation) {
            Write-Information "  ✅ $folder (Primary)" -ForegroundColor Green
        } else {
            Write-Information "  ⚠️  $folder (Not primary)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Information "  No OneDrive accounts found in registry" -ForegroundColor Gray
}

# 3. Environment Variables
Write-Information "`nEnvironment Variables:" -ForegroundColor Yellow
$envVars = Get-ChildItem env: | Where-Object Name -like "*OneDrive*"
if ($envVars) {
    foreach ($var in $envVars) {
        Write-Information "  $($var.Name) = $($var.Value)" -ForegroundColor Gray
    }
} else {
    Write-Information "  No OneDrive environment variables found" -ForegroundColor Gray
}

# 4. Folder Analysis
Write-Information "`nFound OneDrive Folders:" -ForegroundColor Yellow
$commonPaths = @(
    "$env:USERPROFILE\OneDrive",
    "C:\Users\$env:USERNAME\OneDrive",
    "D:\OneDrive",
    "F:\OneDrive"
)

foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $item = Get-Item $path
        Write-Information "`n  Scanning: $($item.FullName)..." -ForegroundColor Gray
        $fileCount = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $folderCount = (Get-ChildItem $path -Recurse -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
        
        if ($path -eq $PrimaryLocation) {
            Write-Information "  ✅ PRIMARY: $($item.FullName)" -ForegroundColor Green
        } elseif ($fileCount -eq 0) {
            Write-Information "  ⚠️  REDUNDANT: $($item.FullName) (empty)" -ForegroundColor Yellow
        } else {
            Write-Information "  ⚠️  REDUNDANT: $($item.FullName)" -ForegroundColor Yellow
        }
        
        Write-Information "     Files: $fileCount | Folders: $folderCount | Last Modified: $($item.LastWriteTime)" -ForegroundColor Gray
    }
}

Write-Information ""
