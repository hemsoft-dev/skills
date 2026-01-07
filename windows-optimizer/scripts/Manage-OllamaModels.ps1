<#
.SYNOPSIS
    Manages Ollama LLM models - list, analyze, and bulk remove.
.DESCRIPTION
    Lists Ollama models with sizes, identifies large models, and can remove all or selected models.
.PARAMETER Action
    List, RemoveAll, or RemoveOld
.PARAMETER OlderThanDays
    For RemoveOld action, remove models not modified in this many days (default: 90)
.EXAMPLE
    .\Manage-OllamaModels.ps1 -Action List
    .\Manage-OllamaModels.ps1 -Action RemoveAll
    .\Manage-OllamaModels.ps1 -Action RemoveOld -OlderThanDays 60
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('List', 'RemoveAll', 'RemoveOld')]
    [string]$Action,
    
    [int]$OlderThanDays = 90
)

$ErrorActionPreference = 'SilentlyContinue'

# Check if Ollama is installed
$ollamaPath = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $ollamaPath) {
    Write-Host "Ollama is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== OLLAMA MODEL MANAGER ===" -ForegroundColor Cyan

# Get current models
$modelOutput = ollama list 2>&1
$models = @()

foreach ($line in ($modelOutput -split "`n" | Select-Object -Skip 1)) {
    if ($line -match '^\s*(\S+)\s+(\S+)\s+(\S+\s*\S*)\s+(.+)$') {
        $name = $Matches[1]
        $size = $Matches[3]
        $modified = $Matches[4]
        
        # Parse size to GB
        $sizeGB = 0
        if ($size -match '(\d+\.?\d*)\s*GB') { $sizeGB = [double]$Matches[1] }
        elseif ($size -match '(\d+\.?\d*)\s*MB') { $sizeGB = [double]$Matches[1] / 1024 }
        
        $models += [PSCustomObject]@{
            Name = $name
            Size = $size
            SizeGB = $sizeGB
            Modified = $modified
        }
    }
}

if ($models.Count -eq 0) {
    Write-Host "No Ollama models found." -ForegroundColor Yellow
    
    # Check folder size anyway
    $folderSize = (Get-ChildItem "$env:USERPROFILE\.ollama" -Recurse -Force -EA SilentlyContinue | 
                   Measure-Object Length -Sum).Sum / 1GB
    if ($folderSize -gt 0.1) {
        Write-Host "However, .ollama folder is $([math]::Round($folderSize, 2)) GB" -ForegroundColor Yellow
        Write-Host "You may want to delete: $env:USERPROFILE\.ollama" -ForegroundColor Gray
    }
    exit 0
}

$totalSize = ($models | Measure-Object SizeGB -Sum).Sum

switch ($Action) {
    'List' {
        Write-Host "`nInstalled Models ($($models.Count)):`n" -ForegroundColor Yellow
        
        $models | Sort-Object SizeGB -Descending | ForEach-Object {
            $color = if ($_.SizeGB -gt 10) { "Red" } elseif ($_.SizeGB -gt 5) { "Yellow" } else { "White" }
            Write-Host ("  {0,-35} {1,10} {2}" -f $_.Name, $_.Size, $_.Modified) -ForegroundColor $color
        }
        
        Write-Host "`nTotal: $([math]::Round($totalSize, 1)) GB in $($models.Count) models" -ForegroundColor Cyan
        Write-Host "`nTip: Use -Action RemoveAll to delete all models" -ForegroundColor Gray
    }
    
    'RemoveAll' {
        Write-Host "`nRemoving all $($models.Count) models (~$([math]::Round($totalSize, 1)) GB)...`n" -ForegroundColor Yellow
        
        foreach ($model in $models) {
            Write-Host "  Removing $($model.Name)..." -NoNewline
            ollama rm $model.Name 2>&1 | Out-Null
            Write-Host " done" -ForegroundColor Green
        }
        
        Write-Host "`n✓ All models removed! ~$([math]::Round($totalSize, 1)) GB freed" -ForegroundColor Green
    }
    
    'RemoveOld' {
        Write-Host "`nLooking for models older than $OlderThanDays days...`n" -ForegroundColor Yellow
        
        $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
        $oldModels = @()
        
        foreach ($model in $models) {
            # Parse relative time (e.g., "5 months ago")
            $isOld = $false
            if ($model.Modified -match '(\d+)\s*month') { 
                $months = [int]$Matches[1]
                $isOld = $months * 30 -gt $OlderThanDays
            }
            elseif ($model.Modified -match '(\d+)\s*week') {
                $weeks = [int]$Matches[1]
                $isOld = $weeks * 7 -gt $OlderThanDays
            }
            elseif ($model.Modified -match '(\d+)\s*day') {
                $days = [int]$Matches[1]
                $isOld = $days -gt $OlderThanDays
            }
            
            if ($isOld) { $oldModels += $model }
        }
        
        if ($oldModels.Count -eq 0) {
            Write-Host "No models older than $OlderThanDays days found." -ForegroundColor Green
        } else {
            $oldSize = ($oldModels | Measure-Object SizeGB -Sum).Sum
            Write-Host "Found $($oldModels.Count) old models (~$([math]::Round($oldSize, 1)) GB):`n"
            
            foreach ($model in $oldModels) {
                Write-Host "  Removing $($model.Name) ($($model.Modified))..." -NoNewline
                ollama rm $model.Name 2>&1 | Out-Null
                Write-Host " done" -ForegroundColor Green
            }
            
            Write-Host "`n✓ Removed $($oldModels.Count) old models! ~$([math]::Round($oldSize, 1)) GB freed" -ForegroundColor Green
        }
    }
}

Write-Host ""
