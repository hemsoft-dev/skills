#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fixes misplaced $InformationPreference = 'Continue' statements in PowerShell scripts.

.DESCRIPTION
    Removes $InformationPreference from incorrect locations and places it correctly
    after the param block and before Set-StrictMode.

.PARAMETER Path
    Root path to search for PowerShell scripts.

.EXAMPLE
    .\Fix-InformationPreferencePlacement.ps1 -Path .
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Path = '.'
)

$InformationPreference = 'Continue'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Information "`e[36m=== $InformationPreference Placement Fixer ===`e[0m"
Write-Information ""

$scripts = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse -File
Write-Information "`e[90mFound $($scripts.Count) PowerShell scripts`e[0m"
Write-Information ""

$fixedCount = 0

foreach ($script in $scripts) {
    $content = Get-Content -Path $script.FullName -Raw
    
    # Check if file has $InformationPreference
    if ($content -notmatch '\$InformationPreference\s*=\s*[''"]Continue[''"]') {
        continue
    }
    
    # Split into lines
    $lines = $content -split "`r?`n"
    
    # Remove ALL $InformationPreference lines
    $cleanedLines = $lines | Where-Object { $_ -notmatch '^\s*\$InformationPreference\s*=\s*[''"]Continue[''"]' }
    
    # Find correct insertion point
    $insertIndex = -1
    $inCommentBlock = $false
    $inParamBlock = $false
    
    for ($i = 0; $i -lt $cleanedLines.Count; $i++) {
        $line = $cleanedLines[$i].Trim()
        
        # Skip shebang
        if ($i -eq 0 -and $line -match '^#!') {
            continue
        }
        
        # Track comment blocks
        if ($line -match '^<#') {
            $inCommentBlock = $true
            continue
        }
        if ($inCommentBlock -and $line -match '#>$') {
            $inCommentBlock = $false
            continue
        }
        if ($inCommentBlock) {
            continue
        }
        
        # Track param blocks
        if ($line -match '^\[CmdletBinding') {
            $inParamBlock = $true
            continue
        }
        if ($inParamBlock) {
            if ($line -match '^\)$') {
                # End of param block - insert after this
                $insertIndex = $i + 1
                break
            }
            continue
        }
        
        # If we find Set-StrictMode before anything else, insert before it
        if ($line -match '^Set-StrictMode') {
            $insertIndex = $i
            break
        }
        
        # If we find $ErrorActionPreference, insert before it
        if ($line -match '^\$ErrorActionPreference') {
            $insertIndex = $i
            break
        }
    }
    
    # If we didn't find a good spot, skip this file
    if ($insertIndex -eq -1) {
        Write-Information "`e[33m[SKIP] $($script.Name) - couldn't determine correct placement`e[0m"
        continue
    }
    
    # Insert $InformationPreference at the correct location
    $newLines = @()
    for ($i = 0; $i -lt $cleanedLines.Count; $i++) {
        if ($i -eq $insertIndex) {
            # Add blank line if previous line isn't blank
            if ($i -gt 0 -and $cleanedLines[$i-1].Trim() -ne '') {
                $newLines += ''
            }
            $newLines += '$InformationPreference = ''Continue'''
            # Only add blank line after if next line exists and isn't blank
            if ($i -lt $cleanedLines.Count -and $cleanedLines[$i].Trim() -ne '') {
                $newLines += ''
            }
        }
        $newLines += $cleanedLines[$i]
    }
    
    $newContent = $newLines -join "`n"
    
    if ($newContent -ne $content) {
        Set-Content -Path $script.FullName -Value $newContent -NoNewline
        Write-Information "`e[32m✓ Fixed: $($script.Name)`e[0m"
        $fixedCount++
    }
}

Write-Information ""
Write-Information "`e[36m=== Summary ===`e[0m"
Write-Information "`e[32m✓ Fixed $fixedCount files`e[0m"
Write-Information ""
