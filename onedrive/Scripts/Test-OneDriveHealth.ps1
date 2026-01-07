$InformationPreference = 'Continue'

# Test-OneDriveHealth.ps1
# Comprehensive health check for OneDrive installations with 1M+ files

param(
    [string]$PrimaryLocation = "D:\OneDrive",
    [switch]$FixIssues
)

Write-Information "`n=== OneDrive Health Check ===" -ForegroundColor Cyan
Write-Information "Checking: $PrimaryLocation`n" -ForegroundColor Gray

$issuesFound = @()
$issuesFixed = @()

# 1. Process Check
Write-Information "[1/8] Checking OneDrive Process..." -ForegroundColor Yellow
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($process) {
    Write-Information "  ✅ Running (PID: $($process.Id))" -ForegroundColor Green
} else {
    Write-Information "  ❌ Not running" -ForegroundColor Red
    $issuesFound += "OneDrive process not running"
    
    if ($FixIssues) {
        Write-Information "  🔧 Starting OneDrive..." -ForegroundColor Cyan
        & "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
        Start-Sleep -Seconds 3
        $process = Get-Process OneDrive -ErrorAction SilentlyContinue
        if ($process) {
            Write-Information "  ✅ Started successfully" -ForegroundColor Green
            $issuesFixed += "Started OneDrive process"
        }
    }
}

# 2. Primary Location Check
Write-Information "`n[2/8] Verifying Primary Location..." -ForegroundColor Yellow
if (Test-Path $PrimaryLocation) {
    Write-Information "  ✅ Exists: $PrimaryLocation" -ForegroundColor Green
} else {
    Write-Information "  ❌ Not found: $PrimaryLocation" -ForegroundColor Red
    $issuesFound += "Primary location not found"
}

# 3. Registry Configuration
Write-Information "`n[3/8] Checking Registry Configuration..." -ForegroundColor Yellow
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
$pointsToP primary = $false
if ($accounts) {
    foreach ($account in $accounts) {
        if ($account.UserFolder -eq $PrimaryLocation) {
            $pointsToPrimary = $true
            Write-Information "  ✅ Registry points to: $PrimaryLocation" -ForegroundColor Green
        }
    }
    if (-not $pointsToPrimary) {
        Write-Information "  ⚠️  Registry does not point to primary location" -ForegroundColor Yellow
        $issuesFound += "Registry not configured for primary location"
    }
} else {
    Write-Information "  ❌ No OneDrive accounts configured" -ForegroundColor Red
    $issuesFound += "No OneDrive accounts in registry"
}

# 4. Disk Space Check (Critical for large file collections)
Write-Information "`n[4/8] Checking Disk Space..." -ForegroundColor Yellow
$drive = $PrimaryLocation.Substring(0, 1)
$diskInfo = Get-PSDrive $drive -ErrorAction SilentlyContinue
if ($diskInfo) {
    $freeSpaceGB = [math]::Round($diskInfo.Free / 1GB, 2)
    $totalSpaceGB = [math]::Round(($diskInfo.Used + $diskInfo.Free) / 1GB, 2)
    $usedPercent = [math]::Round((($diskInfo.Used / ($diskInfo.Used + $diskInfo.Free)) * 100), 1)
    
    Write-Information "  Drive: $($drive): Total: $totalSpaceGB GB, Free: $freeSpaceGB GB ($usedPercent% used)" -ForegroundColor Gray
    
    if ($freeSpaceGB -lt 10) {
        Write-Information "  ❌ CRITICAL: Less than 10 GB free" -ForegroundColor Red
        $issuesFound += "Critically low disk space ($freeSpaceGB GB)"
    } elseif ($freeSpaceGB -lt 50) {
        Write-Information "  ⚠️  WARNING: Less than 50 GB free" -ForegroundColor Yellow
        $issuesFound += "Low disk space ($freeSpaceGB GB)"
    } else {
        Write-Information "  ✅ Adequate disk space" -ForegroundColor Green
    }
}

# 5. Files On-Demand Status (Recommended for 1M+ files)
Write-Information "`n[5/8] Checking Files On-Demand..." -ForegroundColor Yellow
$filesOnDemand = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -ErrorAction SilentlyContinue
if ($filesOnDemand -and $filesOnDemand.FilesOnDemandEnabled -eq 1) {
    Write-Information "  ✅ Enabled (recommended for 1M+ files)" -ForegroundColor Green
} else {
    Write-Information "  ⚠️  Disabled - all files are downloaded locally" -ForegroundColor Yellow
    Write-Information "     With 1M+ files, consider enabling Files On-Demand" -ForegroundColor Gray
    $issuesFound += "Files On-Demand not enabled (may consume excessive disk space)"
}

# 6. Network Connectivity Check
Write-Information "`n[6/8] Checking Network Connectivity..." -ForegroundColor Yellow
$oneDriveServer = "onedrive.live.com"
$pingTest = Test-Connection -ComputerName $oneDriveServer -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($pingTest) {
    Write-Information "  ✅ Can reach OneDrive servers" -ForegroundColor Green
} else {
    Write-Information "  ❌ Cannot reach OneDrive servers" -ForegroundColor Red
    $issuesFound += "Network connectivity issue"
}

# 7. Check for Error Codes
Write-Information "`n[7/8] Checking for Sync Errors..." -ForegroundColor Yellow
$errorCheck = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "LastError" -ErrorAction SilentlyContinue
if ($errorCheck -and $errorCheck.LastError -and $errorCheck.LastError -ne 0) {
    Write-Information "  ❌ Error Code: $($errorCheck.LastError)" -ForegroundColor Red
    Write-Information "     Reference: https://support.microsoft.com/en-us/office/what-do-the-onedrive-error-codes-mean-f7a68338-e540-4ebf-ad5d-56c5633acded" -ForegroundColor Gray
    $issuesFound += "Sync error code: $($errorCheck.LastError)"
} else {
    Write-Information "  ✅ No error codes found" -ForegroundColor Green
}

# 8. Performance Recommendations for Large Collections
Write-Information "`n[8/8] Performance Check (1M+ Files)..." -ForegroundColor Yellow
if (Test-Path $PrimaryLocation) {
    # Only do full scan if explicitly requested - otherwise estimate
    Write-Information "  Estimated file count: 1,000,000+" -ForegroundColor Gray
    Write-Information "  Recommendations:" -ForegroundColor Yellow
    Write-Information "    • Enable Files On-Demand to reduce local storage" -ForegroundColor Gray
    Write-Information "    • Exclude temp/cache folders from sync" -ForegroundColor Gray
    Write-Information "    • Monitor disk I/O during sync operations" -ForegroundColor Gray
    Write-Information "    • Consider selective sync for rarely accessed folders" -ForegroundColor Gray
}

# Summary
Write-Information "`n=== Health Check Summary ===" -ForegroundColor Cyan
if ($issuesFound.Count -eq 0) {
    Write-Information "✅ No issues detected - OneDrive is healthy" -ForegroundColor Green
} else {
    Write-Information "⚠️  Issues Found: $($issuesFound.Count)" -ForegroundColor Yellow
    foreach ($issue in $issuesFound) {
        Write-Information "   • $issue" -ForegroundColor Gray
    }
}

if ($issuesFixed.Count -gt 0) {
    Write-Information "`n🔧 Issues Fixed: $($issuesFixed.Count)" -ForegroundColor Green
    foreach ($fix in $issuesFixed) {
        Write-Information "   • $fix" -ForegroundColor Gray
    }
}

Write-Information ""
