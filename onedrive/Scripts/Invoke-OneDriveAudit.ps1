$InformationPreference = 'Continue'

# Invoke-OneDriveAudit.ps1
# Comprehensive OneDrive location and sync status audit

param(
    [string]$PrimaryLocation = "D:\OneDrive"
)

Write-Information "[36m`n=== OneDrive Location Audit ===`e[0m"
Write-Information "[90mPrimary Location: $PrimaryLocation`n`e[0m"

# 1. Process Status
Write-Information "[33mProcess Status:`e[0m"
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($process) {
    Write-Information "[32m  ✅ Running (PID: $($process.Id))`e[0m"
    Write-Information "[90m  Path: $($process.Path)`e[0m"
} else {
    Write-Information "[31m  ❌ Not running`e[0m"
}

# 2. Registry Configuration
Write-Information "[33m`nRegistry Configuration:`e[0m"
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
if ($accounts) {
    foreach ($account in $accounts) {
        $folder = $account.UserFolder
        if ($folder -eq $PrimaryLocation) {
            Write-Information "[32m  ✅ $folder (Primary)`e[0m"
        } else {
            Write-Information "[33m  ⚠️  $folder (Not primary)`e[0m"
        }
    }
} else {
    Write-Information "[90m  No OneDrive accounts found in registry`e[0m"
}

# 3. Environment Variables
Write-Information "[33m`nEnvironment Variables:`e[0m"
$envVars = Get-ChildItem env: | Where-Object Name -like "*OneDrive*"
if ($envVars) {
    foreach ($var in $envVars) {
        Write-Information "[90m  $($var.Name) = $($var.Value)`e[0m"
    }
} else {
    Write-Information "[90m  No OneDrive environment variables found`e[0m"
}

# 4. Folder Analysis
Write-Information "[33m`nFound OneDrive Folders:`e[0m"
$commonPaths = @(
    "$env:USERPROFILE\OneDrive",
    "C:\Users\$env:USERNAME\OneDrive",
    "D:\OneDrive",
    "F:\OneDrive"
)

foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $item = Get-Item $path
        Write-Information "[90m`n  Scanning: $($item.FullName)...`e[0m"
        $fileCount = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $folderCount = (Get-ChildItem $path -Recurse -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
        
        if ($path -eq $PrimaryLocation) {
            Write-Information "[32m  ✅ PRIMARY: $($item.FullName)`e[0m"
        } elseif ($fileCount -eq 0) {
            Write-Information "[33m  ⚠️  REDUNDANT: $($item.FullName) (empty)`e[0m"
        } else {
            Write-Information "[33m  ⚠️  REDUNDANT: $($item.FullName)`e[0m"
        }
        
        Write-Information "[90m     Files: $fileCount | Folders: $folderCount | Last Modified: $($item.LastWriteTime)`e[0m"
    }
}

Write-Information ""
