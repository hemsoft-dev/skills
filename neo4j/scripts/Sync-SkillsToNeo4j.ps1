[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='User-facing script requires colored output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='Simple tool with default credentials')]
param()
<#
.SYNOPSIS
    Incrementally syncs modified skills to Neo4j graph database.

.DESCRIPTION
    Only updates skills that have been modified since last sync, making it faster
    than a full re-import. Tracks last sync time and processes changed files.

.PARAMETER Force
    Force full re-sync of all skills regardless of modification time.

.EXAMPLE
    .\Sync-SkillsToNeo4j.ps1

.EXAMPLE
    .\Sync-SkillsToNeo4j.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [string]$SkillsPath = "$env:USERPROFILE\.claude\skills",
    [string]$Neo4jUri = "bolt://localhost:7687",
    [string]$Username = "neo4j",
    [string]$Password = "password"
)

$syncFile = "$env:USERPROFILE\.neo4j\last-sync.txt"

# Get last sync time
$lastSync = if ((Test-Path $syncFile) -and -not $Force) {
    Get-Content $syncFile | Get-Date
} else {
    [DateTime]::MinValue
}

Write-Host "🔄 Neo4j Skills Sync" -ForegroundColor Cyan
Write-Host "Last sync: $lastSync" -ForegroundColor Gray

# Find modified SKILL.md files
$modifiedSkills = Get-ChildItem -Path $SkillsPath -Recurse -Filter "SKILL.md" |
    Where-Object {
        $_.DirectoryName -notmatch '\\(node_modules|\.git|History)\\' -and
        $_.LastWriteTime -gt $lastSync
    }

if ($modifiedSkills.Count -eq 0) {
    Write-Host "✅ No skills modified since last sync" -ForegroundColor Green
    exit 0
}

Write-Host "📝 Found $($modifiedSkills.Count) modified skill(s)" -ForegroundColor Yellow
foreach ($file in $modifiedSkills) {
    Write-Host "  - $($file.Directory.Name)" -ForegroundColor Gray
}

# Ask for confirmation
$response = Read-Host "`nSync these skills to Neo4j? (y/n)"
if ($response -ne 'y') {
    Write-Host "❌ Sync cancelled" -ForegroundColor Red
    exit 1
}

# Run full import (it's idempotent with MERGE)
Write-Host "`n🚀 Running sync..." -ForegroundColor Cyan
& "$PSScriptRoot\Import-SkillsToNeo4j.ps1" -SkillsPath $SkillsPath -Username $Username -Password $Password

# Update sync timestamp
$syncFile | Split-Path | New-Item -ItemType Directory -Force | Out-Null
Get-Date | Out-File $syncFile -Force

Write-Host "`n✅ Sync complete!" -ForegroundColor Green
Write-Host "Next sync will only process files modified after $(Get-Date)" -ForegroundColor Gray
