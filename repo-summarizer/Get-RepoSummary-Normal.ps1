<#
.SYNOPSIS
    Collects normal repository metadata for the repo-summarizer skill.
.DESCRIPTION
    Gathers full statistics, top 10 contributors, and activity trends using GitHub CLI only.
    Resolves usernames to real names and consolidates contributors with the same identity.
    Outputs structured JSON for LLM report generation.
.PARAMETER Owner
    Repository owner (username or organization).
.PARAMETER Repo
    Repository name.
.EXAMPLE
    .\Get-RepoSummary-Normal.ps1 -Owner "HemSoft" -Repo "hemsoft-power-ai"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo
)

$ErrorActionPreference = "Stop"

# Cache for resolved usernames to avoid duplicate API calls
$script:UserNameCache = @{}

function Get-GitHubUserRealName {
    param([string]$Username)
    
    if ($script:UserNameCache.ContainsKey($Username)) {
        return $script:UserNameCache[$Username]
    }
    
    try {
        $userData = gh api "users/$Username" --jq '.name // empty' 2>$null
        $realName = if ($userData -and $userData.Trim()) { $userData.Trim() } else { $Username }
        $script:UserNameCache[$Username] = $realName
        return $realName
    }
    catch {
        $script:UserNameCache[$Username] = $Username
        return $Username
    }
}

function Merge-ContributorsByRealName {
    param([array]$Contributors)
    
    Write-Host "Resolving contributor identities..." -ForegroundColor Cyan
    
    # First, resolve all usernames to real names
    $contributorsWithNames = $Contributors | ForEach-Object {
        $realName = Get-GitHubUserRealName -Username $_.login
        @{
            username      = $_.login
            realName      = $realName
            contributions = $_.contributions
            avatarUrl     = $_.avatar_url
        }
    }
    
    # Group by real name and merge contributions
    $merged = $contributorsWithNames | Group-Object { $_.realName } | ForEach-Object {
        $group = $_.Group
        $totalContributions = ($group | Measure-Object -Property contributions -Sum).Sum
        $usernames = @($group | ForEach-Object { $_.username })
        $primaryUser = $group | Sort-Object { $_.contributions } -Descending | Select-Object -First 1
        
        @{
            realName      = $_.Name
            usernames     = $usernames
            contributions = $totalContributions
            avatarUrl     = $primaryUser.avatarUrl
        }
    } | Sort-Object { $_.contributions } -Descending
    
    return @($merged)
}

$result = @{
    effortLevel = "Normal"
    generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    repository  = @{
        owner = $Owner
        name  = $Repo
    }
}

# Get basic repo metadata
Write-Host "Fetching repository metadata..." -ForegroundColor Cyan
$repoData = gh repo view "$Owner/$Repo" --json description,stargazerCount,forkCount,createdAt,pushedAt,primaryLanguage,licenseInfo | ConvertFrom-Json

$result.repository.description = $repoData.description
$result.repository.stars = $repoData.stargazerCount
$result.repository.forks = $repoData.forkCount
$result.repository.createdAt = $repoData.createdAt
$result.repository.pushedAt = $repoData.pushedAt
$result.repository.primaryLanguage = $repoData.primaryLanguage.name
$result.repository.license = $repoData.licenseInfo.name

# Get commit history via GitHub API
Write-Host "Fetching commit history..." -ForegroundColor Cyan
$commitsJson = gh api "repos/$Owner/$Repo/commits" --paginate --jq '.[]'
$commits = $commitsJson | ConvertFrom-Json
$result.repository.totalCommits = $commits.Count

# Get first commit date (oldest commit)
$oldestCommit = $commits | Select-Object -Last 1
$result.repository.firstCommitDate = $oldestCommit.commit.author.date

# Calculate age in days
$firstCommitDate = [datetime]::Parse($result.repository.firstCommitDate)
$result.repository.ageDays = [math]::Floor(((Get-Date) - $firstCommitDate).TotalDays)

# Get top 10 contributors (after consolidation by real name)
Write-Host "Fetching contributors..." -ForegroundColor Cyan
$contributorsJson = gh api "repos/$Owner/$Repo/contributors" --paginate --jq '.[]'
$contributors = $contributorsJson | ConvertFrom-Json
$mergedContributors = Merge-ContributorsByRealName -Contributors $contributors
$result.contributors = @($mergedContributors | Select-Object -First 10 | ForEach-Object {
    @{
        realName      = $_.realName
        usernames     = $_.usernames
        contributions = $_.contributions
        avatarUrl     = $_.avatarUrl
    }
})
$result.totalContributors = $mergedContributors.Count

# Get issue statistics
Write-Host "Fetching issue statistics..." -ForegroundColor Cyan
$issues = gh issue list -R "$Owner/$Repo" --state all --json number,state,createdAt,closedAt --limit 1000 | ConvertFrom-Json

$result.issues = @{
    total  = $issues.Count
    open   = ($issues | Where-Object { $_.state -eq "OPEN" }).Count
    closed = ($issues | Where-Object { $_.state -eq "CLOSED" }).Count
}

# Get PR statistics
Write-Host "Fetching PR statistics..." -ForegroundColor Cyan
$prs = gh pr list -R "$Owner/$Repo" --state all --json number,state,createdAt,mergedAt,closedAt --limit 1000 | ConvertFrom-Json

$result.pullRequests = @{
    total  = $prs.Count
    open   = ($prs | Where-Object { $_.state -eq "OPEN" }).Count
    merged = ($prs | Where-Object { $_.mergedAt }).Count
    closed = ($prs | Where-Object { $_.state -eq "CLOSED" -and -not $_.mergedAt }).Count
}

# Recent activity (last 30 days)
Write-Host "Analyzing recent activity..." -ForegroundColor Cyan
$thirtyDaysAgo = (Get-Date).AddDays(-30)

$recentIssues = $issues | Where-Object { [datetime]$_.createdAt -gt $thirtyDaysAgo }
$recentPRs = $prs | Where-Object { [datetime]$_.createdAt -gt $thirtyDaysAgo }
$recentCommits = $commits | Where-Object { [datetime]$_.commit.author.date -gt $thirtyDaysAgo }

$result.recentActivity = @{
    periodDays          = 30
    issuesCreated       = $recentIssues.Count
    pullRequestsCreated = $recentPRs.Count
    commits             = $recentCommits.Count
}

# Output JSON
$result | ConvertTo-Json -Depth 10
