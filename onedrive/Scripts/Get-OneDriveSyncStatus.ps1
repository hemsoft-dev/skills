# Get-OneDriveSyncStatus.ps1
# Comprehensive OneDrive sync status monitoring including backlog analysis

param(
    [string]$OneDrivePath = "D:\OneDrive",
    [switch]$IncludeBacklog,
    [switch]$Detailed
)

Write-Host "`n=== OneDrive Sync Status ===" -ForegroundColor Cyan
Write-Host "Monitoring: $OneDrivePath`n" -ForegroundColor Gray

# 1. Check OneDrive Process Status
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if (-not $process) {
    Write-Host "❌ OneDrive is not running" -ForegroundColor Red
    Write-Host "   Run Start-OneDriveProcess.ps1 to start it" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ OneDrive Running (PID: $($process.Id))" -ForegroundColor Green

# 2. Check Registry for Sync Status
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue

if ($accounts) {
    foreach ($account in $accounts) {
        $displayName = $account.DisplayName
        $folder = $account.UserFolder
        
        if ($folder -eq $OneDrivePath) {
            Write-Host "`n📁 Account: $displayName" -ForegroundColor Yellow
            Write-Host "   Folder: $folder" -ForegroundColor Gray
            
            # Check sync status from registry
            $accountPath = $account.PSPath
            
            # LastSyncTime
            $lastSync = Get-ItemProperty -Path $accountPath -Name "LastUpdateTime" -ErrorAction SilentlyContinue
            if ($lastSync) {
                $lastSyncTime = [DateTime]::FromFileTime($lastSync.LastUpdateTime)
                $timeSince = (Get-Date) - $lastSyncTime
                Write-Host "   Last Sync: $lastSyncTime ($([math]::Round($timeSince.TotalMinutes, 1)) min ago)" -ForegroundColor Gray
            }
            
            # Sync root ID (if available)
            $syncRootId = Get-ItemProperty -Path $accountPath -Name "ClientFirstSignInTimestamp" -ErrorAction SilentlyContinue
            if ($syncRootId) {
                Write-Host "   ✅ Sync configured" -ForegroundColor Green
            }
        }
    }
}

# 3. Check for Files On-Demand Status
Write-Host "`n📊 Files On-Demand:" -ForegroundColor Yellow
$filesOnDemand = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -ErrorAction SilentlyContinue
if ($filesOnDemand -and $filesOnDemand.FilesOnDemandEnabled -eq 1) {
    Write-Host "   ✅ Enabled (saves disk space)" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Disabled (all files downloaded)" -ForegroundColor Yellow
}

# 4. Check File Count and Backlog
if ($IncludeBacklog -and (Test-Path $OneDrivePath)) {
    Write-Host "`n📈 File Analysis:" -ForegroundColor Yellow
    Write-Host "   Scanning folder (this may take a while for 1M+ files)..." -ForegroundColor Gray
    
    # Count all files
    $allFiles = Get-ChildItem -Path $OneDrivePath -Recurse -File -ErrorAction SilentlyContinue
    $totalCount = ($allFiles | Measure-Object).Count
    Write-Host "   Total Files: $totalCount" -ForegroundColor Gray
    
    # Check for sync pending files (cloud state attributes)
    # State 0 = Not synced/online-only, 1 = Available locally, 8 = Locally available always
    $cloudFiles = $allFiles | Where-Object { 
        $_.Attributes -match "ReparsePoint" -or 
        $_.Length -eq 0 
    }
    $cloudOnlyCount = ($cloudFiles | Measure-Object).Count
    
    Write-Host "   Cloud-Only Files: $cloudOnlyCount" -ForegroundColor Gray
    Write-Host "   Local Files: $($totalCount - $cloudOnlyCount)" -ForegroundColor Gray
    
    # Calculate sync percentage
    if ($totalCount -gt 0) {
        $syncPercent = [math]::Round((($totalCount - $cloudOnlyCount) / $totalCount) * 100, 2)
        Write-Host "   Sync Progress: $syncPercent%" -ForegroundColor $(if ($syncPercent -gt 90) { "Green" } elseif ($syncPercent -gt 50) { "Yellow" } else { "Red" })
    }
}

# 5. Check for Common Issues
Write-Host "`n🔍 Issue Detection:" -ForegroundColor Yellow

# Check disk space
$drive = $OneDrivePath.Substring(0, 2)
$diskInfo = Get-PSDrive $drive.Substring(0, 1) -ErrorAction SilentlyContinue
if ($diskInfo) {
    $freeSpaceGB = [math]::Round($diskInfo.Free / 1GB, 2)
    $usedPercent = [math]::Round((($diskInfo.Used / ($diskInfo.Used + $diskInfo.Free)) * 100), 1)
    
    if ($freeSpaceGB -lt 10) {
        Write-Host "   ⚠️  Low disk space: $freeSpaceGB GB free ($usedPercent% used)" -ForegroundColor Red
    } elseif ($freeSpaceGB -lt 50) {
        Write-Host "   ⚠️  Disk space: $freeSpaceGB GB free ($usedPercent% used)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Disk space: $freeSpaceGB GB free ($usedPercent% used)" -ForegroundColor Green
    }
}

# Check for OneDrive errors in registry
$errors = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "LastError" -ErrorAction SilentlyContinue
if ($errors -and $errors.LastError) {
    Write-Host "   ❌ Last Error Code: $($errors.LastError)" -ForegroundColor Red
    Write-Host "      See: https://support.microsoft.com/en-us/office/what-do-the-onedrive-error-codes-mean-f7a68338-e540-4ebf-ad5d-56c5633acded" -ForegroundColor Gray
} else {
    Write-Host "   ✅ No errors detected" -ForegroundColor Green
}

# 6. Detailed Information
if ($Detailed) {
    Write-Host "`n📋 Detailed Configuration:" -ForegroundColor Yellow
    
    # Show all registry settings
    $oneDriveSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -ErrorAction SilentlyContinue
    if ($oneDriveSettings) {
        $oneDriveSettings.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
            Write-Host "   $($_.Name): $($_.Value)" -ForegroundColor Gray
        }
    }
}

Write-Host ""
