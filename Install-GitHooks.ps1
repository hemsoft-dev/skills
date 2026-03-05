#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs and configures Git pre-commit hooks for PowerShell quality checks.

.DESCRIPTION
    Sets up the pre-commit hook to automatically run PSScriptAnalyzer on all
    staged PowerShell files before allowing commits. Ensures cross-platform
    compatibility and enforces coding standards.

.EXAMPLE
    .\Install-GitHooks.ps1
    Installs the pre-commit hook and makes it executable.
#>

[CmdletBinding()]
param()

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Information "`e[36m🔧 Installing Git pre-commit hooks...`e[0m"

# Verify we're in a git repository
if (-not (Test-Path '.git')) {
    Write-Information "`e[31m❌ Not a git repository! Run this from the repository root.`e[0m"
    exit 1
}

# Ensure PSScriptAnalyzer is installed
Write-Information "`e[36mChecking for PSScriptAnalyzer...`e[0m"
if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
    Write-Information "`e[33mInstalling PSScriptAnalyzer...`e[0m"
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    Write-Information "`e[32m✓ PSScriptAnalyzer installed`e[0m"
} else {
    Write-Information "`e[32m✓ PSScriptAnalyzer already installed`e[0m"
}

# Verify .PSScriptAnalyzerSettings.psd1 exists
if (-not (Test-Path '.PSScriptAnalyzerSettings.psd1')) {
    Write-Information "`e[31m❌ Missing .PSScriptAnalyzerSettings.psd1 configuration file!`e[0m"
    exit 1
}
Write-Information "`e[32m✓ Found .PSScriptAnalyzerSettings.psd1`e[0m"

# Check if hooks directory exists
$hooksDir = Join-Path '.git' 'hooks'
if (-not (Test-Path $hooksDir)) {
    Write-Information "`e[31m❌ Hooks directory not found: $hooksDir`e[0m"
    exit 1
}

# Path to the pre-commit hook
$hookPath = Join-Path $hooksDir 'pre-commit'

# Check if hook already exists
if (Test-Path $hookPath) {
    Write-Information "`e[33m⚠️  Pre-commit hook already exists`e[0m"
    $response = Read-Host "Overwrite existing hook? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Information "`e[33mInstallation cancelled`e[0m"
        exit 0
    }
}

Write-Information "`e[36mConfiguring pre-commit hook...`e[0m"

$hookScript = @'
#!/usr/bin/env pwsh
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StagedFilesByExtension([string]$ExtensionPattern) {
    return @(git diff --cached --name-only --diff-filter=ACMR | Where-Object { $_ -match $ExtensionPattern })
}

function Write-HookInfo([string]$Message) {
    Write-Host "[pre-commit] $Message"
}

$stagedPs1 = Get-StagedFilesByExtension '\.ps1$'
$stagedMd = Get-StagedFilesByExtension '\.md$'

if ($stagedPs1.Count -gt 0) {
    Write-HookInfo "Running PSScriptAnalyzer on $($stagedPs1.Count) staged PowerShell file(s)..."
    $analysis = @(Invoke-ScriptAnalyzer -Path $stagedPs1 -Settings .PSScriptAnalyzerSettings.psd1)
    if ($analysis.Count -gt 0) {
        Write-HookInfo 'PowerShell lint errors/warnings found:'
        $analysis | Format-Table -AutoSize | Out-Host
        exit 1
    }
}

if ($stagedMd.Count -gt 0) {
    Write-HookInfo "Running markdownlint-cli2 on $($stagedMd.Count) staged Markdown file(s)..."
    & markdownlint-cli2 @stagedMd
    if ($LASTEXITCODE -ne 0) {
        Write-HookInfo 'Markdown lint errors found.'
        exit 1
    }
}

exit 0
'@

Set-Content -Path $hookPath -Value $hookScript -Encoding utf8

# On Unix-like systems, ensure the hook is executable
if ($IsLinux -or $IsMacOS) {
    Write-Information "`e[36mSetting executable permissions...`e[0m"
    chmod +x $hookPath
    if ($LASTEXITCODE -ne 0) {
        Write-Information "`e[31m❌ Failed to make hook executable`e[0m"
        exit 1
    }
}

Write-Information "`e[32m✓ Pre-commit hook installed successfully!`e[0m"
Write-Information ""
Write-Information "`e[36m📋 What happens now:`e[0m"
Write-Information "  • Every commit will run PSScriptAnalyzer on staged .ps1 files"
Write-Information "  • Commits are blocked if any errors or warnings are found"
Write-Information "  • Cross-platform compatibility is enforced"
Write-Information "  • No suppressions allowed without justification"
Write-Information ""
Write-Information "`e[36m🧪 Test the hook:`e[0m"
Write-Information "  1. Stage a PowerShell file: git add some-script.ps1"
Write-Information "  2. Try to commit: git commit -m 'test'"
Write-Information "  3. The hook will analyze your file automatically"
Write-Information ""
Write-Information "`e[32m✓ Setup complete!`e[0m"
