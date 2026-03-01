#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the LLM Models section of a diary entry.

.DESCRIPTION
    Fetches new model releases from OpenRouter API and top apps rankings
    from the OpenRouter rankings page via Playwright. Injects the data
    into the diary entry's LLM Models section.

    LMSYS Chatbot Arena leaderboard is behind Cloudflare and cannot be
    scraped reliably. The script checks the previous entry for existing
    LMSYS data and carries forward a "no changes" note with the last
    known date.

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\060-llm-models.ps1 -Date 2026-02-28 -EntryPath ..\entries\2026-02-28.md
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
    $EntryPath = Join-Path $PSScriptRoot '..' 'entries' "$Date.md"
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

# --- Helper: find last LMSYS date from previous entries ---
function Get-LastLMSYSDate {
    $entriesDir = Join-Path $PSScriptRoot '..' 'entries'
    $entries = Get-ChildItem $entriesDir -Filter '*.md' |
        Where-Object { $_.BaseName -lt $Date } |
        Sort-Object Name -Descending

    foreach ($entry in $entries) {
        $content = Get-Content $entry.FullName -Raw
        # Check if this entry has actual LMSYS data (Elo scores with real numbers)
        if ($content -match '\|\s*\d+\s*\|.*\|\s*1[2-5]\d{2}\s*\|') {
            return $entry.BaseName
        }
        # Check for "no changes since" reference
        if ($content -match '[Nn]o changes since (\d{4}-\d{2}-\d{2})') {
            return $Matches[1]
        }
    }
    return $null
}

Write-Information "`e[1;36mGathering LLM model data...`e[0m"

# ============================================================
# SECTION 1: LMSYS Chatbot Arena Leaderboard
# ============================================================
$lastLMSYSDate = Get-LastLMSYSDate
$lmsysSection = if ($lastLMSYSDate) {
    "### LMSYS Chatbot Arena Leaderboard`n`n*(No changes since $lastLMSYSDate — see previous entry for current rankings)*`n`n*Leaderboard source: [LMSYS Chatbot Arena](https://lmarena.ai/leaderboard)*"
} else {
    "### LMSYS Chatbot Arena Leaderboard`n`n*Unable to fetch leaderboard data (Cloudflare-protected).*`n`n*Source: [LMSYS Chatbot Arena](https://lmarena.ai/leaderboard)*"
}
Write-Information "`e[90m  LMSYS: Carried forward from $lastLMSYSDate`e[0m"

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

        # Pricing per 1M tokens
        $promptPrice = [decimal]$m.pricing.prompt * 1000000
        $compPrice = [decimal]$m.pricing.completion * 1000000
        $pricing = "`$$($promptPrice.ToString('0.00')) / `$$($compPrice.ToString('0.00'))"

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
# SECTION 3: Top OpenRouter Apps (by Token Usage) via Playwright
# ============================================================
Write-Information "`e[1;36mFetching OpenRouter app rankings via Playwright...`e[0m"

$appsSection = ''
try {
    # Resolve playwright package and chromium executable from global npm
    $npmRoot = Join-Path $env:APPDATA 'npm' 'node_modules'
    $pwPkg = Join-Path $npmRoot '@playwright' 'cli' 'node_modules' 'playwright'
    if (-not (Test-Path $pwPkg)) { throw "Playwright npm package not found at $pwPkg" }

    # Find latest installed chromium browser
    $msPlaywright = Join-Path $env:LOCALAPPDATA 'ms-playwright'
    $chromiumDir = Get-ChildItem $msPlaywright -Directory -Filter 'chromium-*' |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $chromiumDir) { throw "No chromium browser installed in $msPlaywright" }
    $chromeExe = Join-Path $chromiumDir.FullName 'chrome-win64' 'chrome.exe'
    if (-not (Test-Path $chromeExe)) { throw "Chrome executable not found at $chromeExe" }

    $escapedPkg = $pwPkg -replace '\\', '\\\\'
    $escapedExe = $chromeExe -replace '\\', '\\\\'

    $tempJs = Join-Path ([System.IO.Path]::GetTempPath()) "diary-or-rankings-$Date.cjs"
    $jsContent = @"
const { chromium } = require('$escapedPkg');
(async () => {
    const browser = await chromium.launch({ headless: true, executablePath: '$escapedExe' });
    const page = await browser.newPage();
    try {
        await page.goto('https://openrouter.ai/rankings/apps', { waitUntil: 'networkidle', timeout: 30000 });
        await page.waitForTimeout(3000);

        const data = await page.evaluate(() => {
            const text = document.body.innerText;
            const appsMatch = text.match(/Top Apps[\s\S]*?Largest public apps[\s\S]*?Today\n([\s\S]*?)(?=\n\nProduct|$)/);
            if (!appsMatch) return [];
            const section = appsMatch[1];
            const entries = [];
            const lines = section.split('\n').filter(l => l.trim());
            let i = 0;
            while (i < lines.length && entries.length < 10) {
                const rankMatch = lines[i].match(/^(\d+)\.$/);
                if (rankMatch) {
                    const rank = parseInt(rankMatch[1]);
                    const name = lines[i+1] ? lines[i+1].trim() : '';
                    const desc = lines[i+2] ? lines[i+2].trim() : '';
                    const tokensLine = lines[i+3] ? lines[i+3].trim() : '';
                    const tokenMatch = tokensLine.match(/([\d.]+[TGBM])tokens/i);
                    const tokens = tokenMatch ? tokenMatch[1] : tokensLine;
                    entries.push({rank, name, desc, tokens});
                    i += 4;
                } else { i++; }
            }
            return entries;
        });

        const links = await page.evaluate(() => {
            const appLinks = document.querySelectorAll('a[href*="/apps?url="]');
            return Array.from(appLinks).slice(0, 10).map(l => {
                const urlMatch = l.href.match(/url=(.+)/);
                return urlMatch ? decodeURIComponent(urlMatch[1]) : '';
            });
        });

        data.forEach((item, i) => { item.url = links[i] || ''; });
        console.log(JSON.stringify(data));
    } finally { await browser.close(); }
})();
"@
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($tempJs, $jsContent, $utf8NoBom)

    $rawOutput = node $tempJs 2>$null
    Remove-Item $tempJs -ErrorAction SilentlyContinue

    $apps = $rawOutput | ConvertFrom-Json

    if ($apps.Count -gt 0) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("### Top OpenRouter Apps (by Token Usage)")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| # | App | Description | Tokens |")
        [void]$sb.AppendLine("|---|-----|-------------|--------|")

        foreach ($app in $apps) {
            $appLink = if ($app.url) {
                "[$($app.name)]($($app.url))"
            } else {
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
    Write-Information "`e[1;33mPlaywright scraping failed: $_. Skipping app rankings.`e[0m"
    $appsSection = "### Top OpenRouter Apps (by Token Usage)`n`n*Failed to fetch rankings (Playwright error).*"
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
