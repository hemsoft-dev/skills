[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepositoryPath = "."
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Get-CommandSnapshot {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        return [pscustomobject]@{
            Installed = $false
            Path      = $null
        }
    }

    return [pscustomobject]@{
        Installed = $true
        Path      = $command.Source
    }
}

function Get-SonarConfiguration {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$RelativeFiles
    )

    $properties = [ordered]@{}
    foreach ($relativeFile in $RelativeFiles) {
        $fullPath = Join-Path $Root ($relativeFile -replace "/", [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            continue
        }

        foreach ($line in Get-Content -LiteralPath $fullPath -ErrorAction SilentlyContinue) {
            if ($line -match '^\s*(sonar\.(?:projectKey|organization|region|host\.url))\s*=\s*(.*?)\s*$') {
                $key = $Matches[1]
                if (-not $properties.Contains($key)) {
                    $properties[$key] = $Matches[2]
                }
            }
        }
    }

    return [pscustomobject]$properties
}

$resolvedInput = (Resolve-Path -LiteralPath $RepositoryPath).Path
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $gitCommand) {
    throw "git is required but was not found on PATH."
}

$rootOutput = @(& git -C $resolvedInput rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or $rootOutput.Count -eq 0) {
    throw "The path is not inside a git repository: $resolvedInput"
}

$root = (Resolve-Path -LiteralPath $rootOutput[0]).Path
$branchOutput = @(& git -C $root branch --show-current 2>$null)
$branch = if ($branchOutput.Count -gt 0) { [string]$branchOutput[0] } else { "" }

$remoteUrls = @()
$remoteNames = @(& git -C $root remote 2>$null)
foreach ($remoteName in $remoteNames) {
    $urls = @(& git -C $root remote get-url --all $remoteName 2>$null)
    foreach ($url in $urls) {
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            $remoteUrls += [string]$url
        }
    }
}
$remoteUrls = @($remoteUrls | Sort-Object -Unique)

$trackedFiles = @(& git -C $root ls-files 2>$null)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to list tracked files in $root."
}

$sonarConfigFiles = @($trackedFiles | Where-Object {
    $_ -match '(^|/)(sonar-project\.properties|SonarQube\.Analysis\.xml)$' -or
    $_ -match '(^|/)[^/]*sonar[^/]*\.(yml|yaml|properties)$'
} | Sort-Object -Unique)

$dotNetBuildFiles = @($trackedFiles | Where-Object {
    $_ -match '\.(csproj|vbproj|props|targets)$'
})
$csharpAnalyzerFiles = @()
$visualBasicAnalyzerFiles = @()
foreach ($relativeFile in $dotNetBuildFiles) {
    $fullPath = Join-Path $root ($relativeFile -replace "/", [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    $content = Get-Content -LiteralPath $fullPath -Raw -ErrorAction SilentlyContinue
    if ($content -match 'SonarAnalyzer\.CSharp') {
        $csharpAnalyzerFiles += $relativeFile
    }
    if ($content -match 'SonarAnalyzer\.VisualBasic') {
        $visualBasicAnalyzerFiles += $relativeFile
    }
}
$csharpAnalyzerFiles = @($csharpAnalyzerFiles | Sort-Object -Unique)
$visualBasicAnalyzerFiles = @($visualBasicAnalyzerFiles | Sort-Object -Unique)

$ciCandidates = @($trackedFiles | Where-Object {
    $_ -match '^\.github/workflows/.+\.(yml|yaml)$' -or
    $_ -match '(^|/)(azure-pipelines[^/]*|bitbucket-pipelines|\.gitlab-ci)\.(yml|yaml)$' -or
    $_ -match '(^|/)(pipelines|\.azuredevops)/.+\.(yml|yaml)$' -or
    $_ -match '(^|/)Jenkinsfile$'
})

$sonarCiFiles = @()
foreach ($relativeFile in $ciCandidates) {
    $fullPath = Join-Path $root ($relativeFile -replace "/", [IO.Path]::DirectorySeparatorChar)
    if ((Test-Path -LiteralPath $fullPath -PathType Leaf) -and
        (Select-String -LiteralPath $fullPath -Pattern 'sonar' -Quiet -ErrorAction SilentlyContinue)) {
        $sonarCiFiles += $relativeFile
    }
}
$sonarCiFiles = @($sonarCiFiles | Sort-Object -Unique)

$projectTypes = @()
if ($trackedFiles -match '\.(sln|slnx|csproj|vbproj)$') { $projectTypes += ".NET" }
if ($trackedFiles -match '(^|/)pom\.xml$') { $projectTypes += "Maven" }
if ($trackedFiles -match '(^|/)(build\.gradle(\.kts)?|settings\.gradle(\.kts)?|gradlew)$') { $projectTypes += "Gradle" }
if ($trackedFiles -match '(^|/)package\.json$') { $projectTypes += "Node/npm" }
if ($trackedFiles -match '\.(c|cc|cpp|cxx|h|hh|hpp|hxx)$') { $projectTypes += "C/C++" }
if ($projectTypes.Count -eq 0) { $projectTypes += "Other or undetected" }

$sonarProperties = Get-SonarConfiguration -Root $root -RelativeFiles $sonarConfigFiles
$reliasEvidence = @()
foreach ($url in $remoteUrls) {
    if ($url -match '(?i)(relias-engineering|bitbucket\.org[/:]relias(?:/|$))') {
        $reliasEvidence += "remote:$url"
    }
}
if ($null -ne $sonarProperties.PSObject.Properties['sonar.organization'] -and
    $sonarProperties.'sonar.organization' -match '^(relias|relias-github)$') {
    $reliasEvidence += "sonar.organization:$($sonarProperties.'sonar.organization')"
}
$reliasEvidence = @($reliasEvidence | Sort-Object -Unique)

$dotnetToolVersion = $null
$dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
if ($null -ne $dotnetCommand) {
    $toolLines = @(& dotnet tool list --global 2>$null)
    foreach ($line in $toolLines) {
        if ($line -match '^dotnet-sonarscanner\s+(\S+)\s+') {
            $dotnetToolVersion = $Matches[1]
            break
        }
    }
}

$warnings = @()
if ($reliasEvidence.Count -eq 0) {
    $warnings += "Relias ownership was not proven. Do not run or configure Sonar until ownership is confirmed."
}
if ($sonarCiFiles.Count -gt 0) {
    $warnings += "CI-based Sonar analysis exists. Confirm automatic analysis is disabled before running that CI configuration."
}
if (-not (Test-Path Env:SONAR_TOKEN)) {
    $warnings += "SONAR_TOKEN is not present in this process environment."
}
if ($sonarConfigFiles.Count -eq 0 -and $sonarCiFiles.Count -eq 0) {
    $warnings += "No tracked Sonar configuration or Sonar-enabled CI file was detected."
}
if ($csharpAnalyzerFiles.Count -gt 0 -or $visualBasicAnalyzerFiles.Count -gt 0) {
    $warnings += "A standalone SonarAnalyzer package reference was detected. Its local compiler findings are not a SonarQube quality gate or proof of the scanner's server-selected rule profile."
}

$result = [ordered]@{
    Repository = [ordered]@{
        Root             = $root
        Branch           = $branch
        Remotes          = $remoteUrls
        ProjectTypes     = $projectTypes
        IsVerifiedRelias = ($reliasEvidence.Count -gt 0)
        ReliasEvidence   = $reliasEvidence
    }
    Sonar = [ordered]@{
        ConfigurationFiles = $sonarConfigFiles
        CiFiles            = $sonarCiFiles
        Properties         = $sonarProperties
        LikelyMode         = if ($sonarCiFiles.Count -gt 0) { "CI-based" } else { "Unknown; check SonarQube Cloud Analysis Method" }
        TokenPresent       = [bool](Test-Path Env:SONAR_TOKEN)
    }
    StandaloneAnalyzers = [ordered]@{
        CSharpFiles       = $csharpAnalyzerFiles
        VisualBasicFiles = $visualBasicAnalyzerFiles
    }
    Tools = [ordered]@{
        DotNetSonarScanner = [ordered]@{
            Command = Get-CommandSnapshot -Name "dotnet-sonarscanner"
            GlobalToolVersion = $dotnetToolVersion
        }
        SonarScannerCli = Get-CommandSnapshot -Name "sonar-scanner"
        DotNet          = Get-CommandSnapshot -Name "dotnet"
        Java            = Get-CommandSnapshot -Name "java"
        Maven           = Get-CommandSnapshot -Name "mvn"
        Gradle          = Get-CommandSnapshot -Name "gradle"
    }
    Warnings = $warnings
}

$result | ConvertTo-Json -Depth 7
