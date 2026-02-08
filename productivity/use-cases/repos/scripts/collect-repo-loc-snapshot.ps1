<#
.SYNOPSIS
    Collects total lines of code snapshots for a repository by checking out historical commits.

.DESCRIPTION
    For each date in the range, finds the last commit before midnight, checks out that state,
    runs cloc to count lines of code, and saves the snapshot. Uses the local clone path from
    repo-config.json (READ-ONLY operations only - never commits or pushes).

.PARAMETER StartDate
    Start date for collection (YYYY-MM-DD format)

.PARAMETER EndDate
    End date for collection (YYYY-MM-DD format)

.PARAMETER RepoName
    Name of the repository (must exist in repo-config.json with localPath)

.PARAMETER Branch
    Branch to track (default: main). Falls back to master if main doesn't exist.

.EXAMPLE
    .\collect-repo-loc-snapshot.ps1 -StartDate "2026-01-01" -EndDate "2026-01-31" -RepoName "relias-assistant"

.EXAMPLE
    .\collect-repo-loc-snapshot.ps1 -StartDate "2026-01-01" -EndDate "2026-01-31" -RepoName "policy-manager" -Branch "develop"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$StartDate,
    
    [Parameter(Mandatory = $true)]
    [string]$EndDate,
    
    [Parameter(Mandatory = $true)]
    [string]$RepoName,
    
    [Parameter(Mandatory = $false)]
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

# Paths
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "..\config\repo-config.json"
$dataDir = Join-Path $scriptDir "..\data\$RepoName"

# Load config
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$repo = $config.repositories | Where-Object { $_.name -eq $RepoName -and $_.enabled }

if (-not $repo) {
    Write-Error "Repository '$RepoName' not found or not enabled in config"
    exit 1
}

if (-not $repo.localPath) {
    Write-Error "Repository '$RepoName' does not have a localPath configured"
    exit 1
}

$localPath = $repo.localPath

if (-not (Test-Path $localPath)) {
    Write-Error "Local clone not found at: $localPath"
    Write-Error "Clone using: git clone $($repo.sshCloneUrl) `"$localPath`""
    exit 1
}

# Ensure data directory exists
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

Write-Host "Collecting LOC snapshots from $StartDate to $EndDate" -ForegroundColor Cyan
Write-Host "Repository: $RepoName"
Write-Host "Local path: $localPath"
Write-Host ""

# Change to repo directory
Push-Location $localPath

try {
    # Store current state to restore later
    $originalRef = git rev-parse HEAD 2>$null
    $originalBranch = git rev-parse --abbrev-ref HEAD 2>$null
    
    # Fetch latest (read-only operation)
    Write-Host "Fetching latest changes..." -ForegroundColor Gray
    git fetch --all --quiet 2>$null
    
    # Determine target branch (check if specified branch exists, fallback to master)
    $targetBranch = "origin/$Branch"
    $branchExists = git rev-parse --verify $targetBranch 2>$null
    if (-not $branchExists) {
        $targetBranch = "origin/master"
        $masterExists = git rev-parse --verify $targetBranch 2>$null
        if (-not $masterExists) {
            Write-Error "Neither 'origin/$Branch' nor 'origin/master' branch found"
            exit 1
        }
        Write-Host "Branch '$Branch' not found, using 'master'" -ForegroundColor Yellow
    } else {
        Write-Host "Tracking branch: $Branch" -ForegroundColor Gray
    }
    
    # Parse date range
    $start = [DateTime]::ParseExact($StartDate, "yyyy-MM-dd", $null)
    $end = [DateTime]::ParseExact($EndDate, "yyyy-MM-dd", $null)
    
    $currentDate = $start
    $snapshotsCollected = 0
    $skippedDates = 0
    
    while ($currentDate -le $end) {
        $dateStr = $currentDate.ToString("yyyy-MM-dd")
        $outputFile = Join-Path $dataDir "loc-snapshot-$dateStr.json"
        
        # Find the last commit before end of this date (23:59:59) on the specified branch only
        $beforeDate = $currentDate.AddDays(1).ToString("yyyy-MM-dd")
        $lastCommit = git log --before="$beforeDate" --format="%H" -n 1 $targetBranch 2>$null
        
        if (-not $lastCommit) {
            Write-Host "  $dateStr - No commits found before this date, skipping" -ForegroundColor DarkGray
            $skippedDates++
            $currentDate = $currentDate.AddDays(1)
            continue
        }
        
        # Get commit info
        $commitDate = git log -1 --format="%ci" $lastCommit 2>$null
        $commitMsg = git log -1 --format="%s" $lastCommit 2>$null
        if ($commitMsg.Length -gt 50) { $commitMsg = $commitMsg.Substring(0, 47) + "..." }
        
        Write-Host "  $dateStr - Checking out $($lastCommit.Substring(0,7))..." -NoNewline
        
        # Checkout the commit (detached HEAD)
        git checkout --quiet $lastCommit 2>$null
        
        # Run cloc with JSON output
        # Exclude .xlf files (auto-generated i18n translation files - not authored code)
        $clocOutput = & cloc . --json --quiet --exclude-ext=xlf 2>$null | ConvertFrom-Json
        
        if (-not $clocOutput) {
            Write-Host " cloc failed" -ForegroundColor Red
            $currentDate = $currentDate.AddDays(1)
            continue
        }
        
        # Extract summary
        $summary = $clocOutput.SUM
        $totalFiles = $summary.nFiles
        $totalBlank = $summary.blank
        $totalComment = $summary.comment
        $totalCode = $summary.code
        
        # Build language breakdown
        $languages = @()
        foreach ($prop in $clocOutput.PSObject.Properties) {
            if ($prop.Name -notin @("header", "SUM")) {
                $lang = $prop.Value
                $languages += [PSCustomObject]@{
                    language = $prop.Name
                    files    = $lang.nFiles
                    blank    = $lang.blank
                    comment  = $lang.comment
                    code     = $lang.code
                }
            }
        }
        
        # Sort by code lines descending
        $languages = $languages | Sort-Object -Property code -Descending
        
        # Build snapshot object
        $snapshot = [PSCustomObject]@{
            snapshotDate    = $dateStr
            collectionTime  = (Get-Date).ToString("o")
            repository      = $RepoName
            commitSha       = $lastCommit
            commitDate      = $commitDate
            commitMessage   = $commitMsg
            summary         = [PSCustomObject]@{
                totalFiles   = $totalFiles
                blankLines   = $totalBlank
                commentLines = $totalComment
                codeLines    = $totalCode
            }
            topLanguages    = $languages | Select-Object -First 15
            allLanguages    = $languages
        }
        
        # Save to file
        $snapshot | ConvertTo-Json -Depth 10 | Set-Content $outputFile -Encoding UTF8
        
        Write-Host " $totalCode LOC ($totalFiles files)" -ForegroundColor Green
        $snapshotsCollected++
        
        $currentDate = $currentDate.AddDays(1)
    }
    
    Write-Host ""
    Write-Host "=== Collection Summary ===" -ForegroundColor Cyan
    Write-Host "Snapshots collected: $snapshotsCollected"
    Write-Host "Dates skipped: $skippedDates"
    Write-Host "Data saved to: $dataDir"
    
} finally {
    # Restore original state
    Write-Host ""
    Write-Host "Restoring repository state..." -ForegroundColor Gray
    
    if ($originalBranch -and $originalBranch -ne "HEAD") {
        git checkout --quiet $originalBranch 2>$null
    } elseif ($originalRef) {
        git checkout --quiet $originalRef 2>$null
    }
    
    Pop-Location
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
