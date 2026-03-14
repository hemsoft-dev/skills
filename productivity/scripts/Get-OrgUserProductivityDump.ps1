#Requires -Version 7.0
<#
.SYNOPSIS
    Dumps detailed month-to-date productivity metrics for all org members to JSON.
.DESCRIPTION
    Enumerates members of the relias-engineering organization, runs
    Get-UserProductivityBreakdown.ps1 for each user, and writes the combined
    results to one JSON file along with best-effort profile identity data.

    By default, the reporting window is the current month through the current
    timestamp. Failures for individual users are captured in the output so one
    bad account does not abort the entire dump. Full names come from GitHub user
    profiles. Email is populated only when GitHub exposes a public email for the
    account.
.PARAMETER Since
    Inclusive start date for the reporting window. Defaults to the first day of
    the current month at midnight.
.PARAMETER Until
    Inclusive end timestamp for the reporting window. Defaults to the current time.
.PARAMETER OutputPath
    Path to the JSON file to create. Defaults to
    org-user-productivity-relias-engineering-{date}.json in the current directory.
.PARAMETER UserLimit
    Optional maximum number of users to process. Useful for validation runs.
.EXAMPLE
    .\Get-OrgUserProductivityDump.ps1
.EXAMPLE
    .\Get-OrgUserProductivityDump.ps1 -UserLimit 5
#>

[CmdletBinding()]
param(
    [datetime]$Since = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0),

    [datetime]$Until = (Get-Date),

    [string]$OutputPath,

    [ValidateRange(1, 10000)]
    [int]$UserLimit = 0
)

$ErrorActionPreference = 'Stop'

$Organization = 'relias-engineering'
$breakdownScriptPath = Join-Path $PSScriptRoot 'Get-UserProductivityBreakdown.ps1'

if (-not (Test-Path -LiteralPath $breakdownScriptPath)) {
    throw "Could not find breakdown script at '$breakdownScriptPath'."
}

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
        [string]$Path
    )

    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $output = & gh api $Path 2> $stderrFile
        $stderrOutput = Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue
    }
    finally {
        if ([System.IO.File]::Exists($stderrFile)) {
            [System.IO.File]::Delete($stderrFile)
        }
    }

    if ($LASTEXITCODE -ne 0) {
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

function Get-OrganizationMembers {
    $page = 1
    $members = [System.Collections.Generic.List[object]]::new()

    do {
        $response = Invoke-GhApiJson -Path "/orgs/$Organization/members?per_page=100&page=$page"
        $batch = @($response)
        foreach ($member in $batch) {
            if ($null -ne $member -and -not [string]::IsNullOrWhiteSpace($member.login)) {
                $members.Add($member)
            }
        }

        $page++
    } while ($batch.Count -eq 100)

    $distinctMembers = @($members | Group-Object -Property login | ForEach-Object { $_.Group[0] } | Sort-Object -Property login)
    if ($UserLimit -gt 0) {
        return @($distinctMembers | Select-Object -First $UserLimit)
    }

    return $distinctMembers
}

function Get-UserProfile {
    param(
        [Parameter(Mandatory)]
        [string]$Username
    )

    $profile = Invoke-GhApiJson -Path "/users/$Username"
    return [PSCustomObject]@{
        Username = $Username
        FullName = $profile.name
        Email    = $profile.email
        HtmlUrl  = $profile.html_url
    }
}

try {
    $null = & gh auth status
}
catch {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

$members = @(Get-OrganizationMembers)
Write-Information "Processing $($members.Count) users for $Organization..." -InformationAction Continue

$results = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[object]]::new()
$currentIndex = 0

foreach ($member in $members) {
    $currentIndex++
    Write-Information "[$currentIndex/$($members.Count)] $($member.login)" -InformationAction Continue

    $profile = $null
    try {
        $profile = Get-UserProfile -Username $member.login
    }
    catch {
        $failures.Add([PSCustomObject]@{
            Username = $member.login
            Stage    = 'profile'
            Error    = $_.Exception.Message
        })

        $profile = [PSCustomObject]@{
            Username = $member.login
            FullName = $null
            Email    = $null
            HtmlUrl  = $null
        }
    }

    try {
        $userJson = & $breakdownScriptPath -Username $member.login -Since $Since -Until $Until -OutputFormat Json
        $userResult = $userJson | ConvertFrom-Json
        $results.Add([PSCustomObject]@{
            Username          = $userResult.Username
            FullName          = $profile.FullName
            Email             = $profile.Email
            ProfileUrl        = $profile.HtmlUrl
            StartDate         = $userResult.StartDate
            EndDate           = $userResult.EndDate
            PremiumRequests   = $userResult.PremiumRequests
            Commits           = $userResult.Commits
            LinesAdded        = $userResult.LinesAdded
            LinesDeleted      = $userResult.LinesDeleted
            NetLOC            = $userResult.NetLOC
            TotalLinesChanged = $userResult.TotalLinesChanged
            OpenPRs           = $userResult.OpenPRs
            MergedPRs         = $userResult.MergedPRs
            ClosedPRs         = $userResult.ClosedPRs
            ApprovedReviews   = $userResult.ApprovedReviews
            CommentReviews    = $userResult.CommentReviews
            OpenIssues        = $userResult.OpenIssues
            ClosedIssues      = $userResult.ClosedIssues
            WorkflowRuns      = $userResult.WorkflowRuns
        })
    }
    catch {
        $failures.Add([PSCustomObject]@{
            Username = $member.login
            Stage    = 'metrics'
            Error    = $_.Exception.Message
        })
    }
}

$payload = [PSCustomObject]@{
    Organization    = $Organization
    StartDate       = $Since.ToString('yyyy-MM-dd HH:mm')
    EndDate         = $Until.ToString('yyyy-MM-dd HH:mm')
    GeneratedAt     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    UserCount       = $members.Count
    SuccessCount    = $results.Count
    FailureCount    = $failures.Count
    Users           = @($results)
    Failures        = @($failures)
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath

[PSCustomObject]@{
    Organization = $Organization
    OutputPath   = $OutputPath
    StartDate    = $payload.StartDate
    EndDate      = $payload.EndDate
    UserCount    = $payload.UserCount
    SuccessCount = $payload.SuccessCount
    FailureCount = $payload.FailureCount
} | Format-Table -AutoSize | Out-String | Write-Output