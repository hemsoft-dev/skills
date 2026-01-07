<#
.SYNOPSIS
    Quick system tune-up - runs common maintenance tasks.
.DESCRIPTION
    Combines temp cleanup, cache clearing, and health check into one command.
.PARAMETER Full
    Run all cleanup tasks including browser caches
.PARAMETER CheckOnly
    Only analyze, don't clean anything
.EXAMPLE
    .\Invoke-QuickTuneup.ps1
    .\Invoke-QuickTuneup.ps1 -Full
    .\Invoke-QuickTuneup.ps1 -CheckOnly
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Information "`n" -NoNewline
Write-Information "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Information "║       QUICK SYSTEM TUNE-UP           ║" -ForegroundColor Cyan
Write-Information "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Information ""

$totalFreed = 0

# 1. Check for handle leaks
Write-Information "1. HANDLE LEAK CHECK" -ForegroundColor Yellow
$leaks = Get-Process | Where-Object { $_.Handles -gt 5000 } | Sort-Object Handles -Descending
if ($leaks) {
    Write-Information "   ⚠ Found processes with high handles:" -ForegroundColor Red
    $leaks | ForEach-Object {
        Write-Information "     $($_.Name): $($_.Handles) handles" -ForegroundColor Red
    }
    Write-Information "   Tip: Restart these apps to clear handle leaks" -ForegroundColor Gray
} else {
    Write-Information "   ✓ No handle leaks detected" -ForegroundColor Green
}

# 2. Memory check
Write-Information "`n2. MEMORY STATUS" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$memPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
$memGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)

$memColor = if ($memPct -gt 90) { "Red" } elseif ($memPct -gt 75) { "Yellow" } else { "Green" }
Write-Information "   RAM: $memGB GB / $totalGB GB ($memPct%)" -ForegroundColor $memColor

# 3. Temp files
Write-Information "`n3. TEMP FILES" -ForegroundColor Yellow
$tempSize = (Get-ChildItem $env:TEMP -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
$winTempSize = (Get-ChildItem "C:\Windows\Temp" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
$totalTemp = $tempSize + $winTempSize

Write-Information "   User Temp: $([math]::Round($tempSize, 0)) MB"
Write-Information "   Windows Temp: $([math]::Round($winTempSize, 0)) MB"

if (-not $CheckOnly -and $totalTemp -gt 100) {
    Remove-Item "$env:TEMP\*" -Recurse -Force -EA SilentlyContinue
    Remove-Item "C:\Windows\Temp\*" -Recurse -Force -EA SilentlyContinue
    Write-Information "   ✓ Cleaned ~$([math]::Round($totalTemp, 0)) MB" -ForegroundColor Green
    $totalFreed += $totalTemp
}

# 4. Dev caches (npm, nuget)
Write-Information "`n4. DEV CACHES" -ForegroundColor Yellow
$npmSize = (Get-ChildItem "$env:LOCALAPPDATA\npm-cache" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB
$nugetSize = (Get-ChildItem "$env:USERPROFILE\.nuget\packages" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB

if ($npmSize -gt 0.1) { Write-Information "   npm cache: $([math]::Round($npmSize, 2)) GB" }
if ($nugetSize -gt 0.1) { Write-Information "   NuGet cache: $([math]::Round($nugetSize, 2)) GB" }

if (-not $CheckOnly -and ($npmSize -gt 1 -or $nugetSize -gt 5)) {
    if ($npmSize -gt 1) {
        npm cache clean --force 2>&1 | Out-Null
        Write-Information "   ✓ npm cache cleaned" -ForegroundColor Green
        $totalFreed += $npmSize * 1024  # Convert to MB
    }
}

# 5. Browser caches (if Full)
if ($Full) {
    Write-Information "`n5. BROWSER CACHES" -ForegroundColor Yellow
    
    $edgeSize = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
    $chromeSize = (Get-ChildItem "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
    
    if ($edgeSize -gt 0) { Write-Information "   Edge cache: $([math]::Round($edgeSize, 0)) MB" }
    if ($chromeSize -gt 0) { Write-Information "   Chrome cache: $([math]::Round($chromeSize, 0)) MB" }
    
    if (-not $CheckOnly) {
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -EA SilentlyContinue
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*" -Recurse -Force -EA SilentlyContinue
        Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -EA SilentlyContinue
        Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*" -Recurse -Force -EA SilentlyContinue
        Write-Information "   ✓ Browser caches cleaned" -ForegroundColor Green
        $totalFreed += $edgeSize + $chromeSize
    }
}

# 6. Disk space
Write-Information "`n6. DISK SPACE" -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
    $pct = [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 0)
    $color = if ($pct -gt 90) { "Red" } elseif ($pct -gt 75) { "Yellow" } else { "Green" }
    Write-Information "   $($_.Name): $pct% used ($([math]::Round($_.Free/1GB, 0)) GB free)" -ForegroundColor $color
}

# Summary
Write-Information "`n" -NoNewline
Write-Information "════════════════════════════════════════" -ForegroundColor Cyan
if ($CheckOnly) {
    Write-Information "Analysis complete (no changes made)" -ForegroundColor Yellow
} else {
    Write-Information "✓ Tune-up complete! ~$([math]::Round($totalFreed, 0)) MB freed" -ForegroundColor Green
}
Write-Information ""
