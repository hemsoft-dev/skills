[CmdletBinding()]
param(
    [string]$Workspace = $(if ($env:BITBUCKET_WORKSPACE) { $env:BITBUCKET_WORKSPACE } else { 'relias' }),
    [string]$GitHubOwner = $(if ($env:GITHUB_OWNER) { $env:GITHUB_OWNER } else { 'relias-engineering' }),
    [string[]]$RepoPattern = @('*'),
    [int]$MaxRepos = 0,
    [int]$StaleWarningDays = 180,
    [int]$StaleCriticalDays = 365,
    [string]$OutputPath,
    [switch]$SkipGitHub,
    [int]$GitHubLimit = 1000,
    [string]$AtlassianEmail = $env:ATLASSIAN_EMAIL,
    [string]$BitbucketToken = $(if ($env:BITBUCKET_API_TOKEN) { $env:BITBUCKET_API_TOKEN } elseif ($env:BITBUCKET_API_KEY) { $env:BITBUCKET_API_KEY } else { $null }),
    [string]$BitbucketUsername = $env:BITBUCKET_USERNAME
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-ToDateTimeOffset {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return [DateTimeOffset]::Parse($Value)
}

function Get-AgeDays {
    param([AllowNull()][Nullable[DateTimeOffset]]$Timestamp)

    if ($null -eq $Timestamp) {
        return $null
    }

    return [int][Math]::Floor(([DateTimeOffset]::UtcNow - $Timestamp.ToUniversalTime()).TotalDays)
}

function Get-Staleness {
    param([AllowNull()][Nullable[int]]$AgeDays)

    if ($null -eq $AgeDays) {
        return 'No commits'
    }

    if ($AgeDays -ge $StaleCriticalDays) {
        return 'Critical'
    }

    if ($AgeDays -ge $StaleWarningDays) {
        return 'Warning'
    }

    return 'Fresh'
}

function Get-BitbucketIdentity {
    if (-not [string]::IsNullOrWhiteSpace($AtlassianEmail)) {
        return $AtlassianEmail
    }

    if (-not [string]::IsNullOrWhiteSpace($BitbucketUsername)) {
        return $BitbucketUsername
    }

    throw "Bitbucket identity not found. Set ATLASSIAN_EMAIL or BITBUCKET_USERNAME."
}

function Get-BitbucketHeaders {
    if ([string]::IsNullOrWhiteSpace($BitbucketToken)) {
        throw "Bitbucket token not found. Set BITBUCKET_API_TOKEN or BITBUCKET_API_KEY."
    }

    $identity = Get-BitbucketIdentity
    $pair = '{0}:{1}' -f $identity, $BitbucketToken
    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    return @{
        Authorization = "Basic $basic"
        Accept        = 'application/json'
    }
}

function Invoke-BitbucketPagedGet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $items = @()
    $next = $Uri

    while ($next) {
        $response = Invoke-RestMethod -Method Get -Headers $Headers -Uri $next

        if ($response.PSObject.Properties.Name -contains 'values' -and $null -ne $response.values) {
            $items += @($response.values)
        }
        else {
            $items += @($response)
        }

        if ($response.PSObject.Properties.Name -contains 'next') {
            $next = $response.next
        }
        else {
            $next = $null
        }
    }

    return $items
}

function Test-RepoPattern {
    param(
        [Parameter(Mandatory = $true)]
        $Repo,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Repo.slug -like $pattern -or $Repo.name -like $pattern -or $Repo.full_name -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-GitHubRepoIndex {
    param(
        [string]$Owner,
        [int]$Limit
    )

    if ($SkipGitHub.IsPresent) {
        return @{}
    }

    & gh auth status 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI is not authenticated. Run 'gh auth login' or use -SkipGitHub."
    }

    $json = & gh repo list $Owner --limit $Limit --json name,isArchived,pushedAt,defaultBranchRef,url 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list GitHub repos for '$Owner'."
    }

    $repos = $json | ConvertFrom-Json
    $index = @{}

    foreach ($repo in $repos) {
        $index[$repo.name.ToLowerInvariant()] = $repo
    }

    return $index
}

function Get-BitbucketCommitInfo {
    param(
        [string]$WorkspaceName,

        [Parameter(Mandatory = $true)]
        $Repo,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $defaultBranch = if ($null -ne $Repo.mainbranch) { $Repo.mainbranch.name } else { $null }

    if ([string]::IsNullOrWhiteSpace($defaultBranch)) {
        $uri = "https://api.bitbucket.org/2.0/repositories/$WorkspaceName/$($Repo.slug)/commits?pagelen=1"
    }
    else {
        $escapedBranch = [Uri]::EscapeDataString($defaultBranch)
        $uri = "https://api.bitbucket.org/2.0/repositories/$WorkspaceName/$($Repo.slug)/commits/${escapedBranch}?pagelen=1"
    }

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-RestMethod -Method Get -Headers $Headers -Uri $uri

            $commit = $null
            if ($response.PSObject.Properties.Name -contains 'values' -and $null -ne $response.values) {
                $commit = @($response.values | Select-Object -First 1)[0]
            }

            return [PSCustomObject]@{
                DefaultBranch = $defaultBranch
                Commit        = $commit
                LookupStatus  = if ($null -ne $commit) { 'OK' } else { 'No commits' }
                LookupError   = $null
            }
        }
        catch {
            $statusCode = $null
            $errorMessage = $_.Exception.Message

            if ($_.Exception.Response) {
                try {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                catch {}
            }

            if ($statusCode -in 404, 409) {
                return [PSCustomObject]@{
                    DefaultBranch = $defaultBranch
                    Commit        = $null
                    LookupStatus  = 'No commits'
                    LookupError   = $null
                }
            }

            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds (2 * $attempt)
                continue
            }

            return [PSCustomObject]@{
                DefaultBranch = $defaultBranch
                Commit        = $null
                LookupStatus  = 'Lookup error'
                LookupError   = $errorMessage
            }
        }
    }
}

function Get-MigrationStatus {
    param(
        [bool]$BitbucketArchived,
        [bool]$GitHubRepoFound
    )

    if ($GitHubRepoFound -and $BitbucketArchived) {
        return 'Likely migrated'
    }

    if ($GitHubRepoFound) {
        return 'GitHub match found'
    }

    if ($BitbucketArchived) {
        return 'Archived in Bitbucket only'
    }

    return 'Bitbucket only'
}

$bitbucketHeaders = Get-BitbucketHeaders
$githubIndex = Get-GitHubRepoIndex -Owner $GitHubOwner -Limit $GitHubLimit

$bitbucketUri = "https://api.bitbucket.org/2.0/repositories/${Workspace}?pagelen=100&sort=full_name"
$repos = Invoke-BitbucketPagedGet -Uri $bitbucketUri -Headers $bitbucketHeaders |
    Where-Object { Test-RepoPattern -Repo $_ -Patterns $RepoPattern } |
    Sort-Object slug

if ($MaxRepos -gt 0) {
    $repos = @($repos | Select-Object -First $MaxRepos)
}

if ($repos.Count -eq 0) {
    throw "No Bitbucket repositories matched the supplied filters."
}

$results = @()
$repoCount = $repos.Count

for ($index = 0; $index -lt $repoCount; $index++) {
    $repo = $repos[$index]
    $percent = [int](($index / [Math]::Max($repoCount, 1)) * 100)

    Write-Progress -Activity 'Auditing Bitbucket repositories' -Status "$($index + 1)/$repoCount $($repo.slug)" -PercentComplete $percent

    $commitInfo = Get-BitbucketCommitInfo -WorkspaceName $Workspace -Repo $repo -Headers $bitbucketHeaders
    $commit = $commitInfo.Commit

    $bitbucketLastCommitAt = $null
    if ($null -ne $commit -and $commit.PSObject.Properties.Name -contains 'date') {
        $bitbucketLastCommitAt = Convert-ToDateTimeOffset $commit.date
    }
    $bitbucketLastCommitAgeDays = Get-AgeDays $bitbucketLastCommitAt
    $bitbucketStaleness = if ($commitInfo.LookupStatus -eq 'Lookup error') { 'Lookup error' } else { Get-Staleness -AgeDays $bitbucketLastCommitAgeDays }

    $githubRepo = $null
    if (-not $SkipGitHub.IsPresent) {
        $githubRepo = $githubIndex[$repo.slug.ToLowerInvariant()]
    }

    $githubPushedAt = $null
    $githubLastPushAgeDays = $null
    if ($null -ne $githubRepo -and $null -ne $githubRepo.pushedAt) {
        $githubPushedAt = Convert-ToDateTimeOffset $githubRepo.pushedAt
        $githubLastPushAgeDays = Get-AgeDays $githubPushedAt
    }

    $bitbucketArchived = $false
    if ($repo.PSObject.Properties.Name -contains 'archived' -and $repo.archived -eq $true) {
        $bitbucketArchived = $true
    }

    $results += [PSCustomObject]@{
        BitbucketRepo            = $repo.slug
        BitbucketName            = $repo.name
        BitbucketProject         = if ($null -ne $repo.project) { $repo.project.key } else { $null }
        BitbucketArchived        = $bitbucketArchived
        BitbucketDefaultBranch   = $commitInfo.DefaultBranch
        BitbucketCommitLookupStatus = $commitInfo.LookupStatus
        BitbucketCommitLookupError = $commitInfo.LookupError
        BitbucketLastCommitAt    = if ($null -ne $bitbucketLastCommitAt) { $bitbucketLastCommitAt.ToString('o') } else { $null }
        BitbucketLastCommitAgeDays = $bitbucketLastCommitAgeDays
        BitbucketStaleness       = $bitbucketStaleness
        BitbucketUpdatedOn       = $repo.updated_on
        BitbucketUrl             = $repo.links.html.href
        GitHubRepoFound          = ($null -ne $githubRepo)
        GitHubRepo               = if ($null -ne $githubRepo) { $githubRepo.name } else { $null }
        GitHubArchived           = if ($null -ne $githubRepo) { [bool]$githubRepo.isArchived } else { $null }
        GitHubDefaultBranch      = if ($null -ne $githubRepo -and $null -ne $githubRepo.defaultBranchRef) { $githubRepo.defaultBranchRef.name } else { $null }
        GitHubPushedAt           = if ($null -ne $githubPushedAt) { $githubPushedAt.ToString('o') } else { $null }
        GitHubLastPushAgeDays    = $githubLastPushAgeDays
        GitHubUrl                = if ($null -ne $githubRepo) { $githubRepo.url } else { $null }
        MigrationStatus          = Get-MigrationStatus -BitbucketArchived $bitbucketArchived -GitHubRepoFound ($null -ne $githubRepo)
    }
}

Write-Progress -Activity 'Auditing Bitbucket repositories' -Completed

$summary = [PSCustomObject]@{
    Workspace             = $Workspace
    BitbucketRepoCount    = $results.Count
    GitHubMatchCount      = @($results | Where-Object { $_.GitHubRepoFound }).Count
    BitbucketArchivedCount = @($results | Where-Object { $_.BitbucketArchived }).Count
    StaleWarningCount     = @($results | Where-Object { $_.BitbucketStaleness -eq 'Warning' }).Count
    StaleCriticalCount    = @($results | Where-Object { $_.BitbucketStaleness -eq 'Critical' }).Count
}

Write-Host ("Bitbucket repos: {0} | GitHub matches: {1} | Bitbucket archived: {2} | Warning stale: {3} | Critical stale: {4}" -f `
    $summary.BitbucketRepoCount, `
    $summary.GitHubMatchCount, `
    $summary.BitbucketArchivedCount, `
    $summary.StaleWarningCount, `
    $summary.StaleCriticalCount)

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $extension = [IO.Path]::GetExtension($OutputPath).ToLowerInvariant()
    switch ($extension) {
        '.csv' {
            $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        }
        '.json' {
            $results | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8
        }
        default {
            throw "OutputPath must end with .csv or .json."
        }
    }

    Write-Host "Wrote audit report to $OutputPath"
}

$results
