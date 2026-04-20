<#
.SYNOPSIS
    Initialize Stryker.NET mutation testing configuration for a C# project.

.PARAMETER ProjectRoot
    Path to the project root directory (solution root). Defaults to current directory.

.PARAMETER TestProject
    Relative path to the test project .csproj file (from project root).

.PARAMETER SourceProject
    Relative path to the source project .csproj file (from project root).

.EXAMPLE
    .\Setup-CSharp.ps1 -ProjectRoot "C:\Projects\my-api" -TestProject "tests\MyApi.Tests\MyApi.Tests.csproj" -SourceProject "src\MyApi\MyApi.csproj"
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = ".",

    [Parameter(Mandatory = $true)]
    [string]$TestProject,

    [Parameter(Mandatory = $false)]
    [string]$SourceProject
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path $ProjectRoot

Write-Host "Setting up Stryker.NET in: $ProjectRoot" -ForegroundColor Cyan

# Step 1: Install dotnet-stryker
Write-Host "`n[1/3] Installing dotnet-stryker..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
    # Check if tool manifest exists
    if (-not (Test-Path ".config/dotnet-tools.json")) {
        dotnet new tool-manifest
    }
    dotnet tool install dotnet-stryker
    if ($LASTEXITCODE -ne 0) {
        Write-Host "dotnet-stryker may already be installed, attempting restore..." -ForegroundColor Gray
        dotnet tool restore
    }
}
finally {
    Pop-Location
}

# Step 2: Create .mutation-testing directory
Write-Host "`n[2/3] Creating .mutation-testing directory..." -ForegroundColor Yellow
$mutationDir = Join-Path $ProjectRoot ".mutation-testing"
$reportsDir = Join-Path $mutationDir "reports"
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null

# Step 3: Create config file
Write-Host "`n[3/3] Writing stryker-config.json..." -ForegroundColor Yellow

$strykerConfig = @{
    "stryker-config" = @{
        "test-projects" = @($TestProject)
        reporters       = @("html", "json", "cleartext")
        thresholds      = @{ high = 80; low = 60; break = $null }
        mutate          = @(
            "**/*.cs"
            "!**/Migrations/**/*.cs"
            "!**/obj/**/*.cs"
            "!**/bin/**/*.cs"
        )
    }
}

if ($SourceProject) {
    $strykerConfig["stryker-config"]["project"] = $SourceProject
}

$configJson = $strykerConfig | ConvertTo-Json -Depth 4
$configPath = Join-Path $mutationDir "stryker-config.json"
$configJson | Set-Content -Path $configPath -Encoding UTF8

# Step 4: Update .gitignore
$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$ignoreEntry = ".mutation-testing/reports/"
if (Test-Path $gitignorePath) {
    $content = Get-Content $gitignorePath -Raw
    if ($content -notmatch [regex]::Escape($ignoreEntry)) {
        Write-Host "Adding $ignoreEntry to .gitignore" -ForegroundColor Gray
        Add-Content -Path $gitignorePath -Value "`n# Mutation testing reports`n$ignoreEntry"
    }
}
else {
    "# Mutation testing reports`n$ignoreEntry" | Set-Content -Path $gitignorePath -Encoding UTF8
}

Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "Config: $configPath" -ForegroundColor Gray
Write-Host "Edit the 'mutate' globs to target specific modules before running." -ForegroundColor Gray
