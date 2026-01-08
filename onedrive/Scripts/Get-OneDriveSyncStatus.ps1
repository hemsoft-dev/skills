$InformationPreference = 'Continue'

# Get-OneDriveSyncStatus.ps1
# Comprehensive OneDrive sync status monitoring including backlog analysis

param(
    [string]$OneDrivePath = "D:\OneDrive",
    [switch]$IncludeBacklog,
    [switch]$Detailed
)

Write-Information "[36m`n=== OneDrive Sync Status ===`e[0m"
Write-Information "[90mMonitoring: $OneDrivePath`n`e[0m"

# 1. Check OneDrive Process Status
$process = Get-Process OneDrive -ErrorAction SilentlyContinue
if (-not $process) {
    Write-Information "[31m❌ OneDrive is not running`e[0m"
    Write-Information "[90m   Run Start-OneDriveProcess.ps1 to start it`e[0m"
    exit 1
}

Write-Information "[32m✅ OneDrive Running (PID: $($process.Id))`e[0m"

# 2. Check Registry for Sync Status
$accounts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue

if ($accounts) {
    foreach ($account in $accounts) {
        $displayName = $account.DisplayName
        $folder = $account.UserFolder
        
        if ($folder -eq $OneDrivePath) {
            Write-Information "[33m`n📁 Account: $displayName`e[0m"
            Write-Information "[90m   Folder: $folder`e[0m"
            
            # Check sync status from registry
            $accountPath = $account.PSPath
            
            # LastSyncTime
            $lastSync = Get-ItemProperty -Path $accountPath -Name "LastUpdateTime" -ErrorAction SilentlyContinue
            if ($lastSync) {
                $lastSyncTime = [DateTime]::FromFileTime($lastSync.LastUpdateTime)
                $timeSince = (Get-Date) - $lastSyncTime
                Write-Information "[90m   Last Sync: $lastSyncTime ($([math]::Round($timeSince.TotalMinutes, 1)) min ago)`e[0m"
            }
            
            # Sync root ID (if available)
            $syncRootId = Get-ItemProperty -Path $accountPath -Name "ClientFirstSignInTimestamp" -ErrorAction SilentlyContinue
            if ($syncRootId) {
                Write-Information "[32m   ✅ Sync configured`e[0m"
            }
        }
    }
}

# 3. Check for Files On-Demand Status
Write-Information "[33m`n📊 Files On-Demand:`e[0m"
$filesOnDemand = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -ErrorAction SilentlyContinue
if ($filesOnDemand -and $filesOnDemand.FilesOnDemandEnabled -eq 1) {
    Write-Information "[32m   ✅ Enabled (saves disk space)`e[0m"
} else {
    Write-Information "[33m   ⚠️  Disabled (all files downloaded)`e[0m"
}

# 4. Check File Count and Backlog
if ($IncludeBacklog -and (Test-Path $OneDrivePath)) {
    Write-Information "[33m`n📈 File Analysis:`e[0m"
    Write-Information "[90m   Scanning folder (this may take a while for 1M+ files)...`e[0m"
    
    # Count all files
    $allFiles = Get-ChildItem -Path $OneDrivePath -Recurse -File -ErrorAction SilentlyContinue
    $totalCount = ($allFiles | Measure-Object).Count
    Write-Information "[90m   Total Files: $totalCount`e[0m"
    
    # Check for sync pending files (cloud state attributes)
    # State 0 = Not synced/online-only, 1 = Available locally, 8 = Locally available always
    $cloudFiles = $allFiles | Where-Object { 
        $_.Attributes -match "ReparsePoint" -or 
        $_.Length -eq 0 
    }
    $cloudOnlyCount = ($cloudFiles | Measure-Object).Count
    
    Write-Information "[90m   Cloud-Only Files: $cloudOnlyCount`e[0m"
    Write-Information "[90m   Local Files: $($totalCount - $cloudOnlyCount)`e[0m"
    
    # Calculate sync percentage
    if ($totalCount -gt 0) {
        $syncPercent = [math]::Round((($totalCount - $cloudOnlyCount) / $totalCount) * 100, 2)
        Write-Information "   Sync Progress: $syncPercent%" -ForegroundColor $(if ($syncPercent -gt 90) { "Green" } elseif ($syncPercent -gt 50) { "Yellow" } else { "Red" })
    }
}

# 5. Check for Common Issues
Write-Information "[33m`n🔍 Issue Detection:`e[0m"

# Check disk space
$drive = $OneDrivePath.Substring(0, 2)
$diskInfo = Get-PSDrive $drive.Substring(0, 1) -ErrorAction SilentlyContinue
if ($diskInfo) {
    $freeSpaceGB = [math]::Round($diskInfo.Free / 1GB, 2)
    $usedPercent = [math]::Round((($diskInfo.Used / ($diskInfo.Used + $diskInfo.Free)) * 100), 1)
    
    if ($freeSpaceGB -lt 10) {
        Write-Information "[31m   ⚠️  Low disk space: $freeSpaceGB GB free ($usedPercent% used)`e[0m"
    } elseif ($freeSpaceGB -lt 50) {
        Write-Information "[33m   ⚠️  Disk space: $freeSpaceGB GB free ($usedPercent% used)`e[0m"
    } else {
        Write-Information "[32m   ✅ Disk space: $freeSpaceGB GB free ($usedPercent% used)`e[0m"
    }
}

# Check for OneDrive errors in registry
$errors = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "LastError" -ErrorAction SilentlyContinue
if ($errors -and $errors.LastError) {
    Write-Information "[31m   ❌ Last Error Code: $($errors.LastError)`e[0m"
    Write-Information "[90m      See: https://support.microsoft.com/en-us/office/what-do-the-onedrive-error-codes-mean-f7a68338-e540-4ebf-ad5d-56c5633acded`e[0m"
} else {
    Write-Information "[32m   ✅ No errors detected`e[0m"
}

# 6. Detailed Information
if ($Detailed) {
    Write-Information "[33m`n📋 Detailed Configuration:`e[0m"
    
    # Show all registry settings
    $oneDriveSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -ErrorAction SilentlyContinue
    if ($oneDriveSettings) {
        $oneDriveSettings.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
            Write-Information "[90m   $($_.Name): $($_.Value)`e[0m"
        }
    }
}

Write-Information ""
