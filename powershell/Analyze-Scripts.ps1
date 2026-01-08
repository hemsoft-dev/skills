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

$InformationPreference = 'Continue'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure PSScriptAnalyzer is installed
if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
    Write-Information "[33m📦 Installing PSScriptAnalyzer...`e[0m"
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    Write-Information "[32m✅ PSScriptAnalyzer installed`e[0m"
    Write-Information ""
}

Write-Information "[36m========================================`e[0m"
Write-Information "[36mPowerShell Script Analysis`e[0m"
Write-Information "[36m========================================`e[0m"
Write-Information ""
Write-Information "[90mPath:     $Path`e[0m"
Write-Information "[90mSeverity: $($Severity -join ', ')`e[0m"
if ($ExcludeRule) {
    Write-Information "[90mExcluded: $($ExcludeRule -join ', ')`e[0m"
}
if ($Fix) {
    Write-Information "[33mMode:     Auto-fix enabled`e[0m"
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

Write-Information "[33m🔍 Analyzing PowerShell scripts...`e[0m"
$results = Invoke-ScriptAnalyzer @analyzeParams

if ($results) {
    Write-Information ""
    Write-Information "[33mFound $($results.Count) issue(s):`e[0m"
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
        Write-Information "[36m📄 $($fileGroup.Name)`e[0m"
        
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
            Write-Information "[90m     $($issue.Message)`e[0m"
        }
        Write-Information ""
    }
    
    # Summary
    Write-Information "[36m========================================`e[0m"
    $errorCount = ($results | Where-Object Severity -eq 'Error').Count
    $warningCount = ($results | Where-Object Severity -eq 'Warning').Count
    
    if ($errorCount -gt 0) {
        Write-Information "[31m❌ Analysis failed with $errorCount error(s) and $warningCount warning(s)`e[0m"
        exit 1
    } else {
        Write-Information "[33m⚠️  Analysis completed with $warningCount warning(s)`e[0m"
        exit 0
    }
} else {
    Write-Information "[36m========================================`e[0m"
    Write-Information "[32m✅ No issues found!`e[0m"
    Write-Information "[36m========================================`e[0m"
    exit 0
}
