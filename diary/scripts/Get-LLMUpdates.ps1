<#
.SYNOPSIS
    Checks LMSYS Chatbot Arena leaderboard and OpenRouter for new model releases.

.DESCRIPTION
    This script fetches the current LMSYS Chatbot Arena leaderboard (Overall, Coding, Vision)
    via web search and checks OpenRouter API for new model releases in the last N days.
    It compares against the tracking file (config/llm-leaderboard.json) to detect changes.

.PARAMETER DaysBack
    Number of days to look back for new model releases (default: 7)

.PARAMETER Force
    Force display of all data even if no changes detected

.PARAMETER OutputFormat
    Output format: Table, List, JSON, or Markdown (default: Markdown)

.EXAMPLE
    .\Get-LLMUpdates.ps1
    Checks for leaderboard changes and new models from last 7 days

.EXAMPLE
    .\Get-LLMUpdates.ps1 -DaysBack 14 -Force -OutputFormat Table
    Shows all data from last 14 days in table format
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$DaysBack = 7,
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [ValidateSet('Table', 'List', 'JSON', 'Markdown')]
    [string]$OutputFormat = 'Markdown'
)

$ErrorActionPreference = "Stop"

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path (Split-Path -Parent $scriptDir) "config\llm-leaderboard.json"

# Load tracking configuration
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
} else {
    Write-Warning "Configuration file not found: $configPath"
    Write-Warning "Run this from the diary skill folder or create config/llm-leaderboard.json"
    exit 1
}

Write-Information "🤖 LLM Models Update Checker" -InformationAction Continue
Write-Information ("=" * 50) -InformationAction Continue

# ============================================================================
# PART 1: LMSYS Chatbot Arena Leaderboard (via Claude/Web Search)
# ============================================================================

Write-Information "`n📊 LMSYS Chatbot Arena Leaderboard" -InformationAction Continue
Write-Information "Note: This requires Claude to fetch via web search" -InformationAction Continue
Write-Information "The script will output instructions for manual checking" -InformationAction Continue
Write-Information "Visit: https://lmarena.ai/leaderboard" -InformationAction Continue

$leaderboardData = @{
    overall = @()
    coding = @()
    vision = @()
    hasChanges = $false
}

# Since PowerShell can't easily scrape the leaderboard, we provide instructions
# for Claude to fetch this data via web search
Write-Information "`nℹ️  LEADERBOARD CHECK REQUIRED:" -InformationAction Continue
Write-Information "  Use: WebSearch with 'LMSYS Chatbot Arena leaderboard January 2026'" -InformationAction Continue
Write-Information "  Extract: Top 5 models from Overall, Coding, and Vision categories" -InformationAction Continue
Write-Information "  Format: Rank, Model Name, Elo Score" -InformationAction Continue

# ============================================================================
# PART 2: OpenRouter Model Releases (via API)
# ============================================================================

Write-Information "`n🚀 OpenRouter Model Releases" -InformationAction Continue
Write-Information "⚠️  IMPORTANT: Don't rely on announcements page alone!" -InformationAction Continue
Write-Information "   Many models are added without announcements." -InformationAction Continue

$newModels = @()

if ($env:OPENROUTER_API_KEY) {
    try {
        Write-Information "Fetching models from OpenRouter API..." -InformationAction Continue
        
        $headers = @{
            "Authorization" = "Bearer $env:OPENROUTER_API_KEY"
            "HTTP-Referer" = "https://github.com/hemzaz/claude-skills"
            "X-Title" = "Diary LLM Tracker"
        }
        
        $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/models" -Headers $headers -Method Get
        
        if ($response.data) {
            $cutoffDate = (Get-Date).AddDays(-$DaysBack)
            
            # Filter models by creation date if available
            # Note: OpenRouter API might not provide created_at field for all models
            # We'll need to check the actual response structure
            
            foreach ($model in $response.data) {
                # Try to determine if model is new based on available fields
                # This may need adjustment based on actual API response
                
                # For now, we'll collect all models and let Claude filter by announcements
                $modelInfo = [PSCustomObject]@{
                    Name = $model.id
                    DisplayName = if ($model.name) { $model.name } else { $model.id }
                    Context = if ($model.context_length) { "$($model.context_length / 1000)K" } else { "Unknown" }
                    Pricing = if ($model.pricing) {
                        $prompt = [math]::Round($model.pricing.prompt * 1000000, 2)
                        $completion = [math]::Round($model.pricing.completion * 1000000, 2)
                        "$$prompt/$$completion per 1M"
                    } else { "Unknown" }
                    Description = $model.description
                    Architecture = $model.architecture
                    TopProvider = if ($model.top_provider) { $model.top_provider.name } else { "Unknown" }
                }
                
                $newModels += $modelInfo
            }
            
            Write-Information "Fetched $($response.data.Count) total models from OpenRouter" -InformationAction Continue
Write-Information "ℹ️  Note: OpenRouter API doesn't provide release dates" -InformationAction Continue
Write-Information "ℹ️  BEST METHOD: Check AI model tracker sites:" -InformationAction Continue
Write-Information "     https://llm-stats.com/llm-updates - Comprehensive release tracking" -InformationAction Continue
Write-Information "     https://www.aitimelines.club/recent - Last 24 hours updates" -InformationAction Continue
Write-Information "     Then cross-reference with OpenRouter availability" -InformationAction Continue
Write-Information "ℹ️  SECONDARY: Check OpenRouter models page:" -InformationAction Continue
Write-Information "     https://openrouter.ai/models?fmt=table&order=newest" -InformationAction Continue
Write-Information "     Visit individual model pages to check 'Created' date" -InformationAction Continue
Write-Information "ℹ️  TERTIARY: Direct provider announcements" -InformationAction Continue
Write-Information "     OpenAI, Anthropic, Google AI, xAI, HuggingFace" -InformationAction Continue
Write-Information "ℹ️  FALLBACK: Check announcements (many models don't get announced)" -InformationAction Continue
Write-Information "     https://openrouter.ai/announcements" -InformationAction Continue
            
        } else {
            Write-Warning "No model data returned from OpenRouter API"
        }
        
    } catch {
        Write-Warning "Failed to fetch from OpenRouter API: $_"
        Write-Information "Falling back to manual check instructions" -InformationAction Continue
    }
} else {
    Write-Information "ℹ️  OPENROUTER_API_KEY not found in environment" -InformationAction Continue
    Write-Information "  Set environment variable to enable API access" -InformationAction Continue
    Write-Information "  Or use WebSearch: 'OpenRouter new models January 2026'" -InformationAction Continue
}

Write-Information "  Visit: https://openrouter.ai/models?fmt=table&order=newest" -InformationAction Continue
Write-Information "  Visit: https://openrouter.ai/announcements" -InformationAction Continue

# ============================================================================
# PART 3: OpenRouter App Rankings (via Web Search)
# ============================================================================

Write-Information "`n📱 OpenRouter App Rankings" -InformationAction Continue
Write-Information "Tracking top applications by token usage on OpenRouter" -InformationAction Continue
Write-Information "Visit: https://openrouter.ai/rankings/apps" -InformationAction Continue

$appRankings = @()

Write-Information "`nℹ️  APP RANKINGS CHECK REQUIRED:" -InformationAction Continue
Write-Information "  Use: WebSearch with 'OpenRouter app rankings January 2026'" -InformationAction Continue
Write-Information "  Extract: Top 10 apps with rank, name, description, token count" -InformationAction Continue
Write-Information "  Compare: Against config/llm-leaderboard.json -> openrouter_apps.last_displayed_rankings" -InformationAction Continue
Write-Information "  Track Changes: Position changes (↑/↓), new entries (NEW), token deltas >10B" -InformationAction Continue

# ============================================================================
# Output Results
# ============================================================================

Write-Information "`n" -InformationAction Continue
Write-Information ("=" * 50) -InformationAction Continue
Write-Information "✅ Check Complete" -InformationAction Continue
Write-Information "`nNext Steps:" -InformationAction Continue
Write-Information "1. Use Claude with WebSearch to fetch LMSYS leaderboard rankings" -InformationAction Continue
Write-Information "2. Use Claude with WebSearch to check OpenRouter announcements for last $DaysBack days" -InformationAction Continue
Write-Information "3. Compare results against config/llm-leaderboard.json" -InformationAction Continue
Write-Information "4. Update diary entry if changes detected" -InformationAction Continue

# Return structured data for programmatic use
if ($OutputFormat -eq 'JSON') {
    @{
        leaderboard = $leaderboardData
        models = $newModels
        config_path = $configPath
        days_back = $DaysBack
    } | ConvertTo-Json -Depth 10
}
