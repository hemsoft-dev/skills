#Requires -Version 7.0
<#
.SYNOPSIS
    Collects org-wide user productivity metrics into one JSON file.
.DESCRIPTION
    Enumerates members of the relias-engineering organization, walks each
    non-archived, non-forked repository once to aggregate commits, pull
    requests, issues, review activity, and workflow runs by user, and then
    enriches the result with per-user premium request totals from the GitHub
    billing API.

    This is the primary org-wide user productivity script. It produces one JSON
    payload containing all collected metrics. Premium requests are included by
    default; use SkipPremiumRequests only when a faster partial run is needed.
.PARAMETER Since
    Inclusive start date for the reporting window. Defaults to the first day of
    the current month at midnight.
.PARAMETER Until
    Inclusive end timestamp for the reporting window. Defaults to the current time.
.PARAMETER OutputPath
    Path to the JSON file to create. Defaults to
    org-user-productivity-relias-engineering-{date}.json in the current directory.
.PARAMETER UserLimit
    Optional maximum number of users to include. Useful for validation runs.
.PARAMETER RepoLimit
    Optional maximum number of repositories to process. Useful for validation runs.
.PARAMETER SkipPremiumRequests
    Skip per-user premium request enrichment. Use this only for faster partial runs.
.EXAMPLE
    .\Get-AllOrgUserProductivity.ps1
.EXAMPLE
    .\Get-AllOrgUserProductivity.ps1 -UserLimit 10 -RepoLimit 5
.EXAMPLE
    .\Get-AllOrgUserProductivity.ps1 -SkipPremiumRequests
#>

[CmdletBinding()]
param(
    [datetime]$Since = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0),

    [datetime]$Until = (Get-Date),

    [string]$OutputPath,

    [ValidateRange(1, 10000)]
    [int]$UserLimit = 0,

    [ValidateRange(1, 10000)]
    [int]$RepoLimit = 0,

    [switch]$SkipPremiumRequests
)

$ErrorActionPreference = 'Stop'

$Organization = 'relias-engineering'
$Enterprise = 'bertelsmann'
$SinceUtc = $Since.ToUniversalTime()
$UntilUtc = $Until.ToUniversalTime()

if ($Since -gt $Until) {
    throw 'Since must be earlier than or equal to Until.'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $reportDate = Get-Date -Format 'yyyy-MM-dd'
    $OutputPath = Join-Path (Get-Location) "org-user-productivity-$Organization-$reportDate.json"
}

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$Headers,

        [switch]$AllowFailure
    )

    $arguments = @('api')
    if ($null -ne $Headers) {
        foreach ($header in $Headers) {
            $arguments += @('-H', $header)
        }
    }
    $arguments += $Path

    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $output = & gh @arguments 2> $stderrFile
        $stderrOutput = Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue
    }
    finally {
        if ([System.IO.File]::Exists($stderrFile)) {
            [System.IO.File]::Delete($stderrFile)
        }
    }

    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $null
        }

        $errorMessage = $stderrOutput
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = ($output | Out-String).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = "GitHub API call failed for '$Path'."
        }

        throw $errorMessage
    }

    if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Test-IsWithinRange {
    param(
        [Parameter(Mandatory)]
        [datetime]$Value,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End
    )

    return $Value -ge $Start -and $Value -le $End
}

function New-UserMetricRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [string]$FullName,

        [string]$Email,

        [string]$ProfileUrl
    )

    return [PSCustomObject]@{
        Username          = $Username
        FullName          = $FullName
        Email             = $Email
        ProfileUrl        = $ProfileUrl
        StartDate         = $Since.ToString('yyyy-MM-dd')
        EndDate           = $Until.ToString('yyyy-MM-dd HH:mm')
        PremiumRequests   = $null
        Commits           = 0
        LinesAdded        = 0
        LinesDeleted      = 0
        NetLOC            = 0
        TotalLinesChanged = 0
        OpenPRs           = 0
        MergedPRs         = 0
        ClosedPRs         = 0
        ApprovedReviews   = 0
        CommentReviews    = 0
        OpenIssues        = 0
        ClosedIssues      = 0
        WorkflowRuns      = 0
    }
}

function Get-OrganizationMembers {
    $page = 1
    $members = [System.Collections.Generic.List[object]]::new()

    do {
        Write-Information "Loading organization members page $page..." -InformationAction Continue
        $response = Invoke-GhApiJson -Path "/orgs/$Organization/members?per_page=100&page=$page"
        $batch = @($response)
        foreach ($member in $batch) {
            if ($null -ne $member -and -not [string]::IsNullOrWhiteSpace($member.login)) {
                $members.Add($member)
            }
        }

        $page++
    } while ($batch.Count -eq 100)

    $distinctMembers = @(
        $members |
            Group-Object -Property login |
            ForEach-Object { $_.Group[0] } |
            Sort-Object -Property login
    )

    if ($UserLimit -gt 0) {
        return @($distinctMembers | Select-Object -First $UserLimit)
    }

    return $distinctMembers
}

function Get-UserIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$Username
    )

    $githubUser = Invoke-GhApiJson -Path "/users/$Username" -AllowFailure
    if ($null -eq $githubUser) {
        return [PSCustomObject]@{
            FullName   = $null
            Email      = $null
            ProfileUrl = $null
        }
    }

    return [PSCustomObject]@{
        FullName   = $githubUser.name
        Email      = $githubUser.email
        ProfileUrl = $githubUser.html_url
    }
}

function Get-RepositoryList {
    $repositories = @(
        gh repo list $Organization --limit 500 --json name,isArchived,isFork |
            ConvertFrom-Json |
            Where-Object { -not $_.isArchived -and -not $_.isFork } |
            Sort-Object -Property name
    )

    if ($RepoLimit -gt 0) {
        return @($repositories | Select-Object -First $RepoLimit)
    }

    return $repositories
}

function Get-CoreRateState {
    $rateLimit = Invoke-GhApiJson -Path '/rate_limit'
    return [PSCustomObject]@{
        Remaining = [int]$rateLimit.resources.core.remaining
        ResetEpoch = [int64]$rateLimit.resources.core.reset
    }
}

function Wait-ForCoreBudget {
    param(
        [Parameter(Mandatory)]
        [ref]$RemainingCalls,

        [Parameter(Mandatory)]
        [ref]$ResetEpoch,

        [int]$Threshold = 5
    )

    if ($RemainingCalls.Value -gt $Threshold) {
        return
    }

    $rateState = Get-CoreRateState
    $RemainingCalls.Value = $rateState.Remaining
    $ResetEpoch.Value = $rateState.ResetEpoch

    if ($RemainingCalls.Value -gt $Threshold) {
        return
    }

    $resetTime = [DateTimeOffset]::FromUnixTimeSeconds($ResetEpoch.Value).LocalDateTime
    $sleepSeconds = [math]::Ceiling(($resetTime - (Get-Date)).TotalSeconds) + 5
    if ($sleepSeconds -gt 0) {
        Write-Information "Core limit nearly exhausted. Sleeping until $resetTime..." -InformationAction Continue
        Start-Sleep -Seconds $sleepSeconds
    }

    $rateState = Get-CoreRateState
    $RemainingCalls.Value = $rateState.Remaining
    $ResetEpoch.Value = $rateState.ResetEpoch
}

function Add-PremiumRequestMetrics {
    param(
        [Parameter(Mandatory)]
        [hashtable]$UserMap
    )

    $headers = @('Accept: application/vnd.github+json')
    $rateState = Get-CoreRateState
    $remainingCalls = $rateState.Remaining
    $resetEpoch = $rateState.ResetEpoch
    $usernames = @($UserMap.Keys | Sort-Object)
    $totalUsers = $usernames.Count
    $userIndex = 0

    foreach ($username in $usernames) {
        $userIndex++
        $percentComplete = [int][math]::Floor((($userIndex - 1) / [math]::Max($totalUsers, 1)) * 100)
        Write-Progress -Activity 'Collecting premium requests' -Status "[$userIndex/$totalUsers] $username | Core remaining: $remainingCalls" -PercentComplete $percentComplete -CurrentOperation 'Querying daily billing usage'
        Write-Information "[Premium $userIndex/$totalUsers] $username" -InformationAction Continue

        $total = 0.0
        for ($date = $Since.Date; $date -le $Until.Date; $date = $date.AddDays(1)) {
            Wait-ForCoreBudget -RemainingCalls ([ref]$remainingCalls) -ResetEpoch ([ref]$resetEpoch)

            $queryString = @(
                "year=$($date.Year)",
                "month=$($date.Month)",
                "day=$($date.Day)",
                "user=$([System.Uri]::EscapeDataString($username))",
                'product=Copilot'
            ) -join '&'

            $path = "/enterprises/$Enterprise/settings/billing/premium_request/usage?$queryString"
            $response = Invoke-GhApiJson -Path $path -Headers $headers -AllowFailure
            $remainingCalls--

            if ($null -eq $response) {
                continue
            }

            foreach ($item in @($response.usageItems)) {
                if ($null -ne $item.grossQuantity) {
                    $total += [double]$item.grossQuantity
                }
            }
        }

        $UserMap[$username].PremiumRequests = [math]::Round($total, 2)
        $completedPercent = [int][math]::Floor(($userIndex / [math]::Max($totalUsers, 1)) * 100)
        Write-Progress -Activity 'Collecting premium requests' -Status "[$userIndex/$totalUsers] $username | Premium: $($UserMap[$username].PremiumRequests) | Core remaining: $remainingCalls" -PercentComplete $completedPercent -CurrentOperation 'Completed user enrichment'
    }

    Write-Progress -Activity 'Collecting premium requests' -Completed
}

function Add-CommitMetricsForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [hashtable]$UserMap,

        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Failures
    )

    $queryParts = @(
        "since=$([System.Uri]::EscapeDataString($SinceUtc.ToString('o')))",
        "until=$([System.Uri]::EscapeDataString($UntilUtc.ToString('o')))",
        'per_page=100'
    )

    $page = 1
    do {
        $path = "/repos/$Organization/$RepositoryName/commits?{0}&page={1}" -f ($queryParts -join '&'), $page
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response)
        foreach ($commit in $batch) {
            if ($null -eq $commit.author -or [string]::IsNullOrWhiteSpace($commit.author.login)) {
                continue
            }

            $username = $commit.author.login
            if (-not $UserMap.ContainsKey($username)) {
                continue
            }

            try {
                $details = Invoke-GhApiJson -Path "/repos/$Organization/$RepositoryName/commits/$($commit.sha)" -AllowFailure
                if ($null -eq $details) {
                    continue
                }

                $record = $UserMap[$username]
                $record.Commits++
                foreach ($file in @($details.files)) {
                    if ($null -eq $file) {
                        continue
                    }

                    $added = [int]$file.additions
                    $deleted = [int]$file.deletions
                    $record.LinesAdded += $added
                    $record.LinesDeleted += $deleted
                    $record.NetLOC += ($added - $deleted)
                    $record.TotalLinesChanged += ($added + $deleted)
                }
            }
            catch {
                $Failures.Add([PSCustomObject]@{
                    Repository = $RepositoryName
                    Stage      = 'commit-details'
                    Username   = $username
                    Error      = $_.Exception.Message
                })
            }
        }

        $page++
    } while ($batch.Count -eq 100)
}

function Add-PullRequestMetricsForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [hashtable]$UserMap
    )

    $page = 1
    $shouldContinue = $true

    while ($shouldContinue) {
        $path = "/repos/$Organization/$RepositoryName/pulls?state=all&sort=created&direction=desc&per_page=100&page=$page"
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response)
        if ($batch.Count -eq 0) {
            break
        }

        foreach ($pull in $batch) {
            $createdAt = ([datetimeoffset]::Parse($pull.created_at)).UtcDateTime
            if ($createdAt -lt $SinceUtc) {
                $shouldContinue = $false
                continue
            }
            if (-not (Test-IsWithinRange -Value $createdAt -Start $SinceUtc -End $UntilUtc)) {
                continue
            }
            if ($null -eq $pull.user -or [string]::IsNullOrWhiteSpace($pull.user.login)) {
                continue
            }

            $username = $pull.user.login
            if (-not $UserMap.ContainsKey($username)) {
                continue
            }

            $record = $UserMap[$username]
            if (-not [string]::IsNullOrWhiteSpace($pull.merged_at)) {
                $record.MergedPRs++
            }
            elseif ($pull.state -eq 'closed') {
                $record.ClosedPRs++
            }
            else {
                $record.OpenPRs++
            }
        }

        if (-not $shouldContinue -or $batch.Count -lt 100) {
            break
        }

        $page++
    }
}

function Add-IssueMetricsForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [hashtable]$UserMap
    )

    $page = 1
    $shouldContinue = $true

    while ($shouldContinue) {
        $path = "/repos/$Organization/$RepositoryName/issues?state=all&sort=created&direction=desc&per_page=100&page=$page"
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response)
        if ($batch.Count -eq 0) {
            break
        }

        foreach ($issue in $batch) {
            if ($null -ne $issue.pull_request) {
                continue
            }

            $createdAt = ([datetimeoffset]::Parse($issue.created_at)).UtcDateTime
            if ($createdAt -lt $SinceUtc) {
                $shouldContinue = $false
                continue
            }
            if (-not (Test-IsWithinRange -Value $createdAt -Start $SinceUtc -End $UntilUtc)) {
                continue
            }
            if ($null -eq $issue.user -or [string]::IsNullOrWhiteSpace($issue.user.login)) {
                continue
            }

            $username = $issue.user.login
            if (-not $UserMap.ContainsKey($username)) {
                continue
            }

            $record = $UserMap[$username]
            if ($issue.state -eq 'closed') {
                $record.ClosedIssues++
            }
            else {
                $record.OpenIssues++
            }
        }

        if (-not $shouldContinue -or $batch.Count -lt 100) {
            break
        }

        $page++
    }
}

function Add-WorkflowRunMetricsForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [hashtable]$UserMap
    )

    $createdQualifier = "$($Since.ToString('yyyy-MM-dd'))..$($Until.ToString('yyyy-MM-dd'))"
    $page = 1

    do {
        $path = "/repos/$Organization/$RepositoryName/actions/runs?created=$([System.Uri]::EscapeDataString($createdQualifier))&per_page=100&page=$page"
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response.workflow_runs)
        foreach ($run in $batch) {
            if ([string]::IsNullOrWhiteSpace($run.created_at)) {
                continue
            }

            $createdAt = ([datetimeoffset]::Parse($run.created_at)).UtcDateTime
            if (-not (Test-IsWithinRange -Value $createdAt -Start $SinceUtc -End $UntilUtc)) {
                continue
            }

            $username = $null
            if ($null -ne $run.actor -and -not [string]::IsNullOrWhiteSpace($run.actor.login)) {
                $username = $run.actor.login
            }
            elseif ($null -ne $run.triggering_actor -and -not [string]::IsNullOrWhiteSpace($run.triggering_actor.login)) {
                $username = $run.triggering_actor.login
            }

            if ([string]::IsNullOrWhiteSpace($username) -or -not $UserMap.ContainsKey($username)) {
                continue
            }

            $UserMap[$username].WorkflowRuns++
        }

        $page++
    } while ($batch.Count -eq 100)
}

function Add-ReviewMetricsForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [hashtable]$UserMap,

        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Failures
    )

    $page = 1
    $shouldContinue = $true

    while ($shouldContinue) {
        $path = "/repos/$Organization/$RepositoryName/pulls?state=all&sort=updated&direction=desc&per_page=100&page=$page"
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response)
        if ($batch.Count -eq 0) {
            break
        }

        foreach ($pull in $batch) {
            $updatedAt = ([datetimeoffset]::Parse($pull.updated_at)).UtcDateTime
            if ($updatedAt -lt $SinceUtc) {
                $shouldContinue = $false
                continue
            }
            if (-not (Test-IsWithinRange -Value $updatedAt -Start $SinceUtc -End $UntilUtc)) {
                continue
            }

            $reviewPage = 1
            $reviewBatch = @()
            do {
                try {
                    $reviewPath = "/repos/$Organization/$RepositoryName/pulls/$($pull.number)/reviews?per_page=100&page=$reviewPage"
                    $reviewResponse = Invoke-GhApiJson -Path $reviewPath -AllowFailure
                    if ($null -eq $reviewResponse) {
                        break
                    }

                    $reviewBatch = @($reviewResponse)
                    foreach ($review in $reviewBatch) {
                        if ($null -eq $review.user -or [string]::IsNullOrWhiteSpace($review.user.login)) {
                            continue
                        }
                        if ([string]::IsNullOrWhiteSpace($review.submitted_at)) {
                            continue
                        }

                        $submittedAt = ([datetimeoffset]::Parse($review.submitted_at)).UtcDateTime
                        if (-not (Test-IsWithinRange -Value $submittedAt -Start $SinceUtc -End $UntilUtc)) {
                            continue
                        }

                        $username = $review.user.login
                        if (-not $UserMap.ContainsKey($username)) {
                            continue
                        }

                        switch ($review.state) {
                            'APPROVED' {
                                $UserMap[$username].ApprovedReviews++
                            }
                            'COMMENTED' {
                                $UserMap[$username].CommentReviews++
                            }
                        }
                    }
                }
                catch {
                    $Failures.Add([PSCustomObject]@{
                        Repository = $RepositoryName
                        Stage      = 'reviews'
                        Username   = $null
                        Error      = $_.Exception.Message
                    })
                    break
                }

                $reviewPage++
            } while ($reviewBatch.Count -eq 100)
        }

        if (-not $shouldContinue -or $batch.Count -lt 100) {
            break
        }

        $page++
    }
}

try {
    $null = & gh auth status
}
catch {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

Write-Information "Discovering members for $Organization..." -InformationAction Continue
$members = @(Get-OrganizationMembers)
Write-Information "Found $($members.Count) members. Loading user identities..." -InformationAction Continue
$userMap = @{}
$memberCount = $members.Count
$memberIndex = 0
foreach ($member in $members) {
    $memberIndex++
    $memberPercent = [int][math]::Floor(($memberIndex / [math]::Max($memberCount, 1)) * 100)
    Write-Progress -Activity 'Loading user identities' -Status "[$memberIndex/$memberCount] $($member.login)" -PercentComplete $memberPercent -CurrentOperation 'Fetching GitHub profile details'
    Write-Information "[User $memberIndex/$memberCount] $($member.login)" -InformationAction Continue
    $memberIdentity = Get-UserIdentity -Username $member.login
    $userMap[$member.login] = New-UserMetricRecord -Username $member.login -FullName $memberIdentity.FullName -Email $memberIdentity.Email -ProfileUrl $memberIdentity.ProfileUrl
}
Write-Progress -Activity 'Loading user identities' -Completed

Write-Information 'Loading repository list...' -InformationAction Continue
$repositories = @(Get-RepositoryList)
$failures = [System.Collections.Generic.List[object]]::new()

Write-Information "Processing $($repositories.Count) repositories for $($userMap.Count) users..." -InformationAction Continue

$currentIndex = 0
$totalRepositories = $repositories.Count
foreach ($repository in $repositories) {
    $currentIndex++
    $repoPercent = [int][math]::Floor(($currentIndex / [math]::Max($totalRepositories, 1)) * 100)
    Write-Progress -Activity 'Collecting repository activity' -Status "[$currentIndex/$totalRepositories] $($repository.name)" -PercentComplete $repoPercent -CurrentOperation 'Aggregating commits, PRs, issues, reviews, and workflow runs'
    Write-Information "[$currentIndex/$($repositories.Count)] $($repository.name)" -InformationAction Continue

    Add-CommitMetricsForRepository -RepositoryName $repository.name -UserMap $userMap -Failures $failures
    Add-PullRequestMetricsForRepository -RepositoryName $repository.name -UserMap $userMap
    Add-IssueMetricsForRepository -RepositoryName $repository.name -UserMap $userMap
    Add-WorkflowRunMetricsForRepository -RepositoryName $repository.name -UserMap $userMap
    Add-ReviewMetricsForRepository -RepositoryName $repository.name -UserMap $userMap -Failures $failures
}

Write-Progress -Activity 'Collecting repository activity' -Completed

if (-not $SkipPremiumRequests) {
    Write-Information 'Collecting per-user premium requests...' -InformationAction Continue
    Add-PremiumRequestMetrics -UserMap $userMap
}

$orderedUsers = @($userMap.Values | Sort-Object -Property Username)
$payload = [PSCustomObject]@{
    Organization            = $Organization
    Collector               = 'RepoCentric'
    PremiumRequestsIncluded = (-not [bool]$SkipPremiumRequests)
    StartDate               = $Since.ToString('yyyy-MM-dd HH:mm')
    EndDate                 = $Until.ToString('yyyy-MM-dd HH:mm')
    GeneratedAt             = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    UserCount               = $orderedUsers.Count
    RepositoryCount         = $repositories.Count
    Users                   = $orderedUsers
    Failures                = @($failures)
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath

[PSCustomObject]@{
    Organization            = $Organization
    OutputPath              = $OutputPath
    StartDate               = $payload.StartDate
    EndDate                 = $payload.EndDate
    UserCount               = $payload.UserCount
    RepositoryCount         = $payload.RepositoryCount
    PremiumRequestsIncluded = $payload.PremiumRequestsIncluded
    FailureCount            = $payload.Failures.Count
} | Format-Table -AutoSize | Out-String | Write-Output