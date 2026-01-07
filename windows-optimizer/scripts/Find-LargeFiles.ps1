<#
.SYNOPSIS
    Finds large files consuming disk space.
.DESCRIPTION
    Scans specified drives or directories for large files and reports them sorted by size.
.PARAMETER Path
    Path to scan (default: C:\)
.PARAMETER MinSizeMB
    Minimum file size in MB to report (default: 100)
.PARAMETER Top
    Number of results to show (default: 50)
.PARAMETER ExcludeSystem
    Exclude Windows and Program Files directories
.EXAMPLE
    .\Find-LargeFiles.ps1
    .\Find-LargeFiles.ps1 -Path D:\ -MinSizeMB 500
    .\Find-LargeFiles.ps1 -Path C:\Users -Top 20
#>
[CmdletBinding()]
param(
    [string]$Path = "C:\",
    [int]$MinSizeMB = 100,
    [int]$Top = 50,
    [switch]$ExcludeSystem
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== LARGE FILE SCANNER ===" -ForegroundColor Cyan
Write-Host "Path: $Path"
Write-Host "Minimum Size: $MinSizeMB MB"
Write-Host "Scanning... (this may take a while)`n"

$minBytes = $MinSizeMB * 1MB

$excludePaths = @()
if ($ExcludeSystem) {
    $excludePaths = @(
        "$env:SystemRoot",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:ProgramData"
    )
    Write-Host "Excluding system directories" -ForegroundColor Gray
}

$files = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { 
        $_.Length -ge $minBytes -and
        (-not $ExcludeSystem -or ($excludePaths | ForEach-Object { $_.FullName -notlike "$_*" }) -notcontains $false)
    } |
    Sort-Object Length -Descending |
    Select-Object -First $Top

if ($files.Count -eq 0) {
    Write-Host "No files found larger than $MinSizeMB MB" -ForegroundColor Yellow
    return
}

Write-Host "TOP $($files.Count) LARGEST FILES:" -ForegroundColor Yellow
Write-Host ("-" * 80)
Write-Host ("{0,-12} {1,-20} {2}" -f "SIZE", "MODIFIED", "PATH") -ForegroundColor Gray
Write-Host ("-" * 80)

$totalSize = 0
foreach ($file in $files) {
    $sizeMB = [math]::Round($file.Length / 1MB, 0)
    $sizeGB = [math]::Round($file.Length / 1GB, 2)
    $totalSize += $file.Length
    
    $sizeStr = if ($sizeGB -ge 1) { "$sizeGB GB" } else { "$sizeMB MB" }
    $dateStr = $file.LastWriteTime.ToString("yyyy-MM-dd")
    
    $color = if ($sizeGB -ge 10) { "Red" } 
             elseif ($sizeGB -ge 1) { "Yellow" } 
             else { "White" }
    
    Write-Host ("{0,-12} {1,-20} {2}" -f $sizeStr, $dateStr, $file.FullName) -ForegroundColor $color
}

$totalGB = [math]::Round($totalSize / 1GB, 2)
Write-Host ("-" * 80)
Write-Host "Total: $totalGB GB in $($files.Count) files`n" -ForegroundColor Cyan

# Category breakdown
Write-Host "BY FILE TYPE:" -ForegroundColor Yellow
$files | Group-Object Extension | 
    Select-Object @{N='Extension';E={if($_.Name){"$($_.Name)"} else {"(none)"}}}, 
                  Count, 
                  @{N='TotalGB';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum/1GB, 2)}} |
    Sort-Object TotalGB -Descending |
    Format-Table -AutoSize

# Common cleanup candidates
Write-Host "COMMON CLEANUP CANDIDATES:" -ForegroundColor Yellow
$candidates = @(
    @{ Pattern = "*.iso"; Desc = "ISO Images" },
    @{ Pattern = "*.vhdx"; Desc = "Virtual Disks" },
    @{ Pattern = "*.zip"; Desc = "ZIP Archives" },
    @{ Pattern = "*.log"; Desc = "Log Files" },
    @{ Pattern = "*.tmp"; Desc = "Temp Files" },
    @{ Pattern = "*.bak"; Desc = "Backup Files" },
    @{ Pattern = "*.old"; Desc = "Old Files" }
)

foreach ($candidate in $candidates) {
    $matches = $files | Where-Object { $_.Name -like $candidate.Pattern }
    if ($matches) {
        $size = [math]::Round(($matches | Measure-Object Length -Sum).Sum / 1GB, 2)
        Write-Host "  $($candidate.Desc): $($matches.Count) files, $size GB" -ForegroundColor Gray
    }
}

Write-Host ""
