#!/usr/bin/env pwsh
param(
    [Parameter()]
    [string]$RepoPath = '.',

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Err([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-ActiveHooksPath {
    param([string]$RepoRoot)

    $configured = (git -C $RepoRoot config --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($configured)) {
        return '.git/hooks'
    }

    return $configured.Trim()
}

function Get-RepoRoot {
    param([string]$Path)

    $resolved = Resolve-Path -Path $Path -ErrorAction Stop
    $candidate = $resolved.Path

    if (Test-Path -Path (Join-Path $candidate '.git')) {
        return $candidate
    }

    $gitTop = git -C $candidate rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitTop) {
        return $gitTop.Trim()
    }

    throw "Path '$candidate' is not inside a git repository."
}

function Remove-ManagedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Marker,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        Write-Warn "Not found: $Label ($Path)"
        return
    }

    $content = Get-Content -Path $Path -Raw
    $isManaged = $content -match [regex]::Escape($Marker)

    if ($isManaged -or $Force) {
        Remove-Item -Path $Path -Force
        Write-Ok "Removed: $Label"
        return
    }

    throw "$Label exists but was not installed by copilot-hooks skill. Use -Force to remove it."
}

function Remove-HuskyBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return
    }

    $text = Get-Content -Path $Path -Raw
    $pattern = '(?s)\r?\n?# copilot-hooks:begin markdown gate.*?# copilot-hooks:end markdown gate\r?\n?'
    $updated = [regex]::Replace($text, $pattern, "`r`n")
    if ($updated -ne $text) {
        Set-Content -Path $Path -Value $updated.TrimEnd() + "`r`n" -Encoding utf8NoBOM
        Write-Ok "Removed Husky markdown gate block: $Path"
    }
}

$repoRoot = Get-RepoRoot -Path $RepoPath
$activeHooksPath = Get-ActiveHooksPath -RepoRoot $repoRoot
$hooksDir = Join-Path $repoRoot '.git/hooks'

# File paths
$preCommitPath = Join-Path $hooksDir 'pre-commit'
$preCommitMarkdownPath = Join-Path $hooksDir 'pre-commit-markdown.ps1'
$markdownConfigPath = Join-Path $repoRoot '.markdownlint.jsonc'
$huskyPreCommitPath = Join-Path $repoRoot '.husky/pre-commit'

$copilotHooksDir = Join-Path $repoRoot '.github/hooks'
$copilotHooksJsonPath = Join-Path $copilotHooksDir 'hooks.json'
$playDonePs1Path = Join-Path $copilotHooksDir 'play-done.ps1'
$playDoneShPath = Join-Path $copilotHooksDir 'play-done.sh'
$logPromptPs1Path = Join-Path $copilotHooksDir 'Log-Prompt.ps1'
$logPromptShPath = Join-Path $copilotHooksDir 'log-prompt.sh'
$autoCommitShPath = Join-Path $copilotHooksDir 'auto-commit.sh'
$hooksSettingsPath = Join-Path $copilotHooksDir 'hooks-settings.json'
$audioFilePath = Join-Path $copilotHooksDir 'done.mp3'

# Legacy paths
$legacyStandaloneHookJsonPath = Join-Path $copilotHooksDir 'session-stop-autopush.json'
$legacyCopilotStopScriptPath = Join-Path $copilotHooksDir 'Invoke-AgentSessionAutoPush.ps1'
$copilotStopScriptPath = Join-Path $repoRoot 'copilot/scripts/Invoke-AgentSessionAutoPush.ps1'
$legacyScriptsAutoCommitPath = Join-Path $repoRoot '.github/scripts/auto-commit.sh'

try {
    # ─────────────────────────────────────────────────────────────────────────
    # Copilot CLI hooks
    # ─────────────────────────────────────────────────────────────────────────

    Remove-ManagedFile -Path $playDonePs1Path -Marker 'Managed by copilot-hooks skill' -Label 'play-done.ps1 (audio notification)'
    Remove-ManagedFile -Path $playDoneShPath -Marker 'Managed by copilot-hooks skill' -Label 'play-done.sh (audio notification)'
    Remove-ManagedFile -Path $logPromptPs1Path -Marker 'Managed by copilot-hooks skill' -Label 'Log-Prompt.ps1 (prompt logging)'
    Remove-ManagedFile -Path $logPromptShPath -Marker 'Managed by copilot-hooks skill' -Label 'log-prompt.sh (prompt logging)'
    Remove-ManagedFile -Path $autoCommitShPath -Marker 'Managed by copilot-hooks skill' -Label 'auto-commit.sh (session-end)'

    # hooks.json - remove entirely if managed, otherwise remove just our entries
    if (Test-Path $copilotHooksJsonPath) {
        $hjContent = Get-Content -Path $copilotHooksJsonPath -Raw
        # If it only has our managed hooks (postToolUse, userPromptSubmitted, sessionEnd), remove it
        $hasOnlyOurHooks = $hjContent -match 'play-done' -and $hjContent -match '[Ll]og-[Pp]rompt' -and $hjContent -match 'auto-commit'
        if ($hasOnlyOurHooks -or $Force) {
            Remove-Item -Path $copilotHooksJsonPath -Force
            Write-Ok "Removed: hooks.json"
        } else {
            Write-Warn "hooks.json has custom entries - not removing (use -Force to override)"
        }
    }

    # Settings file (optional, user may want to keep)
    if ((Test-Path $hooksSettingsPath) -and $Force) {
        Remove-Item -Path $hooksSettingsPath -Force
        Write-Ok "Removed: hooks-settings.json"
    } elseif (Test-Path $hooksSettingsPath) {
        Write-Warn "Kept hooks-settings.json (use -Force to remove)"
    }

    # Audio file (user-provided, only remove with -Force)
    if ((Test-Path $audioFilePath) -and $Force) {
        Remove-Item -Path $audioFilePath -Force
        Write-Ok "Removed: done.mp3"
    } elseif (Test-Path $audioFilePath) {
        Write-Warn "Kept done.mp3 (user-provided, use -Force to remove)"
    }

    # ─────────────────────────────────────────────────────────────────────────
    # Pre-commit hooks
    # ─────────────────────────────────────────────────────────────────────────

    Remove-ManagedFile -Path $preCommitPath -Marker 'Managed by copilot-hooks skill' -Label 'pre-commit hook'
    Remove-ManagedFile -Path $preCommitMarkdownPath -Marker 'Managed by copilot-hooks skill' -Label 'pre-commit-markdown hook'
    Remove-ManagedFile -Path $markdownConfigPath -Marker 'Managed by copilot-hooks skill' -Label 'starter markdownlint config'

    if ($activeHooksPath -eq '.husky/_') {
        Remove-HuskyBlock -Path $huskyPreCommitPath
    }

    # ─────────────────────────────────────────────────────────────────────────
    # Legacy artifacts
    # ─────────────────────────────────────────────────────────────────────────

    Remove-ManagedFile -Path $legacyScriptsAutoCommitPath -Marker 'Managed by copilot-hooks skill' -Label 'Legacy .github/scripts/auto-commit.sh'
    Remove-ManagedFile -Path $legacyStandaloneHookJsonPath -Marker 'copilot/scripts/Invoke-AgentSessionAutoPush.ps1' -Label 'Legacy standalone Stop hook profile'
    Remove-ManagedFile -Path $legacyCopilotStopScriptPath -Marker 'Managed by copilot-hooks skill' -Label 'Legacy Copilot Stop auto-push script'
    Remove-ManagedFile -Path $copilotStopScriptPath -Marker 'Managed by copilot-hooks skill' -Label 'Legacy copilot/scripts PowerShell hook'
} catch {
    Write-Err $_.Exception.Message
    exit 1
}

Write-Ok 'Uninstall complete'
exit 0
