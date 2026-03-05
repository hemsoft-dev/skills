#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [Parameter()]
    [string]$RepoPath = '.',

    [Parameter()]
    [switch]$Force
)

function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Err([string]$Message) { Write-Host $Message -ForegroundColor Red }

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

$repoRoot = Get-RepoRoot -Path $RepoPath
$hooksDir = Join-Path $repoRoot '.git/hooks'

$preCommitPath = Join-Path $hooksDir 'pre-commit'
$preCommitMarkdownPath = Join-Path $hooksDir 'pre-commit-markdown.ps1'
$markdownConfigPath = Join-Path $repoRoot '.markdownlint.jsonc'

try {
    Remove-ManagedFile -Path $preCommitPath -Marker 'Managed by copilot-hooks skill' -Label 'pre-commit hook'
    Remove-ManagedFile -Path $preCommitMarkdownPath -Marker 'Managed by copilot-hooks skill' -Label 'pre-commit-markdown hook'
    Remove-ManagedFile -Path $markdownConfigPath -Marker 'Managed by copilot-hooks skill' -Label 'starter markdownlint config'
} catch {
    Write-Err $_.Exception.Message
    exit 1
}

Write-Ok 'Uninstall complete'
exit 0
