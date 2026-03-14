#Requires -Version 7.0
<#
.SYNOPSIS
    Reports premium requests, commits, and pull requests for a user over a date range.
.DESCRIPTION
    Compares GitHub Copilot premium request consumption against authored GitHub
    productivity for a single user in a single organization. The output is
    intentionally concise: date range, premium requests, commits, and pull
    requests.

    Premium requests are fetched from the enterprise billing usage API when an
    enterprise slug is supplied and the active token has enterprise billing
    access. If that API is not available in the current environment, you can
    supply -PremiumRequestsOverride to inject a known total.
.PARAMETER Username
    GitHub username to analyze.
.PARAMETER Org
    GitHub organization to analyze. Defaults to relias-engineering.
.PARAMETER Since
    Inclusive start date for the reporting period.
.PARAMETER Until
    Inclusive end timestamp for the reporting period. Defaults to the current time.
.PARAMETER Enterprise
    Enterprise slug for the premium request billing API.
.PARAMETER PremiumRequestsOverride
    Optional manual premium request total. Use this when the billing endpoint is
    unavailable or when you already have the number from the GitHub UI.
.PARAMETER PremiumQuantityField
    Which billing quantity to aggregate from the premium request usage API.
    Gross is the consumed quantity; Net is the billable quantity after discounts.
.PARAMETER ThrottleMs
    Delay between per-repository commit API requests.
.PARAMETER IncludeArchived
    Include archived repositories when counting commits.
.PARAMETER IncludeForks
    Include forked repositories when counting commits.
.PARAMETER OutputFormat
    Output mode: Table or Json.
.EXAMPLE
    .\Get-UserOrgProductivity.ps1 -Username ssadhula-relias -Since '2026-02-01' -Until '2026-02-28' -PremiumRequestsOverride 3400
.EXAMPLE
    .\Get-UserOrgProductivity.ps1 -Username ssadhula-relias -Org relias-engineering -Enterprise relias -Since '2026-02-01' -Until '2026-02-28'
.EXAMPLE
    .\Get-UserOrgProductivity.ps1 -Username ssadhula-relias -Org relias-engineering -Enterprise bertelsmann -Since '2026-03-01'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [ValidateNotNullOrEmpty()]
    [string]$Org = 'relias-engineering',

    [Parameter(Mandatory)]
    [datetime]$Since,

    [datetime]$Until = (Get-Date),

    [string]$Enterprise,

    [double]$PremiumRequestsOverride,

    [ValidateSet('Gross', 'Net')]
    [string]$PremiumQuantityField = 'Gross',

    [ValidateRange(0, 5000)]
    [int]$ThrottleMs = 0,

    [switch]$IncludeArchived,

    [switch]$IncludeForks,

    [ValidateSet('Table', 'Json')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

if ($Since.Date -gt $Until.Date) {
    throw 'Since must be earlier than or equal to Until.'
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

        Write-Error -Message $errorMessage -ErrorAction Stop
    }

    if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Get-SearchDateQualifier {
    param(
        [Parameter(Mandatory)]
        [string]$FieldName,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End
    )

    return "${FieldName}:$($Start.ToString('yyyy-MM-dd'))..$($End.ToString('yyyy-MM-dd'))"
}

function Get-TotalPullRequestCount {
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Author,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End
    )

    $query = @(
        "org:$Organization",
        "author:$Author",
        'is:pr',
        (Get-SearchDateQualifier -FieldName 'created' -Start $Start -End $End)
    ) -join ' '

    $encodedQuery = [System.Uri]::EscapeDataString($query)
    $result = Invoke-GhApiJson -Path "/search/issues?q=$encodedQuery&per_page=1"
    return [int]$result.total_count
}

function Get-CommitCountForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [string]$Author,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End,

        [int]$DelayMs
    )

    $queryParts = @(
        "author=$([System.Uri]::EscapeDataString($Author))",
        "since=$([System.Uri]::EscapeDataString($Start.ToUniversalTime().ToString('o')))",
        "until=$([System.Uri]::EscapeDataString($End.ToUniversalTime().ToString('o')))",
        'per_page=100'
    )

    $page = 1
    $commitCount = 0

    do {
        $path = "/repos/$Organization/$RepositoryName/commits?{0}&page={1}" -f ($queryParts -join '&'), $page
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response)
        $commitCount += $batch.Count
        $page++

        if ($DelayMs -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }
    } while ($batch.Count -eq 100)

    return $commitCount
}

function Get-TotalCommitCount {
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Author,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End,

        [int]$DelayMs,

        [bool]$IncludeArchivedRepositories,

        [bool]$IncludeForkRepositories
    )

    $repositories = @(gh repo list $Organization --limit 500 --json name,isArchived,isFork | ConvertFrom-Json)
    if (-not $IncludeArchivedRepositories) {
        $repositories = @($repositories | Where-Object { -not $_.isArchived })
    }

    if (-not $IncludeForkRepositories) {
        $repositories = @($repositories | Where-Object { -not $_.isFork })
    }

    $totalCommits = 0

    foreach ($repository in $repositories) {
        $totalCommits += Get-CommitCountForRepository -Organization $Organization -RepositoryName $repository.name -Author $Author -Start $Start -End $End -DelayMs $DelayMs
    }

    return $totalCommits
}

function Get-TotalPremiumRequestCount {
    param(
        [Parameter(Mandatory)]
        [string]$EnterpriseSlug,

        [Parameter(Mandatory)]
        [string]$UserLogin,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End,

        [Parameter(Mandatory)]
        [ValidateSet('Gross', 'Net')]
        [string]$QuantityField
    )

    $quantityPropertyName = if ($QuantityField -eq 'Gross') { 'grossQuantity' } else { 'netQuantity' }
    $headers = @('Accept: application/vnd.github+json')
    $total = 0.0

    for ($date = $Start.Date; $date -le $End.Date; $date = $date.AddDays(1)) {
        $queryString = @(
            "year=$($date.Year)",
            "month=$($date.Month)",
            "day=$($date.Day)",
            "user=$([System.Uri]::EscapeDataString($UserLogin))",
            'product=Copilot'
        ) -join '&'

        $path = "/enterprises/$EnterpriseSlug/settings/billing/premium_request/usage?$queryString"
        $response = Invoke-GhApiJson -Path $path -Headers $headers
        foreach ($item in @($response.usageItems)) {
            $value = $item.$quantityPropertyName
            if ($null -ne $value) {
                $total += [double]$value
            }
        }
    }

    return $total
}

try {
    $null = & gh auth status
}
catch {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

$null = Invoke-GhApiJson -Path "/users/$Username"

$premiumRequests = 0.0
if ($PSBoundParameters.ContainsKey('PremiumRequestsOverride')) {
    $premiumRequests = [double]$PremiumRequestsOverride
}
else {
    if ([string]::IsNullOrWhiteSpace($Enterprise)) {
        throw 'Enterprise is required unless PremiumRequestsOverride is provided.'
    }

    try {
        $premiumRequests = Get-TotalPremiumRequestCount -EnterpriseSlug $Enterprise -UserLogin $Username -Start $Since -End $Until -QuantityField $PremiumQuantityField
    }
    catch {
        throw "Failed to retrieve premium requests. This endpoint requires the enterprise slug and a token with enterprise billing access, typically admin:enterprise. Underlying error: $($_.Exception.Message)"
    }
}

$totalPullRequests = Get-TotalPullRequestCount -Organization $Org -Author $Username -Start $Since -End $Until
$totalCommits = Get-TotalCommitCount -Organization $Org -Author $Username -Start $Since -End $Until -DelayMs $ThrottleMs -IncludeArchivedRepositories:$IncludeArchived -IncludeForkRepositories:$IncludeForks

$summary = [PSCustomObject]@{
    StartDate       = $Since.ToString('yyyy-MM-dd')
    EndDate         = $Until.ToString('yyyy-MM-dd HH:mm')
    PremiumRequests = [math]::Round($premiumRequests, 2)
    Commits         = $totalCommits
    PullRequests    = $totalPullRequests
}

if ($OutputFormat -eq 'Json') {
    $summary | ConvertTo-Json -Depth 4
    return
}

$summaryTable = @(
    [PSCustomObject]@{ Metric = 'Start Date'; Value = $summary.StartDate }
    [PSCustomObject]@{ Metric = 'End Date'; Value = $summary.EndDate }
    [PSCustomObject]@{ Metric = 'Premium Requests'; Value = $summary.PremiumRequests }
    [PSCustomObject]@{ Metric = 'Commits'; Value = $summary.Commits }
    [PSCustomObject]@{ Metric = 'Pull Requests'; Value = $summary.PullRequests }
)

$summaryTable | Format-Table -AutoSize | Out-String | Write-Output