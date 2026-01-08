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
        Write-Information "[90m  [$Name] Path not found: $Path`e[0m"
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
        Write-Information "[32m  [$Name] Freed: $freed MB`e[0m"
    } else {
        Write-Information "[90m  [$Name] Already clean or in use`e[0m"
    }
    
    return $freed
}

Write-Information "[36m`n=== DISK CLEANUP ===`e[0m"
Write-Information "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$totalFreed = 0

# User Temp
Write-Information "[33mCleaning User Temp...`e[0m"
$totalFreed += Clear-FolderContent -Path $env:TEMP -Name "User Temp"

# Windows Temp
Write-Information "[33mCleaning Windows Temp...`e[0m"
$totalFreed += Clear-FolderContent -Path "$env:SystemRoot\Temp" -Name "Windows Temp"

# Prefetch (requires admin)
Write-Information "[33mCleaning Prefetch...`e[0m"
$totalFreed += Clear-FolderContent -Path "$env:SystemRoot\Prefetch" -Name "Prefetch"

# Windows Error Reports
Write-Information "[33mCleaning Error Reports...`e[0m"
$totalFreed += Clear-FolderContent -Path "$env:LOCALAPPDATA\Microsoft\Windows\WER" -Name "WER Local"
$totalFreed += Clear-FolderContent -Path "$env:ProgramData\Microsoft\Windows\WER" -Name "WER System"

# Delivery Optimization
Write-Information "[33mCleaning Delivery Optimization...`e[0m"
if ($PSCmdlet.ShouldProcess("Delivery Optimization Cache", "Clear")) {
    try {
        Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
        Write-Information "[32m  [Delivery Optimization] Cleared`e[0m"
    } catch {
        Write-Information "[90m  [Delivery Optimization] Could not clear (may require elevation)`e[0m"
    }
}

# Recycle Bin
Write-Information "[33mClearing Recycle Bin...`e[0m"
if ($PSCmdlet.ShouldProcess("Recycle Bin", "Clear")) {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Information "[32m  [Recycle Bin] Cleared`e[0m"
    } catch {
        Write-Information "[90m  [Recycle Bin] Already empty or error`e[0m"
    }
}

# Browser Caches
if ($IncludeBrowserCache) {
    Write-Information "[33m`nCleaning Browser Caches...`e[0m"
    
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
    Write-Information "[33m`nRunning Windows Update Cleanup (this may take a while)...`e[0m"
    
    if ($PSCmdlet.ShouldProcess("Component Store", "DISM Cleanup")) {
        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            Write-Information "[90m  Analyzing component store...`e[0m"
            Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>&1 | Out-Null
            
            Write-Information "[90m  Starting cleanup...`e[0m"
            Dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "[32m  [DISM] Cleanup completed successfully`e[0m"
            } else {
                Write-Information "[33m  [DISM] Cleanup completed with warnings`e[0m"
            }
        } else {
            Write-Information "[31m  [DISM] Requires administrator privileges - skipped`e[0m"
        }
    }
}

Write-Information "[36m`n=== CLEANUP SUMMARY ===`e[0m"
Write-Information "Total space freed: ~$totalFreed MB"
Write-Information "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

if (-not $IncludeBrowserCache) {
    Write-Information "[90mTip: Add -IncludeBrowserCache to also clear browser caches`e[0m"
}
if (-not $IncludeWindowsUpdate) {
    Write-Information "[90mTip: Add -IncludeWindowsUpdate for deeper cleanup (requires admin)`e[0m"
}
