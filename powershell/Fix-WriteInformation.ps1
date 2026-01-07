#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fixes all Write-Information -ForegroundColor usage across PowerShell scripts.

.DESCRIPTION
    Replaces invalid Write-Information -ForegroundColor calls with proper ANSI escape codes.
    Ensures $InformationPreference = 'Continue' is set at the start of each script.

.PARAMETER Path
    Root path to search for PowerShell scripts. Defaults to current directory.

.PARAMETER WhatIf
    Show what would be changed without making changes.

.EXAMPLE
    .\Fix-WriteInformation.ps1 -Path . -WhatIf
    .\Fix-WriteInformation.ps1 -Path .

.NOTES
    Author: Claude (GitHub Copilot)
    Version: 1.0.0
    Date: 2026-01-07
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Path = '.',
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$InformationPreference = 'Continue'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Color mapping: PowerShell color name -> ANSI escape code
$colorMap = @{
    'Black'       = "`e[30m"
    'DarkBlue'    = "`e[34m"
    'DarkGreen'   = "`e[32m"
    'DarkCyan'    = "`e[36m"
    'DarkRed'     = "`e[31m"
    'DarkMagenta' = "`e[35m"
    'DarkYellow'  = "`e[33m"
    'Gray'        = "`e[90m"
    'DarkGray'    = "`e[90m"
    'Blue'        = "`e[94m"
    'Green'       = "`e[32m"
    'Cyan'        = "`e[36m"
    'Red'         = "`e[31m"
    'Magenta'     = "`e[35m"
    'Yellow'      = "`e[33m"
    'White'       = "`e[97m"
}

function Test-HasInformationPreference {
    param([string]$Content)
    
    # Check if $InformationPreference = 'Continue' exists
    return $Content -match '\$InformationPreference\s*=\s*[''"]Continue[''"]'
}

function Add-InformationPreference {
    param([string]$Content)
    
    # Find the right place to insert $InformationPreference
    $lines = $Content -split "`r?`n"
    $insertIndex = 0
    
    # Skip shebang
    if ($lines[0] -match '^#!') {
        $insertIndex = 1
    }
    
    # Skip comment blocks
    $inCommentBlock = $false
    for ($i = $insertIndex; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        
        if ($line -match '^<#') {
            $inCommentBlock = $true
        }
        
        if ($inCommentBlock) {
            if ($line -match '#>$') {
                $inCommentBlock = $false
                $insertIndex = $i + 1
            }
            continue
        }
        
        # Skip single-line comments and empty lines
        if ($line -match '^#' -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        
        # If we find [CmdletBinding()] or param(), we should insert BEFORE it
        if ($line -match '^\[CmdletBinding\(' -or $line -match '^param\s*\(') {
            # Insert right here, before this line
            break
        }
        
        # If we find Set-StrictMode or $ErrorActionPreference, insert before it
        if ($line -match '^\$ErrorActionPreference' -or $line -match '^Set-StrictMode') {
            # Insert right here
            break
        }
        
        # If we hit Write-Information, we need to insert before it
        if ($line -match '^Write-Information') {
            # Insert right here
            break
        }
        
        $insertIndex = $i + 1
    }
    
    # Make sure we have a good place to insert
    if ($insertIndex -ge $lines.Count) {
        $insertIndex = $lines.Count
    }
    
    # Insert the line with proper blank line separation
    $newLines = @()
    if ($insertIndex -eq 0) {
        $newLines = @('$InformationPreference = ''Continue''', '') + $lines
    }
    else {
        $newLines = $lines[0..($insertIndex-1)]
        # Add blank line if previous line isn't blank
        if ($newLines[-1].Trim() -ne '') {
            $newLines += ''
        }
        $newLines += '$InformationPreference = ''Continue'''
        $newLines += ''
        if ($insertIndex -lt $lines.Count) {
            $newLines += $lines[$insertIndex..($lines.Count-1)]
        }
    }
    
    return $newLines -join "`n"
}

function Convert-WriteInformationLine {
    param([string]$Line)
    
    Write-Information "[97mtext`e[0m"
    # We need to extract everything between Write-Information and -ForegroundColor
    if ($Line -notmatch 'Write-Information\s+(.+)\s+-ForegroundColor\s+(\w+)') {
        return $Line
    }
    
    $message = $matches[1].Trim()
    $color = $matches[2]
    
    # Get ANSI code
    $ansiCode = $colorMap[$color]
    if (-not $ansiCode) {
        Write-Information "`e[33mWarning: Unknown color '$color', defaulting to white`e[0m"
        $ansiCode = "`e[97m"
    }
    
    $resetCode = '`e[0m'
    
    # Handle different message patterns
    if ($message -match '^"((?:[^"\\]|\\.)*)"\s*$') {
        # Double-quoted string
        $innerText = $matches[1]
        $newMessage = "`"$ansiCode$innerText$resetCode`""
    }
    elseif ($message -match "^'((?:[^'\\]|\\.)*)'\s*$") {
        # Single-quoted string
        $innerText = $matches[1]
        $newMessage = "`"$ansiCode$innerText$resetCode`""
    }
    elseif ($message -match '^\$\w+\s*$') {
        # Simple variable like $var
        $newMessage = "`"$ansiCode`${$message}$resetCode`""
    }
    elseif ($message -match '^\(') {
        # Expression like (-f ...) or (Get-Date)
        $newMessage = "`"$ansiCode`$($message)$resetCode`""
    }
    else {
        # Complex expression - wrap it
        $newMessage = "`"$ansiCode`$($message)$resetCode`""
    }
    
    # Build the new line preserving indentation
    $indent = ''
    if ($Line -match '^(\s*)') {
        $indent = $matches[1]
    }
    
    $newLine = "${indent}Write-Information $newMessage"
    return $newLine
}

# Main execution
Write-Information "`e[36m=== Write-Information Fixer ===`e[0m"
Write-Information ""

# Find all PowerShell scripts
Write-Information "`e[33mSearching for PowerShell scripts in: $Path`e[0m"
$scripts = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse -File

Write-Information "`e[90mFound $($scripts.Count) PowerShell scripts`e[0m"
Write-Information ""

$fixedCount = 0
$totalReplacements = 0
$filesWithIssues = 0

foreach ($script in $scripts) {
    Write-Information "`e[90mProcessing: $($script.FullName)`e[0m"
    
    $content = Get-Content -Path $script.FullName -Raw
    $originalContent = $content
    
    # Check if this script has Write-Information -ForegroundColor
    if ($content -notmatch 'Write-Information\s+.+?\s+-ForegroundColor') {
        Write-Information "  `e[90mNo fixes needed`e[0m"
        continue
    }
    
    $filesWithIssues++
    
    # Process line by line
    $lines = $content -split "`r?`n"
    $newLines = @()
    $replacements = 0
    
    foreach ($line in $lines) {
        if ($line -match 'Write-Information\s+.+?\s+-ForegroundColor') {
            $newLine = Convert-WriteInformationLine -Line $line
            $newLines += $newLine
            $replacements++
        }
        else {
            $newLines += $line
        }
    }
    
    $newContent = $newLines -join "`n"
    
    # Add $InformationPreference if missing
    if (-not (Test-HasInformationPreference -Content $newContent)) {
        Write-Information "  `e[33mAdding `$InformationPreference`e[0m"
        $newContent = Add-InformationPreference -Content $newContent
    }
    
    # Apply changes
    if ($newContent -ne $originalContent) {
        if ($WhatIf) {
            Write-Information "  `e[33m[WhatIf] Would fix $replacements instances`e[0m"
            $totalReplacements += $replacements
        }
        else {
            Set-Content -Path $script.FullName -Value $newContent -NoNewline
            Write-Information "  `e[32m✓ Fixed $replacements instances`e[0m"
            $fixedCount++
            $totalReplacements += $replacements
        }
    }
}

Write-Information ""
Write-Information "`e[36m=== Summary ===`e[0m"
Write-Information "`e[90mScripts scanned: $($scripts.Count)`e[0m"
Write-Information "`e[90mScripts with issues: $filesWithIssues`e[0m"
if ($WhatIf) {
    Write-Information "`e[33m[WhatIf Mode] Would fix $totalReplacements instances across $filesWithIssues files`e[0m"
}
else {
    Write-Information "`e[32m✓ Fixed $totalReplacements instances across $fixedCount files`e[0m"
}
Write-Information ""
