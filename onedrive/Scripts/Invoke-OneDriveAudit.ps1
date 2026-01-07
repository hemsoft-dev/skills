# Invoke-OneDriveAudit.ps1
# Comprehensive OneDrive location and sync status audit

param(
    [string]$PrimaryLocation = "D:\OneDrive"
)

Write-Host "`n=== OneDrive Location Audit ===" -ForegroundColor Cyan
Write-Host "Primary Location: $PrimaryLocation`n" -ForegroundColor Gray

# 1. Process Status
Write-Host "Process Status:" -ForegroundColor Yellow
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "  ✅ Running (PID: $($process.Id))" -ForegroundColor Green
    Write-Host "  Path: $($process.Path)" -ForegroundColor Gray
} else {
    Write-Host "  ❌ Not running" -ForegroundColor Red
}

# 2. Registry Configuration
Write-Host "`nRegistry Configuration:" -ForegroundColor Yellow
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
if ($accounts) {
    foreach ($account in $accounts) {
        $folder = $account.UserFolder
        if ($folder -eq $PrimaryLocation) {
            Write-Host "  ✅ $folder (Primary)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  $folder (Not primary)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  No OneDrive accounts found in registry" -ForegroundColor Gray
}

# 3. Environment Variables
Write-Host "`nEnvironment Variables:" -ForegroundColor Yellow
$envVars = Get-ChildItem env: | Where-Object Name -like "*OneDrive*"
if ($envVars) {
    foreach ($var in $envVars) {
        Write-Host "  $($var.Name) = $($var.Value)" -ForegroundColor Gray
    }
} else {
    Write-Host "  No OneDrive environment variables found" -ForegroundColor Gray
}

# 4. Folder Analysis
Write-Host "`nFound OneDrive Folders:" -ForegroundColor Yellow
$commonPaths = @(
    "$env:USERPROFILE\OneDrive",
    "C:\Users\$env:USERNAME\OneDrive",
    "D:\OneDrive",
    "F:\OneDrive"
)

foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $item = Get-Item $path
        Write-Host "`n  Scanning: $($item.FullName)..." -ForegroundColor Gray
        $fileCount = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $folderCount = (Get-ChildItem $path -Recurse -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
        
        if ($path -eq $PrimaryLocation) {
            Write-Host "  ✅ PRIMARY: $($item.FullName)" -ForegroundColor Green
        } elseif ($fileCount -eq 0) {
            Write-Host "  ⚠️  REDUNDANT: $($item.FullName) (empty)" -ForegroundColor Yellow
        } else {
            Write-Host "  ⚠️  REDUNDANT: $($item.FullName)" -ForegroundColor Yellow
        }
        
        Write-Host "     Files: $fileCount | Folders: $folderCount | Last Modified: $($item.LastWriteTime)" -ForegroundColor Gray
    }
}

Write-Host ""
