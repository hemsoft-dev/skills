# crap-report.ps1 — Deterministic CRAP score calculator (multi-stack)
# CRAP(m) = complexity(m)^2 × (1 - coverage(m)/100)^3 + complexity(m)
#
# Supports: TypeScript/JavaScript, .NET/C#, Python
# Auto-detects stack from project files, or use -Stack to override.
#
# Usage: .\crap-report.ps1 [-Threshold 6] [-Top 20] [-Format table|json|csv] [-Stack auto|ts|dotnet|python]
param(
    [double]$Threshold = 6,
    [int]$Top = 30,
    [string]$CoverageDir = "",
    [string]$Format = "table",
    [ValidateSet("auto", "ts", "dotnet", "python")]
    [string]$Stack = "auto",
    [switch]$SkipCoverage,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "crap-report.ps1 — Multi-Stack CRAP Score Calculator" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PARAMETERS" -ForegroundColor Yellow
    Write-Host "  -Threshold <n>    CRAP threshold (default: 6, functions >= this are flagged)"
    Write-Host "  -Top <n>          Show top N worst scores (default: 30)"
    Write-Host "  -CoverageDir <p>  Coverage output directory (auto-detected if omitted)"
    Write-Host "  -Format <fmt>     Output format: table, json, csv (default: table)"
    Write-Host "  -Stack <s>        Force stack: auto, ts, dotnet, python (default: auto)"
    Write-Host "  -SkipCoverage     Skip running tests, use existing coverage data"
    Write-Host "  -Help             Show this help"
    Write-Host ""
    Write-Host "SUPPORTED STACKS" -ForegroundColor Yellow
    Write-Host "  ts      — TypeScript/JavaScript (vitest/jest + eslint)"
    Write-Host "  dotnet  — .NET/C# (coverlet + Cobertura XML)"
    Write-Host "  python  — Python (pytest-cov + radon)"
    Write-Host ""
    Write-Host "REQUIREMENTS" -ForegroundColor Yellow
    Write-Host "  ts:     coverage-summary.json + eslint"
    Write-Host "  dotnet: Cobertura XML from coverlet (has complexity per method)"
    Write-Host "  python: coverage.xml + radon"
    exit 0
}

# --- Stack Detection ---
function Detect-Stack {
    if (Get-ChildItem "*.sln" -ErrorAction SilentlyContinue) { return "dotnet" }
    if (Get-ChildItem "*.csproj" -ErrorAction SilentlyContinue) { return "dotnet" }
    if (Test-Path "pyproject.toml") { return "python" }
    if (Test-Path "setup.py") { return "python" }
    if (Test-Path "requirements.txt") { return "python" }
    if (Test-Path "package.json") { return "ts" }
    Write-Host "ERROR: Could not detect project stack. Use -Stack to specify." -ForegroundColor Red
    exit 1
}

if ($Stack -eq "auto") {
    $Stack = Detect-Stack
    Write-Host "Detected stack: $Stack" -ForegroundColor DarkGray
}

# --- Shared CRAP calculation ---
function Calculate-CRAP([double]$complexity, [double]$coveragePct) {
    $covFraction = $coveragePct / 100.0
    $crap = [math]::Pow($complexity, 2) * [math]::Pow((1 - $covFraction), 3) + $complexity
    return [math]::Round($crap, 1)
}

# --- Stack-specific implementations ---
$crapResults = @()
$totalStats = @{ lines = 0; branches = 0; functions = 0; statements = 0 }

switch ($Stack) {
    "ts" {
        # TypeScript/JavaScript: vitest/jest coverage-summary.json + eslint complexity
        if (-not $CoverageDir) { $CoverageDir = "coverage" }
        $summaryPath = Join-Path $CoverageDir "coverage-summary.json"

        if (-not $SkipCoverage -or -not (Test-Path $summaryPath)) {
            Write-Host "Running tests with coverage..." -ForegroundColor Cyan
            $runCmd = if (Get-Command bun -ErrorAction SilentlyContinue) { "bun" } else { "npx" }
            & $runCmd vitest run --coverage 2>&1 | Out-Null
            if (-not (Test-Path $summaryPath)) {
                Write-Host "ERROR: Coverage data not generated at $summaryPath" -ForegroundColor Red
                exit 1
            }
        }

        if (-not (Test-Path $summaryPath)) {
            Write-Host "ERROR: No coverage data at $summaryPath. Run tests with coverage first." -ForegroundColor Red
            exit 1
        }

        Write-Host "Parsing coverage data..." -ForegroundColor DarkGray
        $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
        $totalStats = @{
            lines = $summary.total.lines.pct
            branches = $summary.total.branches.pct
            functions = $summary.total.functions.pct
            statements = $summary.total.statements.pct
        }

        $fileCoverage = @{}
        foreach ($prop in $summary.PSObject.Properties) {
            if ($prop.Name -eq 'total') { continue }
            $relativePath = $prop.Name -replace '\\', '/'
            # Strip absolute path to get relative
            if ($relativePath -match '[A-Z]:/') {
                $relativePath = $relativePath -replace '^.*?/(src/)', '$1'
            }
            $cwd = (Get-Location).Path -replace '\\', '/'
            $relativePath = $relativePath -replace [regex]::Escape("$cwd/"), ""
            $fileCoverage[$relativePath] = @{
                Lines = $prop.Value.lines.pct
                Branches = $prop.Value.branches.pct
                Functions = $prop.Value.functions.pct
                Statements = $prop.Value.statements.pct
            }
        }

        # Run eslint complexity analysis
        Write-Host "Running eslint complexity analysis..." -ForegroundColor DarkGray
        $eslintCmd = if (Get-Command bun -ErrorAction SilentlyContinue) { "bun" } else { "npx" }
        $eslintOutput = ""

        # Detect source directories from coverage keys
        $srcDirs = @($fileCoverage.Keys | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique)
        $globPatterns = @($srcDirs | ForEach-Object { "$_/**/*.{ts,tsx,js,jsx}" })

        try {
            $eslintArgs = @($globPatterns) + @("--rule", "complexity: [warn, 1]", "--format", "json", "--no-error-on-unmatched-pattern")
            $eslintOutput = & $eslintCmd eslint @eslintArgs 2>$null
        } catch {}

        if (-not $eslintOutput) {
            try {
                $eslintOutput = & $eslintCmd eslint "src/**/*.{ts,tsx}" --rule "complexity: [warn, 1]" --format json --no-error-on-unmatched-pattern 2>$null
            } catch {}
        }

        if (-not $eslintOutput) {
            Write-Host "WARNING: Could not get eslint complexity output" -ForegroundColor Yellow
        } else {
            try {
                $eslintData = $eslintOutput | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $eslintData = $null
            }

            if ($eslintData) {
                foreach ($fileResult in $eslintData) {
                    $filePath = $fileResult.filePath -replace '\\', '/'
                    $filePath = $filePath -replace '^.*?/(src/)', '$1'

                    $cov = $fileCoverage[$filePath]
                    if (-not $cov) {
                        $fileName = Split-Path $filePath -Leaf
                        $matchKey = $fileCoverage.Keys | Where-Object { $_ -like "*$fileName" } | Select-Object -First 1
                        if ($matchKey) { $cov = $fileCoverage[$matchKey]; $filePath = $matchKey }
                        else { continue }
                    }

                    $coveragePct = $cov.Branches

                    foreach ($msg in $fileResult.messages) {
                        if ($msg.ruleId -ne 'complexity') { continue }

                        $complexity = 1
                        if ($msg.message -match 'complexity of (\d+)') {
                            $complexity = [int]$Matches[1]
                        }

                        $fnName = "anonymous"
                        if ($msg.message -match "^(?:Function|Async function|Method|Async method) '([^']+)' has") {
                            $fnName = $Matches[1]
                        } elseif ($msg.message -match "^(?:Arrow function|Async arrow function) has") {
                            $fnName = "arrow:L$($msg.line)"
                        } elseif ($msg.message -match "'([^']+)'") {
                            $fnName = $Matches[1]
                        } else {
                            $fnName = "fn:L$($msg.line)"
                        }

                        $crap = Calculate-CRAP $complexity $coveragePct

                        $crapResults += [PSCustomObject]@{
                            File       = $filePath
                            Function   = $fnName
                            Line       = $msg.line
                            Complexity = $complexity
                            Coverage   = [math]::Round($coveragePct, 1)
                            CRAP       = $crap
                        }
                    }
                }
            }
        }
    }

    "dotnet" {
        # .NET/C#: Cobertura XML from coverlet (includes complexity per method)
        if (-not $CoverageDir) { $CoverageDir = "TestResults" }

        # Find Cobertura XML
        $coberturaPath = ""
        $searchPaths = @(
            (Join-Path $CoverageDir "coverage.cobertura.xml"),
            (Join-Path $CoverageDir "cobertura-coverage.xml"),
            "coverage.cobertura.xml"
        )
        # Also search recursively in TestResults
        $recursive = Get-ChildItem $CoverageDir -Filter "*.cobertura.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($recursive) { $searchPaths = @($recursive.FullName) + $searchPaths }

        foreach ($p in $searchPaths) {
            if (Test-Path $p) { $coberturaPath = $p; break }
        }

        if (-not $coberturaPath -and -not $SkipCoverage) {
            Write-Host "Running tests with coverage..." -ForegroundColor Cyan
            & dotnet test --collect:"XPlat Code Coverage" --results-directory $CoverageDir -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura 2>&1 | Out-Null
            $recursive = Get-ChildItem $CoverageDir -Filter "*.cobertura.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($recursive) { $coberturaPath = $recursive.FullName }
        }

        if (-not $coberturaPath -or -not (Test-Path $coberturaPath)) {
            Write-Host "ERROR: No Cobertura XML found. Run 'dotnet test --collect:""XPlat Code Coverage""' first." -ForegroundColor Red
            exit 1
        }

        Write-Host "Parsing Cobertura XML: $coberturaPath" -ForegroundColor DarkGray
        [xml]$cobertura = Get-Content $coberturaPath

        # Extract overall stats
        $totalStats = @{
            lines = [math]::Round([double]$cobertura.coverage.'line-rate' * 100, 2)
            branches = [math]::Round([double]$cobertura.coverage.'branch-rate' * 100, 2)
            functions = 0
            statements = 0
        }

        # Parse per-method: each <method> has complexity and line-rate
        foreach ($package in $cobertura.coverage.packages.package) {
            foreach ($class in $package.classes.class) {
                $className = $class.name
                $fileName = $class.filename
                if (-not $fileName) { $fileName = $className }

                foreach ($method in $class.methods.method) {
                    $methodName = $method.name
                    $complexity = [int]($method.complexity)
                    if ($complexity -lt 1) { $complexity = 1 }

                    $lineRate = [double]($method.'line-rate')
                    $branchRate = if ($method.'branch-rate') { [double]($method.'branch-rate') } else { $lineRate }
                    $coveragePct = [math]::Round($branchRate * 100, 1)

                    $crap = Calculate-CRAP $complexity $coveragePct

                    # Skip constructors and trivial property accessors
                    if ($methodName -match '^\.ctor$|^get_|^set_' -and $complexity -le 1) { continue }

                    $crapResults += [PSCustomObject]@{
                        File       = $fileName
                        Function   = "$className.$methodName"
                        Line       = 0
                        Complexity = $complexity
                        Coverage   = $coveragePct
                        CRAP       = $crap
                    }
                }
            }
        }

        # Compute function-level total
        $totalStats.functions = if ($crapResults.Count -gt 0) {
            [math]::Round(($crapResults | Where-Object { $_.Coverage -gt 0 }).Count / $crapResults.Count * 100, 2)
        } else { 0 }
    }

    "python" {
        # Python: pytest-cov coverage.xml + radon cyclomatic complexity
        if (-not $CoverageDir) { $CoverageDir = "." }
        $coverageXml = Join-Path $CoverageDir "coverage.xml"

        if (-not $SkipCoverage -or -not (Test-Path $coverageXml)) {
            Write-Host "Running tests with coverage..." -ForegroundColor Cyan
            & python -m pytest --cov --cov-report=xml:$coverageXml 2>&1 | Out-Null
        }

        if (-not (Test-Path $coverageXml)) {
            Write-Host "ERROR: No coverage.xml found. Run 'pytest --cov --cov-report=xml' first." -ForegroundColor Red
            exit 1
        }

        # Check for radon
        $radonAvailable = $false
        try { & python -m radon --version 2>$null | Out-Null; $radonAvailable = $true } catch {}
        if (-not $radonAvailable) {
            try { & radon --version 2>$null | Out-Null; $radonAvailable = $true } catch {}
        }

        if (-not $radonAvailable) {
            Write-Host "ERROR: radon not found. Install with: pip install radon" -ForegroundColor Red
            exit 1
        }

        # Parse coverage XML (Cobertura format from pytest-cov)
        Write-Host "Parsing coverage.xml..." -ForegroundColor DarkGray
        [xml]$cobertura = Get-Content $coverageXml

        $totalStats = @{
            lines = [math]::Round([double]$cobertura.coverage.'line-rate' * 100, 2)
            branches = [math]::Round([double]$cobertura.coverage.'branch-rate' * 100, 2)
            functions = 0
            statements = 0
        }

        # Build file-level coverage map
        $fileCoveragePy = @{}
        foreach ($package in $cobertura.coverage.packages.package) {
            foreach ($class in $package.classes.class) {
                $fileName = $class.filename
                $branchRate = if ($class.'branch-rate') { [double]($class.'branch-rate') } else { [double]($class.'line-rate') }
                $fileCoveragePy[$fileName] = [math]::Round($branchRate * 100, 1)
            }
        }

        # Run radon for cyclomatic complexity
        Write-Host "Running radon complexity analysis..." -ForegroundColor DarkGray

        # Detect source directories
        $srcDir = if (Test-Path "src") { "src" } elseif (Test-Path "app") { "app" } else { "." }
        $radonJson = & python -m radon cc $srcDir -j 2>$null

        if ($radonJson) {
            try {
                $radonData = $radonJson | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $radonData = $null
            }

            if ($radonData) {
                foreach ($prop in $radonData.PSObject.Properties) {
                    $fileName = $prop.Name -replace '\\', '/'
                    $coverage = if ($fileCoveragePy[$fileName]) { $fileCoveragePy[$fileName] } else { 0 }

                    foreach ($fn in $prop.Value) {
                        $complexity = [int]$fn.complexity
                        $fnName = $fn.name
                        $lineno = $fn.lineno

                        $crap = Calculate-CRAP $complexity $coverage

                        $crapResults += [PSCustomObject]@{
                            File       = $fileName
                            Function   = $fnName
                            Line       = $lineno
                            Complexity = $complexity
                            Coverage   = $coverage
                            CRAP       = $crap
                        }
                    }
                }
            }
        }
    }
}

# --- Output (shared across all stacks) ---
$sorted = $crapResults | Sort-Object CRAP -Descending | Select-Object -First $Top
$aboveThreshold = @($crapResults | Where-Object { $_.CRAP -ge $Threshold })
$totalFunctions = $crapResults.Count

Write-Host ""
Write-Host "===== CRAP Score Report ($Stack) =====" -ForegroundColor Cyan
Write-Host "Formula: CRAP(m) = complexity^2 * (1 - coverage/100)^3 + complexity" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Overall Coverage:" -ForegroundColor Yellow
Write-Host "  Lines:      $($totalStats.lines)%"
Write-Host "  Branches:   $($totalStats.branches)%"
if ($totalStats.functions) { Write-Host "  Functions:  $($totalStats.functions)%" }
if ($totalStats.statements) { Write-Host "  Statements: $($totalStats.statements)%" }
Write-Host ""
Write-Host "CRAP Summary:" -ForegroundColor Yellow
Write-Host "  Total functions analyzed: $totalFunctions"
Write-Host "  Functions >= CRAP $Threshold`: $($aboveThreshold.Count)"
$maxCrap = if ($sorted.Count -gt 0) { $sorted[0].CRAP } else { 0 }
Write-Host "  Worst CRAP score: $maxCrap"
Write-Host ""

if ($Format -eq 'json') {
    $output = @{
        timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        stack = $Stack
        threshold = $Threshold
        coverage = $totalStats
        summary = @{
            totalFunctions = $totalFunctions
            aboveThreshold = $aboveThreshold.Count
            worstScore = $maxCrap
        }
        results = @($sorted | ForEach-Object {
            @{ file = $_.File; function = $_.Function; line = $_.Line; complexity = $_.Complexity; coverage = $_.Coverage; crap = $_.CRAP }
        })
    }
    $output | ConvertTo-Json -Depth 4
} elseif ($Format -eq 'csv') {
    $sorted | ConvertTo-Csv -NoTypeInformation
} else {
    # Table format
    if ($sorted.Count -eq 0) {
        Write-Host "No functions with complexity > 1 found." -ForegroundColor Green
    } else {
        Write-Host ("{0,-40} {1,-20} {2,4} {3,5} {4,6} {5,6}" -f "File", "Function", "Line", "Cplx", "Cov%", "CRAP") -ForegroundColor White
        Write-Host ("-" * 85)
        foreach ($r in $sorted) {
            $color = if ($r.CRAP -ge 30) { "Red" } elseif ($r.CRAP -ge $Threshold) { "Yellow" } else { "Green" }
            $flag = if ($r.CRAP -ge 30) { " !!!" } elseif ($r.CRAP -ge $Threshold) { " *" } else { "" }
            $displayFile = if ($r.File.Length -gt 38) { "..." + $r.File.Substring($r.File.Length - 35) } else { $r.File }
            $displayFn = if ($r.Function.Length -gt 18) { $r.Function.Substring(0, 18) + ".." } else { $r.Function }
            Write-Host ("{0,-40} {1,-20} {2,4} {3,5} {4,5}% {5,6}{6}" -f $displayFile, $displayFn, $r.Line, $r.Complexity, $r.Coverage, $r.CRAP, $flag) -ForegroundColor $color
        }
        Write-Host ""
        Write-Host "Legend: " -NoNewline
        Write-Host "!!!" -ForegroundColor Red -NoNewline
        Write-Host " = CRAP >= 30  " -NoNewline
        Write-Host "*" -ForegroundColor Yellow -NoNewline
        Write-Host " = CRAP >= $Threshold  " -NoNewline
        Write-Host "green" -ForegroundColor Green -NoNewline
        Write-Host " = below threshold"
    }
}

Write-Host ""

# Return exit code based on findings
if ($aboveThreshold.Count -gt 0) {
    exit 1
} else {
    exit 0
}
