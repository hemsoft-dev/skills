[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='User-facing script requires colored output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='Simple tool with default credentials')]
param()
<#
.SYNOPSIS
    Adds a PowerShell profile alias for quick Neo4j skills sync.

.DESCRIPTION
    Adds a 'Sync-Skills' function to your PowerShell profile for easy access.
    After running this, you can just type 'Sync-Skills' from anywhere.

.EXAMPLE
    .\Setup-ProfileAlias.ps1
# >

$syncScript = "$env:USERPROFILE\.claude\skills\neo4j\scripts\Sync-SkillsToNeo4j.ps1"

Write-Host "🔧 Adding Sync-Skills alias to PowerShell profile" -ForegroundColor Cyan

# Create profile if it doesn't exist

if (-not (Test-Path $PROFILE)) {
    Write-Host "Creating PowerShell profile..." -ForegroundColor Yellow
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
}

# Check if alias already exists

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -match 'function Sync-Skills') {
    Write-Host "⚠️  Sync-Skills function already exists in profile" -ForegroundColor Yellow
    $response = Read-Host "Replace it? (y/n)"
    if ($response -ne 'y') {
        Write-Host "❌ Cancelled" -ForegroundColor Red
        exit 0
    }
    # Remove old function
    $profileContent = $profileContent -replace '(?ms)function Sync-Skills \{.*?\}', ''
    $profileContent | Out-File $PROFILE -Force
}

# Add the function

$functionCode = @"

## ---------------------------------------

## Neo4j Skills Sync Alias

## ---------------------------------------
function Sync-Skills {
    <#
    .SYNOPSIS
        Quick alias to sync Claude skills to Neo4j.
    #>
    & "$syncScript"
}
"@

Add-Content -Path $PROFILE -Value $functionCode

Write-Host "✅ Alias added to PowerShell profile" -ForegroundColor Green
Write-Host "`nReload your profile:" -ForegroundColor White
Write-Host "  .`$PROFILE" -ForegroundColor Cyan
Write-Host "`nThen use:" -ForegroundColor White
Write-Host "  Sync-Skills" -ForegroundColor Cyan
Write-Host "`nProfile location: $PROFILE" -ForegroundColor Gray

# Offer to reload now

$response = Read-Host "`nReload profile now? (y/n)"
if ($response -eq 'y') {
    . $PROFILE
    Write-Host "✅ Profile reloaded! Try typing: Sync-Skills" -ForegroundColor Green
}
