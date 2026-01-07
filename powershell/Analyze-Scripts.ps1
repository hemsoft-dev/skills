$InformationPreference = 'Continue'

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
    Write-Information "📦 Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    Write-Information "✅ PSScriptAnalyzer installed" -ForegroundColor Green
    Write-Information ""
}

Write-Information "========================================" -ForegroundColor Cyan
Write-Information "PowerShell Script Analysis" -ForegroundColor Cyan
Write-Information "========================================" -ForegroundColor Cyan
Write-Information ""
Write-Information "Path:     $Path" -ForegroundColor Gray
Write-Information "Severity: $($Severity -join ', ')" -ForegroundColor Gray
if ($ExcludeRule) {
    Write-Information "Excluded: $($ExcludeRule -join ', ')" -ForegroundColor Gray
}
if ($Fix) {
    Write-Information "Mode:     Auto-fix enabled" -ForegroundColor Yellow
}
Write-Information ""

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

Write-Information "🔍 Analyzing PowerShell scripts..." -ForegroundColor Yellow
$results = Invoke-ScriptAnalyzer @analyzeParams

if ($results) {
    Write-Information ""
    Write-Information "Found $($results.Count) issue(s):" -ForegroundColor Yellow
    Write-Information ""
    
    # Group by severity
    $grouped = $results | Group-Object Severity | Sort-Object Name
    foreach ($group in $grouped) {
        $color = switch ($group.Name) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            default { 'White' }
        }
        Write-Information "  $($group.Name): $($group.Count)" -ForegroundColor $color
    }
    Write-Information ""
    
    # Group by file
    $byFile = $results | Group-Object ScriptName
    foreach ($fileGroup in $byFile) {
        Write-Information "📄 $($fileGroup.Name)" -ForegroundColor Cyan
        
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
            
            Write-Information "  $severityIcon Line $($issue.Line): $($issue.RuleName)" -ForegroundColor $color
            Write-Information "     $($issue.Message)" -ForegroundColor Gray
        }
        Write-Information ""
    }
    
    # Summary
    Write-Information "========================================" -ForegroundColor Cyan
    $errorCount = ($results | Where-Object Severity -eq 'Error').Count
    $warningCount = ($results | Where-Object Severity -eq 'Warning').Count
    
    if ($errorCount -gt 0) {
        Write-Information "❌ Analysis failed with $errorCount error(s) and $warningCount warning(s)" -ForegroundColor Red
        exit 1
    } else {
        Write-Information "⚠️  Analysis completed with $warningCount warning(s)" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Information "========================================" -ForegroundColor Cyan
    Write-Information "✅ No issues found!" -ForegroundColor Green
    Write-Information "========================================" -ForegroundColor Cyan
    exit 0
}
