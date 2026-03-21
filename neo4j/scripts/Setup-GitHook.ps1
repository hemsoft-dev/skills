[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='User-facing script requires colored output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='Simple tool with default credentials')]
param()
<#
.SYNOPSIS
    Creates a git post-commit hook to auto-sync skills to Neo4j.

.DESCRIPTION
    Installs a git hook that automatically runs the Neo4j sync script
    after every commit in the skills repository.

.EXAMPLE
    .\Setup-GitHook.ps1
#>

$skillsRepo = "$env:USERPROFILE\.claude\skills"
$hookPath = "$skillsRepo\.git\hooks\post-commit"
$syncScript = "$skillsRepo\neo4j\scripts\Sync-SkillsToNeo4j.ps1"

Write-Host "🔧 Setting up git post-commit hook for Neo4j sync" -ForegroundColor Cyan

# Check if .git exists

if (-not (Test-Path "$skillsRepo\.git")) {
    Write-Warning "Git repository not found at $skillsRepo"
    Write-Host "Initialize git first with: git init" -ForegroundColor Yellow
    exit 1
}

# Create hooks directory if it doesn't exist

$hooksDir = Split-Path $hookPath
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}

# Create the hook script

$hookContent = @"
# !/bin/sh

# Auto-sync skills to Neo4j after commit

echo "🔄 Syncing skills to Neo4j..."
pwsh.exe -NoProfile -File "$syncScript"
"@

$hookContent | Out-File $hookPath -Encoding utf8 -NoNewline

Write-Host "✅ Git hook installed at: $hookPath" -ForegroundColor Green
Write-Host "`nThe sync script will run automatically after every git commit." -ForegroundColor Gray
Write-Host "`nTo disable: Delete $hookPath" -ForegroundColor Gray
