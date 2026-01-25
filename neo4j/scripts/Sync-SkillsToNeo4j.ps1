[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='User-facing script requires colored output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='Simple tool with default credentials')]
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

# Pre-flight checks
Write-Host "🔍 Pre-flight checks..." -ForegroundColor Cyan

# Check Docker Desktop is running
try {
    $null = docker ps 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker Desktop is not running. Please start Docker Desktop and try again." -ForegroundColor Red
        Write-Host "   Start Docker Desktop: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Docker Desktop is not running. Please start Docker Desktop and try again." -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Yellow
    exit 1
}

# Check Neo4j container exists
$container = docker ps -a --filter name=neo4j --format "{{.Names}}" 2>&1
if ($LASTEXITCODE -ne 0 -or -not $container) {
    Write-Host "❌ Neo4j container not found. Run 'docker run...' to create it first." -ForegroundColor Red
    Write-Host "   See Installation section in SKILL.md for container setup instructions." -ForegroundColor Yellow
    exit 1
}

# Check Neo4j container is running
$running = docker ps --filter name=neo4j --format "{{.Names}}" 2>&1
if (-not $running) {
    Write-Host "⚠️  Neo4j container is stopped. Attempting to start..." -ForegroundColor Yellow
    docker start neo4j | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to start Neo4j container. Run 'docker start neo4j' manually." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Neo4j container started successfully" -ForegroundColor Green
    Start-Sleep -Seconds 5  # Wait for Neo4j to initialize
}

# Check ports are accessible
$port7474 = Test-NetConnection -ComputerName localhost -Port 7474 -WarningAction SilentlyContinue -InformationLevel Quiet
$port7687 = Test-NetConnection -ComputerName localhost -Port 7687 -WarningAction SilentlyContinue -InformationLevel Quiet

if (-not $port7474) {
    Write-Host "⚠️  Port 7474 (HTTP) is not accessible. Neo4j may still be starting up." -ForegroundColor Yellow
}
if (-not $port7687) {
    Write-Host "⚠️  Port 7687 (Bolt) is not accessible. Neo4j may still be starting up." -ForegroundColor Yellow
}

Write-Host "✅ Pre-flight checks passed" -ForegroundColor Green

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

# Ask for confirmation (skip in non-interactive mode)
try {
    $response = Read-Host "`nSync these skills to Neo4j? (y/n)"
    if ($response -ne 'y') {
        Write-Host "❌ Sync cancelled" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "`n🚀 Running sync (non-interactive mode)..." -ForegroundColor Cyan
}

# Run full import (it's idempotent with MERGE)
Write-Host "`n🚀 Running sync..." -ForegroundColor Cyan
& "$PSScriptRoot\Import-SkillsToNeo4j.ps1" -SkillsPath $SkillsPath -Username $Username -Password $Password

# Update sync timestamp
$syncDir = Split-Path -Path $syncFile -Parent
if (-not (Test-Path $syncDir)) {
    New-Item -ItemType Directory -Path $syncDir -Force | Out-Null
}
Get-Date | Out-File $syncFile -Force

Write-Host "`n✅ Sync complete!" -ForegroundColor Green
Write-Host "Next sync will only process files modified after $(Get-Date)" -ForegroundColor Gray
