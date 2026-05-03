<#
.SYNOPSIS
    Track GitHub Copilot premium request / AI credit costs for Relias-Engineering.

.DESCRIPTION
    Queries the GitHub billing API to report Copilot usage costs at the org level.
    Supports daily, weekly, monthly, and year-to-date periods.
    Shows side-by-side comparison of current PRU billing vs projected token-based AI Credits billing.

    API Endpoint: /orgs/Relias-Engineering/settings/billing/premium_request/usage
    Supports filters: year, month, day (no per-user via org endpoint for enterprise orgs).

    For per-user breakdown, requires enterprise billing token with admin:enterprise scope.
    Enterprise endpoint: /enterprises/bertelsmann/settings/billing/premium_request/usage?user={login}

.PARAMETER Period
    Reporting period: Daily, Weekly, Monthly, or YTD.

.PARAMETER Date
    Specific date for Daily period (format: yyyy-MM-dd). Defaults to today.

.PARAMETER Previous
    Use the previous period (yesterday, last week, last month).

.PARAMETER Year
    Specific year for Monthly/YTD queries.

.PARAMETER Month
    Specific month (1-12) for Monthly queries.

.PARAMETER Raw
    Output raw JSON instead of formatted report.

.EXAMPLE
    .\Get-CopilotCost.ps1 -Period Daily
    .\Get-CopilotCost.ps1 -Period Daily -Previous
    .\Get-CopilotCost.ps1 -Period Weekly
    .\Get-CopilotCost.ps1 -Period Monthly -Previous
    .\Get-CopilotCost.ps1 -Period YTD
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Daily', 'Weekly', 'Monthly', 'YTD')]
    [string]$Period,

    [string]$Date,
    [switch]$Previous,
    [int]$Year,
    [int]$Month,
    [switch]$Raw
)

$InformationPreference = 'Continue'
$Org = 'Relias-Engineering'
$PricePerRequest = 0.04
$PricePerCredit = 0.01
$CreditsPerSeat = 3900  # Enterprise plan: 3,900 AI Credits/user/month
$PromotionalCreditsPerSeat = 7000  # Jun-Aug 2026 promotional period

# ── Model Multiplier & Token Pricing Lookup ───────────────────────────────────
# Maps model names to: [CurrentMultiplier, NewMultiplier (June 2026), TokenCostPerRequest]
# TokenCostPerRequest = estimated average cost in $ per interaction based on published token rates
# Formula: AI Credits = (grossQuantity / CurrentMultiplier) × NewMultiplier

$ModelLookup = @{
    # Anthropic models
    'Claude Haiku 4.5'    = @{ Current = 0.33; New = 0.33; InputPer1M = 1.00; CachedPer1M = 0.10; OutputPer1M = 5.00 }
    'Claude Sonnet 4'     = @{ Current = 1;    New = 1;    InputPer1M = 3.00; CachedPer1M = 0.30; OutputPer1M = 15.00 }
    'Claude Sonnet 4.5'   = @{ Current = 1;    New = 6;    InputPer1M = 3.00; CachedPer1M = 0.30; OutputPer1M = 15.00 }
    'Claude Sonnet 4.6'   = @{ Current = 1;    New = 9;    InputPer1M = 3.00; CachedPer1M = 0.30; OutputPer1M = 15.00 }
    'Claude Opus 4.5'     = @{ Current = 3;    New = 15;   InputPer1M = 5.00; CachedPer1M = 0.50; OutputPer1M = 25.00 }
    'Claude Opus 4.6'     = @{ Current = 3;    New = 27;   InputPer1M = 5.00; CachedPer1M = 0.50; OutputPer1M = 25.00 }
    'Claude Opus 4.7'     = @{ Current = 15;   New = 27;   InputPer1M = 5.00; CachedPer1M = 0.50; OutputPer1M = 25.00 }
    # OpenAI models
    'GPT-4.1'             = @{ Current = 0;    New = 1;    InputPer1M = 2.00; CachedPer1M = 0.50; OutputPer1M = 8.00 }
    'GPT-5 mini'          = @{ Current = 0;    New = 0.33; InputPer1M = 0.25; CachedPer1M = 0.025; OutputPer1M = 2.00 }
    'GPT-5.2'             = @{ Current = 1;    New = 3;    InputPer1M = 1.75; CachedPer1M = 0.175; OutputPer1M = 14.00 }
    'GPT-5.2-Codex'       = @{ Current = 1;    New = 3;    InputPer1M = 1.75; CachedPer1M = 0.175; OutputPer1M = 14.00 }
    'GPT-5.3-Codex'       = @{ Current = 1;    New = 6;    InputPer1M = 1.75; CachedPer1M = 0.175; OutputPer1M = 14.00 }
    'GPT-5.4'             = @{ Current = 1;    New = 6;    InputPer1M = 2.50; CachedPer1M = 0.25; OutputPer1M = 15.00 }
    'GPT-5.4 mini'        = @{ Current = 0.33; New = 6;    InputPer1M = 0.75; CachedPer1M = 0.075; OutputPer1M = 4.50 }
    'GPT-5.4 nano'        = @{ Current = 0.33; New = 0.33; InputPer1M = 0.20; CachedPer1M = 0.02; OutputPer1M = 1.25 }
    'GPT-5.5'             = @{ Current = 1;    New = 15;   InputPer1M = 5.00; CachedPer1M = 0.50; OutputPer1M = 30.00 }
    # Google models
    'Gemini 2.5 Pro'      = @{ Current = 1;    New = 1;    InputPer1M = 1.25; CachedPer1M = 0.125; OutputPer1M = 10.00 }
    'Gemini 3 Flash'      = @{ Current = 0.33; New = 0.33; InputPer1M = 0.50; CachedPer1M = 0.05; OutputPer1M = 3.00 }
    'Gemini 3.1 Pro'      = @{ Current = 1;    New = 6;    InputPer1M = 2.00; CachedPer1M = 0.20; OutputPer1M = 12.00 }
    # xAI
    'Grok Code Fast 1'    = @{ Current = 0.25; New = 0.33; InputPer1M = 0.20; CachedPer1M = 0.02; OutputPer1M = 1.50 }
    # Special models (estimate based on similar tier)
    'Code Review model'   = @{ Current = 1;    New = 6;    InputPer1M = 3.00; CachedPer1M = 0.30; OutputPer1M = 15.00 }
    'Coding Agent model'  = @{ Current = 1;    New = 6;    InputPer1M = 3.00; CachedPer1M = 0.30; OutputPer1M = 15.00 }
}

# ── NDJSON Internal Model Name → Display Name ────────────────────────────────
$NdjsonModelMap = @{
    'claude-opus-4.6'   = 'Claude Opus 4.6'
    'claude-opus-4.7'   = 'Claude Opus 4.7'
    'claude-opus-4.5'   = 'Claude Opus 4.5'
    'claude-4.6-sonnet' = 'Claude Sonnet 4.6'
    'claude-4.5-sonnet' = 'Claude Sonnet 4.5'
    'claude-4-sonnet'   = 'Claude Sonnet 4'
    'claude-4.5-haiku'  = 'Claude Haiku 4.5'
    'gpt-5.4'           = 'GPT-5.4'
    'gpt-5.3-codex'     = 'GPT-5.3-Codex'
    'gpt-5.2-codex'     = 'GPT-5.2-Codex'
    'gpt-5.2'           = 'GPT-5.2'
    'gpt-5.4-mini'      = 'GPT-5.4 mini'
    'gpt-5.4-nano'      = 'GPT-5.4 nano'
    'gpt-5.5'           = 'GPT-5.5'
    'gpt-4.1'           = 'GPT-4.1'
    'gpt-5-mini'        = 'GPT-5 mini'
    'gemini-2.5-pro'    = 'Gemini 2.5 Pro'
    'gemini-3-flash'    = 'Gemini 3 Flash'
    'gemini-3.1-pro'    = 'Gemini 3.1 Pro'
    'auto'              = 'Auto'
}

function Get-ModelInfo {
    param([string]$ModelName)
    # Strip "Auto: " prefix for lookup
    $lookupName = $ModelName -replace '^Auto:\s*', ''
    $info = $ModelLookup[$lookupName]
    if (-not $info) {
        # Fallback: assume multiplier=1 for unknown models
        return @{ Current = 1; New = 6; InputPer1M = 3.00; CachedPer1M = 0.30; OutputPer1M = 15.00; IsEstimate = $true }
    }
    $result = $info.Clone()
    # Auto model selection gives 10% discount on multipliers
    if ($ModelName -match '^Auto:') {
        $result.Current = $result.Current * 0.9
        $result.New = $result.New * 0.9
    }
    return $result
}

# ── API Helper ────────────────────────────────────────────────────────────────

function Get-PremiumRequestUsage {
    param(
        [int]$QueryYear,
        [int]$QueryMonth,
        [int]$QueryDay = 0
    )

    $url = "/orgs/$Org/settings/billing/premium_request/usage?year=$QueryYear&month=$QueryMonth"
    if ($QueryDay -gt 0) { $url += "&day=$QueryDay" }

    $response = gh api $url -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "API call failed: $response"
        return $null
    }
    return ($response | ConvertFrom-Json)
}

function Get-SeatInfo {
    $response = gh api "/orgs/$Org/copilot/billing" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($response | ConvertFrom-Json)
}

# ── NDJSON Metrics (Real Token Data) ──────────────────────────────────────────

function Get-NdjsonMetric {
    param([string]$Day)
    # Fetches per-user NDJSON metrics from the org-level metrics endpoint.
    # Returns an array of parsed user records with real token data (CLI) and
    # model×feature interaction counts (all users).
    try {
        $apiResp = gh api "/orgs/$Org/copilot/metrics/reports/users-1-day?day=$Day" `
            -H "Accept: application/vnd.github+json" `
            -H "X-GitHub-Api-Version: 2026-03-10" 2>&1
        if ($LASTEXITCODE -ne 0) { return $null }
        $meta = $apiResp | ConvertFrom-Json
        if (-not $meta.download_links -or $meta.download_links.Count -eq 0) { return $null }

        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            Invoke-WebRequest -Uri $meta.download_links[0] -OutFile $tempFile -TimeoutSec 30 -UseBasicParsing
            $lines = Get-Content $tempFile -Encoding UTF8
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }

        $records = @()
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed.Length -gt 0 -and $trimmed[0] -eq '{') {
                try {
                    $records += ($trimmed | ConvertFrom-Json)
                } catch {
                    Write-Verbose "Skipping malformed NDJSON line: $_"
                }
            }
        }
        return $records
    } catch {
        Write-Warning "NDJSON metrics fetch failed: $_"
        return $null
    }
}

function Resolve-NdjsonModelName {
    param([string]$InternalName)
    $display = $NdjsonModelMap[$InternalName]
    if ($display) { return $display }
    # Best-effort: capitalize words
    return ($InternalName -replace '-', ' ' -replace '(\b\w)', { $_.Value.ToUpper() })
}

function Get-TokenCostForModel {
    param([string]$DisplayModelName, [long]$PromptTokens, [long]$OutputTokens)
    $info = $ModelLookup[$DisplayModelName]
    if (-not $info) {
        # Fallback: Sonnet-tier pricing
        $info = @{ InputPer1M = 3.00; OutputPer1M = 15.00 }
    }
    $promptCost = ($PromptTokens / 1000000.0) * $info.InputPer1M
    $outputCost = ($OutputTokens / 1000000.0) * $info.OutputPer1M
    return ($promptCost + $outputCost)
}

function Format-TokenCount {
    param([long]$Tokens)
    if ($Tokens -ge 1000000000) { return "{0:N1}B" -f ($Tokens / 1000000000.0) }
    if ($Tokens -ge 1000000)    { return "{0:N1}M" -f ($Tokens / 1000000.0) }
    if ($Tokens -ge 1000)       { return "{0:N0}K" -f ($Tokens / 1000.0) }
    return "$Tokens"
}

function Write-TokenActual {
    param($NdjsonRecords)
    if (-not $NdjsonRecords -or $NdjsonRecords.Count -eq 0) { return }

    # ── CLI Token Actuals ──
    $cliUsers = @($NdjsonRecords | Where-Object { $_.used_cli -eq $true -and $_.totals_by_cli.token_usage })
    if ($cliUsers.Count -gt 0) {
        Write-Information "`e[33m── Actual Token Data (CLI Users) ──────────────────────────────`e[0m"
        Write-Information "  `e[90mSource: NDJSON metrics — real prompt/output token counts`e[0m"
        Write-Information ""

        $totalPrompt = [long]0
        $totalOutput = [long]0
        $totalCost = [decimal]0
        $totalRequests = 0
        $cliRows = @()

        foreach ($user in $cliUsers) {
            $cli = $user.totals_by_cli
            $prompt = [long]$cli.token_usage.prompt_tokens_sum
            $output = [long]$cli.token_usage.output_tokens_sum
            # CLI model is not specified in the data; use Sonnet pricing as default
            $userCost = Get-TokenCostForModel -DisplayModelName 'Claude Sonnet 4.6' -PromptTokens $prompt -OutputTokens $output
            $totalPrompt += $prompt
            $totalOutput += $output
            $totalCost += $userCost
            $totalRequests += $cli.request_count

            $cliRows += [PSCustomObject]@{
                User         = $user.user_login
                Requests     = $cli.request_count
                'Input Tok'  = Format-TokenCount -Tokens $prompt
                'Output Tok' = Format-TokenCount -Tokens $output
                'Avg/Req'    = "{0:N0}" -f $cli.token_usage.avg_tokens_per_request
                'Est. Cost'  = "`${0:N2}" -f $userCost
            }
        }

        $cliRows | Sort-Object { [decimal]($_.('Est. Cost') -replace '[`$,]','') } -Descending | Format-Table -AutoSize

        Write-Information "  CLI Totals: $($cliUsers.Count) users | $totalRequests requests | Input: $(Format-TokenCount $totalPrompt) | Output: $(Format-TokenCount $totalOutput)"
        Write-Information "  `e[35mEstimated CLI token cost: `$$("{0:N2}" -f $totalCost)`e[0m (Sonnet 4.6 pricing: `$3/M input, `$15/M output)"
        Write-Information "  `e[90mNote: CLI model not specified in data; actual cost may vary per model used.`e[0m"
        Write-Information ""
    }

    # ── Model × Feature Interaction Summary (All Users) ──
    $modelFeatureSummary = @{}
    foreach ($record in $NdjsonRecords) {
        if ($record.totals_by_model_feature) {
            foreach ($mf in $record.totals_by_model_feature) {
                $displayModel = Resolve-NdjsonModelName -InternalName $mf.model
                $key = "$displayModel|$($mf.feature)"
                if (-not $modelFeatureSummary.ContainsKey($key)) {
                    $modelFeatureSummary[$key] = @{ Model = $displayModel; Feature = $mf.feature; Interactions = 0; Users = 0 }
                }
                $modelFeatureSummary[$key].Interactions += $mf.user_initiated_interaction_count
                if ($mf.user_initiated_interaction_count -gt 0) { $modelFeatureSummary[$key].Users += 1 }
            }
        }
    }

    if ($modelFeatureSummary.Count -gt 0) {
        Write-Information "`e[33m── Model × Feature Interactions (All Users, NDJSON) ──────────`e[0m"
        Write-Information "  `e[90mSource: NDJSON metrics — interaction counts (no token data for IDE/chat)`e[0m"
        Write-Information ""

        $mfRows = $modelFeatureSummary.Values |
            Where-Object { $_.Interactions -gt 0 } |
            Sort-Object { $_.Interactions } -Descending |
            Select-Object -First 15 |
            ForEach-Object {
                $feat = if ([string]::IsNullOrWhiteSpace($_.Feature)) { '' } else { $_.Feature }
                $featureLabel = switch -Wildcard ($feat) {
                    'chat_panel_agent_mode'  { 'Agent' }
                    'chat_panel_ask_mode'    { 'Ask' }
                    'chat_panel_edit_mode'   { 'Edit' }
                    'chat_panel_custom_mode' { 'Custom' }
                    'chat_inline'            { 'Inline Chat' }
                    'agent_edit'             { 'Agent Edit' }
                    'code_completion'        { 'Completion' }
                    'code_review'            { 'Code Review' }
                    'copilot_cli'            { 'CLI' }
                    'coding_agent'           { 'Coding Agent' }
                    ''                       { 'Other' }
                    default                  { $feat }
                }
                [PSCustomObject]@{
                    Model        = $_.Model
                    Feature      = $featureLabel
                    Interactions = $_.Interactions
                    Users        = $_.Users
                }
            }

        $mfRows | Format-Table -AutoSize

        $totalActiveUsers = ($NdjsonRecords | Measure-Object).Count
        $totalInteractions = ($modelFeatureSummary.Values | Measure-Object -Property Interactions -Sum).Sum
        $cliUserCount = $cliUsers.Count
        $ideOnlyCount = $totalActiveUsers - $cliUserCount

        Write-Information "  Total: $totalActiveUsers active users ($cliUserCount CLI + $ideOnlyCount IDE-only) | $totalInteractions interactions"
        Write-Information "  `e[90mToken counts NOT available for IDE/chat/agent interactions — only request counts shown.`e[0m"
        Write-Information "  `e[90mAfter June 1, 2026: billing API should expose AI Credit consumption for all usage.`e[0m"
        Write-Information ""
    }
}

# ── Token Economy Calculation ─────────────────────────────────────────────────

function Convert-ToAICredit {
    param($UsageItems)
    # Converts current PRU-based usage items to estimated AI Credit consumption
    # Formula: AI Credits = (grossQuantity / currentMultiplier) × newMultiplier
    # This uses the new multiplier as GitHub's own estimate of credits per request

    $totalCredits = 0.0
    $itemDetails = @()

    foreach ($item in $UsageItems) {
        $modelInfo = Get-ModelInfo -ModelName $item.model
        $currentMult = $modelInfo.Current
        $newMult = $modelInfo.New

        # Derive actual request count from PRU quantity
        if ($currentMult -gt 0) {
            $actualRequests = $item.grossQuantity / $currentMult
        } else {
            # Free models (multiplier=0) don't consume PRUs; estimate 1:1
            $actualRequests = $item.grossQuantity
        }

        # Estimated AI Credits under new billing
        $credits = $actualRequests * $newMult
        $creditCost = $credits * $PricePerCredit
        $totalCredits += $credits

        $itemDetails += [PSCustomObject]@{
            Model          = $item.model
            PRUs           = [math]::Round($item.grossQuantity, 1)
            PRU_Cost       = [math]::Round($item.grossAmount, 2)
            ActualRequests = [math]::Round($actualRequests, 0)
            AICredits      = [math]::Round($credits, 1)
            AIC_Cost       = [math]::Round($creditCost, 2)
            Multiplier     = "$($currentMult)x → $($newMult)x"
        }
    }

    return [PSCustomObject]@{
        TotalCredits = [math]::Round($totalCredits, 1)
        TotalCost    = [math]::Round($totalCredits * $PricePerCredit, 2)
        Items        = $itemDetails
    }
}

# ── Formatting ────────────────────────────────────────────────────────────────

function Format-RequestData {
    param($UsageItems)

    $totalRequests = ($UsageItems | Measure-Object -Property grossQuantity -Sum).Sum
    $totalGross = ($UsageItems | Measure-Object -Property grossAmount -Sum).Sum
    $totalNet = ($UsageItems | Measure-Object -Property netAmount -Sum).Sum

    $tokenEconomy = Convert-ToAICredit -UsageItems $UsageItems

    return [PSCustomObject]@{
        TotalRequests = [math]::Round($totalRequests, 1)
        GrossCost     = [math]::Round($totalGross, 2)
        NetCost       = [math]::Round($totalNet, 2)
        AICredits     = $tokenEconomy.TotalCredits
        AICreditCost  = $tokenEconomy.TotalCost
        TokenDetails  = $tokenEconomy.Items
        Items         = $UsageItems
    }
}

function Write-Header {
    param([string]$PeriodLabel, [string]$DateRange)
    Write-Information ""
    Write-Information "`e[36m╔══════════════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Information "`e[36m║  Copilot Cost — $Org`e[0m"
    Write-Information "`e[36m║  Period: $PeriodLabel — $DateRange`e[0m"
    Write-Information "`e[36m║  Billing Comparison: Premium Requests (current) vs AI Credits (Jun 1)`e[0m"
    Write-Information "`e[36m╚══════════════════════════════════════════════════════════════════════════╝`e[0m"
    Write-Information ""
}

function Write-ModelBreakdown {
    param($UsageItems, [string]$Label = "By Model")

    $tokenEconomy = Convert-ToAICredit -UsageItems $UsageItems

    Write-Information "`e[33m── $Label (PRU vs AI Credits) ────────────────────────────────`e[0m"
    $tokenEconomy.Items | Sort-Object -Property PRUs -Descending | ForEach-Object {
        [PSCustomObject]@{
            Model      = $_.Model
            PRUs       = $_.PRUs
            'PRU $'    = "`${0:N2}" -f $_.PRU_Cost
            Requests   = $_.ActualRequests
            AICredits  = $_.AICredits
            'AIC $'    = "`${0:N2}" -f $_.AIC_Cost
            'Mult'     = $_.Multiplier
        }
    } | Format-Table -AutoSize

    # Show totals
    $totalPRU = ($tokenEconomy.Items | Measure-Object -Property PRU_Cost -Sum).Sum
    $totalAIC = ($tokenEconomy.Items | Measure-Object -Property AIC_Cost -Sum).Sum
    $delta = $totalAIC - $totalPRU
    $deltaSign = if ($delta -gt 0) { "+" } else { "" }
    $deltaColor = if ($delta -gt 0) { "`e[31m" } else { "`e[32m" }
    $totalPRUFmt = "{0:N2}" -f $totalPRU
    $totalAICFmt = "{0:N2}" -f $totalAIC
    $deltaFmt = "{0:N2}" -f $delta
    $pctChange = if ($totalPRU -gt 0) { (($totalAIC - $totalPRU) / $totalPRU) * 100 } else { 0 }
    $pctFmt = "{0:N0}" -f $pctChange

    Write-Information "  `e[33mTotals:`e[0m  PRU: `$$totalPRUFmt  |  AI Credits: `$$totalAICFmt  |  Delta: ${deltaColor}${deltaSign}`$$deltaFmt (${deltaSign}$pctFmt%)`e[0m"
    Write-Information ""
}

function Write-BudgetStatus {
    param(
        [decimal]$TotalRequests,
        [decimal]$TotalAICredits,
        [int]$SeatCount,
        [int]$DaysInMonth,
        [int]$DaysElapsed
    )

    # ── Current: Premium Request Budget ──
    $pruAllotment = $SeatCount * 1000
    $pruPctUsed = if ($pruAllotment -gt 0) { ($TotalRequests / $pruAllotment) * 100 } else { 0 }
    $pruRemaining = $pruAllotment - $TotalRequests

    # ── Token Economy: AI Credits Budget ──
    # Use promotional rate for Jun-Aug 2026, standard otherwise
    $now = Get-Date
    $isPromotional = ($now.Year -eq 2026 -and $now.Month -ge 6 -and $now.Month -le 8)
    $creditsPerSeatActual = if ($isPromotional) { $PromotionalCreditsPerSeat } else { $CreditsPerSeat }
    $aicAllotment = $SeatCount * $creditsPerSeatActual
    $aicPctUsed = if ($aicAllotment -gt 0) { ($TotalAICredits / $aicAllotment) * 100 } else { 0 }
    $aicRemaining = $aicAllotment - $TotalAICredits

    $pruPctFmt = "{0:N1}" -f $pruPctUsed
    $aicPctFmt = "{0:N1}" -f $aicPctUsed

    Write-Information "`e[33m── Budget Status ────────────────────────────────────────────`e[0m"
    Write-Information "  Seats:                 $SeatCount"
    Write-Information ""
    Write-Information "  `e[36m┌─ Current (PRU) ─────────────────────────────────────────┐`e[0m"
    Write-Information "  `e[36m│`e[0m  Allotment:   $($pruAllotment.ToString('N0')) PRUs ($SeatCount × 1,000)"
    Write-Information "  `e[36m│`e[0m  Consumed:    $($TotalRequests.ToString('N1')) ($pruPctFmt%)"
    Write-Information "  `e[36m│`e[0m  Remaining:   $($pruRemaining.ToString('N1')) PRUs"
    Write-Information "  `e[36m└─────────────────────────────────────────────────────────┘`e[0m"
    Write-Information ""
    $promoNote = if ($isPromotional) { " (PROMOTIONAL Jun-Aug)" } else { "" }
    Write-Information "  `e[35m┌─ Token Economy (AI Credits) ────────────────────────────┐`e[0m"
    Write-Information "  `e[35m│`e[0m  Allotment:   $($aicAllotment.ToString('N0')) credits ($SeatCount × $($creditsPerSeatActual.ToString('N0')))$promoNote"
    Write-Information "  `e[35m│`e[0m  Consumed:    $($TotalAICredits.ToString('N1')) credits = `$$("{0:N2}" -f ($TotalAICredits * $PricePerCredit)) ($aicPctFmt%)"
    Write-Information "  `e[35m│`e[0m  Remaining:   $($aicRemaining.ToString('N1')) credits = `$$("{0:N2}" -f ($aicRemaining * $PricePerCredit))"
    Write-Information "  `e[35m└─────────────────────────────────────────────────────────┘`e[0m"

    if ($DaysElapsed -gt 0 -and $DaysInMonth -gt 0) {
        $avgPRUPerDay = $TotalRequests / $DaysElapsed
        $projPRU = $avgPRUPerDay * $DaysInMonth
        $avgAICPerDay = $TotalAICredits / $DaysElapsed
        $projAIC = $avgAICPerDay * $DaysInMonth

        $projPRUColor = if ($projPRU -gt $pruAllotment) { "`e[31m" } else { "`e[32m" }
        $projAICColor = if ($projAIC -gt $aicAllotment) { "`e[31m" } else { "`e[32m" }

        $avgPRUFmt = "{0:N1}" -f $avgPRUPerDay
        $avgAICFmt = "{0:N1}" -f $avgAICPerDay
        $projPRUFmt = "{0:N0}" -f $projPRU
        $projAICFmt = "{0:N0}" -f $projAIC

        Write-Information ""
        Write-Information "`e[33m── Projection (End of Month) ────────────────────────────────`e[0m"
        Write-Information "  Avg/Day:      PRU: $avgPRUFmt  |  AIC: $avgAICFmt credits (`$$("{0:N2}" -f ($avgAICPerDay * $PricePerCredit))/day)"
        Write-Information "  EOM Total:    PRU: ${projPRUColor}$projPRUFmt / $($pruAllotment.ToString('N0'))`e[0m  |  AIC: ${projAICColor}$projAICFmt / $($aicAllotment.ToString('N0'))`e[0m"

        if ($projPRU -gt $pruAllotment) {
            $overPRU = $projPRU - $pruAllotment
            Write-Information "  PRU Overage:  `e[31m$("{0:N0}" -f $overPRU) requests = `$$("{0:N2}" -f ($overPRU * $PricePerRequest))`e[0m"
        }
        if ($projAIC -gt $aicAllotment) {
            $overAIC = $projAIC - $aicAllotment
            Write-Information "  AIC Overage:  `e[31m$("{0:N0}" -f $overAIC) credits = `$$("{0:N2}" -f ($overAIC * $PricePerCredit))`e[0m"
        }
    }
    Write-Information ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

$now = Get-Date
$billing = Get-SeatInfo
$seatCount = if ($billing) { $billing.seat_breakdown.total } else { 0 }

switch ($Period) {
    'Daily' {
        if ($Date) {
            $target = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
        } elseif ($Previous) {
            $target = $now.AddDays(-1)
        } else {
            $target = $now
        }

        $data = Get-PremiumRequestUsage -QueryYear $target.Year -QueryMonth $target.Month -QueryDay $target.Day
        if ($Raw -and $data) { $data | ConvertTo-Json -Depth 5; exit 0 }

        Write-Header -PeriodLabel "Daily" -DateRange $target.ToString('yyyy-MM-dd')

        if ($data -and $data.usageItems -and $data.usageItems.Count -gt 0) {
            $summary = Format-RequestData -UsageItems $data.usageItems
            Write-Information "`e[33m── Summary ──────────────────────────────────────────────────`e[0m"
            Write-Information "  `e[36mPremium Requests:`e[0m  $($summary.TotalRequests) PRUs → `$$($summary.GrossCost) gross / `$$($summary.NetCost) net"
            Write-Information "  `e[35mToken Economy:`e[0m     $($summary.AICredits) AI Credits → `$$($summary.AICreditCost) (multiplier estimate)"
            Write-Information ""
            Write-ModelBreakdown -UsageItems $data.usageItems

            # ── NDJSON Metrics: Real Token Data ──
            Write-Information "`e[36m  Fetching NDJSON metrics for actual token data...`e[0m"
            $ndjsonRecords = Get-NdjsonMetric -Day $target.ToString('yyyy-MM-dd')
            if ($ndjsonRecords) {
                Write-TokenActual -NdjsonRecords $ndjsonRecords
            } else {
                Write-Information "  `e[90mNDJSON metrics not available for this date (data typically available after midnight UTC).`e[0m"
                Write-Information ""
            }

            Write-BudgetStatus -TotalRequests $summary.TotalRequests -TotalAICredits $summary.AICredits `
                -SeatCount $seatCount `
                -DaysInMonth ([DateTime]::DaysInMonth($target.Year, $target.Month)) `
                -DaysElapsed $target.Day
        } else {
            Write-Information "  No usage data available for this date."
            Write-Information "  (Data may not yet be generated — typically available after midnight UTC)"
            Write-Information ""
        }
    }

    'Weekly' {
        if ($Previous) {
            $endDate = ($now.AddDays(-7)).Date
            $startDate = ($now.AddDays(-13)).Date
        } else {
            $endDate = $now.Date
            $startDate = ($now.AddDays(-6)).Date
        }

        Write-Header -PeriodLabel "Weekly" -DateRange "$($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd'))"

        $weekTotal = 0
        $weekAIC = 0
        $allItems = @()
        $dailyRows = @()

        for ($i = 0; $i -le ($endDate - $startDate).Days; $i++) {
            $day = $startDate.AddDays($i)
            $data = Get-PremiumRequestUsage -QueryYear $day.Year -QueryMonth $day.Month -QueryDay $day.Day
            $dayRequests = 0
            $dayCredits = 0
            if ($data -and $data.usageItems) {
                $dayRequests = ($data.usageItems | Measure-Object -Property grossQuantity -Sum).Sum
                $dayTokenData = Convert-ToAICredit -UsageItems $data.usageItems
                $dayCredits = $dayTokenData.TotalCredits
                $allItems += $data.usageItems
            }
            $weekTotal += $dayRequests
            $weekAIC += $dayCredits
            $dailyRows += [PSCustomObject]@{
                Date       = $day.ToString('yyyy-MM-dd')
                Day        = $day.ToString('ddd')
                PRUs       = [math]::Round($dayRequests, 1)
                'PRU $'    = "`${0:N2}" -f ($dayRequests * $PricePerRequest)
                AICredits  = [math]::Round($dayCredits, 1)
                'AIC $'    = "`${0:N2}" -f ($dayCredits * $PricePerCredit)
            }
        }

        if ($Raw) { $dailyRows | ConvertTo-Json -Depth 3; exit 0 }

        Write-Information "`e[33m── Summary ──────────────────────────────────────────────────`e[0m"
        $weekTotalFmt = "{0:N1}" -f $weekTotal
        $weekCostFmt = "{0:N2}" -f ($weekTotal * $PricePerRequest)
        $weekAICFmt = "{0:N1}" -f $weekAIC
        $weekAICCostFmt = "{0:N2}" -f ($weekAIC * $PricePerCredit)
        $weekAvgFmt = "{0:N1}" -f ($weekTotal / 7)
        Write-Information "  `e[36mPremium Requests:`e[0m  $weekTotalFmt PRUs → `$$weekCostFmt gross"
        Write-Information "  `e[35mToken Economy:`e[0m     $weekAICFmt AI Credits → `$$weekAICCostFmt estimated"
        Write-Information "  Avg/Day:            $weekAvgFmt PRUs"
        Write-Information ""
        Write-Information "`e[33m── Daily Breakdown ──────────────────────────────────────────`e[0m"
        $dailyRows | Format-Table -AutoSize

        if ($allItems.Count -gt 0) {
            Write-ModelBreakdown -UsageItems $allItems -Label "Week Model Summary"
        }

        Write-BudgetStatus -TotalRequests $weekTotal -TotalAICredits $weekAIC -SeatCount $seatCount `
            -DaysInMonth ([DateTime]::DaysInMonth($now.Year, $now.Month)) `
            -DaysElapsed $now.Day
    }

    'Monthly' {
        if ($Previous) {
            $target = $now.AddMonths(-1)
            $qYear = $target.Year
            $qMonth = $target.Month
        } else {
            $qYear = if ($Year -gt 0) { $Year } else { $now.Year }
            $qMonth = if ($Month -gt 0) { $Month } else { $now.Month }
        }

        $daysInMonth = [DateTime]::DaysInMonth($qYear, $qMonth)
        $isCurrentMonth = ($qYear -eq $now.Year -and $qMonth -eq $now.Month)
        $daysElapsed = if ($isCurrentMonth) { $now.Day } else { $daysInMonth }
        $monthLabel = (Get-Date -Year $qYear -Month $qMonth -Day 1).ToString('MMMM yyyy')

        $data = Get-PremiumRequestUsage -QueryYear $qYear -QueryMonth $qMonth
        if ($Raw -and $data) { $data | ConvertTo-Json -Depth 5; exit 0 }

        Write-Header -PeriodLabel "Monthly" -DateRange $monthLabel

        if ($data -and $data.usageItems -and $data.usageItems.Count -gt 0) {
            $summary = Format-RequestData -UsageItems $data.usageItems
            Write-Information "`e[33m── Summary ──────────────────────────────────────────────────`e[0m"
            Write-Information "  `e[36mPremium Requests:`e[0m  $($summary.TotalRequests) PRUs → `$$($summary.GrossCost) gross / `$$($summary.NetCost) net"
            Write-Information "  `e[35mToken Economy:`e[0m     $($summary.AICredits) AI Credits → `$$($summary.AICreditCost) estimated"
            if ($isCurrentMonth) {
                Write-Information "  Days Elapsed:       $daysElapsed of $daysInMonth"
            }
            Write-Information ""
            Write-ModelBreakdown -UsageItems $data.usageItems
            Write-BudgetStatus -TotalRequests $summary.TotalRequests -TotalAICredits $summary.AICredits `
                -SeatCount $seatCount `
                -DaysInMonth $daysInMonth -DaysElapsed $daysElapsed
        } else {
            Write-Information "  No usage data available for $monthLabel."
            Write-Information ""
        }
    }

    'YTD' {
        $qYear = if ($Year -gt 0) { $Year } else { $now.Year }
        $endMonth = if ($qYear -eq $now.Year) { $now.Month } else { 12 }

        Write-Header -PeriodLabel "Year-to-Date" -DateRange "$qYear (Jan–$((Get-Date -Year $qYear -Month $endMonth -Day 1).ToString('MMM')))"

        $ytdTotal = 0
        $ytdAIC = 0
        $monthlyRows = @()

        for ($m = 1; $m -le $endMonth; $m++) {
            $data = Get-PremiumRequestUsage -QueryYear $qYear -QueryMonth $m
            $monthRequests = 0
            $monthCredits = 0
            if ($data -and $data.usageItems) {
                $monthRequests = ($data.usageItems | Measure-Object -Property grossQuantity -Sum).Sum
                $monthTokenData = Convert-ToAICredit -UsageItems $data.usageItems
                $monthCredits = $monthTokenData.TotalCredits
            }
            $ytdTotal += $monthRequests
            $ytdAIC += $monthCredits
            $monthlyRows += [PSCustomObject]@{
                Month      = (Get-Date -Year $qYear -Month $m -Day 1).ToString('MMM yyyy')
                PRUs       = [math]::Round($monthRequests, 1)
                'PRU $'    = "`${0:N2}" -f ($monthRequests * $PricePerRequest)
                AICredits  = [math]::Round($monthCredits, 1)
                'AIC $'    = "`${0:N2}" -f ($monthCredits * $PricePerCredit)
            }
        }

        if ($Raw) { $monthlyRows | ConvertTo-Json -Depth 3; exit 0 }

        $ytdPRUAllotment = $seatCount * 1000 * $endMonth
        $ytdAICAllotment = $seatCount * $CreditsPerSeat * $endMonth
        $pruPctUsed = if ($ytdPRUAllotment -gt 0) { ($ytdTotal / $ytdPRUAllotment) * 100 } else { 0 }
        $aicPctUsed = if ($ytdAICAllotment -gt 0) { ($ytdAIC / $ytdAICAllotment) * 100 } else { 0 }

        Write-Information "`e[33m── Summary ──────────────────────────────────────────────────`e[0m"
        $ytdTotalFmt = "{0:N1}" -f $ytdTotal
        $ytdCostFmt = "{0:N2}" -f ($ytdTotal * $PricePerRequest)
        $ytdAICFmt = "{0:N1}" -f $ytdAIC
        $ytdAICCostFmt = "{0:N2}" -f ($ytdAIC * $PricePerCredit)
        $pruPctFmt = "{0:N1}" -f $pruPctUsed
        $aicPctFmt = "{0:N1}" -f $aicPctUsed

        Write-Information "  `e[36mPremium Requests (YTD):`e[0m"
        Write-Information "    Total:       $ytdTotalFmt PRUs → `$$ytdCostFmt"
        Write-Information "    Allotment:   $($ytdPRUAllotment.ToString('N0')) ($seatCount × 1,000 × $endMonth months)"
        Write-Information "    Utilization: $pruPctFmt%"
        Write-Information ""
        Write-Information "  `e[35mToken Economy (YTD):`e[0m"
        Write-Information "    Total:       $ytdAICFmt AI Credits → `$$ytdAICCostFmt"
        Write-Information "    Allotment:   $($ytdAICAllotment.ToString('N0')) ($seatCount × $CreditsPerSeat × $endMonth months)"
        Write-Information "    Utilization: $aicPctFmt%"
        Write-Information ""
        Write-Information "  Seats: $seatCount"
        Write-Information ""
        Write-Information "`e[33m── Monthly Breakdown ────────────────────────────────────────`e[0m"
        $monthlyRows | Format-Table -AutoSize
    }
}
