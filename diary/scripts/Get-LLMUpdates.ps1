<#
.SYNOPSIS
    Checks OpenRouter for new model releases and tracks model additions.

.DESCRIPTION
    Retrieves all models from the OpenRouter API, filters by creation date
    to find new releases, and diffs against a saved model list to detect
    additions since the last run. Also provides reference links for LMSYS
    Chatbot Arena leaderboard and OpenRouter app rankings (manual checks).

    Outputs a formatted text file to the diary output folder for caching.

    Requires the OPENROUTER_API_KEY environment variable to be set.

.PARAMETER DaysBack
    Number of days to look back for new model releases (default: 7)

.PARAMETER Force
    Force display of all recent data even if no new models detected

.EXAMPLE
    .\Get-LLMUpdates.ps1
    Checks for new models from the last 7 days

.EXAMPLE
    .\Get-LLMUpdates.ps1 -DaysBack 14 -Force
    Shows all models from the last 14 days
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$DaysBack = 7,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir = Join-Path (Split-Path -Parent $scriptDir) "config"
$configPath = Join-Path $configDir "llm-leaderboard.json"
$modelTrackingPath = Join-Path $configDir "openrouter-models.json"
$outputDir = Join-Path (Split-Path -Parent $scriptDir) "output"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$today = Get-Date -Format "yyyy-MM-dd"
$outputFile = Join-Path $outputDir "$today-llm-updates.txt"

# Load API key with Machine-level fallback
$apiKey = $env:OPENROUTER_API_KEY
if (-not $apiKey) {
    $apiKey = [System.Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "Machine")
}
if (-not $apiKey) {
    $apiKey = [System.Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
}

if (-not $apiKey) {
    Write-Error "OPENROUTER_API_KEY environment variable is not set."
    exit 1
}

Write-Information "LLM Models Update Checker" -InformationAction Continue
Write-Information ("=" * 50) -InformationAction Continue

# ============================================================================
# PART 1: OpenRouter New Models (via API + created timestamp)
# ============================================================================

$outputLines = @()
$newModelsByDate = @()
$newModelsByDiff = @()

try {
    Write-Information "`nFetching models from OpenRouter API..." -InformationAction Continue

    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "HTTP-Referer"  = "https://github.com/hemzaz/claude-skills"
        "X-Title"       = "Diary LLM Tracker"
    }

    $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/models" -Headers $headers -Method Get

    if (-not $response.data -or $response.data.Count -eq 0) {
        Write-Warning "No model data returned from OpenRouter API"
        $outputLines += "OpenRouter API returned no data"
    }
    else {
        $totalModels = $response.data.Count
        Write-Information "Total models on OpenRouter: $totalModels" -InformationAction Continue

        # --- Filter by created timestamp ---
        $cutoffUnix = [DateTimeOffset]::UtcNow.AddDays(-$DaysBack).ToUnixTimeSeconds()

        $newModelsByDate = $response.data |
            Where-Object { $_.created -and $_.created -gt $cutoffUnix } |
            Sort-Object created -Descending |
            ForEach-Object {
                $createdDate = [DateTimeOffset]::FromUnixTimeSeconds($_.created).DateTime.ToString("yyyy-MM-dd")
                $promptPrice = if ($_.pricing.prompt) { [math]::Round([decimal]$_.pricing.prompt * 1000000, 2) } else { "?" }
                $completionPrice = if ($_.pricing.completion) { [math]::Round([decimal]$_.pricing.completion * 1000000, 2) } else { "?" }
                $ctxK = if ($_.context_length) { "$([math]::Round($_.context_length / 1000))K" } else { "?" }

                [PSCustomObject]@{
                    Id          = $_.id
                    Name        = if ($_.name) { $_.name } else { $_.id }
                    Created     = $createdDate
                    Context     = $ctxK
                    Pricing     = "`$$promptPrice/`$$completionPrice per 1M"
                    Modality    = if ($_.architecture.modality) { $_.architecture.modality } else { "?" }
                }
            }

        Write-Information "New models in last $DaysBack days: $($newModelsByDate.Count)" -InformationAction Continue

        # --- Diff against saved model list ---
        $currentModelIds = $response.data | ForEach-Object { $_.id } | Sort-Object

        if (Test-Path $modelTrackingPath) {
            $previousData = Get-Content $modelTrackingPath -Raw | ConvertFrom-Json
            $previousIds = $previousData.model_ids | Sort-Object

            $addedIds = $currentModelIds | Where-Object { $_ -notin $previousIds }
            $removedIds = $previousIds | Where-Object { $_ -notin $currentModelIds }

            if ($addedIds.Count -gt 0) {
                Write-Information "New models since last run: $($addedIds.Count)" -InformationAction Continue
                $newModelsByDiff = $addedIds
            }
            if ($removedIds.Count -gt 0) {
                Write-Information "Removed models since last run: $($removedIds.Count)" -InformationAction Continue
            }
        }
        else {
            Write-Information "First run — saving model list for future diffs" -InformationAction Continue
        }

        # Save current model list for next diff
        @{
            last_updated = $today
            total_models = $totalModels
            model_ids    = $currentModelIds
        } | ConvertTo-Json -Depth 3 | Set-Content $modelTrackingPath -Encoding UTF8
        Write-Information "Model tracking saved to: $modelTrackingPath" -InformationAction Continue

        # --- Build output ---
        $outputLines += "OpenRouter Model Report ($today)"
        $outputLines += "Total models: $totalModels"
        $outputLines += ""

        if ($newModelsByDate.Count -gt 0) {
            $outputLines += "New models (last $DaysBack days):"
            foreach ($m in $newModelsByDate) {
                $outputLines += "  $($m.Id) — $($m.Name) [$($m.Created)]"
                $outputLines += "    Context: $($m.Context) | Pricing: $($m.Pricing) | Modality: $($m.Modality)"
            }
        }
        else {
            $outputLines += "No new models in the last $DaysBack days."
        }

        if ($newModelsByDiff.Count -gt 0) {
            $outputLines += ""
            $outputLines += "Added since last run:"
            foreach ($id in $newModelsByDiff) {
                $outputLines += "  + $id"
            }
        }

        if ($removedIds -and $removedIds.Count -gt 0) {
            $outputLines += ""
            $outputLines += "Removed since last run:"
            foreach ($id in $removedIds) {
                $outputLines += "  - $id"
            }
        }
    }
}
catch {
    Write-Error "Failed to fetch from OpenRouter API: $_"
    $outputLines += "Error fetching OpenRouter API: $_"
}

# ============================================================================
# PART 2: Reference Links (manual checks required by Claude)
# ============================================================================

$outputLines += ""
$outputLines += "Manual checks required:"
$outputLines += "  LMSYS Leaderboard: https://lmarena.ai/leaderboard"
$outputLines += "  OpenRouter Apps: https://openrouter.ai/rankings/apps"
$outputLines += "  OpenRouter Announcements: https://openrouter.ai/announcements"

# ============================================================================
# Save Output
# ============================================================================

$output = $outputLines -join "`n"
$output | Set-Content $outputFile -Encoding UTF8
Write-Information "`nOutput saved to: $outputFile" -InformationAction Continue

# Display results
Write-Output $output
