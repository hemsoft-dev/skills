<#
.SYNOPSIS
    Collects minimal repository metadata for the repo-summarizer skill.
.DESCRIPTION
    Gathers basic metadata and top 5 contributors using GitHub CLI only.
    Resolves usernames to real names and consolidates contributors with the same identity.
    Outputs structured JSON for LLM report generation.
.PARAMETER Owner
    Repository owner (username or organization).
.PARAMETER Repo
    Repository name.
.EXAMPLE
    .\Get-RepoSummary-Minimal.ps1 -Owner "HemSoft" -Repo "hemsoft-power-ai"
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
    effortLevel = "Minimal"
    generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    repository  = @{
        owner = $Owner
        name  = $Repo
    }
}

# Get basic repo metadata
Write-Information "[36mFetching repository metadata...`e[0m"
$repoData = gh repo view "$Owner/$Repo" --json description,stargazerCount,forkCount,createdAt,pushedAt | ConvertFrom-Json

$result.repository.description = $repoData.description
$result.repository.stars = $repoData.stargazerCount
$result.repository.forks = $repoData.forkCount
$result.repository.createdAt = $repoData.createdAt
$result.repository.pushedAt = $repoData.pushedAt

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

# Get top 5 contributors (after consolidation by real name)
Write-Information "[36mFetching contributors...`e[0m"
$contributorsJson = gh api "repos/$Owner/$Repo/contributors" --paginate --jq '.[]'
$contributors = $contributorsJson | ConvertFrom-Json
$mergedContributors = Merge-ContributorsByRealName -Contributors $contributors
$result.contributors = @($mergedContributors | Select-Object -First 5 | ForEach-Object {
    @{
        realName      = $_.realName
        usernames     = $_.usernames
        contributions = $_.contributions
    }
})
$result.totalContributors = $mergedContributors.Count

# Output JSON
$result | ConvertTo-Json -Depth 10
