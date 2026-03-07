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

function Remove-StopHookEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HooksJsonPath,

        [Parameter(Mandatory = $true)]
        [switch]$Force
    )

    if (-not (Test-Path $HooksJsonPath)) {
        return
    }

    try {
        $hooksObj = Get-Content -Path $HooksJsonPath -Raw | ConvertFrom-Json
        if ($null -eq $hooksObj.hooks) {
            return
        }

        $updated = $false
        if ($null -ne $hooksObj.hooks.PSObject.Properties['sessionEnd']) {
            $before = @($hooksObj.hooks.sessionEnd)
            $after = @(
                $before | Where-Object {
                    $bash = "$($_.bash)"
                    -not ($bash -match '\.github/scripts/auto-commit\.sh')
                }
            )

            if ($after.Count -ne $before.Count) {
                if ($after.Count -gt 0) {
                    $hooksObj.hooks.sessionEnd = $after
                }
                else {
                    $hooksObj.hooks.PSObject.Properties.Remove('sessionEnd')
                }
                $updated = $true
            }
        }

        if ($null -ne $hooksObj.hooks.PSObject.Properties['Stop']) {
            $hooksObj.hooks.PSObject.Properties.Remove('Stop')
            $updated = $true
        }

        if ($updated) {
            $hooksObj | ConvertTo-Json -Depth 10 | Set-Content -Path $HooksJsonPath -Encoding utf8NoBOM
            Write-Ok "Removed managed sessionEnd hook entry from: $HooksJsonPath"
        }
    } catch {
        if (-not $Force) {
            throw "Could not parse $HooksJsonPath. Use -Force to skip JSON entry cleanup."
        }
        Write-Warn "Skipping hooks.json entry removal due to parse error (forced): $HooksJsonPath"
    }
}

$repoRoot = Get-RepoRoot -Path $RepoPath
$activeHooksPath = Get-ActiveHooksPath -RepoRoot $repoRoot
$hooksDir = Join-Path $repoRoot '.git/hooks'

$preCommitPath = Join-Path $hooksDir 'pre-commit'
$preCommitMarkdownPath = Join-Path $hooksDir 'pre-commit-markdown.ps1'
$markdownConfigPath = Join-Path $repoRoot '.markdownlint.jsonc'
$huskyPreCommitPath = Join-Path $repoRoot '.husky/pre-commit'
$copilotHooksJsonPath = Join-Path $repoRoot '.github/hooks/hooks.json'
$copilotAutoCommitScriptPath = Join-Path $repoRoot '.github/scripts/auto-commit.sh'
$legacyStandaloneHookJsonPath = Join-Path $repoRoot '.github/hooks/session-stop-autopush.json'
$legacyCopilotStopScriptPath = Join-Path $repoRoot '.github/hooks/Invoke-AgentSessionAutoPush.ps1'
$copilotStopScriptPath = Join-Path $repoRoot 'copilot/scripts/Invoke-AgentSessionAutoPush.ps1'

try {
    Remove-ManagedFile -Path $preCommitPath -Marker 'Managed by copilot-hooks skill' -Label 'pre-commit hook'
    Remove-ManagedFile -Path $preCommitMarkdownPath -Marker 'Managed by copilot-hooks skill' -Label 'pre-commit-markdown hook'
    Remove-ManagedFile -Path $markdownConfigPath -Marker 'Managed by copilot-hooks skill' -Label 'starter markdownlint config'

    if ($activeHooksPath -eq '.husky/_') {
        Remove-HuskyBlock -Path $huskyPreCommitPath
    }

    Remove-ManagedFile -Path $copilotAutoCommitScriptPath -Marker 'Managed by copilot-hooks skill' -Label 'Copilot sessionEnd auto-commit shell script'
    Remove-StopHookEntry -HooksJsonPath $copilotHooksJsonPath -Force:$Force
    Remove-ManagedFile -Path $legacyStandaloneHookJsonPath -Marker 'copilot/scripts/Invoke-AgentSessionAutoPush.ps1' -Label 'Legacy standalone Stop hook profile'
    Remove-ManagedFile -Path $legacyCopilotStopScriptPath -Marker 'Managed by copilot-hooks skill' -Label 'Legacy Copilot Stop auto-push script'
    Remove-ManagedFile -Path $copilotStopScriptPath -Marker 'Managed by copilot-hooks skill' -Label 'Legacy copilot/scripts PowerShell hook'
} catch {
    Write-Err $_.Exception.Message
    exit 1
}

Write-Ok 'Uninstall complete'
exit 0
