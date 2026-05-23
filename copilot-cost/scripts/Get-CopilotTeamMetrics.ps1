<#
.SYNOPSIS
    Report Copilot usage metrics broken down by team for Relias-Engineering.

.DESCRIPTION
    Joins the user-teams-1-day NDJSON report with the users-1-day NDJSON report
    to produce team-level Copilot usage metrics. Supports single-day or multi-day
    rolling window aggregation.

    API Endpoints (API Version 2026-03-10):
      - GET /orgs/{org}/copilot/metrics/reports/user-teams-1-day?day={YYYY-MM-DD}
      - GET /orgs/{org}/copilot/metrics/reports/users-1-day?day={YYYY-MM-DD}

    The join is performed on (user_id, day, organization_id). Aggregation groups
    by team_id (stable identifier); slug is carried as display metadata.

    IMPORTANT: Users on multiple teams are counted in EACH team's aggregate.
    Team totals are NOT additive — do not sum them to reproduce org totals.

    Teams with fewer than 5 Copilot-seated users are excluded by the API.

.PARAMETER Day
    Specific day (YYYY-MM-DD). Defaults to yesterday (latest available data).

.PARAMETER Window
    Number of days to aggregate (1-28). Default: 1. When >1, fetches each day
    in the window and produces a rolling aggregate with correct distinct-user counts.

.PARAMETER Team
    Filter output to a specific team slug.

.PARAMETER Raw
    Output raw JSON instead of formatted report.

.EXAMPLE
    .\Get-CopilotTeamMetrics.ps1
    .\Get-CopilotTeamMetrics.ps1 -Day "2026-05-20"
    .\Get-CopilotTeamMetrics.ps1 -Window 7
    .\Get-CopilotTeamMetrics.ps1 -Window 28 -Team "platform-engineering"
#>

[CmdletBinding()]
param(
    [string]$Day,
    [ValidateRange(1, 28)]
    [int]$Window = 1,
    [string]$Team,
    [switch]$Raw
)

$InformationPreference = 'Continue'
$Org = 'Relias-Engineering'
$ApiVersion = '2026-03-10'

# ── NDJSON Fetch Helper ───────────────────────────────────────────────────────
# Downloads ALL download_links (handles multi-shard reports)

function Get-NdjsonReport {
    param(
        [string]$Endpoint,
        [string]$Description
    )

    try {
        $apiResp = gh api $Endpoint `
            -H "Accept: application/vnd.github+json" `
            -H "X-GitHub-Api-Version: $ApiVersion" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$Description API call failed: $apiResp"
            return $null
        }
        $meta = $apiResp | ConvertFrom-Json
        if (-not $meta.download_links -or $meta.download_links.Count -eq 0) {
            Write-Verbose "$Description returned no download links"
            return $null
        }

        $records = @()
        foreach ($url in $meta.download_links) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                Invoke-WebRequest -Uri $url -OutFile $tempFile -TimeoutSec 60 -UseBasicParsing
                $lines = Get-Content $tempFile -Encoding UTF8
                foreach ($line in $lines) {
                    $trimmed = $line.Trim()
                    if ($trimmed.Length -gt 0 -and $trimmed[0] -eq '{') {
                        try {
                            $records += ($trimmed | ConvertFrom-Json)
                        } catch {
                            Write-Verbose "Skipping malformed NDJSON line in $Description"
                        }
                    }
                }
            } finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        return $records
    } catch {
        Write-Warning "$Description fetch failed: $_"
        return $null
    }
}

# ── Main Logic ────────────────────────────────────────────────────────────────

# Determine date range
if ($Day) {
    $endDate = [datetime]::ParseExact($Day, 'yyyy-MM-dd', $null)
} else {
    # Default to yesterday (metrics typically available after midnight UTC)
    $endDate = (Get-Date).AddDays(-1).Date
}
$startDate = $endDate.AddDays(-($Window - 1))

Write-Information ""
Write-Information "`e[36m╔══════════════════════════════════════════════════════════════════════════╗`e[0m"
Write-Information "`e[36m║  Copilot Team Metrics — $Org`e[0m"
if ($Window -eq 1) {
    Write-Information "`e[36m║  Day: $($endDate.ToString('yyyy-MM-dd'))`e[0m"
} else {
    Write-Information "`e[36m║  Window: $($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd')) ($Window days)`e[0m"
}
if ($Team) {
    Write-Information "`e[36m║  Filter: team=$Team`e[0m"
}
Write-Information "`e[36m╚══════════════════════════════════════════════════════════════════════════╝`e[0m"
Write-Information ""

# Accumulate joined data across the window
# Key: team_id → { slug, user_ids (HashSet), metrics accumulators }
$teamData = @{}
$daysProcessed = 0
$daysWithData = 0

for ($i = 0; $i -lt $Window; $i++) {
    $currentDay = $startDate.AddDays($i)
    $dayStr = $currentDay.ToString('yyyy-MM-dd')

    Write-Verbose "Fetching data for $dayStr..."

    # Fetch user-teams report
    $userTeams = Get-NdjsonReport `
        -Endpoint "/orgs/$Org/copilot/metrics/reports/user-teams-1-day?day=$dayStr" `
        -Description "user-teams ($dayStr)"

    # Fetch per-user usage report
    $userUsage = Get-NdjsonReport `
        -Endpoint "/orgs/$Org/copilot/metrics/reports/users-1-day?day=$dayStr" `
        -Description "users-1-day ($dayStr)"

    $daysProcessed++

    if (-not $userTeams -or -not $userUsage) {
        Write-Verbose "No data available for $dayStr — skipping"
        continue
    }

    $daysWithData++

    # Build lookup: user_id → usage record for this day
    $usageLookup = @{}
    foreach ($record in $userUsage) {
        $key = "$($record.user_id)"
        $usageLookup[$key] = $record
    }

    # Join: for each user-team row, find matching usage and accumulate
    foreach ($membership in $userTeams) {
        $teamId = "$($membership.team_id)"
        $slug = $membership.slug
        $userId = "$($membership.user_id)"

        # Filter by team if specified
        if ($Team -and $slug -ne $Team) { continue }

        # Find usage for this user on this day
        $usage = $usageLookup[$userId]
        if (-not $usage) { continue }

        # Initialize team accumulator if needed
        if (-not $teamData.ContainsKey($teamId)) {
            $teamData[$teamId] = @{
                TeamId      = $teamId
                Slug        = $slug
                UserIds     = [System.Collections.Generic.HashSet[string]]::new()
                ChatUsers   = [System.Collections.Generic.HashSet[string]]::new()
                AgentUsers  = [System.Collections.Generic.HashSet[string]]::new()
                CliUsers    = [System.Collections.Generic.HashSet[string]]::new()
                Interactions = 0
                CodeGenerations = 0
                CodeAcceptances = 0
                LocSuggested = 0
                LocAdded     = 0
                CliPromptTokens = [long]0
                CliOutputTokens = [long]0
                CliRequests  = 0
            }
        }

        $t = $teamData[$teamId]
        # Update slug to latest seen (handles renames within window)
        $t.Slug = $slug

        # Distinct user tracking
        [void]$t.UserIds.Add($userId)
        if ($usage.used_chat -eq $true) { [void]$t.ChatUsers.Add($userId) }
        if ($usage.used_agent -eq $true) { [void]$t.AgentUsers.Add($userId) }
        if ($usage.used_cli -eq $true) { [void]$t.CliUsers.Add($userId) }

        # Additive metrics
        $t.Interactions += [int]($usage.user_initiated_interaction_count)
        $t.CodeGenerations += [int]($usage.code_generation_activity_count)
        $t.CodeAcceptances += [int]($usage.code_acceptance_activity_count)
        $t.LocSuggested += [int]($usage.loc_suggested_to_add_sum)
        $t.LocAdded += [int]($usage.loc_added_sum)

        # CLI token data
        if ($usage.used_cli -eq $true -and $usage.totals_by_cli.token_usage) {
            $t.CliPromptTokens += [long]($usage.totals_by_cli.token_usage.prompt_tokens_sum)
            $t.CliOutputTokens += [long]($usage.totals_by_cli.token_usage.output_tokens_sum)
            $t.CliRequests += [int]($usage.totals_by_cli.request_count)
        }
    }
}

# ── Output ────────────────────────────────────────────────────────────────────

if ($daysWithData -eq 0) {
    Write-Information "  `e[90mNo team metrics data available for the requested period.`e[0m"
    Write-Information "  `e[90mPossible reasons:`e[0m"
    Write-Information "    - Data not yet generated (typically available after midnight UTC)"
    Write-Information "    - No teams with 5+ Copilot-seated users"
    Write-Information "    - API access issue"
    Write-Information ""
    exit 0
}

Write-Information "`e[33m── Data Coverage ────────────────────────────────────────────`e[0m"
Write-Information "  Days requested: $daysProcessed | Days with data: $daysWithData | Teams found: $($teamData.Count)"
Write-Information ""

if ($teamData.Count -eq 0) {
    Write-Information "  `e[90mNo team data found. Teams must have 5+ Copilot-seated users to appear.`e[0m"
    Write-Information ""
    exit 0
}

# Build output objects
$results = $teamData.Values | ForEach-Object {
    $acceptRate = if ($_.CodeGenerations -gt 0) { [math]::Round(($_.CodeAcceptances / $_.CodeGenerations) * 100, 1) } else { 0 }
    [PSCustomObject]@{
        team_id         = $_.TeamId
        slug            = $_.Slug
        active_users    = $_.UserIds.Count
        chat_users      = $_.ChatUsers.Count
        agent_users     = $_.AgentUsers.Count
        cli_users       = $_.CliUsers.Count
        interactions    = $_.Interactions
        code_generations = $_.CodeGenerations
        code_acceptances = $_.CodeAcceptances
        accept_rate_pct = $acceptRate
        loc_suggested   = $_.LocSuggested
        loc_added       = $_.LocAdded
        cli_prompt_tokens = $_.CliPromptTokens
        cli_output_tokens = $_.CliOutputTokens
        cli_requests    = $_.CliRequests
    }
} | Sort-Object -Property interactions -Descending

if ($Raw) {
    $results | ConvertTo-Json -Depth 5
    exit 0
}

# ── Formatted Output ──────────────────────────────────────────────────────────

Write-Information "`e[33m── Team Usage Summary ───────────────────────────────────────`e[0m"

$tableRows = $results | ForEach-Object {
    [PSCustomObject]@{
        Team          = $_.slug
        'Active'      = $_.active_users
        'Chat'        = $_.chat_users
        'Agent'       = $_.agent_users
        'CLI'         = $_.cli_users
        'Interactions' = $_.interactions
        'CodeGen'     = $_.code_generations
        'Accept%'     = "$($_.accept_rate_pct)%"
        'LOC Added'   = $_.loc_added
    }
}

$tableRows | Format-Table -AutoSize

# ── Detailed Per-Team Stats ──
if ($results.Count -le 10 -or $Team) {
    Write-Information "`e[33m── Detailed Breakdown ──────────────────────────────────────`e[0m"
    foreach ($t in $results) {
        Write-Information "  `e[36m$($t.slug)`e[0m (team_id: $($t.team_id))"
        Write-Information "    Active Users: $($t.active_users) | Chat: $($t.chat_users) | Agent: $($t.agent_users) | CLI: $($t.cli_users)"
        Write-Information "    Interactions: $($t.interactions) | Code Generations: $($t.code_generations) | Acceptances: $($t.code_acceptances) ($($t.accept_rate_pct)%)"
        Write-Information "    LOC Suggested: $($t.loc_suggested) | LOC Added: $($t.loc_added)"
        if ($t.cli_requests -gt 0) {
            $promptK = [math]::Round($t.cli_prompt_tokens / 1000, 0)
            $outputK = [math]::Round($t.cli_output_tokens / 1000, 0)
            Write-Information "    CLI: $($t.cli_requests) requests | Prompt: ${promptK}K tokens | Output: ${outputK}K tokens"
        }
        Write-Information ""
    }
}

# ── Org Totals Comparison ──
$totalActiveAcrossTeams = ($results | Measure-Object -Property active_users -Sum).Sum

Write-Information "`e[33m── Notes ───────────────────────────────────────────────────`e[0m"
Write-Information "  `e[90m• Users on multiple teams are counted in EACH team — team totals are NOT additive`e[0m"
Write-Information "  `e[90m• Sum of active users across teams ($totalActiveAcrossTeams) may exceed org total due to multi-team membership`e[0m"
Write-Information "  `e[90m• Teams with <5 Copilot-seated users are excluded by the API (privacy threshold)`e[0m"
if ($Window -gt 1) {
    Write-Information "  `e[90m• Distinct-user counts (Active, Chat, Agent, CLI) are deduplicated across the full window`e[0m"
}
Write-Information ""
