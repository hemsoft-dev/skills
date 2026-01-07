<#
.SYNOPSIS
    Cleans temporary files, caches, and Windows update leftovers.
.DESCRIPTION
    Safely removes temporary files from common locations to free disk space.
    Includes Windows temp, user temp, browser caches, and optional Windows Update cleanup.
.PARAMETER IncludeBrowserCache
    Also clear Edge and Chrome browser caches
.PARAMETER IncludeWindowsUpdate
    Run DISM cleanup (requires elevation, takes longer)
.PARAMETER WhatIf
    Show what would be deleted without actually deleting
.EXAMPLE
    .\Clear-TempFiles.ps1
    .\Clear-TempFiles.ps1 -IncludeBrowserCache
    .\Clear-TempFiles.ps1 -IncludeWindowsUpdate
    .\Clear-TempFiles.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$IncludeBrowserCache,
    [switch]$IncludeWindowsUpdate
)

$InformationPreference = 'Continue'

$ErrorActionPreference = 'SilentlyContinue'

function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($size / 1MB, 2)
    }
    return 0
}

function Clear-FolderContent {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,
        [string]$Name
    )
    
    if (-not (Test-Path $Path)) {
        Write-Information "  [$Name] Path not found: $Path" -ForegroundColor Gray
        return 0
    }
    
    $beforeSize = Get-FolderSize $Path
    
    if ($PSCmdlet.ShouldProcess($Path, "Clear contents")) {
        Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    $afterSize = Get-FolderSize $Path
    $freed = $beforeSize - $afterSize
    
    if ($freed -gt 0) {
        Write-Information "  [$Name] Freed: $freed MB" -ForegroundColor Green
    } else {
        Write-Information "  [$Name] Already clean or in use" -ForegroundColor Gray
    }
    
    return $freed
}

Write-Information "`n=== DISK CLEANUP ===" -ForegroundColor Cyan
Write-Information "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$totalFreed = 0

# User Temp
Write-Information "Cleaning User Temp..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContent -Path $env:TEMP -Name "User Temp"

# Windows Temp
Write-Information "Cleaning Windows Temp..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContent -Path "$env:SystemRoot\Temp" -Name "Windows Temp"

# Prefetch (requires admin)
Write-Information "Cleaning Prefetch..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContent -Path "$env:SystemRoot\Prefetch" -Name "Prefetch"

# Windows Error Reports
Write-Information "Cleaning Error Reports..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContent -Path "$env:LOCALAPPDATA\Microsoft\Windows\WER" -Name "WER Local"
$totalFreed += Clear-FolderContent -Path "$env:ProgramData\Microsoft\Windows\WER" -Name "WER System"

# Delivery Optimization
Write-Information "Cleaning Delivery Optimization..." -ForegroundColor Yellow
if ($PSCmdlet.ShouldProcess("Delivery Optimization Cache", "Clear")) {
    try {
        Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
        Write-Information "  [Delivery Optimization] Cleared" -ForegroundColor Green
    } catch {
        Write-Information "  [Delivery Optimization] Could not clear (may require elevation)" -ForegroundColor Gray
    }
}

# Recycle Bin
Write-Information "Clearing Recycle Bin..." -ForegroundColor Yellow
if ($PSCmdlet.ShouldProcess("Recycle Bin", "Clear")) {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Information "  [Recycle Bin] Cleared" -ForegroundColor Green
    } catch {
        Write-Information "  [Recycle Bin] Already empty or error" -ForegroundColor Gray
    }
}

# Browser Caches
if ($IncludeBrowserCache) {
    Write-Information "`nCleaning Browser Caches..." -ForegroundColor Yellow
    
    # Edge
    $edgeCachePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
    )
    foreach ($path in $edgeCachePaths) {
        $totalFreed += Clear-FolderContent -Path $path -Name "Edge Cache"
    }
    
    # Chrome
    $chromeCachePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
    )
    foreach ($path in $chromeCachePaths) {
        $totalFreed += Clear-FolderContent -Path $path -Name "Chrome Cache"
    }
}

# Windows Update Cleanup (DISM)
if ($IncludeWindowsUpdate) {
    Write-Information "`nRunning Windows Update Cleanup (this may take a while)..." -ForegroundColor Yellow
    
    if ($PSCmdlet.ShouldProcess("Component Store", "DISM Cleanup")) {
        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            Write-Information "  Analyzing component store..." -ForegroundColor Gray
            Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>&1 | Out-Null
            
            Write-Information "  Starting cleanup..." -ForegroundColor Gray
            Dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "  [DISM] Cleanup completed successfully" -ForegroundColor Green
            } else {
                Write-Information "  [DISM] Cleanup completed with warnings" -ForegroundColor Yellow
            }
        } else {
            Write-Information "  [DISM] Requires administrator privileges - skipped" -ForegroundColor Red
        }
    }
}

Write-Information "`n=== CLEANUP SUMMARY ===" -ForegroundColor Cyan
Write-Information "Total space freed: ~$totalFreed MB"
Write-Information "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

if (-not $IncludeBrowserCache) {
    Write-Information "Tip: Add -IncludeBrowserCache to also clear browser caches" -ForegroundColor Gray
}
if (-not $IncludeWindowsUpdate) {
    Write-Information "Tip: Add -IncludeWindowsUpdate for deeper cleanup (requires admin)" -ForegroundColor Gray
}
