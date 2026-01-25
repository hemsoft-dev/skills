#Requires -Version 7.0

<#
.SYNOPSIS
    Gets GitHub and Bitbucket repository counts for Relias with delta tracking.

.DESCRIPTION
    Retrieves the current count of repositories in both GitHub (relias-engineering) 
    and Bitbucket (relias workspace), compares them to yesterday's counts, and 
    displays the deltas. Updates the tracking file with today's counts.

.PARAMETER TrackingFile
    Path to JSON file storing historical repo counts. Defaults to config/repo-counts.json.

.EXAMPLE
    Get-ReliasRepoCounts

.EXAMPLE
    Get-ReliasRepoCounts -TrackingFile "C:\path\to\counts.json"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TrackingFile
)

# Set default tracking file path
if (-not $TrackingFile) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $TrackingFile = Join-Path $scriptDir "..\config\repo-counts.json"
}

# Ensure tracking file directory exists
$trackingDir = Split-Path -Parent $TrackingFile
if (-not (Test-Path $trackingDir)) {
    New-Item -ItemType Directory -Path $trackingDir -Force | Out-Null
}

# Load yesterday's counts if file exists
$yesterdayCounts = @{
    GitHub = $null
    Bitbucket = $null
    Date = $null
}

if (Test-Path $TrackingFile) {
    try {
        $data = Get-Content $TrackingFile -Raw | ConvertFrom-Json
        $yesterdayCounts.GitHub = $data.GitHub
        $yesterdayCounts.Bitbucket = $data.Bitbucket
        $yesterdayCounts.Date = $data.Date
    }
    catch {
        Write-Warning "Failed to read tracking file: $_"
    }
}

# Get GitHub repo count
try {
    $ghOutput = gh auth switch -u fhemmerrelias 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to switch GitHub account: $ghOutput"
    }
    
    $ghRepos = gh repo list relias-engineering --limit 1000 --json name 2>&1 | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0 -and $ghRepos) {
        $todayGitHub = ($ghRepos | Measure-Object).Count
    }
    else {
        Write-Error "Failed to get GitHub repo count: $ghRepos"
        $todayGitHub = $null
    }
}
catch {
    Write-Error "Error getting GitHub repo count: $_"
    $todayGitHub = $null
}

# Get Bitbucket repo count
try {
    $bbScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "Get-BitbucketRepoCount.ps1"
    $todayBitbucket = & $bbScript -Workspace relias 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get Bitbucket repo count: $todayBitbucket"
        $todayBitbucket = $null
    }
    else {
        $todayBitbucket = [int]$todayBitbucket
    }
}
catch {
    Write-Error "Error getting Bitbucket repo count: $_"
    $todayBitbucket = $null
}

# Calculate deltas
$ghDelta = $null
$bbDelta = $null

if ($null -ne $todayGitHub -and $null -ne $yesterdayCounts.GitHub) {
    $ghDelta = $todayGitHub - $yesterdayCounts.GitHub
}

if ($null -ne $todayBitbucket -and $null -ne $yesterdayCounts.Bitbucket) {
    $bbDelta = $todayBitbucket - $yesterdayCounts.Bitbucket
}

# Format output
$output = "GitHub: $todayGitHub"
if ($null -ne $ghDelta) {
    if ($ghDelta -gt 0) {
        $output += " (+$ghDelta)"
    }
    elseif ($ghDelta -lt 0) {
        $output += " ($ghDelta)"
    }
    else {
        $output += " (0)"
    }
}

$output += ", Bitbucket: $todayBitbucket"
if ($null -ne $bbDelta) {
    if ($bbDelta -gt 0) {
        $output += " (+$bbDelta)"
    }
    elseif ($bbDelta -lt 0) {
        $output += " ($bbDelta)"
    }
    else {
        $output += " (0)"
    }
}

# Save today's counts for tomorrow
if ($null -ne $todayGitHub -and $null -ne $todayBitbucket) {
    $today = Get-Date -Format "yyyy-MM-dd"
    $saveData = @{
        Date = $today
        GitHub = $todayGitHub
        Bitbucket = $todayBitbucket
    }
    
    try {
        $saveData | ConvertTo-Json | Set-Content $TrackingFile -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to save tracking file: $_"
    }
}

# Output formatted string
Write-Output $output
