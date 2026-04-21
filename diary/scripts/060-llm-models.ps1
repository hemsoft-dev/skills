#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the LLM Models section of a diary entry.

.DESCRIPTION
    Fetches the LMSYS Chatbot Arena leaderboard by parsing embedded
    Next.js hydration data from lmarena.ai (Overall, Coding, Vision).
    Falls back to carrying forward data from the most recent previous
    entry if fetching fails.

    Also fetches new model releases from the OpenRouter API and top
    apps rankings from the OpenRouter rankings page.

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\060-llm-models.ps1 -Date 2026-02-28 -EntryPath ..\entries\2026\02\2026-02-28.md
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Resolve entry path ---
if (-not $EntryPath) {
    $year = $Date.Substring(0, 4)
    $month = $Date.Substring(5, 2)
    $EntryPath = Join-Path $PSScriptRoot '..' 'entries' $year $month "$Date.md"
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

# --- Validate API key ---
$apiKey = $env:OPENROUTER_API_KEY
if (-not $apiKey) {
    Write-Error "OPENROUTER_API_KEY environment variable is not set."
    exit 1
}

# --- Helper: find previous entry with LMSYS data (for carry-forward fallback) ---
function Get-LastLMSYSSection {
    $entriesDir = Join-Path $PSScriptRoot '..' 'entries'
    $entries = Get-ChildItem $entriesDir -Filter '*.md' -Recurse |
        Where-Object { $_.BaseName -lt $Date } |
        Sort-Object Name -Descending

    foreach ($entry in $entries) {
        $content = Get-Content $entry.FullName -Raw
        if ($content -match '(?s)(### LMSYS Chatbot Arena Leaderboard.+?)(?=\n### New Model|\n### Top Open|\n---|\n## )') {
            $section = $Matches[1]
            if ($section -match '\|\s*\d+\s*\|' -or $section -match '\|\s*#\d+\s*\|') {
                return @{ Date = $entry.BaseName; Section = $section.Trim() }
            }
        }
    }
    return $null
}

# --- Helper: extract ranked model array from lmarena.ai page HTML ---
function Get-LmarenaModelList {
    param([string]$PageUrl)

    $resp = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
    $content = $resp.Content

    $searchStr = '\"models\":[{\"name\":\"'
    $idx = $content.IndexOf($searchStr)
    if ($idx -lt 0) { return $null }

    $arrStart = $content.IndexOf('[', $idx)
    $chunk = $content.Substring($arrStart, [Math]::Min(400000, $content.Length - $arrStart))

    $depth = 0; $endPos = 0
    for ($i = 0; $i -lt $chunk.Length; $i++) {
        $c = $chunk[$i]
        if ($c -eq '\' -and ($i + 1) -lt $chunk.Length -and $chunk[$i + 1] -eq '"') { $i++; continue }
        if ($c -eq '[') { $depth++ }
        elseif ($c -eq ']') { $depth--; if ($depth -eq 0) { $endPos = $i + 1; break } }
    }

    if ($endPos -eq 0) { return $null }
    $json = $chunk.Substring(0, $endPos).Replace('\"', '"')
    return ($json | ConvertFrom-Json)
}

# --- Helper: extract vision models (simple string array) from lmarena.ai/leaderboard/vision ---
function Get-LmarenaVisionRanking {
    $resp = Invoke-WebRequest -Uri 'https://lmarena.ai/leaderboard/vision' -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
    $content = $resp.Content

    $scripts = [regex]::Matches($content, '<script[^>]*>([\s\S]*?)</script>')
    foreach ($s in $scripts) {
        $script = $s.Groups[1].Value
        if ($script.Length -gt 30000 -and $script.Length -lt 200000 -and $script -match 'vision') {
            $mIdx = $script.IndexOf('\"models\":[\"')
            if ($mIdx -lt 0) { continue }

            $arrStart = $mIdx + '\"models\":['.Length - 1
            $chunk = $script.Substring($arrStart, [Math]::Min(20000, $script.Length - $arrStart))

            $depth = 0; $endPos = 0
            for ($i = 0; $i -lt $chunk.Length; $i++) {
                $c = $chunk[$i]
                if ($c -eq '\' -and ($i + 1) -lt $chunk.Length -and $chunk[$i + 1] -eq '"') { $i++; continue }
                if ($c -eq '[') { $depth++ }
                elseif ($c -eq ']') { $depth--; if ($depth -eq 0) { $endPos = $i + 1; break } }
            }

            if ($endPos -eq 0) { return $null }
            $json = $chunk.Substring(0, $endPos).Replace('\"', '"')
            return ($json | ConvertFrom-Json)
        }
    }
    return $null
}

Write-Information "`e[1;36mGathering LLM model data...`e[0m"

# ============================================================
# SECTION 1: LMSYS Chatbot Arena Leaderboard (live fetch)
# ============================================================
$lmsysSection = ''
try {
    Write-Information "`e[90m  LMSYS: Fetching from lmarena.ai...`e[0m"

    $models = Get-LmarenaModelList -PageUrl 'https://lmarena.ai/leaderboard'
    if (-not $models -or $models.Count -eq 0) { throw 'No models parsed from main leaderboard' }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("### LMSYS Chatbot Arena Leaderboard")
    [void]$sb.AppendLine()

    # Overall Top 5
    $overall = $models | Where-Object { $null -ne $_.overall } |
        Sort-Object { [int]$_.overall } | Select-Object -First 5
    [void]$sb.AppendLine("**Overall (Top 5)** *(Updated $Date)*")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Rank | Model | Organization |")
    [void]$sb.AppendLine("|------|-------|--------------|")
    foreach ($m in $overall) {
        [void]$sb.AppendLine("| $($m.overall) | $($m.name) | $($m.organization) |")
    }
    [void]$sb.AppendLine()

    # Coding Top 5
    $coding = $models | Where-Object { $null -ne $_.coding } |
        Sort-Object { [int]$_.coding } | Select-Object -First 5
    [void]$sb.AppendLine("**Coding (Top 5)** *(Updated $Date)*")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Rank | Model | Organization |")
    [void]$sb.AppendLine("|------|-------|--------------|")
    foreach ($m in $coding) {
        [void]$sb.AppendLine("| $($m.coding) | $($m.name) | $($m.organization) |")
    }
    [void]$sb.AppendLine()

    # Vision Top 5 (separate page)
    try {
        $visionModels = Get-LmarenaVisionRanking
        if ($visionModels -and $visionModels.Count -gt 0) {
            [void]$sb.AppendLine("**Vision (Top 5)** *(Updated $Date)*")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine("| Rank | Model |")
            [void]$sb.AppendLine("|------|-------|")
            for ($i = 0; $i -lt [Math]::Min(5, $visionModels.Count); $i++) {
                [void]$sb.AppendLine("| $($i + 1) | $($visionModels[$i]) |")
            }
            [void]$sb.AppendLine()
        }
    }
    catch {
        Write-Information "`e[33m  Vision leaderboard fetch failed: $_`e[0m"
    }

    [void]$sb.Append("*Source: [LMSYS Chatbot Arena](https://lmarena.ai/leaderboard)*")

    $lmsysSection = $sb.ToString()
    Write-Information "`e[32m  LMSYS: $($models.Count) models fetched (Overall: $($overall.Count), Coding: $($coding.Count))`e[0m"
}
catch {
    Write-Information "`e[33m  LMSYS fetch failed: $_. Falling back to previous entry.`e[0m"

    $prev = Get-LastLMSYSSection
    if ($prev) {
        $lmsysSection = $prev.Section
        Write-Information "`e[90m  LMSYS: Carried forward from $($prev.Date)`e[0m"
    }
    else {
        $lmsysSection = "### LMSYS Chatbot Arena Leaderboard`n`n*Unable to fetch leaderboard data. No previous entry with data found.*`n`n*Source: [LMSYS Chatbot Arena](https://lmarena.ai/leaderboard)*"
        Write-Information "`e[33m  LMSYS: No data available`e[0m"
    }
}

# ============================================================
# SECTION 2: New Model Releases (Last 7 Days) from OpenRouter
# ============================================================
Write-Information "`e[1;36mFetching new model releases from OpenRouter...`e[0m"

$modelsSection = ''
try {
    $headers = @{ Authorization = "Bearer $apiKey" }
    $response = Invoke-RestMethod -Uri 'https://openrouter.ai/api/v1/models' -Headers $headers -ErrorAction Stop

    $cutoff = (Get-Date).AddDays(-7).ToUniversalTime()
    $recent = $response.data | Where-Object {
        $_.created -and ([datetimeoffset]::FromUnixTimeSeconds($_.created).UtcDateTime -gt $cutoff)
    } | Sort-Object created -Descending

    $totalModels = $response.data.Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("### New Model Releases (Last 7 Days)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Model | Provider | Released | Context | Pricing (in/out per 1M) |")
    [void]$sb.AppendLine("|-------|----------|----------|---------|-------------------------|")

    foreach ($m in $recent) {
        $relDate = [datetimeoffset]::FromUnixTimeSeconds($m.created).ToString('MMM d')
        $provider = ($m.id -split '/')[0]
        # Format provider name: capitalize first letter of each segment
        $providerDisplay = ($provider -split '-' | ForEach-Object { 
            if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } else { $_ }
        }) -join ' '

        # Context length
        $ctx = if ($m.context_length -ge 1024) { "$([math]::Floor($m.context_length / 1024))K" } else { "$($m.context_length)" }

        # Pricing per 1M tokens (router models return -1000000 as sentinel)
        $promptPrice = [decimal]$m.pricing.prompt * 1000000
        $compPrice = [decimal]$m.pricing.completion * 1000000
        $pricing = if ($promptPrice -lt 0 -or $compPrice -lt 0) {
            'Dynamic (router)'
        } else {
            "`$$($promptPrice.ToString('0.00')) / `$$($compPrice.ToString('0.00'))"
        }

        # Clean model name (remove provider prefix if present in name)
        $modelName = $m.name -replace "^${provider}:\s*", '' -replace "^${providerDisplay}:\s*", ''

        $link = "https://openrouter.ai/$($m.id)"
        [void]$sb.AppendLine("| [$modelName]($link) | $providerDisplay | $relDate | $ctx | $pricing |")
    }

    [void]$sb.AppendLine()
    [void]$sb.Append("*Total models on OpenRouter: $totalModels*")

    $modelsSection = $sb.ToString()
    Write-Information "`e[32m  New models: $($recent.Count) in last 7 days (total: $totalModels)`e[0m"
}
catch {
    Write-Information "`e[1;31mFailed to fetch OpenRouter models: $_`e[0m"
    $modelsSection = "### New Model Releases (Last 7 Days)`n`n*Failed to fetch from OpenRouter API.*"
}

# ============================================================
# SECTION 3: Top OpenRouter Apps (by Token Usage) via HTTP
# ============================================================
Write-Information "`e[1;36mFetching OpenRouter app rankings via web request...`e[0m"

$appsSection = ''
try {
    $response = Invoke-WebRequest -Uri 'https://openrouter.ai/rankings/apps' -UseBasicParsing -ErrorAction Stop
    $html = $response.Content

    $appsHeaderIndex = $html.IndexOf('href="#apps"')
    if ($appsHeaderIndex -lt 0) {
        throw 'Top Apps section anchor not found in rankings page.'
    }

    $sectionEndIndex = $html.IndexOf('Visit the new App &amp; Agent Rankings', $appsHeaderIndex)
    if ($sectionEndIndex -lt 0) {
        $sectionEndIndex = $html.Length
    }

    $appsHtml = $html.Substring($appsHeaderIndex, $sectionEndIndex - $appsHeaderIndex)
    $entryPattern = '<div class="grid grid-cols-12 items-center rounded-lg">[\s\S]*?<div class="col-span-1 text-left text-slate-11">\s*(\d+)(?:<!-- -->)?\.[\s\S]*?<a[^>]+href="(/apps\?url=[^"]+)"[^>]*>([^<]+)(?:<!-- -->)?[\s\S]*?<span class="inline-block truncate cursor-help"[^>]*>([^<]+)</span>[\s\S]*?<span class="text-sm font-medium text-muted-foreground">([^<]+)</span>\s*<span class="text-xs text-slate-9 ml-1">tokens</span>'
    $regexMatches = [regex]::Matches($appsHtml, $entryPattern)

    $apps = @()
    foreach ($match in $regexMatches) {
        $decodedHref = [System.Net.WebUtility]::HtmlDecode($match.Groups[2].Value)
        $decodedUrl = if ($decodedHref -match 'url=(.+)$') {
            [uri]::UnescapeDataString($Matches[1])
        } else {
            ''
        }

        $apps += [pscustomobject]@{
            rank = [int]$match.Groups[1].Value
            name = [System.Net.WebUtility]::HtmlDecode($match.Groups[3].Value).Trim()
            desc = [System.Net.WebUtility]::HtmlDecode($match.Groups[4].Value).Trim() -replace '\|', '–'
            tokens = [System.Net.WebUtility]::HtmlDecode($match.Groups[5].Value).Trim()
            url = $decodedUrl
        }
    }

    $apps = $apps | Sort-Object rank | Select-Object -First 10

    if ($apps.Count -gt 0) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("### Top OpenRouter Apps (by Token Usage)")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| # | App | Description | Tokens |")
        [void]$sb.AppendLine("|---|-----|-------------|--------|")

        foreach ($app in $apps) {
            $appLink = if ($app.url) {
                "[$($app.name)]($($app.url))"
            }
            else {
                $app.name
            }

            [void]$sb.AppendLine("| $($app.rank) | $appLink | $($app.desc) | $($app.tokens) |")
        }

        $appsSection = $sb.ToString().TrimEnd()
        Write-Information "`e[32m  Top apps: $($apps.Count) entries`e[0m"
    }
    else {
        $appsSection = "### Top OpenRouter Apps (by Token Usage)`n`n*Failed to parse rankings page.*"
        Write-Information "`e[1;33m  Could not parse app rankings.`e[0m"
    }
}
catch {
    Write-Information "`e[1;33mHTTP rankings fetch failed: $_. Skipping app rankings.`e[0m"
    $appsSection = "### Top OpenRouter Apps (by Token Usage)`n`n*Failed to fetch rankings (HTTP parsing error).*"
}

# ============================================================
# BUILD & INJECT
# ============================================================
$fullContent = @"
$lmsysSection

$modelsSection

$appsSection
"@

$entry = Get-Content $EntryPath -Raw

$sectionPattern = '(#{2,3}\s+🤖\s+LLM Models\s*\r?\n)([\s\S]*?)(\r?\n---)'
$regex = [regex]::new($sectionPattern)
$m = $regex.Match($entry)
if ($m.Success) {
    # Manually rebuild replacement to avoid regex $ backreference issues in pricing data
    $before = $entry.Substring(0, $m.Index)
    $after = $entry.Substring($m.Index + $m.Length)
    $entry = $before + $m.Groups[1].Value + "`n" + $fullContent + "`n" + $m.Groups[3].Value + $after
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($EntryPath, $entry, $utf8NoBom)
    Write-Information "`e[1;32mLLM Models section injected into diary entry.`e[0m"
}
else {
    Write-Information "`e[1;31mLLM Models section (## 🤖 LLM Models) not found in entry. Cannot inject.`e[0m"
}
