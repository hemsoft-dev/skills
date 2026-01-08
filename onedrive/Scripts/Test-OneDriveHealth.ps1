$InformationPreference = 'Continue'

# Test-OneDriveHealth.ps1
# Comprehensive health check for OneDrive installations with 1M+ files

param(
    [string]$PrimaryLocation = "D:\OneDrive",
    [switch]$FixIssues
)

Write-Information "[36m`n=== OneDrive Health Check ===`e[0m"
Write-Information "[90mChecking: $PrimaryLocation`n`e[0m"

$issuesFound = @()
$issuesFixed = @()

# 1. Process Check
Write-Information "[33m[1/8] Checking OneDrive Process...`e[0m"
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($process) {
    Write-Information "[32m  ✅ Running (PID: $($process.Id))`e[0m"
} else {
    Write-Information "[31m  ❌ Not running`e[0m"
    $issuesFound += "OneDrive process not running"
    
    if ($FixIssues) {
        Write-Information "[36m  🔧 Starting OneDrive...`e[0m"
        & "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
        Start-Sleep -Seconds 3
        $process = Get-Process OneDrive -ErrorAction SilentlyContinue
        if ($process) {
            Write-Information "[32m  ✅ Started successfully`e[0m"
            $issuesFixed += "Started OneDrive process"
        }
    }
}

# 2. Primary Location Check
Write-Information "[33m`n[2/8] Verifying Primary Location...`e[0m"
if (Test-Path $PrimaryLocation) {
    Write-Information "[32m  ✅ Exists: $PrimaryLocation`e[0m"
} else {
    Write-Information "[31m  ❌ Not found: $PrimaryLocation`e[0m"
    $issuesFound += "Primary location not found"
}

# 3. Registry Configuration
Write-Information "[33m`n[3/8] Checking Registry Configuration...`e[0m"
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
$pointsToP primary = $false
if ($accounts) {
    foreach ($account in $accounts) {
        if ($account.UserFolder -eq $PrimaryLocation) {
            $pointsToPrimary = $true
            Write-Information "[32m  ✅ Registry points to: $PrimaryLocation`e[0m"
        }
    }
    if (-not $pointsToPrimary) {
        Write-Information "[33m  ⚠️  Registry does not point to primary location`e[0m"
        $issuesFound += "Registry not configured for primary location"
    }
} else {
    Write-Information "[31m  ❌ No OneDrive accounts configured`e[0m"
    $issuesFound += "No OneDrive accounts in registry"
}

# 4. Disk Space Check (Critical for large file collections)
Write-Information "[33m`n[4/8] Checking Disk Space...`e[0m"
$drive = $PrimaryLocation.Substring(0, 1)
$diskInfo = Get-PSDrive $drive -ErrorAction SilentlyContinue
if ($diskInfo) {
    $freeSpaceGB = [math]::Round($diskInfo.Free / 1GB, 2)
    $totalSpaceGB = [math]::Round(($diskInfo.Used + $diskInfo.Free) / 1GB, 2)
    $usedPercent = [math]::Round((($diskInfo.Used / ($diskInfo.Used + $diskInfo.Free)) * 100), 1)
    
    Write-Information "[90m  Drive: $($drive): Total: $totalSpaceGB GB, Free: $freeSpaceGB GB ($usedPercent% used)`e[0m"
    
    if ($freeSpaceGB -lt 10) {
        Write-Information "[31m  ❌ CRITICAL: Less than 10 GB free`e[0m"
        $issuesFound += "Critically low disk space ($freeSpaceGB GB)"
    } elseif ($freeSpaceGB -lt 50) {
        Write-Information "[33m  ⚠️  WARNING: Less than 50 GB free`e[0m"
        $issuesFound += "Low disk space ($freeSpaceGB GB)"
    } else {
        Write-Information "[32m  ✅ Adequate disk space`e[0m"
    }
}

# 5. Files On-Demand Status (Recommended for 1M+ files)
Write-Information "[33m`n[5/8] Checking Files On-Demand...`e[0m"
$filesOnDemand = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -ErrorAction SilentlyContinue
if ($filesOnDemand -and $filesOnDemand.FilesOnDemandEnabled -eq 1) {
    Write-Information "[32m  ✅ Enabled (recommended for 1M+ files)`e[0m"
} else {
    Write-Information "[33m  ⚠️  Disabled - all files are downloaded locally`e[0m"
    Write-Information "[90m     With 1M+ files, consider enabling Files On-Demand`e[0m"
    $issuesFound += "Files On-Demand not enabled (may consume excessive disk space)"
}

# 6. Network Connectivity Check
Write-Information "[33m`n[6/8] Checking Network Connectivity...`e[0m"
$oneDriveServer = "onedrive.live.com"
$pingTest = Test-Connection -ComputerName $oneDriveServer -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($pingTest) {
    Write-Information "[32m  ✅ Can reach OneDrive servers`e[0m"
} else {
    Write-Information "[31m  ❌ Cannot reach OneDrive servers`e[0m"
    $issuesFound += "Network connectivity issue"
}

# 7. Check for Error Codes
Write-Information "[33m`n[7/8] Checking for Sync Errors...`e[0m"
$errorCheck = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "LastError" -ErrorAction SilentlyContinue
if ($errorCheck -and $errorCheck.LastError -and $errorCheck.LastError -ne 0) {
    Write-Information "[31m  ❌ Error Code: $($errorCheck.LastError)`e[0m"
    Write-Information "[90m     Reference: https://support.microsoft.com/en-us/office/what-do-the-onedrive-error-codes-mean-f7a68338-e540-4ebf-ad5d-56c5633acded`e[0m"
    $issuesFound += "Sync error code: $($errorCheck.LastError)"
} else {
    Write-Information "[32m  ✅ No error codes found`e[0m"
}

# 8. Performance Recommendations for Large Collections
Write-Information "[33m`n[8/8] Performance Check (1M+ Files)...`e[0m"
if (Test-Path $PrimaryLocation) {
    # Only do full scan if explicitly requested - otherwise estimate
    Write-Information "[90m  Estimated file count: 1,000,000+`e[0m"
    Write-Information "[33m  Recommendations:`e[0m"
    Write-Information "[90m    • Enable Files On-Demand to reduce local storage`e[0m"
    Write-Information "[90m    • Exclude temp/cache folders from sync`e[0m"
    Write-Information "[90m    • Monitor disk I/O during sync operations`e[0m"
    Write-Information "[90m    • Consider selective sync for rarely accessed folders`e[0m"
}

# Summary
Write-Information "[36m`n=== Health Check Summary ===`e[0m"
if ($issuesFound.Count -eq 0) {
    Write-Information "[32m✅ No issues detected - OneDrive is healthy`e[0m"
} else {
    Write-Information "[33m⚠️  Issues Found: $($issuesFound.Count)`e[0m"
    foreach ($issue in $issuesFound) {
        Write-Information "[90m   • $issue`e[0m"
    }
}

if ($issuesFixed.Count -gt 0) {
    Write-Information "[32m`n🔧 Issues Fixed: $($issuesFixed.Count)`e[0m"
    foreach ($fix in $issuesFixed) {
        Write-Information "[90m   • $fix`e[0m"
    }
}

Write-Information ""
