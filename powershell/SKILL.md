---
name: powershell
description: V1.1 - Expert in PowerShell scripting, PSScriptAnalyzer linting, profile management, PATH optimization, environment variables, and troubleshooting on Windows.
---

# PowerShell Expert

Expert guidance for PowerShell scripting, code analysis, profiles, PATH management, and troubleshooting.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## PSScriptAnalyzer - PowerShell Linter

### ⚠️ CRITICAL: NO SUPPRESSIONS WITHOUT USER APPROVAL

**NEVER add suppression attributes without explicit user consultation first.**

When PSScriptAnalyzer finds issues:
1. **STOP and present findings to the user**
2. **Explain the impact** of each rule violation
3. **Propose solutions** (fix the code vs. suppress the warning)
4. **Wait for user decision** before proceeding

Suppression attributes like `[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]` hide warnings and should only be used when:
- The user explicitly approves it
- There's a valid reason the rule doesn't apply
- Fixing the issue would break legitimate functionality

**Default approach: FIX the code, don't suppress the warning.**

### What is PSScriptAnalyzer?

**PSScriptAnalyzer** is the official PowerShell linter and static code analyzer that checks for:
- Best practices violations
- Potential bugs and errors
- Code style issues
- Performance problems
- Security concerns

**Integrated with:**
- VS Code PowerShell extension (real-time feedback)
- Command line execution
- CI/CD pipelines
- Git pre-commit hooks

### Installation

```powershell
# Install for current user (recommended)
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser

# Verify installation
Get-Module -Name PSScriptAnalyzer -ListAvailable
```

### Basic Usage

**Analyze a single script:**
```powershell
Invoke-ScriptAnalyzer -Path .\script.ps1
```

**Analyze all scripts in a directory (recursively):**
```powershell
Invoke-ScriptAnalyzer -Path . -Recurse
```

**Filter by severity:**
```powershell
# Only show errors and warnings
Invoke-ScriptAnalyzer -Path .\script.ps1 -Severity Error,Warning

# Only errors
Invoke-ScriptAnalyzer -Path .\script.ps1 -Severity Error
```

**Exclude specific rules:**
```powershell
Invoke-ScriptAnalyzer -Path .\script.ps1 -ExcludeRule PSAvoidUsingWriteHost
```

**Output formats:**
```powershell
# Default table format
Invoke-ScriptAnalyzer -Path .\script.ps1

# JSON for CI/CD
Invoke-ScriptAnalyzer -Path .\script.ps1 | ConvertTo-Json

# Custom formatting
Invoke-ScriptAnalyzer -Path .\script.ps1 | Format-Table -AutoSize
```

### Common Rules

| Rule | Description | Severity |
|------|-------------|----------|
| PSAvoidUsingWriteHost | Avoid Write-Host (use Write-Output) | Warning |
| PSAvoidUsingCmdletAliases | Use full cmdlet names, not aliases | Warning |
| PSUseDeclaredVarsMoreThanAssignments | Variable assigned but never used | Warning |
| PSUseShouldProcessForStateChangingFunctions | Add ShouldProcess for state changes | Warning |
| PSAvoidUsingPlainTextForPassword | Don't use plain text passwords | Error |
| PSUseSingularNouns | Cmdlet nouns should be singular | Warning |
| PSReservedCmdletChar | Avoid reserved characters in names | Error |
| PSAvoidUsingInvokeExpression | Avoid Invoke-Expression (security risk) | Warning |

**Full rule list:**
```powershell
Get-ScriptAnalyzerRule | Format-Table RuleName, Severity
```

### Analysis Workflow

**Step 1: Run initial analysis**
```powershell
$results = Invoke-ScriptAnalyzer -Path .\script.ps1
$results | Group-Object Severity | Select-Object Count, Name
```

**Step 2: Review issues by severity**
```powershell
# Critical errors first
$results | Where-Object Severity -eq 'Error' | Format-List

# Then warnings
$results | Where-Object Severity -eq 'Warning' | Format-List
```

**Step 3: Fix issues**
```powershell
# Some rules support auto-fix
Invoke-ScriptAnalyzer -Path .\script.ps1 -Fix
```

**Step 4: Verify fixes**
```powershell
Invoke-ScriptAnalyzer -Path .\script.ps1
```

### Custom Configuration

Create `.PSScriptAnalyzerSettings.psd1` in your project root:

```powershell
@{
    # Severity levels to include
    Severity = @('Error', 'Warning')
    
    # Rules to exclude
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',  # Allow Write-Host for scripts with UI
        'PSUseShouldProcessForStateChangingFunctions'  # Not needed for all scripts
    )
    
    # Rules to include (overrides defaults)
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSUseDeclaredVarsMoreThanAssignments'
    )
    
    # Custom rules (advanced)
    CustomRulePath = @(
        '.\CustomRules\MyCustomRule.psm1'
    )
}
```

**Use configuration file:**
```powershell
Invoke-ScriptAnalyzer -Path .\script.ps1 -Settings .\.PSScriptAnalyzerSettings.psd1
```

### CI/CD Integration

**Check for errors in build pipeline:**
```powershell
# Analyze all scripts
$results = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error

# Fail build if errors found
if ($results) {
    Write-Error "PSScriptAnalyzer found $($results.Count) errors!"
    $results | Format-Table -AutoSize
    exit 1
}
```

**Azure DevOps example:**
```yaml
- task: PowerShell@2
  displayName: 'Run PSScriptAnalyzer'
  inputs:
    targetType: 'inline'
    script: |
      Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
      $results = Invoke-ScriptAnalyzer -Path $(System.DefaultWorkingDirectory) -Recurse -Severity Error,Warning
      if ($results) {
        $results | Format-Table -AutoSize
        Write-Error "PSScriptAnalyzer found $($results.Count) issues"
        exit 1
      }
```

### VS Code Integration

**PowerShell extension automatically runs PSScriptAnalyzer.**

**Settings (settings.json):**
```json
{
    "powershell.scriptAnalysis.enable": true,
    "powershell.scriptAnalysis.settingsPath": ".PSScriptAnalyzerSettings.psd1"
}
```

### Best Practices for Analysis

1. **Run on all scripts** - Include tests, build scripts, utilities
2. **Fix errors first** - Errors are critical, warnings can wait
3. **Never suppress without user approval** - Fix the code instead
4. **Use configuration file** - Consistent rules across team
5. **Integrate in CI/CD** - Catch issues before merge
6. **Keep analyzer updated** - New rules and improvements
   ```powershell
   Update-Module -Name PSScriptAnalyzer
   ```

### Common Issues and Fixes

**Issue: "Variable assigned but never used"**
```powershell
# ❌ Bad
$result = Get-Process | Where-Object Name -eq 'pwsh'
# Variable not used

# ✅ Good
$result = Get-Process | Where-Object Name -eq 'pwsh'
$result | Format-Table  # Use the variable

# ✅ Or remove assignment if not needed
Get-Process | Where-Object Name -eq 'pwsh' | Format-Table
```

**Issue: "Avoid using Write-Host"**

**DECISION: Use Write-Information with ANSI escape codes for cross-platform compatibility.**

All scripts must work in PowerShell Core inside Linux containers. Write-Host is not cross-platform friendly.

```powershell
# ❌ Bad - Not cross-platform friendly
Write-Host "Processing..." -ForegroundColor Green

# ✅ Good - Cross-platform with colors using ANSI escape codes
$InformationPreference = 'Continue'  # Add at start of script
Write-Information "`e[32mProcessing...`e[0m"  # Green text

# ✅ Good - Use Write-Output for pipeline data
Write-Output "Processing..."

# ✅ Good - Use Write-Verbose for diagnostic messages
Write-Verbose "Processing..." -Verbose
```

**ANSI Color Codes Reference:**
```powershell
# Set $InformationPreference = 'Continue' at the start of your script

Write-Information "`e[31mRed text`e[0m"      # Error/danger
Write-Information "`e[32mGreen text`e[0m"    # Success
Write-Information "`e[33mYellow text`e[0m"   # Warning
Write-Information "`e[34mBlue text`e[0m"     # Info
Write-Information "`e[35mMagenta text`e[0m"  # Debug
Write-Information "`e[36mCyan text`e[0m"     # Highlight
Write-Information "`e[90mGray text`e[0m"     # Muted

# Unicode symbols work too
Write-Information "`e[32m✓ Success`e[0m"
Write-Information "`e[33m⚠️ Warning`e[0m"
Write-Information "`e[31m✗ Error`e[0m"
```

**NEVER use suppression attributes for PSAvoidUsingWriteHost - fix the code instead.**

**Issue: "Use full cmdlet names, not aliases"**
```powershell
# ❌ Bad
ls | ? {$_.Name -like '*.ps1'} | %{$_.FullName}

# ✅ Good
Get-ChildItem | Where-Object {$_.Name -like '*.ps1'} | ForEach-Object {$_.FullName}
```

**Issue: "Avoid Invoke-Expression"**
```powershell
# ❌ Bad - Security risk
$command = "Get-Process"
Invoke-Expression $command

# ✅ Good - Use proper PowerShell constructs
& $command  # Call operator
# Or use proper cmdlets/functions
```

## PowerShell Best Practices

### Script Structure

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Brief description of the script.

.DESCRIPTION
    Detailed description of what the script does.

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    .\script.ps1 -ParameterName "value"
    Description of example.

.NOTES
    Author: Your Name
    Version: 1.0.0
    Date: 2026-01-07
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ParameterName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Option1', 'Option2')]
    [string]$Option = 'Option1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script logic here
Write-Verbose "Processing with parameter: $ParameterName"
```

### Error Handling

```powershell
try {
    # Code that might fail
    Get-Item -Path "C:\NonExistent" -ErrorAction Stop
}
catch [System.Management.Automation.ItemNotFoundException] {
    # Specific exception handling
    Write-Error "File not found: $_"
}
catch {
    # General exception handling
    Write-Error "Unexpected error: $_"
    throw
}
finally {
    # Cleanup code
    Write-Verbose "Cleanup completed"
}
```

### Parameter Validation

```powershell
param(
    # Required string
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    # Must be from set of values
    [ValidateSet('Dev', 'Test', 'Prod')]
    [string]$Environment = 'Dev',
    
    # Must match pattern
    [ValidatePattern('^\d{3}-\d{2}-\d{4}$')]
    [string]$SSN,
    
    # Must be in range
    [ValidateRange(1, 100)]
    [int]$Percentage,
    
    # Must not be null or empty
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    
    # Custom validation
    [ValidateScript({Test-Path $_})]
    [string]$FilePath
)
```

## Quick Analysis Script

Save this as `Analyze-Scripts.ps1` for quick project-wide analysis:

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analyzes all PowerShell scripts in a directory.

.EXAMPLE
    .\Analyze-Scripts.ps1 -Path . -Severity Error,Warning
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Path = '.',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string[]]$Severity = @('Error', 'Warning')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure PSScriptAnalyzer is installed
if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
    Write-Host "Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
}

Write-Host "Analyzing PowerShell scripts in: $Path" -ForegroundColor Cyan
Write-Host "Severity levels: $($Severity -join ', ')" -ForegroundColor Gray
Write-Host ""

$results = Invoke-ScriptAnalyzer -Path $Path -Recurse -Severity $Severity

if ($results) {
    Write-Host "Found $($results.Count) issues:" -ForegroundColor Yellow
    Write-Host ""
    
    # Group by severity
    $grouped = $results | Group-Object Severity
    foreach ($group in $grouped) {
        Write-Host "$($group.Name): $($group.Count)" -ForegroundColor $(
            switch ($group.Name) {
                'Error' { 'Red' }
                'Warning' { 'Yellow' }
                default { 'White' }
            }
        )
    }
    Write-Host ""
    
    # Show details
    $results | Format-Table -AutoSize ScriptName, Line, Severity, RuleName, Message
    
    exit 1
} else {
    Write-Host "✅ No issues found!" -ForegroundColor Green
    exit 0
}
```

## PowerShell Profiles & Environment Management

### ⚠️ PRIORITY: Minimize PATH Length

**NEVER add directories to PATH when an alias/function will suffice.** The user's PATH must remain as short as possible.

- Use `New-Alias` or profile functions for executables instead of adding to PATH
- Example: `function ci { & code-insiders @args }` instead of adding VSCode Insiders bin to PATH
- Only add to PATH when the tool requires it (e.g., multiple sub-commands, DLL dependencies)

### ⚠️ NEVER: Source Profile in VSCode

**NEVER run `. $PROFILE` in VSCode or VSCode Insiders** - it hangs indefinitely. After profile changes, ask the user to reload/restart their terminal instead.

### Profile Locations

PowerShell has **4 profile locations**. Understanding these prevents "works in Terminal A but not Terminal B" issues:

| Profile | Variable | Scope | Recommendation |
|---------|----------|-------|----------------|
| AllUsersAllHosts | `$PROFILE.AllUsersAllHosts` | Everyone, all PS hosts | Admin use only |
| AllUsersCurrentHost | `$PROFILE.AllUsersCurrentHost` | Everyone, this PS version | Rarely needed |
| **CurrentUserAllHosts** | `$PROFILE.CurrentUserAllHosts` | You, ALL terminals | **USE THIS ONE** |
| CurrentUserCurrentHost | `$PROFILE.CurrentUserCurrentHost` | You, this PS version only | Source the above |

**The Golden Rule**: Put ALL customizations in `$PROFILE.CurrentUserAllHosts` (`profile.ps1`). This works in:
- Windows Terminal
- VS Code integrated terminal
- Regular PowerShell console
- PowerShell 7 and Windows PowerShell

**Check which profiles exist:**
```powershell
@($PROFILE.AllUsersAllHosts, $PROFILE.AllUsersCurrentHost, $PROFILE.CurrentUserAllHosts, $PROFILE.CurrentUserCurrentHost) | ForEach-Object { Write-Host "$(if(Test-Path $_){'[X]'}else{'[ ]'}) $_" }
```

### Profile Consolidation

**Problem**: Functions work in one terminal but not another.  
**Cause**: Customizations in `Microsoft.PowerShell_profile.ps1` (CurrentHost) instead of `profile.ps1` (AllHosts).

**Solution**:
1. **Backup both profiles**:
   ```powershell
   $backupDir = "$env:USERPROFILE\Documents\PowerShell\backups"
   New-Item -ItemType Directory -Path $backupDir -Force
   Copy-Item $PROFILE.CurrentUserAllHosts "$backupDir\profile.ps1.bak" -EA SilentlyContinue
   Copy-Item $PROFILE.CurrentUserCurrentHost "$backupDir\Microsoft.PowerShell_profile.ps1.bak"
   ```

2. **Move everything to `profile.ps1`** (CurrentUserAllHosts)

3. **Replace `Microsoft.PowerShell_profile.ps1`** with a one-liner:
   ```powershell
   # This file sources the main profile for consistency across all terminals.
   . $PROFILE.CurrentUserAllHosts
   ```

### Recommended Profile Structure

```powershell
# ============================================================================
# PowerShell Profile - CurrentUserAllHosts (works in ALL terminals)
# ============================================================================

# --- PATH Management (run FIRST) ---
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Ensure critical paths are present
$pathAdditions = @("$env:USERPROFILE\AppData\Roaming\npm", "$env:USERPROFILE\.cargo\bin")
foreach ($p in $pathAdditions) {
    if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) { $env:PATH = "$p;$env:PATH" }
}

# --- Theming (Optional) ---
# oh-my-posh init pwsh --config "$env:USERPROFILE\.config\omp\theme.omp.json" | Invoke-Expression
# Import-Module posh-git

# --- PSStyle (PowerShell 7+ Only) ---
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.FileInfo.Directory = "`e[93m"  # Bright yellow directories
}

# --- Functions/Aliases ---
function myapp { & "C:\Path\To\myapp.exe" @args }
New-Alias -Name k -Value kubectl
```

### Windows PATH Management

**Core Concepts:**
- **User vs. System**: User PATH is appended to System PATH
- **Character Limit**: Effective limit is often 2048 characters - exceeding causes silent failures
- **Registry Storage**: 
  - System: `HKLM:\System\CurrentControlSet\Control\Session Manager\Environment`
  - User: `HKCU:\Environment`

**Analyze Current PATH:**
```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
Write-Host "Length: $($userPath.Length) chars"
$userPath -split ";" | ForEach-Object -Begin { $i = 0 } -Process { Write-Host "$i`: $_"; $i++ }
```

**Identify Dead Paths:**
```powershell
$paths = [Environment]::GetEnvironmentVariable("Path", "User") -split ";"
$paths | Where-Object { $_ -and -not (Test-Path $_) }
```

**Optimization Strategies:**
| Strategy | When to Use | Savings |
|----------|-------------|---------|
| **Remove dead paths** | Path no longer exists | Variable |
| **Profile functions** | Single exe (e.g., `lms.exe`) | ~30-60 chars each |
| **Consolidate** | Multiple sub-folders (e.g., miniconda) | ~100+ chars |

**Example function replacement:**
```powershell
# Instead of PATH: C:\Users\user\.lmstudio\bin (33 chars)
function lms { & "$env:USERPROFILE\.lmstudio\bin\lms.exe" @args }
```

**Apply PATH Changes:**
```powershell
$pathsToRemove = @("C:\old\path1", "C:\old\path2")
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPaths = ($currentPath -split ";") | Where-Object { $_ -and $_ -notin $pathsToRemove }
[Environment]::SetEnvironmentVariable("Path", ($newPaths -join ";"), "User")
```

**Post-Change Protocol:**
After ANY environment or profile change:
1. **Notify the User**: State what changed
2. **Reload Options**: `. $PROFILE` or new terminal
3. **Verification**: Provide test commands

### Terminal Synchronization

**VS Code Terminal Gotchas:**
- VS Code terminals may cache environment variables
- Adding PATH reload to profile start ensures fresh PATH

### Profile Diagnostic Commands

```powershell
# Show profile path
$PROFILE

# Show all profile paths
$PROFILE | Get-Member -Type NoteProperty | ForEach-Object { "$($_.Name): $($PROFILE.$($_.Name))" }

# Test if profile exists
Test-Path $PROFILE

# View profile contents
Get-Content $PROFILE

# Reload profile (in current session)
. $PROFILE

# Check PowerShell version
$PSVersionTable.PSVersion

# Check current PSStyle directory color (PS7+)
$PSStyle.FileInfo.Directory
```

### Common Profile Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Scripts disabled" error | Execution policy | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| "Command not found" in VS Code | Wrong profile or stale session | Check `$PROFILE`, reload or restart terminal |
| Works in Terminal, not VS Code | Customizations in CurrentHost only | Consolidate to AllHosts profile |
| PATH truncated | Exceeds 2048 chars | Optimize with functions/consolidation |
| Changes not persisting | Modified `$env:Path` not registry | Use `[Environment]::SetEnvironmentVariable()` |
| Font issues (broken glyphs) | Missing Nerd Font | Install with `oh-my-posh font install CascadiaCode` |

### Oh-My-Posh Configuration

**Installation**:
```powershell
winget install JanDeDobbeleer.OhMyPosh -s winget
```

**Add to profile**:
```powershell
oh-my-posh init pwsh --config "$env:USERPROFILE\.config\omp\theme.omp.json" | Invoke-Expression
```

**Install Nerd Font**:
```powershell
oh-my-posh font install CascadiaCode
```

Then set `CaskaydiaCove NF` in Windows Terminal settings.

**Windows Terminal Font Config**  
Location: `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`

```json
{
  "profiles": {
    "defaults": {
      "font": {
        "face": "CaskaydiaCove NF",
        "size": 12
      }
    }
  }
}
```

### PSStyle Customization (PowerShell 7+)

**Directory Colors:**
```powershell
# Bright yellow directories (no background)
$PSStyle.FileInfo.Directory = "`e[93m"

# Blue text only (no background)  
$PSStyle.FileInfo.Directory = "`e[34m"
```

**Common ANSI Color Codes:**
| Code | Color |
|------|-------|
| `e[30m` | Black |
| `e[31m` | Red |
| `e[32m` | Green |
| `e[33m` | Yellow |
| `e[34m` | Blue |
| `e[35m` | Magenta |
| `e[36m` | Cyan |
| `e[37m` | White |
| `e[90-97m` | Bright variants |

## Ready-to-Use Scripts

This skill includes helper scripts in the skill directory:

### Analyze-Scripts.ps1
Analyzes PowerShell scripts with PSScriptAnalyzer:
```powershell
& "$env:USERPROFILE\.claude\skills\powershell\Analyze-Scripts.ps1" -Path . -Severity Error,Warning
```

### cleanup-user-path.ps1
Cleans User PATH (no admin required):
```powershell
& "$env:USERPROFILE\.claude\skills\powershell\cleanup-user-path.ps1"
```

### cleanup-system-path.ps1
Cleans System PATH (requires admin):
```powershell
# Run as Administrator
& "$env:USERPROFILE\.claude\skills\powershell\cleanup-system-path.ps1"
```

Both cleanup scripts:
- Backup before changes (timestamped in $env:TEMP)
- Remove duplicate entries (case-insensitive)
- Remove dead paths
- Prompt for confirmation before applying

## File Structure

```
powershell/
├── SKILL.md
├── Analyze-Scripts.ps1
├── cleanup-user-path.ps1
├── cleanup-system-path.ps1
└── History/
    └── {YYYY-MM-DD}.md
```
