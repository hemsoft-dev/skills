#Requires -Version 7.0
<#
.SYNOPSIS
    Gets today's productivity metrics (LOC, commits, PRs, reviews, issues).
.DESCRIPTION
    Queries GitHub API and local git repositories to calculate daily productivity metrics
    including lines of code, commits, pull requests, code reviews, and issues closed.
    Filters to commits by Franz Hemmer and variations.
#>

[CmdletBinding()]
param()

# Configuration
$AuthorPatterns = @(
    "Franz Hemmer",
    "fhemmer",
    "Franz",
    "hemmer"
)

$CodeExtensions = @(
    '.js', '.ts', '.tsx', '.jsx',
    '.py', '.cs', '.fs', '.fsx',
    '.go', '.rs', '.java', '.kt',
    '.c', '.cpp', '.h', '.hpp',
    '.ps1', '.psm1', '.psd1',
    '.rb', '.php', '.swift',
    '.scala', '.clj', '.ex', '.exs',
    '.vue', '.svelte', '.astro'
)

$ExcludePatterns = @(
    'node_modules',
    'bin',
    'obj',
    'dist',
    'build',
    '.git',
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    '*.min.js',
    '*.min.css',
    '*.generated.*',
    '*.designer.*'
)

# Get today's date range
$Today = Get-Date -Format "yyyy-MM-dd"
$StartOfDay = (Get-Date -Hour 0 -Minute 0 -Second 0).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$EndOfDay = (Get-Date -Hour 23 -Minute 59 -Second 59).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Initialize metrics
$Metrics = @{
    LinesOfCode = 0
    Commits = 0
    PullRequests = 0
    CodeReviews = 0
    IssuesClosed = 0
    Repositories = @()
    FileTypes = @{}
    SuspiciousCommits = @()
}

function Test-IsCodeFile {
    param([string]$Path)
    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    return $CodeExtensions -contains $extension
}

function Test-ShouldExclude {
    param([string]$Path)
    foreach ($pattern in $ExcludePatterns) {
        if ($Path -like "*$pattern*") { return $true }
    }
    return $false
}

# Check GitHub CLI authentication
$ghAuth = $null
try {
    $ghAuth = gh auth status 2>&1
} catch {
    Write-Warning "GitHub CLI not available or not authenticated"
}

# Query GitHub API for user's activity
if ($ghAuth -and $ghAuth -notmatch "not logged") {
    # Determine which account to use
    $accounts = gh auth status 2>&1 | Select-String "Logged in to"
    $workAccount = $accounts | Where-Object { $_ -match "fhemmerrelias" }
    $personalAccount = $accounts | Where-Object { $_ -match "HemSoft" -or $_ -match "fhemmer" }

    # Get PRs created today
    try {
        $prsCreated = gh search prs "author:@me created:$Today" --json number,repository,title,createdAt 2>$null | ConvertFrom-Json
        $Metrics.PullRequests += $prsCreated.Count
    } catch {
        Write-Verbose "Could not fetch PRs created: $_"
    }

    # Get PRs reviewed today
    try {
        $prsReviewed = gh search prs "reviewed-by:@me updated:$Today" --json number,repository,title 2>$null | ConvertFrom-Json
        $Metrics.CodeReviews += $prsReviewed.Count
    } catch {
        Write-Verbose "Could not fetch PRs reviewed: $_"
    }

    # Get issues closed today
    try {
        $issues = gh search issues "author:@me state:closed closed:$Today" --json number,repository,title 2>$null | ConvertFrom-Json
        $Metrics.IssuesClosed += $issues.Count
    } catch {
        Write-Verbose "Could not fetch issues: $_"
    }
}

# Query local git repositories
$LocalRepoPaths = [System.Collections.Generic.List[string]]::new()

@(
    "D:\github\temp\hemsoft",
    "D:\github\temp\relias",
    "D:\github",
    "D:\github\Relias",
    "C:\Users\User\.agents\skills"
) | ForEach-Object {
    if (-not [string]::IsNullOrWhiteSpace($_) -and -not $LocalRepoPaths.Contains($_)) {
        $LocalRepoPaths.Add($_)
    }
}

# Include the current working repository root when available
try {
    $currentRepoRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($currentRepoRoot)) {
        $currentRepoRoot = $currentRepoRoot.Trim()
        if (-not $LocalRepoPaths.Contains($currentRepoRoot)) {
            $LocalRepoPaths.Add($currentRepoRoot)
        }
    }
} catch {
    Write-Verbose "Not currently in a git repository."
}

foreach ($basePath in $LocalRepoPaths) {
    if (-not (Test-Path $basePath)) { continue }

    # Find all .git directories
    $gitDirs = Get-ChildItem -Path $basePath -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq ".git" }

    foreach ($gitDir in $gitDirs) {
        $repoPath = $gitDir.Parent.FullName
        Push-Location $repoPath

        try {
            # Check if this is a valid git repo
            $null = git rev-parse --git-dir 2>$null
            if ($LASTEXITCODE -ne 0) { continue }

            # Get commits by author today
            $sinceDate = "$Today 00:00"
            $untilDate = "$Today 23:59"
            $commits = git log --all --since="$sinceDate" --until="$untilDate" --author="Franz" --pretty=format:"%H|%an|%ae|%ad|%s" --date=short 2>$null

            if ([string]::IsNullOrWhiteSpace($commits)) {
                Pop-Location
                continue
            }

            $repoName = Split-Path $repoPath -Leaf
            if ($repoName -notin $Metrics.Repositories) {
                $Metrics.Repositories += $repoName
            }

            foreach ($commitLine in $commits -split "`n") {
                if (-not $commitLine) { continue }

                $parts = $commitLine -split "\|", 5
                if ($parts.Count -lt 5) { continue }

                $commitHash = $parts[0]
                $Metrics.Commits++

                # Get stats for this commit
                $stats = git show --stat --format="" $commitHash 2>$null
                $diffStat = git diff-tree --no-commit-id --numstat -r $commitHash 2>$null

                foreach ($line in $diffStat -split "`n") {
                    if (-not $line) { continue }

                    $statParts = $line -split "\t"
                    if ($statParts.Count -lt 3) { continue }

                    $added = 0
                    $deleted = 0
                    $filePath = $statParts[2]

                    if (-not [int]::TryParse($statParts[0], [ref]$added)) { $added = 0 }
                    if (-not [int]::TryParse($statParts[1], [ref]$deleted)) { $deleted = 0 }

                    # Skip non-code files and excluded paths
                    if (-not (Test-IsCodeFile $filePath)) { continue }
                    if (Test-ShouldExclude $filePath) { continue }

                    # Track file types
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    if ($ext) {
                        if (-not $Metrics.FileTypes.ContainsKey($ext)) {
                            $Metrics.FileTypes[$ext] = 0
                        }
                        $Metrics.FileTypes[$ext]++
                    }

                    # Check for suspicious commits (>1000 lines changed in single file)
                    if (($added + $deleted) -gt 1000) {
                        $Metrics.SuspiciousCommits += @{
                            Hash = $commitHash
                            File = $filePath
                            Added = $added
                            Deleted = $deleted
                            Repo = $repoName
                        }
                    }

                    $Metrics.LinesOfCode += ($added - $deleted)
                }
            }
        } catch {
            Write-Verbose "Error processing $repoPath`: $_"
        } finally {
            Pop-Location
        }
    }
}

# Output formatted results
Write-Output "### 💻 Today's Productivity"
Write-Output ""
Write-Output "| Metric | Count |"
Write-Output "|--------|-------|"
Write-Output "| Lines of Code | $($Metrics.LinesOfCode.ToString("N0")) |"
Write-Output "| Commits | $($Metrics.Commits) |"
Write-Output "| Pull Requests | $($Metrics.PullRequests) |"
Write-Output "| Code Reviews | $($Metrics.CodeReviews) |"
Write-Output "| Issues Closed | $($Metrics.IssuesClosed) |"
Write-Output ""

if ($Metrics.Repositories.Count -gt 0) {
    Write-Output "**Repositories**: $($Metrics.Repositories -join ', ')"
}

if ($Metrics.FileTypes.Count -gt 0) {
    $topTypes = $Metrics.FileTypes.GetEnumerator() |
        Sort-Object Value -Descending |
        Select-Object -First 5 |
        ForEach-Object { $_.Key }
    Write-Output "**File Types**: $($topTypes -join ', ')"
}

# Log suspicious commits to alerts if any
if ($Metrics.SuspiciousCommits.Count -gt 0) {
    Write-Output ""
    Write-Output "⚠️ **Large commits detected**: $($Metrics.SuspiciousCommits.Count) commits with >1000 line changes"

    $alertsDir = "$env:USERPROFILE\.agents\skills\alerts\active"
    if (Test-Path $alertsDir) {
        $alertFile = "$alertsDir\productivity-$Today.json"
        $Metrics.SuspiciousCommits | ConvertTo-Json | Set-Content $alertFile
    }
}
