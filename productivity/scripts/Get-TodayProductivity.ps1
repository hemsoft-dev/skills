#Requires -Version 7.0
<#
.SYNOPSIS
    Gets productivity metrics for a given date (LOC, commits, PRs, reviews, issues).
.DESCRIPTION
    Queries GitHub API (across all known accounts) and local git repositories to
    calculate daily productivity metrics. All times are interpreted as US Eastern.

    Deduplicates commits by SHA to avoid double-counting repos found under
    multiple search roots. Uses explicit author emails/usernames to avoid
    matching unrelated committers.
.PARAMETER Date
    The date to report on in yyyy-MM-dd format. Defaults to today in EST/EDT.
.EXAMPLE
    .\Get-TodayProductivity.ps1
    .\Get-TodayProductivity.ps1 -Date 2026-04-10
#>

[CmdletBinding()]
param(
    [string]$Date
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Timezone: Always use US Eastern
# ---------------------------------------------------------------------------
$Eastern = [System.TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')

if (-not $Date) {
    $nowEastern = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $Eastern)
    $Date = $nowEastern.ToString('yyyy-MM-dd')
}

$ParsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$StartEST   = [datetime]::new($ParsedDate.Year, $ParsedDate.Month, $ParsedDate.Day, 0, 0, 0)
$EndEST     = [datetime]::new($ParsedDate.Year, $ParsedDate.Month, $ParsedDate.Day, 23, 59, 59)
$StartUTC   = [System.TimeZoneInfo]::ConvertTimeToUtc($StartEST, $Eastern)
$EndUTC     = [System.TimeZoneInfo]::ConvertTimeToUtc($EndEST, $Eastern)
# ISO strings available for consumers that need them
# $StartISO = $StartUTC.ToString('yyyy-MM-ddTHH:mm:ssZ')
# $EndISO   = $EndUTC.ToString('yyyy-MM-ddTHH:mm:ssZ')

# ---------------------------------------------------------------------------
# Identity: All known accounts / emails
# ---------------------------------------------------------------------------
$GitHubUsernames = @('fhemmerrelias', 'HemSoft', 'fhemmer2-relias')

# Emails and name patterns used in git commits across all machines
$GitAuthorPatterns = @(
    'franz_hemmer@hotmail.com',
    'fhemmer@relias.com',
    'Franz Hemmer'
)

# ---------------------------------------------------------------------------
# File classification
# ---------------------------------------------------------------------------
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
    'node_modules', 'bin', 'obj', 'dist', 'build', '.git',
    'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml',
    '*.min.js', '*.min.css', '*.generated.*', '*.designer.*'
)

function Test-IsCodeFile {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    return $CodeExtensions -contains $ext
}

function Test-ShouldExclude {
    param([string]$Path)
    foreach ($p in $ExcludePatterns) {
        if ($Path -like "*$p*") { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Metrics accumulator
# ---------------------------------------------------------------------------
$Metrics = @{
    LinesOfCode       = 0
    Commits            = 0
    PullRequests       = 0
    CodeReviews        = 0
    IssuesClosed       = 0
    Repositories       = [System.Collections.Generic.List[string]]::new()
    FileTypes          = @{}
    SuspiciousCommits  = @()
}

# Global set of seen commit SHAs to prevent double-counting
$SeenCommits = [System.Collections.Generic.HashSet[string]]::new()

# ---------------------------------------------------------------------------
# GitHub API queries (across all accounts)
# ---------------------------------------------------------------------------
$ghAvailable = $false
try {
    # Use gh auth token to check the active account only (gh auth status
    # exits non-zero if ANY account has issues, even inactive ones)
    $null = gh auth token 2>&1
    $ghAvailable = ($LASTEXITCODE -eq 0)
} catch { Write-Verbose "gh auth token check failed: $_" }

if ($ghAvailable) {
    # -----------------------------------------------------------------------
    # Strategy: Use gh search API for PRs, reviews, and issues. Search a
    # 3-day date window (PrevDay..NextDay) to cover EST/EDT→UTC offset,
    # then filter results precisely against EST boundaries.
    # -----------------------------------------------------------------------

    # Deduplicate across accounts
    $SeenPRs = [System.Collections.Generic.HashSet[string]]::new()
    $SeenReviews = [System.Collections.Generic.HashSet[string]]::new()
    $SeenIssues = [System.Collections.Generic.HashSet[string]]::new()

    $PrevDay = $ParsedDate.AddDays(-1).ToString('yyyy-MM-dd')
    $NextDay = $ParsedDate.AddDays(1).ToString('yyyy-MM-dd')

    # Issues closed on $Date (EST)
    foreach ($user in $GitHubUsernames) {
        try {
            $raw = gh search issues --author $user --state closed `
                --updated "$PrevDay..$NextDay" --limit 100 `
                --json number,repository,title,closedAt 2>$null
            if ($raw) {
                $issues = $raw | ConvertFrom-Json
                $TargetDate = $ParsedDate.Date
                $filtered = $issues | Where-Object {
                    try {
                        $closedUtc = ([datetime]$_.closedAt).ToUniversalTime()
                        $closedEst = [System.TimeZoneInfo]::ConvertTimeFromUtc($closedUtc, $Eastern)
                        $closedEst.Date -eq $TargetDate
                    } catch { $false }
                }
                foreach ($issue in $filtered) {
                    $issueKey = "$($issue.repository.nameWithOwner)#$($issue.number)"
                    if ($SeenIssues.Add($issueKey)) {
                        $Metrics.IssuesClosed++
                    }
                }
            }
        } catch { Write-Verbose "Issues for ${user}: $_" }
    }
}

# ---------------------------------------------------------------------------
# Local git repositories
# ---------------------------------------------------------------------------
$SearchRoots = @(
    'D:\github\temp\hemsoft',
    'D:\github\temp\relias',
    'D:\github',
    'D:\github\Relias',
    'C:\Users\User\.agents\skills'
)

# Also include the current working directory if it's a repo
try {
    $cwd = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $cwd) { $SearchRoots += $cwd.Trim() }
} catch { Write-Verbose "CWD repo detection failed: $_" }

# Discover all repos under search roots, deduplicate by resolved path
$RepoPathSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($root in $SearchRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Path $root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq '.git' } |
        ForEach-Object {
            $resolved = $_.Parent.FullName
            $null = $RepoPathSet.Add($resolved)
        }
}

# Build the git --author flags (one per pattern)
$authorArgs = $GitAuthorPatterns | ForEach-Object { "--author=$_" }

# EST boundaries as git-compatible strings
$sinceStr = $StartUTC.ToString('yyyy-MM-ddTHH:mm:ss+00:00')
$untilStr = $EndUTC.ToString('yyyy-MM-ddTHH:mm:ss+00:00')

foreach ($repoPath in $RepoPathSet) {
    Push-Location $repoPath
    try {
        $null = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -ne 0) { continue }

        # Query with all author patterns; git log uses OR across --author flags
        $commits = git log --all --since="$sinceStr" --until="$untilStr" `
            $authorArgs `
            --pretty=format:"%H" 2>$null

        if ([string]::IsNullOrWhiteSpace($commits)) { continue }

        $repoName = Split-Path $repoPath -Leaf
        $repoAdded = $false

        foreach ($hash in ($commits -split "`n")) {
            $hash = $hash.Trim()
            if (-not $hash -or $hash.Length -ne 40) { continue }

            # Deduplicate across repos (e.g. same repo found under D:\github and D:\github\Relias)
            if (-not $SeenCommits.Add($hash)) { continue }

            if (-not $repoAdded) {
                $Metrics.Repositories.Add($repoName)
                $repoAdded = $true
            }

            $Metrics.Commits++

            # Diff stats
            $diffStat = git diff-tree --no-commit-id --numstat -r $hash 2>$null
            foreach ($line in ($diffStat -split "`n")) {
                if (-not $line) { continue }
                $parts = $line -split "\t"
                if ($parts.Count -lt 3) { continue }

                $added = 0; $deleted = 0
                $fp = $parts[2]

                if (-not [int]::TryParse($parts[0], [ref]$added))   { $added = 0 }
                if (-not [int]::TryParse($parts[1], [ref]$deleted)) { $deleted = 0 }

                if (-not (Test-IsCodeFile $fp)) { continue }
                if (Test-ShouldExclude $fp) { continue }

                $ext = [System.IO.Path]::GetExtension($fp).ToLower()
                if ($ext) {
                    if (-not $Metrics.FileTypes.ContainsKey($ext)) { $Metrics.FileTypes[$ext] = 0 }
                    $Metrics.FileTypes[$ext]++
                }

                if (($added + $deleted) -gt 1000) {
                    $Metrics.SuspiciousCommits += @{
                        Hash = $hash; File = $fp
                        Added = $added; Deleted = $deleted
                        Repo = $repoName
                    }
                }

                $Metrics.LinesOfCode += ($added - $deleted)
            }
        }
    } catch {
        Write-Verbose "Error processing ${repoPath}: $_"
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# GitHub Search API: PRs merged and Code Reviews (across all repos)
# ---------------------------------------------------------------------------
if ($ghAvailable) {
    # --- PRs authored and merged on $Date (EST) ---
    foreach ($user in $GitHubUsernames) {
        try {
            $raw = gh search prs --author $user --merged `
                --merged-at "$PrevDay..$NextDay" `
                --limit 100 --json number,repository,closedAt 2>$null
            if ($raw) {
                $prs = ($raw -join "`n") | ConvertFrom-Json
                foreach ($pr in $prs) {
                    $prKey = "$($pr.repository.nameWithOwner)#$($pr.number)"
                    if (-not $SeenPRs.Add($prKey)) { continue }

                    $closedUtc = ([datetime]$pr.closedAt).ToUniversalTime()
                    if ($closedUtc -ge $StartUTC -and $closedUtc -le $EndUTC) {
                        $Metrics.PullRequests++
                    }
                }
            }
        } catch { Write-Verbose "Merged PRs for ${user}: $_" }
    }

    # --- Code reviews submitted on $Date (EST) ---
    # Search for candidate PRs reviewed by user, then verify each review date
    foreach ($user in $GitHubUsernames) {
        try {
            $raw = gh search prs --reviewed-by $user `
                --updated "$PrevDay..$NextDay" `
                --limit 100 --json number,repository 2>$null
            if ($raw) {
                $prs = ($raw -join "`n") | ConvertFrom-Json
                foreach ($pr in $prs) {
                    $prKey = "$($pr.repository.nameWithOwner)#$($pr.number)"
                    if (-not $SeenReviews.Add($prKey)) { continue }

                    # Verify actual review date via REST API
                    $nwo = $pr.repository.nameWithOwner
                    $num = $pr.number
                    $escapedUser = $user.Replace('"', '\"')
                    $jqFilter = '.[] | select(.user.login == "' + $escapedUser + '") | .submitted_at'
                    try {
                        $reviewsRaw = gh api "repos/$nwo/pulls/$num/reviews" `
                            --jq $jqFilter 2>$null
                        if ($reviewsRaw) {
                            foreach ($ts in ($reviewsRaw -split "`n")) {
                                $ts = $ts.Trim().Trim('"')
                                if (-not $ts) { continue }
                                try {
                                    $reviewUtc = ([datetime]$ts).ToUniversalTime()
                                    if ($reviewUtc -ge $StartUTC -and $reviewUtc -le $EndUTC) {
                                        $Metrics.CodeReviews++
                                        break
                                    }
                                } catch { Write-Verbose "Date parse for review on ${nwo}#${num}: $_" }
                            }
                        }
                    } catch { Write-Verbose "Review check for ${nwo}#${num}: $_" }
                }
            }
        } catch { Write-Verbose "Reviews for ${user}: $_" }
    }
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
$locSign = if ($Metrics.LinesOfCode -ge 0) { '+' } else { '' }

Write-Output "### 💻 Today's Productivity"
Write-Output ""
Write-Output "| Metric | Count |"
Write-Output "|--------|-------|"
Write-Output "| Lines of Code | ${locSign}$($Metrics.LinesOfCode.ToString('N0')) |"
Write-Output "| Commits | $($Metrics.Commits) |"
Write-Output "| Pull Requests Merged | $($Metrics.PullRequests) |"
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

if ($Metrics.SuspiciousCommits.Count -gt 0) {
    Write-Output ""
    Write-Output "⚠️ **Large commits detected**: $($Metrics.SuspiciousCommits.Count) commits with >1000 line changes"
    $alertsDir = "$env:USERPROFILE\.agents\skills\alerts\active"
    if (Test-Path $alertsDir) {
        $alertFile = "$alertsDir\productivity-$Date.json"
        $Metrics.SuspiciousCommits | ConvertTo-Json | Set-Content $alertFile
    }
}
