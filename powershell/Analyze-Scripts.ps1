#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analyzes all PowerShell scripts in a directory.

.DESCRIPTION
    Uses PSScriptAnalyzer to check PowerShell scripts for errors, warnings,
    and best practice violations.

.PARAMETER Path
    The path to analyze. Defaults to current directory.

.PARAMETER Severity
    The severity levels to include. Defaults to Error and Warning.

.PARAMETER ExcludeRule
    Rules to exclude from analysis.

.PARAMETER Fix
    Automatically fix issues where possible.

.EXAMPLE
    .\Analyze-Scripts.ps1 -Path . -Severity Error,Warning

.EXAMPLE
    .\Analyze-Scripts.ps1 -Path D:\projects\myapp -Fix

.EXAMPLE
    .\Analyze-Scripts.ps1 -ExcludeRule PSAvoidUsingWriteHost
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Path = '.',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string[]]$Severity = @('Error', 'Warning'),
    
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeRule = @(),
    
    [Parameter(Mandatory=$false)]
    [switch]$Fix
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure PSScriptAnalyzer is installed
if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
    Write-Host "📦 Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    Write-Host "✅ PSScriptAnalyzer installed" -ForegroundColor Green
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PowerShell Script Analysis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Path:     $Path" -ForegroundColor Gray
Write-Host "Severity: $($Severity -join ', ')" -ForegroundColor Gray
if ($ExcludeRule) {
    Write-Host "Excluded: $($ExcludeRule -join ', ')" -ForegroundColor Gray
}
if ($Fix) {
    Write-Host "Mode:     Auto-fix enabled" -ForegroundColor Yellow
}
Write-Host ""

$analyzeParams = @{
    Path = $Path
    Recurse = $true
    Severity = $Severity
}

if ($ExcludeRule) {
    $analyzeParams['ExcludeRule'] = $ExcludeRule
}

if ($Fix) {
    $analyzeParams['Fix'] = $true
}

Write-Host "🔍 Analyzing PowerShell scripts..." -ForegroundColor Yellow
$results = Invoke-ScriptAnalyzer @analyzeParams

if ($results) {
    Write-Host ""
    Write-Host "Found $($results.Count) issue(s):" -ForegroundColor Yellow
    Write-Host ""
    
    # Group by severity
    $grouped = $results | Group-Object Severity | Sort-Object Name
    foreach ($group in $grouped) {
        $color = switch ($group.Name) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            default { 'White' }
        }
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor $color
    }
    Write-Host ""
    
    # Group by file
    $byFile = $results | Group-Object ScriptName
    foreach ($fileGroup in $byFile) {
        Write-Host "📄 $($fileGroup.Name)" -ForegroundColor Cyan
        
        foreach ($issue in $fileGroup.Group | Sort-Object Line) {
            $severityIcon = switch ($issue.Severity) {
                'Error' { '❌' }
                'Warning' { '⚠️ ' }
                default { 'ℹ️ ' }
            }
            
            $color = switch ($issue.Severity) {
                'Error' { 'Red' }
                'Warning' { 'Yellow' }
                default { 'White' }
            }
            
            Write-Host "  $severityIcon Line $($issue.Line): $($issue.RuleName)" -ForegroundColor $color
            Write-Host "     $($issue.Message)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Summary
    Write-Host "========================================" -ForegroundColor Cyan
    $errorCount = ($results | Where-Object Severity -eq 'Error').Count
    $warningCount = ($results | Where-Object Severity -eq 'Warning').Count
    
    if ($errorCount -gt 0) {
        Write-Host "❌ Analysis failed with $errorCount error(s) and $warningCount warning(s)" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "⚠️  Analysis completed with $warningCount warning(s)" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ No issues found!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    exit 0
}
