<#
.SYNOPSIS
    Report premium request usage for the Integrations-relias service account.

.DESCRIPTION
    Queries the enterprise billing API for the Integrations-relias service account
    to show premium request consumption by model with AI Credits projections.
    Supports monthly and year-to-date reporting.

    Requires: admin:enterprise scope on the gh CLI token.
    Enterprise endpoint: /enterprises/bertelsmann/settings/billing/premium_request/usage?user=Integrations-relias

.PARAMETER Period
    Reporting period: Monthly (default) or YTD.

.PARAMETER Year
    Specific year. Defaults to current year.

.PARAMETER Month
    Specific month (1-12) for Monthly queries. Defaults to current month.

.PARAMETER Previous
    Use the previous period (previous month).

.PARAMETER Raw
    Output raw JSON instead of formatted report.

.EXAMPLE
    .\internal-relias-cost.ps1
    .\internal-relias-cost.ps1 -Period YTD
    .\internal-relias-cost.ps1 -Period Monthly -Previous
    .\internal-relias-cost.ps1 -Period Monthly -Year 2026 -Month 4
#>

[CmdletBinding()]
param(
    [ValidateSet('Monthly', 'YTD')]
    [string]$Period = 'Monthly',

    [int]$Year,
    [int]$Month,
    [switch]$Previous,
    [switch]$Raw
)

$InformationPreference = 'Continue'
$Enterprise = 'bertelsmann'
$User = 'Integrations-relias'
$PricePerCredit = 0.01

# ── Model Multiplier Lookup ───────────────────────────────────────────────────

$ModelLookup = @{
    'Claude Haiku 4.5'    = @{ Current = 0.33; New = 0.33 }
    'Claude Sonnet 4'     = @{ Current = 1;    New = 1 }
    'Claude Sonnet 4.5'   = @{ Current = 1;    New = 6 }
    'Claude Sonnet 4.6'   = @{ Current = 1;    New = 9 }
    'Claude Opus 4.5'     = @{ Current = 3;    New = 15 }
    'Claude Opus 4.6'     = @{ Current = 3;    New = 27 }
    'Claude Opus 4.7'     = @{ Current = 15;   New = 27 }
    'GPT-4.1'             = @{ Current = 0;    New = 1 }
    'GPT-5 mini'          = @{ Current = 0;    New = 0.33 }
    'GPT-5.2'             = @{ Current = 1;    New = 3 }
    'GPT-5.2-Codex'       = @{ Current = 1;    New = 3 }
    'GPT-5.3-Codex'       = @{ Current = 1;    New = 6 }
    'GPT-5.4'             = @{ Current = 1;    New = 6 }
    'GPT-5.4 mini'        = @{ Current = 0.33; New = 6 }
    'GPT-5.4 nano'        = @{ Current = 0.33; New = 0.33 }
    'GPT-5.5'             = @{ Current = 1;    New = 15 }
    'Gemini 2.5 Pro'      = @{ Current = 1;    New = 1 }
    'Gemini 3 Flash'      = @{ Current = 0.33; New = 0.33 }
    'Gemini 3.1 Pro'      = @{ Current = 1;    New = 6 }
    'Code Review model'   = @{ Current = 1;    New = 6 }
    'Coding Agent model'  = @{ Current = 1;    New = 6 }
}

function Get-ModelInfo {
    param([string]$ModelName)
    $info = $ModelLookup[$ModelName]
    if (-not $info) {
        return @{ Current = 1; New = 6 }
    }
    return $info
}

# ── API Helper ────────────────────────────────────────────────────────────────

function Get-UserUsage {
    param([int]$QueryYear, [int]$QueryMonth)

    $url = "/enterprises/$Enterprise/settings/billing/premium_request/usage?user=$User&year=$QueryYear&month=$QueryMonth"
    $response = gh api $url `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "API call failed for $QueryYear-$('{0:D2}' -f $QueryMonth): $response"
        return $null
    }
    return ($response | ConvertFrom-Json)
}

# ── AI Credits Projection ────────────────────────────────────────────────────

function Convert-ToAICredit {
    param($UsageItems)

    $totalCredits = 0.0
    $details = @()

    foreach ($item in $UsageItems) {
        $info = Get-ModelInfo -ModelName $item.model
        $currentMult = $info.Current
        $newMult = $info.New

        $actualRequests = if ($currentMult -gt 0) { $item.grossQuantity / $currentMult } else { $item.grossQuantity }
        $credits = $actualRequests * $newMult
        $totalCredits += $credits

        $details += [PSCustomObject]@{
            Model    = $item.model
            PRUs     = [math]::Round($item.grossQuantity, 1)
            'PRU $'  = "`${0:N2}" -f $item.grossAmount
            Requests = [math]::Round($actualRequests, 0)
            Credits  = [math]::Round($credits, 1)
            'AIC $'  = "`${0:N2}" -f ($credits * $PricePerCredit)
            Mult     = "$($currentMult)x → $($newMult)x"
        }
    }

    return @{
        TotalCredits = [math]::Round($totalCredits, 1)
        TotalCost    = [math]::Round($totalCredits * $PricePerCredit, 2)
        Details      = $details
    }
}

# ── Formatting ────────────────────────────────────────────────────────────────

function Write-MonthReport {
    param($Data, [string]$MonthLabel)

    $items = $Data.usageItems
    if (-not $items -or $items.Count -eq 0) {
        Write-Information "  `e[90m$MonthLabel — no usage`e[0m"
        return @{ PRUs = 0; Gross = 0; Net = 0; Credits = 0; CreditCost = 0 }
    }

    $totalPRUs = ($items | Measure-Object -Property grossQuantity -Sum).Sum
    $totalGross = ($items | Measure-Object -Property grossAmount -Sum).Sum
    $totalNet = ($items | Measure-Object -Property netAmount -Sum).Sum
    $projection = Convert-ToAICredit -UsageItems $items

    Write-Information "  `e[36m$MonthLabel`e[0m"
    $projection.Details | Sort-Object -Property PRUs -Descending | Format-Table -AutoSize

    Write-Information ("    PRU Total:  {0:N1} PRUs = `${1:N2} gross / `${2:N2} net" -f $totalPRUs, $totalGross, $totalNet)
    Write-Information ("    AIC Total:  {0:N1} credits = `${1:N2} (multiplier estimate)" -f $projection.TotalCredits, $projection.TotalCost)

    $delta = $projection.TotalCost - $totalGross
    $deltaSign = if ($delta -gt 0) { "+" } else { "" }
    $deltaColor = if ($delta -gt 0) { "`e[31m" } else { "`e[32m" }
    Write-Information "    Delta:      ${deltaColor}${deltaSign}`$$("{0:N2}" -f $delta)`e[0m"
    Write-Information ""

    return @{
        PRUs = $totalPRUs; Gross = $totalGross; Net = $totalNet
        Credits = $projection.TotalCredits; CreditCost = $projection.TotalCost
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────

$now = Get-Date
if (-not $Year) { $Year = $now.Year }
if (-not $Month -and $Period -eq 'Monthly') { $Month = $now.Month }

if ($Previous -and $Period -eq 'Monthly') {
    $prev = (Get-Date -Year $Year -Month $Month -Day 1).AddMonths(-1)
    $Year = $prev.Year
    $Month = $prev.Month
}

Write-Information ""
Write-Information "`e[36m╔══════════════════════════════════════════════════════════════════════════╗`e[0m"
Write-Information "`e[36m║  Copilot Cost — $User`e[0m"
Write-Information "`e[36m║  Enterprise: $Enterprise`e[0m"

switch ($Period) {
    'Monthly' {
        $monthName = (Get-Culture).DateTimeFormat.GetMonthName($Month)
        Write-Information "`e[36m║  Period: $monthName $Year`e[0m"
        Write-Information "`e[36m║  Billing: Premium Requests (current) vs AI Credits (Jun 1)`e[0m"
        Write-Information "`e[36m╚══════════════════════════════════════════════════════════════════════════╝`e[0m"
        Write-Information ""

        $data = Get-UserUsage -QueryYear $Year -QueryMonth $Month
        if ($Raw -and $data) { $data | ConvertTo-Json -Depth 5; exit 0 }

        if (-not $data -or -not $data.usageItems -or $data.usageItems.Count -eq 0) {
            Write-Information "  `e[90mNo premium request usage found for $User in $monthName $Year.`e[0m"
            Write-Information ""
            exit 0
        }

        $result = Write-MonthReport -Data $data -MonthLabel "$monthName $Year"

        # Budget context (single user gets 1,000 PRU allotment)
        $pruAllotment = 1000
        $pruPct = ($result.PRUs / $pruAllotment) * 100
        $creditsAllotment = 3900
        $isPromotional = ($Year -eq 2026 -and $Month -ge 6 -and $Month -le 8)
        if ($isPromotional) { $creditsAllotment = 7000 }
        $aicPct = if ($creditsAllotment -gt 0) { ($result.Credits / $creditsAllotment) * 100 } else { 0 }

        Write-Information "`e[33m── Budget Status (Single Seat) ──────────────────────────────`e[0m"
        Write-Information "  PRU:  $("{0:N1}" -f $result.PRUs) / $($pruAllotment.ToString('N0')) ($("{0:N1}" -f $pruPct)% used)"
        Write-Information "  AIC:  $("{0:N1}" -f $result.Credits) / $($creditsAllotment.ToString('N0')) credits ($("{0:N1}" -f $aicPct)% used)"

        if ($Month -eq $now.Month -and $Year -eq $now.Year) {
            $daysElapsed = $now.Day
            $daysInMonth = [datetime]::DaysInMonth($Year, $Month)
            if ($daysElapsed -gt 0) {
                $projPRU = ($result.PRUs / $daysElapsed) * $daysInMonth
                $projAIC = ($result.Credits / $daysElapsed) * $daysInMonth
                $projPRUColor = if ($projPRU -gt $pruAllotment) { "`e[31m" } else { "`e[32m" }
                $projAICColor = if ($projAIC -gt $creditsAllotment) { "`e[31m" } else { "`e[32m" }
                Write-Information ""
                Write-Information "`e[33m── End-of-Month Projection ─────────────────────────────────`e[0m"
                Write-Information "  PRU:  ${projPRUColor}$("{0:N0}" -f $projPRU) / $($pruAllotment.ToString('N0'))`e[0m"
                Write-Information "  AIC:  ${projAICColor}$("{0:N0}" -f $projAIC) / $($creditsAllotment.ToString('N0'))`e[0m"
            }
        }
        Write-Information ""
    }

    'YTD' {
        Write-Information "`e[36m║  Period: Year-to-Date $Year`e[0m"
        Write-Information "`e[36m║  Billing: Premium Requests (current) vs AI Credits (Jun 1)`e[0m"
        Write-Information "`e[36m╚══════════════════════════════════════════════════════════════════════════╝`e[0m"
        Write-Information ""

        $maxMonth = if ($Year -eq $now.Year) { $now.Month } else { 12 }
        $grandPRUs = 0.0; $grandGross = 0.0; $grandNet = 0.0
        $grandCredits = 0.0; $grandCreditCost = 0.0
        $activeMonths = 0
        $allItems = @()

        for ($m = 1; $m -le $maxMonth; $m++) {
            $data = Get-UserUsage -QueryYear $Year -QueryMonth $m
            if ($Raw -and $data) {
                $monthName = (Get-Culture).DateTimeFormat.GetMonthName($m)
                Write-Information "=== $monthName $Year ==="
                $data | ConvertTo-Json -Depth 5
                continue
            }

            $monthName = (Get-Culture).DateTimeFormat.GetMonthName($m)
            if ($data -and $data.usageItems -and $data.usageItems.Count -gt 0) {
                $result = Write-MonthReport -Data $data -MonthLabel "$monthName $Year"
                $grandPRUs += $result.PRUs
                $grandGross += $result.Gross
                $grandNet += $result.Net
                $grandCredits += $result.Credits
                $grandCreditCost += $result.CreditCost
                $activeMonths++
                $allItems += $data.usageItems
            } else {
                Write-Information "  `e[90m$monthName $Year — no usage`e[0m"
            }
        }

        if ($Raw) { exit 0 }

        Write-Information "`e[33m══════════════════════════════════════════════════════════════`e[0m"
        Write-Information "`e[33m  YTD TOTALS ($Year)`e[0m"
        Write-Information "`e[33m══════════════════════════════════════════════════════════════`e[0m"
        Write-Information ""
        Write-Information "  Active months:  $activeMonths"
        Write-Information "  PRU Total:      $("{0:N1}" -f $grandPRUs) PRUs = `$$("{0:N2}" -f $grandGross) gross / `$$("{0:N2}" -f $grandNet) net"
        Write-Information "  AIC Total:      $("{0:N1}" -f $grandCredits) credits = `$$("{0:N2}" -f $grandCreditCost) (multiplier estimate)"

        if ($grandGross -gt 0) {
            $delta = $grandCreditCost - $grandGross
            $deltaSign = if ($delta -gt 0) { "+" } else { "" }
            $deltaColor = if ($delta -gt 0) { "`e[31m" } else { "`e[32m" }
            Write-Information "  Delta:          ${deltaColor}${deltaSign}`$$("{0:N2}" -f $delta)`e[0m"
        }

        # YTD budget: allotment per month × months elapsed
        $ytdPRUAllotment = $maxMonth * 1000
        $ytdPRUPct = if ($ytdPRUAllotment -gt 0) { ($grandPRUs / $ytdPRUAllotment) * 100 } else { 0 }
        Write-Information ""
        Write-Information "`e[33m── YTD Budget (Single Seat) ────────────────────────────────`e[0m"
        Write-Information "  PRU:  $("{0:N1}" -f $grandPRUs) / $($ytdPRUAllotment.ToString('N0')) ($("{0:N1}" -f $ytdPRUPct)% of cumulative allotment)"

        # Model breakdown across all months
        if ($allItems.Count -gt 0) {
            Write-Information ""
            Write-Information "`e[33m── YTD Model Breakdown ─────────────────────────────────────`e[0m"
            $grouped = $allItems | Group-Object -Property model | ForEach-Object {
                $totalQ = ($_.Group | Measure-Object -Property grossQuantity -Sum).Sum
                $totalA = ($_.Group | Measure-Object -Property grossAmount -Sum).Sum
                [PSCustomObject]@{
                    Model    = $_.Name
                    PRUs     = [math]::Round($totalQ, 1)
                    'PRU $'  = "`${0:N2}" -f $totalA
                }
            } | Sort-Object -Property PRUs -Descending
            $grouped | Format-Table -AutoSize
        }

        Write-Information ""
    }
}
