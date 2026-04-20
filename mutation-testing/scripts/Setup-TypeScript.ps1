<#
.SYNOPSIS
    Initialize Stryker mutation testing configuration for a TypeScript project.

.PARAMETER ProjectRoot
    Path to the project root directory. Defaults to current directory.

.PARAMETER TestRunner
    Test runner to use. Valid values: jest, vitest, karma, mocha. Defaults to jest.

.EXAMPLE
    .\Setup-TypeScript.ps1 -ProjectRoot "C:\Projects\my-app" -TestRunner "vitest"
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = ".",

    [Parameter(Mandatory = $false)]
    [ValidateSet("jest", "vitest", "karma", "mocha")]
    [string]$TestRunner = "jest"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path $ProjectRoot

# Map test runner to package name
$runnerPackages = @{
    "jest"   = "@stryker-mutator/jest-runner"
    "vitest" = "@stryker-mutator/vitest-runner"
    "karma"  = "@stryker-mutator/karma-runner"
    "mocha"  = "@stryker-mutator/mocha-runner"
}

$runnerPackage = $runnerPackages[$TestRunner]

Write-Host "Setting up Stryker for TypeScript ($TestRunner runner) in: $ProjectRoot" -ForegroundColor Cyan

# Step 1: Install packages
Write-Host "`n[1/3] Installing Stryker packages..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
    npm install --save-dev "@stryker-mutator/core" "@stryker-mutator/typescript-checker" $runnerPackage
    if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
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
Write-Host "`n[3/3] Writing stryker.conf.json..." -ForegroundColor Yellow
$config = @{
    '$schema'      = "https://raw.githubusercontent.com/stryker-mutator/stryker/master/packages/core/schema/stryker-core.json"
    mutate         = @(
        "src/**/*.ts"
        "!src/**/*.test.ts"
        "!src/**/*.spec.ts"
        "!src/**/*.d.ts"
    )
    testRunner     = $TestRunner
    checkers       = @("typescript")
    reporters      = @("html", "json", "clear-text")
    htmlReporter   = @{ fileName = ".mutation-testing/reports/latest/index.html" }
    jsonReporter   = @{ fileName = ".mutation-testing/reports/latest/report.json" }
    thresholds     = @{ high = 80; low = 60; break = $null }
} | ConvertTo-Json -Depth 4

$configPath = Join-Path $mutationDir "stryker.conf.json"
$config | Set-Content -Path $configPath -Encoding UTF8

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
