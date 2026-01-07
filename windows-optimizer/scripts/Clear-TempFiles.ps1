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

function Clear-FolderContents {
    param(
        [string]$Path,
        [string]$Name
    )
    
    if (-not (Test-Path $Path)) {
        Write-Host "  [$Name] Path not found: $Path" -ForegroundColor Gray
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
        Write-Host "  [$Name] Freed: $freed MB" -ForegroundColor Green
    } else {
        Write-Host "  [$Name] Already clean or in use" -ForegroundColor Gray
    }
    
    return $freed
}

Write-Host "`n=== DISK CLEANUP ===" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$totalFreed = 0

# User Temp
Write-Host "Cleaning User Temp..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContents -Path $env:TEMP -Name "User Temp"

# Windows Temp
Write-Host "Cleaning Windows Temp..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContents -Path "$env:SystemRoot\Temp" -Name "Windows Temp"

# Prefetch (requires admin)
Write-Host "Cleaning Prefetch..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContents -Path "$env:SystemRoot\Prefetch" -Name "Prefetch"

# Windows Error Reports
Write-Host "Cleaning Error Reports..." -ForegroundColor Yellow
$totalFreed += Clear-FolderContents -Path "$env:LOCALAPPDATA\Microsoft\Windows\WER" -Name "WER Local"
$totalFreed += Clear-FolderContents -Path "$env:ProgramData\Microsoft\Windows\WER" -Name "WER System"

# Delivery Optimization
Write-Host "Cleaning Delivery Optimization..." -ForegroundColor Yellow
if ($PSCmdlet.ShouldProcess("Delivery Optimization Cache", "Clear")) {
    try {
        Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
        Write-Host "  [Delivery Optimization] Cleared" -ForegroundColor Green
    } catch {
        Write-Host "  [Delivery Optimization] Could not clear (may require elevation)" -ForegroundColor Gray
    }
}

# Recycle Bin
Write-Host "Clearing Recycle Bin..." -ForegroundColor Yellow
if ($PSCmdlet.ShouldProcess("Recycle Bin", "Clear")) {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host "  [Recycle Bin] Cleared" -ForegroundColor Green
    } catch {
        Write-Host "  [Recycle Bin] Already empty or error" -ForegroundColor Gray
    }
}

# Browser Caches
if ($IncludeBrowserCache) {
    Write-Host "`nCleaning Browser Caches..." -ForegroundColor Yellow
    
    # Edge
    $edgeCachePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
    )
    foreach ($path in $edgeCachePaths) {
        $totalFreed += Clear-FolderContents -Path $path -Name "Edge Cache"
    }
    
    # Chrome
    $chromeCachePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
    )
    foreach ($path in $chromeCachePaths) {
        $totalFreed += Clear-FolderContents -Path $path -Name "Chrome Cache"
    }
}

# Windows Update Cleanup (DISM)
if ($IncludeWindowsUpdate) {
    Write-Host "`nRunning Windows Update Cleanup (this may take a while)..." -ForegroundColor Yellow
    
    if ($PSCmdlet.ShouldProcess("Component Store", "DISM Cleanup")) {
        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            Write-Host "  Analyzing component store..." -ForegroundColor Gray
            $analyzeResult = Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>&1
            
            Write-Host "  Starting cleanup..." -ForegroundColor Gray
            $cleanupResult = Dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [DISM] Cleanup completed successfully" -ForegroundColor Green
            } else {
                Write-Host "  [DISM] Cleanup completed with warnings" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [DISM] Requires administrator privileges - skipped" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== CLEANUP SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total space freed: ~$totalFreed MB"
Write-Host "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

if (-not $IncludeBrowserCache) {
    Write-Host "Tip: Add -IncludeBrowserCache to also clear browser caches" -ForegroundColor Gray
}
if (-not $IncludeWindowsUpdate) {
    Write-Host "Tip: Add -IncludeWindowsUpdate for deeper cleanup (requires admin)" -ForegroundColor Gray
}
