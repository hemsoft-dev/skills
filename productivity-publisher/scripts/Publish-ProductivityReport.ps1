#Requires -Version 7.0

<#
.SYNOPSIS
    Publishes monthly productivity HTML reports to participating repos via pull requests.

.DESCRIPTION
    Copies a pre-generated monthly productivity HTML report to a repository's .relias-metrics/
    folder, configures .gitattributes to exclude from language statistics, commits the changes
    under the fhemmerrelias identity, and creates a pull request.

.PARAMETER ReportPath
    Full path to the monthly HTML report file to publish.
    Example: C:\Users\User\.claude\skills\productivity\reports\2026-01\relias-engineering\some-repo\2026-01-31_productivity.html

.PARAMETER ConfigPath
    Path to the productivity config JSON file that lists participating repos.
    Default: C:\Users\User\.claude\skills\productivity\repos\use-cases\repos.json

.PARAMETER DryRun
    If specified, performs all steps except git push and PR creation (for testing).

.EXAMPLE
    .\Publish-ProductivityReport.ps1 -ReportPath "C:\...\2026-01-31_productivity.html"

.EXAMPLE
    .\Publish-ProductivityReport.ps1 -ReportPath "C:\...\2026-01-31_productivity.html" -DryRun

.NOTES
    Author: Franz Hemmer
    Date: 2026-02-02
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "C:\Users\User\.claude\skills\productivity\repos\use-cases\repos.json",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ANSI color codes for output
$script:Colors = @{
    Reset   = "`e[0m"
    Red     = "`e[91m"
    Green   = "`e[92m"
    Yellow  = "`e[93m"
    Blue    = "`e[94m"
    Magenta = "`e[95m"
    Cyan    = "`e[96m"
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'Reset'
    )
    $colorCode = $script:Colors[$Color]
    Write-Information "$colorCode$Message$($script:Colors.Reset)" -InformationAction Continue
}

function Assert-FileExists {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path $Path)) {
        Write-ColorOutput "ERROR: $Description not found at: $Path" -Color Red
        throw "$Description not found"
    }
}

function Get-RepoInfoFromPath {
    param([string]$Path)
    
    # Expected path format: .../productivity/reports/{YYYY-MM}/{org}/{repo}/{filename}
    # Example: C:\Users\User\.claude\skills\productivity\reports\2026-01\relias-engineering\my-repo\2026-01-31_productivity.html
    
    $pathParts = $Path -split '\\'
    $reportsIndex = $pathParts.IndexOf('reports')
    
    if ($reportsIndex -eq -1 -or $reportsIndex + 3 -ge $pathParts.Count) {
        throw "Invalid report path format. Expected: .../reports/{YYYY-MM}/{org}/{repo}/{filename}"
    }
    
    $month = $pathParts[$reportsIndex + 1]
    $org = $pathParts[$reportsIndex + 2]
    $repo = $pathParts[$reportsIndex + 3]
    $filename = Split-Path $Path -Leaf
    
    return @{
        Month        = $month
        Organization = $org
        Repository   = $repo
        Filename     = $filename
        FullRepoName = "$org/$repo"
    }
}

function Get-LocalClonePath {
    param([string]$Organization, [string]$Repository)
    
    # Determine base path based on organization
    $basePath = switch -Wildcard ($Organization) {
        'relias*' { "D:\github\temp\relias" }
        'hemsoft' { "D:\github\temp\hemsoft" }
        'fhemmer' { "D:\github\temp\hemsoft" }
        default { "D:\github\temp\hemsoft" }
    }
    
    return Join-Path $basePath $Repository
}

function Test-RepoParticipation {
    param([string]$ConfigPath, [string]$RepoFullName)
    
    Assert-FileExists -Path $ConfigPath -Description "Productivity config"
    
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $repoConfig = $config | Where-Object { $_.repo -eq $RepoFullName }
    
    if (-not $repoConfig) {
        Write-ColorOutput "SKIP: Repo '$RepoFullName' not found in config" -Color Yellow
        return $false
    }
    
    if (-not $repoConfig.publish) {
        Write-ColorOutput "SKIP: Repo '$RepoFullName' does not have 'publish: true' in config" -Color Yellow
        return $false
    }
    
    return $true
}

function Sync-RepoToLatest {
    param([string]$ClonePath)
    
    Push-Location $ClonePath
    try {
        Write-ColorOutput "Syncing repo to latest..." -Color Cyan
        git fetch origin 2>&1 | Write-Verbose
        git checkout main 2>&1 | Write-Verbose
        git pull origin main 2>&1 | Write-Verbose
        Write-ColorOutput "✓ Repo synced" -Color Green
    }
    finally {
        Pop-Location
    }
}

function New-PublishBranch {
    param([string]$ClonePath, [string]$Month)
    
    $branchName = "productivity-metrics-$Month"
    
    Push-Location $ClonePath
    try {
        # Check if branch already exists
        $branchExists = git branch --list $branchName
        if ($branchExists) {
            Write-ColorOutput "Branch '$branchName' already exists. Checking out..." -Color Yellow
            git checkout $branchName 2>&1 | Write-Verbose
        }
        else {
            Write-ColorOutput "Creating new branch: $branchName" -Color Cyan
            git checkout -b $branchName 2>&1 | Write-Verbose
        }
        Write-ColorOutput "✓ Branch ready: $branchName" -Color Green
        return $branchName
    }
    finally {
        Pop-Location
    }
}

function Copy-ReportToMetricsFolder {
    param([string]$ClonePath, [string]$ReportPath)
    
    $metricsFolder = Join-Path $ClonePath ".relias-metrics"
    
    if (-not (Test-Path $metricsFolder)) {
        Write-ColorOutput "Creating .relias-metrics folder..." -Color Cyan
        New-Item -Path $metricsFolder -ItemType Directory | Out-Null
    }
    
    $filename = Split-Path $ReportPath -Leaf
    $destinationPath = Join-Path $metricsFolder $filename
    
    Write-ColorOutput "Copying report to .relias-metrics/$filename" -Color Cyan
    Copy-Item -Path $ReportPath -Destination $destinationPath -Force
    Write-ColorOutput "✓ Report copied" -Color Green
    
    return $destinationPath
}

function Set-GitAttributes {
    param([string]$ClonePath)
    
    $gitAttributesPath = Join-Path $ClonePath ".gitattributes"
    $linguistRule = ".relias-metrics/** linguist-generated=true"
    
    if (Test-Path $gitAttributesPath) {
        $content = Get-Content $gitAttributesPath -Raw
        if ($content -match [regex]::Escape($linguistRule)) {
            Write-ColorOutput ".gitattributes already configured" -Color Green
            return
        }
        Write-ColorOutput "Appending linguist rule to .gitattributes" -Color Cyan
        Add-Content -Path $gitAttributesPath -Value "`n$linguistRule"
    }
    else {
        Write-ColorOutput "Creating .gitattributes with linguist rule" -Color Cyan
        Set-Content -Path $gitAttributesPath -Value $linguistRule
    }
    
    Write-ColorOutput "✓ .gitattributes configured" -Color Green
}

function Invoke-GitCommit {
    param([string]$ClonePath, [string]$Month)
    
    Push-Location $ClonePath
    try {
        Write-ColorOutput "Staging changes..." -Color Cyan
        git add .relias-metrics/ .gitattributes 2>&1 | Write-Verbose
        
        $commitMessage = "Add productivity metrics for $Month"
        Write-ColorOutput "Committing: $commitMessage" -Color Cyan
        
        # Commit as fhemmerrelias
        git -c user.name="Franz Hemmer" -c user.email="fhemmer@relias.com" `
            commit -m $commitMessage 2>&1 | Write-Verbose
        
        Write-ColorOutput "✓ Changes committed" -Color Green
    }
    finally {
        Pop-Location
    }
}

function Invoke-GitPush {
    param([string]$ClonePath, [string]$BranchName, [switch]$DryRun)
    
    if ($DryRun) {
        Write-ColorOutput "[DRY RUN] Would push branch: $BranchName" -Color Yellow
        return
    }
    
    Push-Location $ClonePath
    try {
        Write-ColorOutput "Pushing branch to origin..." -Color Cyan
        git push origin $BranchName 2>&1 | Write-Verbose
        Write-ColorOutput "✓ Branch pushed" -Color Green
    }
    finally {
        Pop-Location
    }
}

function New-PullRequest {
    param(
        [string]$RepoFullName,
        [string]$BranchName,
        [string]$Month,
        [switch]$DryRun
    )
    
    if ($DryRun) {
        Write-ColorOutput "[DRY RUN] Would create PR for: $RepoFullName" -Color Yellow
        return
    }
    
    # Format month for display (2026-01 -> January 2026)
    $monthDate = [DateTime]::ParseExact($Month, "yyyy-MM", $null)
    $monthDisplay = $monthDate.ToString("MMMM yyyy")
    
    $title = "Monthly productivity metrics for $monthDisplay"
    $body = "Automated submission of monthly productivity metrics for $monthDisplay."
    
    Write-ColorOutput "Creating pull request..." -Color Cyan
    
    # Switch to fhemmerrelias account for work repos
    if ($RepoFullName -match '^relias') {
        $env:GH_HOST = "github.com"
        $env:GH_TOKEN = $env:GITHUB_TOKEN_FHEMMERRELIAS
    }
    
    try {
        $prUrl = gh pr create --repo $RepoFullName --base main --head $BranchName `
            --title $title --body $body 2>&1
        
        Write-ColorOutput "✓ Pull request created: $prUrl" -Color Green
        return $prUrl
    }
    catch {
        Write-ColorOutput "ERROR: Failed to create PR: $_" -Color Red
        throw
    }
}

# ============================================================================
# Main Script Execution
# ============================================================================

Write-ColorOutput "`n=== Productivity Report Publisher ===" -Color Magenta
Write-ColorOutput "Report: $ReportPath`n" -Color Cyan

# Validate inputs
Assert-FileExists -Path $ReportPath -Description "Report file"
Assert-FileExists -Path $ConfigPath -Description "Config file"

# Parse repo information from path
Write-ColorOutput "Parsing repo information..." -Color Cyan
$repoInfo = Get-RepoInfoFromPath -Path $ReportPath
Write-ColorOutput "  Organization: $($repoInfo.Organization)" -Color Blue
Write-ColorOutput "  Repository: $($repoInfo.Repository)" -Color Blue
Write-ColorOutput "  Month: $($repoInfo.Month)" -Color Blue
Write-ColorOutput "  Filename: $($repoInfo.Filename)`n" -Color Blue

# Check if repo participates in publishing
if (-not (Test-RepoParticipation -ConfigPath $ConfigPath -RepoFullName $repoInfo.FullRepoName)) {
    Write-ColorOutput "Exiting: Repo not configured for publishing" -Color Yellow
    exit 0
}

# Get local clone path
$clonePath = Get-LocalClonePath -Organization $repoInfo.Organization -Repository $repoInfo.Repository
Assert-FileExists -Path $clonePath -Description "Local clone"
Write-ColorOutput "Local clone: $clonePath`n" -Color Blue

# Sync to latest
Sync-RepoToLatest -ClonePath $clonePath

# Create/checkout branch
$branchName = New-PublishBranch -ClonePath $clonePath -Month $repoInfo.Month

# Copy report
$copiedPath = Copy-ReportToMetricsFolder -ClonePath $clonePath -ReportPath $ReportPath

# Configure .gitattributes
Set-GitAttributes -ClonePath $clonePath

# Commit changes
Invoke-GitCommit -ClonePath $clonePath -Month $repoInfo.Month

# Push branch
Invoke-GitPush -ClonePath $clonePath -BranchName $branchName -DryRun:$DryRun

# Create PR
$prUrl = New-PullRequest -RepoFullName $repoInfo.FullRepoName -BranchName $branchName `
    -Month $repoInfo.Month -DryRun:$DryRun

Write-ColorOutput "`n=== Publishing Complete ===" -Color Magenta
if (-not $DryRun) {
    Write-ColorOutput "Pull Request: $prUrl" -Color Green
}
else {
    Write-ColorOutput "[DRY RUN] No changes pushed to remote" -Color Yellow
}
