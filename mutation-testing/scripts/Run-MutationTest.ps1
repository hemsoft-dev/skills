<#
.SYNOPSIS
    Run Stryker mutation testing for TypeScript or C# projects.

.DESCRIPTION
    Executes mutation testing using Stryker, archives reports by date,
    and displays a summary of results.

.PARAMETER Language
    Target language. Valid values: TypeScript, CSharp.

.PARAMETER ProjectRoot
    Path to the project root directory. Defaults to current directory.

.PARAMETER Mutate
    Override the default mutate globs to target specific modules.
    Example: "src/services/auth/**/*.ts"

.PARAMETER ConfigFile
    Path to a custom Stryker config file. Defaults to the standard location
    in .mutation-testing/.

.EXAMPLE
    .\Run-MutationTest.ps1 -Language "TypeScript" -ProjectRoot "."
    .\Run-MutationTest.ps1 -Language "CSharp" -ProjectRoot "." -Mutate "src/Domain/**/*.cs"
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("TypeScript", "CSharp")]
    [string]$Language,

    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = ".",

    [Parameter(Mandatory = $false)]
    [string]$Mutate,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path $ProjectRoot
$mutationDir = Join-Path $ProjectRoot ".mutation-testing"
$dateStamp = Get-Date -Format "yyyy-MM-dd"
$archiveDir = Join-Path $mutationDir "reports" $dateStamp

# Create archive directory for this run
New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

Write-Host "=== Mutation Testing Run ===" -ForegroundColor Cyan
Write-Host "Language:    $Language" -ForegroundColor Gray
Write-Host "Project:     $ProjectRoot" -ForegroundColor Gray
Write-Host "Date:        $dateStamp" -ForegroundColor Gray
if ($Mutate) {
    Write-Host "Target:      $Mutate" -ForegroundColor Gray
}
Write-Host ""

Push-Location $ProjectRoot
try {
    if ($Language -eq "TypeScript") {
        # Determine config file
        if (-not $ConfigFile) {
            $ConfigFile = Join-Path $mutationDir "stryker.conf.json"
        }

        if (-not (Test-Path $ConfigFile)) {
            throw "Config not found: $ConfigFile. Run Setup-TypeScript.ps1 first."
        }

        Write-Host "Running Stryker (TypeScript)..." -ForegroundColor Yellow
        $strykerCommand = @("stryker", "run", "--configFile", $ConfigFile)

        if ($Mutate) {
            $strykerCommand += @("--mutate", $Mutate)
        }

        & npx @strykerCommand

        # Copy reports to dated archive
        $latestDir = Join-Path $mutationDir "reports" "latest"
        if (Test-Path $latestDir) {
            Copy-Item -Path "$latestDir\*" -Destination $archiveDir -Recurse -Force
            Write-Host "`nReport archived to: $archiveDir" -ForegroundColor Gray
        }
    }
    elseif ($Language -eq "CSharp") {
        # Determine config file
        if (-not $ConfigFile) {
            $ConfigFile = Join-Path $mutationDir "stryker-config.json"
        }

        if (-not (Test-Path $ConfigFile)) {
            throw "Config not found: $ConfigFile. Run Setup-CSharp.ps1 first."
        }

        Write-Host "Running Stryker.NET (C#)..." -ForegroundColor Yellow
        $strykerArgs = @("stryker", "--config-file", $ConfigFile, "--output", $archiveDir)

        if ($Mutate) {
            $strykerArgs += @("--mutate", $Mutate)
        }

        & dotnet @strykerArgs

        Write-Host "`nReport saved to: $archiveDir" -ForegroundColor Gray
    }
}
finally {
    Pop-Location
}

# Summary
Write-Host ""
Write-Host "=== Run Complete ===" -ForegroundColor Green
Write-Host "Reports: $archiveDir" -ForegroundColor Gray

$htmlReport = Get-ChildItem -Path $archiveDir -Filter "*.html" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($htmlReport) {
    Write-Host "HTML Report: $($htmlReport.FullName)" -ForegroundColor Gray
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Open the HTML report to review survived mutants"
Write-Host "  2. Triage: real gap vs equivalent mutant vs low-value code"
Write-Host "  3. Write targeted tests to kill survived mutants"
Write-Host "  4. Record mutation score for trend tracking"
