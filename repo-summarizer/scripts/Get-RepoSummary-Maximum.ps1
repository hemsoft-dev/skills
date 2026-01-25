<#
.SYNOPSIS
    Collects maximum repository metadata for the repo-summarizer skill.
.DESCRIPTION
    Performs deep analysis with historical patterns, all contributors, and detailed breakdowns using GitHub CLI only.
    Resolves usernames to real names and consolidates contributors with the same identity.
    Outputs structured JSON for LLM report generation.
.PARAMETER Owner
    Repository owner (username or organization).
.PARAMETER Repo
    Repository name.
.EXAMPLE
    .\Get-RepoSummary-Maximum.ps1 -Owner "HemSoft" -Repo "hemsoft-power-ai"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo
)

$InformationPreference = 'Continue'

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
    
    Write-Information "[36mResolving contributor identities...`e[0m"
    
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
    effortLevel = "Maximum"
    generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    repository  = @{
        owner = $Owner
        name  = $Repo
    }
}

# Get comprehensive repo metadata
Write-Information "[36mFetching repository metadata...`e[0m"
$repoData = gh repo view "$Owner/$Repo" --json description,stargazerCount,forkCount,createdAt,pushedAt,primaryLanguage,licenseInfo,homepageUrl,isArchived,isFork,watchers | ConvertFrom-Json

$result.repository.description = $repoData.description
$result.repository.stars = $repoData.stargazerCount
$result.repository.forks = $repoData.forkCount
$result.repository.watchers = $repoData.watchers.totalCount
$result.repository.createdAt = $repoData.createdAt
$result.repository.pushedAt = $repoData.pushedAt
$result.repository.primaryLanguage = $repoData.primaryLanguage.name
$result.repository.license = $repoData.licenseInfo.name
$result.repository.homepage = $repoData.homepageUrl
$result.repository.isArchived = $repoData.isArchived
$result.repository.isFork = $repoData.isFork

# Get commit history via GitHub API
Write-Information "[36mFetching commit history...`e[0m"
$commitsJson = gh api "repos/$Owner/$Repo/commits" --paginate --jq '.[]'
$commits = $commitsJson | ConvertFrom-Json
$result.repository.totalCommits = $commits.Count

# Get first commit date (oldest commit)
$oldestCommit = $commits | Select-Object -Last 1
$result.repository.firstCommitDate = $oldestCommit.commit.author.date

# Calculate age in days
$firstCommitDate = [datetime]::Parse($result.repository.firstCommitDate)
$result.repository.ageDays = [math]::Floor(((Get-Date) - $firstCommitDate).TotalDays)

# Analyze commit patterns
Write-Information "[36mAnalyzing commit patterns...`e[0m"
$commitDates = $commits | ForEach-Object { [datetime]::Parse($_.commit.author.date) }

# Commits by month
$commitsByMonth = $commitDates | Group-Object { $_.ToString("yyyy-MM") } | Sort-Object Name | ForEach-Object {
    @{
        month   = $_.Name
        commits = $_.Count
    }
}
$result.commitsByMonth = @($commitsByMonth)

# Find peak development period
$peakMonth = $commitsByMonth | Sort-Object { $_.commits } -Descending | Select-Object -First 1
$result.peakDevelopment = @{
    month   = $peakMonth.month
    commits = $peakMonth.commits
}

# Commits by day of week
$commitsByDayOfWeek = $commitDates | Group-Object { $_.DayOfWeek } | ForEach-Object {
    @{
        day     = $_.Name
        commits = $_.Count
    }
}
$result.commitsByDayOfWeek = @($commitsByDayOfWeek)

# Commits by hour
$commitsByHour = $commitDates | Group-Object { $_.Hour } | Sort-Object { [int]$_.Name } | ForEach-Object {
    @{
        hour    = [int]$_.Name
        commits = $_.Count
    }
}
$result.commitsByHour = @($commitsByHour)

# Get ALL contributors (after consolidation by real name)
Write-Information "[36mFetching all contributors...`e[0m"
$contributorsJson = gh api "repos/$Owner/$Repo/contributors" --paginate --jq '.[]'
$contributors = $contributorsJson | ConvertFrom-Json
$mergedContributors = Merge-ContributorsByRealName -Contributors $contributors
$result.contributors = @($mergedContributors | ForEach-Object {
    @{
        rank          = 0
        realName      = $_.realName
        usernames     = $_.usernames
        contributions = $_.contributions
        avatarUrl     = $_.avatarUrl
    }
})
# Add rank
for ($i = 0; $i -lt $result.contributors.Count; $i++) {
    $result.contributors[$i].rank = $i + 1
}
$result.totalContributors = $mergedContributors.Count

# Get comprehensive issue statistics
Write-Information "[36mFetching issue statistics...`e[0m"
$issues = gh issue list -R "$Owner/$Repo" --state all --json number,state,createdAt,closedAt,labels --limit 5000 | ConvertFrom-Json

$openIssues = $issues | Where-Object { $_.state -eq "OPEN" }
$closedIssues = $issues | Where-Object { $_.state -eq "CLOSED" }

$result.issues = @{
    total  = $issues.Count
    open   = $openIssues.Count
    closed = $closedIssues.Count
}

# Average time to close issues
if ($closedIssues.Count -gt 0) {
    $closeTimes = $closedIssues | Where-Object { $_.closedAt } | ForEach-Object {
        ([datetime]$_.closedAt - [datetime]$_.createdAt).TotalDays
    }
    if ($closeTimes.Count -gt 0) {
        $result.issues.avgDaysToClose = [math]::Round(($closeTimes | Measure-Object -Average).Average, 1)
        $result.issues.medianDaysToClose = [math]::Round(($closeTimes | Sort-Object)[[math]::Floor($closeTimes.Count / 2)], 1)
    }
}

# Issue labels breakdown
$allLabels = $issues | ForEach-Object { $_.labels } | Where-Object { $_ } | ForEach-Object { $_.name }
$labelCounts = $allLabels | Group-Object | Sort-Object Count -Descending | Select-Object -First 10
$result.issues.topLabels = @($labelCounts | ForEach-Object {
    @{
        label = $_.Name
        count = $_.Count
    }
})

# Get comprehensive PR statistics
Write-Information "[36mFetching PR statistics...`e[0m"
$prs = gh pr list -R "$Owner/$Repo" --state all --json number,state,createdAt,mergedAt,closedAt,author,additions,deletions --limit 5000 | ConvertFrom-Json

$openPRs = $prs | Where-Object { $_.state -eq "OPEN" }
$mergedPRs = $prs | Where-Object { $_.mergedAt }
$closedPRs = $prs | Where-Object { $_.state -eq "CLOSED" -and -not $_.mergedAt }

$result.pullRequests = @{
    total  = $prs.Count
    open   = $openPRs.Count
    merged = $mergedPRs.Count
    closed = $closedPRs.Count
}

# Average time to merge PRs
if ($mergedPRs.Count -gt 0) {
    $mergeTimes = $mergedPRs | ForEach-Object {
        ([datetime]$_.mergedAt - [datetime]$_.createdAt).TotalDays
    }
    $result.pullRequests.avgDaysToMerge = [math]::Round(($mergeTimes | Measure-Object -Average).Average, 1)
    $result.pullRequests.medianDaysToMerge = [math]::Round(($mergeTimes | Sort-Object)[[math]::Floor($mergeTimes.Count / 2)], 1)
}

# Code churn from PRs
$totalAdditions = ($prs | Measure-Object -Property additions -Sum).Sum
$totalDeletions = ($prs | Measure-Object -Property deletions -Sum).Sum
$result.pullRequests.totalAdditions = $totalAdditions
$result.pullRequests.totalDeletions = $totalDeletions

# Recent activity (last 30 days)
Write-Information "[36mAnalyzing recent activity...`e[0m"
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

# Get releases
Write-Information "[36mFetching releases...`e[0m"
$releasesJson = gh api "repos/$Owner/$Repo/releases" --paginate --jq '.[]' 2>$null
$releases = if ($releasesJson) { $releasesJson | ConvertFrom-Json } else { @() }
if ($releases -and $releases.Count -gt 0) {
    $result.releases = @{
        total  = $releases.Count
        latest = @{
            name        = $releases[0].name
            tag         = $releases[0].tag_name
            publishedAt = $releases[0].published_at
        }
    }
}

# Get languages breakdown
Write-Information "[36mFetching language breakdown...`e[0m"
$languages = gh api "repos/$Owner/$Repo/languages" | ConvertFrom-Json
$totalBytes = ($languages.PSObject.Properties | Measure-Object -Property Value -Sum).Sum
$result.languages = @($languages.PSObject.Properties | ForEach-Object {
    @{
        language   = $_.Name
        bytes      = $_.Value
        percentage = [math]::Round(($_.Value / $totalBytes) * 100, 1)
    }
} | Sort-Object { $_.bytes } -Descending)

# Output JSON
$result | ConvertTo-Json -Depth 10
