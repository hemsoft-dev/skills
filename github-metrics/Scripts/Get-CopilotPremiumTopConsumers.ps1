[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Org,

    [string]$Enterprise,

    [ValidatePattern('^\d{4}-\d{2}$')]
    [string]$ReportMonth = (Get-Date).ToString('yyyy-MM'),

    [ValidateRange(1, 500)]
    [int]$Top = 10,

    [string]$OrgToken,

    [string]$BillingToken
)

$ErrorActionPreference = 'Stop'

$apiHeaders = @(
    'Accept: application/vnd.github+json',
    'X-GitHub-Api-Version: 2022-11-28'
)

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Token
    )

    $arguments = @('api')
    foreach ($header in $apiHeaders) {
        $arguments += @('-H', $header)
    }
    $arguments += $Path

    $envBackup = $null
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $envBackup = $env:GH_TOKEN
        $env:GH_TOKEN = $Token
    }

    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $output = & gh @arguments 2> $stderrFile
        $stderrOutput = Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue
    }
    finally {
        if ($null -ne $envBackup) {
            $env:GH_TOKEN = $envBackup
        }
        elseif (-not [string]::IsNullOrWhiteSpace($Token)) {
            Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
        }

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

        throw $errorMessage.Trim()
    }

    if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Test-GhAuthentication {
    param([string]$Token)

    try {
        $null = Invoke-GhApiJson -Path '/user' -Token $Token
        return $true
    }
    catch {
        return $false
    }
}

function Get-SeatHolderData {
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [string]$Token
    )

    $seatHolders = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $page = 1
    $apiCalls = 0

    do {
        $response = Invoke-GhApiJson -Path "/orgs/$Organization/copilot/billing/seats?per_page=100&page=$page" -Token $Token
        $apiCalls++

        if ($null -eq $response -or $null -eq $response.seats -or $response.seats.Count -eq 0) {
            break
        }

        foreach ($seat in $response.seats) {
            if ($null -ne $seat.assignee -and -not [string]::IsNullOrWhiteSpace($seat.assignee.login)) {
                $null = $seatHolders.Add($seat.assignee.login)
            }
        }

        $page++
    } while ($seatHolders.Count -lt [int]$response.total_seats)

    return [pscustomobject]@{
        Logins   = @($seatHolders | Sort-Object)
        ApiCalls = $apiCalls
    }
}

function Get-BillingPath {
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [string]$EnterpriseSlug,

        [Parameter(Mandatory)]
        [int]$Year,

        [Parameter(Mandatory)]
        [int]$Month,

        [Parameter(Mandatory)]
        [string]$Login
    )

    $query = @(
        "year=$Year",
        "month=$Month",
        'product=Copilot',
        "user=$([System.Uri]::EscapeDataString($Login))"
    ) -join '&'

    if (-not [string]::IsNullOrWhiteSpace($EnterpriseSlug)) {
        return "/enterprises/$EnterpriseSlug/settings/billing/premium_request/usage?$query"
    }

    return "/orgs/$Organization/settings/billing/premium_request/usage?$query"
}

if (-not (Test-GhAuthentication -Token $OrgToken)) {
    throw "Org seat queries require GitHub authentication with org access. Run 'gh auth login' or pass -OrgToken."
}

$billingAuthToken = if (-not [string]::IsNullOrWhiteSpace($BillingToken)) { $BillingToken } else { $OrgToken }
$billingScope = if (-not [string]::IsNullOrWhiteSpace($Enterprise)) { 'enterprise' } else { 'organization' }
$parsedMonth = [datetime]::ParseExact($ReportMonth, 'yyyy-MM', $null)
$year = $parsedMonth.Year
$month = $parsedMonth.Month

$seatData = Get-SeatHolderData -Organization $Org -Token $OrgToken
$results = New-Object System.Collections.Generic.List[object]
$userQueryCalls = 0
$seatHolderCount = $seatData.Logins.Count
$currentIndex = 0

foreach ($login in $seatData.Logins) {
    $currentIndex++
    $percentComplete = [int][math]::Floor((($currentIndex - 1) / [math]::Max($seatHolderCount, 1)) * 100)
    Write-Progress -Activity 'Querying premium request billing' -Status "[$currentIndex/$seatHolderCount] $login" -PercentComplete $percentComplete

    try {
        $response = Invoke-GhApiJson -Path (Get-BillingPath -Organization $Org -EnterpriseSlug $Enterprise -Year $year -Month $month -Login $login) -Token $billingAuthToken
    }
    catch {
        $message = $_.Exception.Message
        if ($billingScope -eq 'organization' -and $message -match 'cannot filter usage by user') {
            throw "Org-level user filtering is unavailable for '$Org'. Re-run with -Enterprise and enterprise billing access."
        }
        if ($billingScope -eq 'enterprise' -and $message -match 'admin:enterprise') {
            throw "Enterprise billing queries for '$Enterprise' require enterprise admin or billing-manager access. Re-run with -BillingToken from that context."
        }

        throw "Premium request query failed for '$login': $message"
    }

    $userQueryCalls++
    $grossQuantity = 0.0
    foreach ($item in @($response.usageItems)) {
        if ($null -ne $item.grossQuantity) {
            $grossQuantity += [double]$item.grossQuantity
        }
    }

    if ($grossQuantity -gt 0) {
        $results.Add([pscustomobject]@{
            Login           = $login
            PremiumRequests = [math]::Round($grossQuantity, 1)
        }) | Out-Null
    }
}

Write-Progress -Activity 'Querying premium request billing' -Completed

$topConsumers = @(
    $results |
        Sort-Object -Property @{ Expression = 'PremiumRequests'; Descending = $true }, @{ Expression = 'Login'; Descending = $false } |
        Select-Object -First $Top
)

$rankedConsumers = New-Object System.Collections.Generic.List[object]
foreach ($consumer in $topConsumers) {
    $rankedConsumers.Add([pscustomobject]@{
        Rank            = $rankedConsumers.Count + 1
        Login           = $consumer.Login
        PremiumRequests = $consumer.PremiumRequests
    }) | Out-Null
}

[pscustomobject]@{
    BillingScope            = $billingScope
    Org                     = $Org
    Enterprise              = if (-not [string]::IsNullOrWhiteSpace($Enterprise)) { $Enterprise } else { $null }
    ReportMonth             = $ReportMonth
    SeatHolderCount         = $seatHolderCount
    UsersWithPremiumUsage   = $results.Count
    ApiCalls                = [pscustomobject]@{
        SeatPages   = $seatData.ApiCalls
        UserQueries = $userQueryCalls
        Total       = $seatData.ApiCalls + $userQueryCalls
    }
    TopConsumers            = $rankedConsumers
}
