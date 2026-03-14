#Requires -Version 7.0
<#
.SYNOPSIS
    Enriches an existing org productivity JSON file with per-user premium requests.
.DESCRIPTION
    Reads an existing org-wide productivity JSON file, queries GitHub's
    user-scoped premium request billing endpoint for each user across the report
    date range, and writes an updated JSON file with PremiumRequests populated.

    This script is rate-aware and will pause until the GitHub core rate limit
    resets when necessary.
.PARAMETER InputPath
    Path to an existing org-wide productivity JSON file.
.PARAMETER OutputPath
    Path to write the enriched JSON file. Defaults to a file next to InputPath
    with -premium appended before the extension.
.PARAMETER Enterprise
    Enterprise slug for premium request lookup. Defaults to bertelsmann.
.PARAMETER UserLimit
    Optional limit for validation runs.
.EXAMPLE
    .\Add-OrgUserPremiumRequests.ps1 -InputPath .\org-fast-full.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,

    [string]$OutputPath,

    [string]$Enterprise = 'bertelsmann',

    [ValidateRange(1, 10000)]
    [int]$UserLimit = 0
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Could not find input file at '$InputPath'."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $inputItem = Get-Item -LiteralPath $InputPath
    $OutputPath = Join-Path $inputItem.DirectoryName ($inputItem.BaseName + '-premium' + $inputItem.Extension)
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

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Name,

        $Value
    )

    $existingProperty = $Object.PSObject.Properties[$Name]
    if ($null -ne $existingProperty) {
        $existingProperty.Value = $Value
        return
    }

    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
}

try {
    $null = & gh auth status
}
catch {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

$payload = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
$since = [datetime]::Parse($payload.StartDate)
$until = [datetime]::Parse($payload.EndDate)
$headers = @('Accept: application/vnd.github+json')

$users = @($payload.Users)
if ($UserLimit -gt 0) {
    $users = @($users | Select-Object -First $UserLimit)
}

$rateState = Get-CoreRateState
$remainingCalls = $rateState.Remaining
$resetEpoch = $rateState.ResetEpoch

$index = 0
foreach ($user in $users) {
    $index++
    Write-Information "[$index/$($users.Count)] $($user.Username)" -InformationAction Continue

    $total = 0.0
    for ($date = $since.Date; $date -le $until.Date; $date = $date.AddDays(1)) {
        Wait-ForCoreBudget -RemainingCalls ([ref]$remainingCalls) -ResetEpoch ([ref]$resetEpoch)

        $queryString = @(
            "year=$($date.Year)",
            "month=$($date.Month)",
            "day=$($date.Day)",
            "user=$([System.Uri]::EscapeDataString($user.Username))",
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

    $user.PremiumRequests = [math]::Round($total, 2)

    if (($index % 10) -eq 0) {
        Set-ObjectProperty -Object $payload -Name 'PremiumRequestsIncluded' -Value $true
        Set-ObjectProperty -Object $payload -Name 'PremiumRequestsEnrichedAt' -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
        $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath
    }
}

Set-ObjectProperty -Object $payload -Name 'PremiumRequestsIncluded' -Value $true
Set-ObjectProperty -Object $payload -Name 'PremiumRequestsEnrichedAt' -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath

[PSCustomObject]@{
    InputPath               = $InputPath
    OutputPath              = $OutputPath
    StartDate               = $payload.StartDate
    EndDate                 = $payload.EndDate
    EnrichedUserCount       = $users.Count
    PremiumRequestsIncluded = $payload.PremiumRequestsIncluded
} | Format-Table -AutoSize | Out-String | Write-Output