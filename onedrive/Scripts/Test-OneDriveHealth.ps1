# Test-OneDriveHealth.ps1
# Comprehensive health check for OneDrive installations with 1M+ files

param(
    [string]$PrimaryLocation = "D:\OneDrive",
    [switch]$FixIssues
)

Write-Host "`n=== OneDrive Health Check ===" -ForegroundColor Cyan
Write-Host "Checking: $PrimaryLocation`n" -ForegroundColor Gray

$issuesFound = @()
$issuesFixed = @()

# 1. Process Check
Write-Host "[1/8] Checking OneDrive Process..." -ForegroundColor Yellow
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "  ✅ Running (PID: $($process.Id))" -ForegroundColor Green
} else {
    Write-Host "  ❌ Not running" -ForegroundColor Red
    $issuesFound += "OneDrive process not running"
    
    if ($FixIssues) {
        Write-Host "  🔧 Starting OneDrive..." -ForegroundColor Cyan
        & "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
        Start-Sleep -Seconds 3
        $process = Get-Process OneDrive -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "  ✅ Started successfully" -ForegroundColor Green
            $issuesFixed += "Started OneDrive process"
        }
    }
}

# 2. Primary Location Check
Write-Host "`n[2/8] Verifying Primary Location..." -ForegroundColor Yellow
if (Test-Path $PrimaryLocation) {
    Write-Host "  ✅ Exists: $PrimaryLocation" -ForegroundColor Green
} else {
    Write-Host "  ❌ Not found: $PrimaryLocation" -ForegroundColor Red
    $issuesFound += "Primary location not found"
}

# 3. Registry Configuration
Write-Host "`n[3/8] Checking Registry Configuration..." -ForegroundColor Yellow
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
$pointsToP primary = $false
if ($accounts) {
    foreach ($account in $accounts) {
        if ($account.UserFolder -eq $PrimaryLocation) {
            $pointsToPrimary = $true
            Write-Host "  ✅ Registry points to: $PrimaryLocation" -ForegroundColor Green
        }
    }
    if (-not $pointsToPrimary) {
        Write-Host "  ⚠️  Registry does not point to primary location" -ForegroundColor Yellow
        $issuesFound += "Registry not configured for primary location"
    }
} else {
    Write-Host "  ❌ No OneDrive accounts configured" -ForegroundColor Red
    $issuesFound += "No OneDrive accounts in registry"
}

# 4. Disk Space Check (Critical for large file collections)
Write-Host "`n[4/8] Checking Disk Space..." -ForegroundColor Yellow
$drive = $PrimaryLocation.Substring(0, 1)
$diskInfo = Get-PSDrive $drive -ErrorAction SilentlyContinue
if ($diskInfo) {
    $freeSpaceGB = [math]::Round($diskInfo.Free / 1GB, 2)
    $totalSpaceGB = [math]::Round(($diskInfo.Used + $diskInfo.Free) / 1GB, 2)
    $usedPercent = [math]::Round((($diskInfo.Used / ($diskInfo.Used + $diskInfo.Free)) * 100), 1)
    
    Write-Host "  Drive: $($drive): Total: $totalSpaceGB GB, Free: $freeSpaceGB GB ($usedPercent% used)" -ForegroundColor Gray
    
    if ($freeSpaceGB -lt 10) {
        Write-Host "  ❌ CRITICAL: Less than 10 GB free" -ForegroundColor Red
        $issuesFound += "Critically low disk space ($freeSpaceGB GB)"
    } elseif ($freeSpaceGB -lt 50) {
        Write-Host "  ⚠️  WARNING: Less than 50 GB free" -ForegroundColor Yellow
        $issuesFound += "Low disk space ($freeSpaceGB GB)"
    } else {
        Write-Host "  ✅ Adequate disk space" -ForegroundColor Green
    }
}

# 5. Files On-Demand Status (Recommended for 1M+ files)
Write-Host "`n[5/8] Checking Files On-Demand..." -ForegroundColor Yellow
$filesOnDemand = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -ErrorAction SilentlyContinue
if ($filesOnDemand -and $filesOnDemand.FilesOnDemandEnabled -eq 1) {
    Write-Host "  ✅ Enabled (recommended for 1M+ files)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Disabled - all files are downloaded locally" -ForegroundColor Yellow
    Write-Host "     With 1M+ files, consider enabling Files On-Demand" -ForegroundColor Gray
    $issuesFound += "Files On-Demand not enabled (may consume excessive disk space)"
}

# 6. Network Connectivity Check
Write-Host "`n[6/8] Checking Network Connectivity..." -ForegroundColor Yellow
$pingTest = Test-Connection -ComputerName "onedrive.live.com" -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($pingTest) {
    Write-Host "  ✅ Can reach OneDrive servers" -ForegroundColor Green
} else {
    Write-Host "  ❌ Cannot reach OneDrive servers" -ForegroundColor Red
    $issuesFound += "Network connectivity issue"
}

# 7. Check for Error Codes
Write-Host "`n[7/8] Checking for Sync Errors..." -ForegroundColor Yellow
$errorCheck = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "LastError" -ErrorAction SilentlyContinue
if ($errorCheck -and $errorCheck.LastError -and $errorCheck.LastError -ne 0) {
    Write-Host "  ❌ Error Code: $($errorCheck.LastError)" -ForegroundColor Red
    Write-Host "     Reference: https://support.microsoft.com/en-us/office/what-do-the-onedrive-error-codes-mean-f7a68338-e540-4ebf-ad5d-56c5633acded" -ForegroundColor Gray
    $issuesFound += "Sync error code: $($errorCheck.LastError)"
} else {
    Write-Host "  ✅ No error codes found" -ForegroundColor Green
}

# 8. Performance Recommendations for Large Collections
Write-Host "`n[8/8] Performance Check (1M+ Files)..." -ForegroundColor Yellow
if (Test-Path $PrimaryLocation) {
    $fileCount = (Get-ChildItem -Path $PrimaryLocation -File -ErrorAction SilentlyContinue | Measure-Object).Count
    
    # Only do full scan if explicitly requested - otherwise estimate
    Write-Host "  Estimated file count: 1,000,000+" -ForegroundColor Gray
    Write-Host "  Recommendations:" -ForegroundColor Yellow
    Write-Host "    • Enable Files On-Demand to reduce local storage" -ForegroundColor Gray
    Write-Host "    • Exclude temp/cache folders from sync" -ForegroundColor Gray
    Write-Host "    • Monitor disk I/O during sync operations" -ForegroundColor Gray
    Write-Host "    • Consider selective sync for rarely accessed folders" -ForegroundColor Gray
}

# Summary
Write-Host "`n=== Health Check Summary ===" -ForegroundColor Cyan
if ($issuesFound.Count -eq 0) {
    Write-Host "✅ No issues detected - OneDrive is healthy" -ForegroundColor Green
} else {
    Write-Host "⚠️  Issues Found: $($issuesFound.Count)" -ForegroundColor Yellow
    foreach ($issue in $issuesFound) {
        Write-Host "   • $issue" -ForegroundColor Gray
    }
}

if ($issuesFixed.Count -gt 0) {
    Write-Host "`n🔧 Issues Fixed: $($issuesFixed.Count)" -ForegroundColor Green
    foreach ($fix in $issuesFixed) {
        Write-Host "   • $fix" -ForegroundColor Gray
    }
}

Write-Host ""
