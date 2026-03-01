#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the Top 5 Trending GitHub Repos section of a diary entry.

.DESCRIPTION
    Scrapes the GitHub Trending page (https://github.com/trending) via Playwright
    to get the top 5 trending repositories with their descriptions, star counts,
    and today's star gains. Injects the data into the diary entry.

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\070-top-trending-github-repos.ps1 -Date 2026-02-28
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

Write-Information "`e[1;36mFetching top trending GitHub repos...`e[0m"

# --- Resolve Playwright package and chromium executable ---
$npmRoot = Join-Path $env:APPDATA 'npm' 'node_modules'
$pwPkg = Join-Path $npmRoot '@playwright' 'cli' 'node_modules' 'playwright'
if (-not (Test-Path $pwPkg)) {
    Write-Error "Playwright npm package not found at $pwPkg"
    exit 1
}

$msPlaywright = Join-Path $env:LOCALAPPDATA 'ms-playwright'
$chromiumDir = Get-ChildItem $msPlaywright -Directory -Filter 'chromium-*' |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $chromiumDir) {
    Write-Error "No chromium browser installed in $msPlaywright"
    exit 1
}
$chromeExe = Join-Path $chromiumDir.FullName 'chrome-win64' 'chrome.exe'
if (-not (Test-Path $chromeExe)) {
    Write-Error "Chrome executable not found at $chromeExe"
    exit 1
}

$escapedPkg = $pwPkg -replace '\\', '\\\\'
$escapedExe = $chromeExe -replace '\\', '\\\\'

# --- Scrape GitHub Trending via Playwright ---
$tempJs = Join-Path ([System.IO.Path]::GetTempPath()) "diary-gh-trending-$Date.cjs"
$jsContent = @"
const { chromium } = require('$escapedPkg');
(async () => {
    const browser = await chromium.launch({ headless: true, executablePath: '$escapedExe' });
    const page = await browser.newPage();
    try {
        await page.goto('https://github.com/trending', { waitUntil: 'networkidle', timeout: 30000 });

        const repos = await page.evaluate(() => {
            const articles = document.querySelectorAll('article.Box-row');
            return Array.from(articles).slice(0, 5).map(article => {
                const repoLink = article.querySelector('h2 a');
                const repo = repoLink ? repoLink.getAttribute('href').replace(/^\//, '') : '';
                const desc = article.querySelector('p');
                const description = desc ? desc.textContent.trim() : '';
                const langSpan = article.querySelector('[itemprop="programmingLanguage"]');
                const language = langSpan ? langSpan.textContent.trim() : '';
                const starLinks = article.querySelectorAll('a.Link--muted');
                let totalStars = '';
                if (starLinks.length > 0) {
                    totalStars = starLinks[0].textContent.trim().replace(/,/g, '').replace(/\s+/g, '');
                }
                const todaySpan = article.querySelector('span.d-inline-block.float-sm-right');
                const todayStars = todaySpan ? todaySpan.textContent.trim() : '';
                return { repo, description, language, totalStars, todayStars };
            });
        });

        console.log(JSON.stringify(repos));
    } finally { await browser.close(); }
})();
"@

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($tempJs, $jsContent, $utf8NoBom)

$rawOutput = node $tempJs 2>$null
Remove-Item $tempJs -ErrorAction SilentlyContinue

if (-not $rawOutput) {
    Write-Information "`e[1;31mPlaywright returned no output. Cannot update trending repos.`e[0m"
    exit 1
}

$repos = $rawOutput | ConvertFrom-Json

if ($repos.Count -lt 1) {
    Write-Information "`e[1;31mNo trending repos found. Cannot update section.`e[0m"
    exit 1
}

# --- Format star counts ---
function Format-Stars([string]$raw) {
    $num = 0
    if ([int]::TryParse($raw, [ref]$num)) {
        if ($num -ge 1000) { return "{0:N0}" -f $num }
        return "$num"
    }
    return $raw
}

# --- Build markdown table ---
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("| # | Repository | Description | Stars |")
[void]$sb.AppendLine("|---|------------|-------------|-------|")

$rank = 0
foreach ($r in $repos) {
    $rank++
    $link = "[$($r.repo)](https://github.com/$($r.repo))"
    $desc = $r.description
    # Truncate long descriptions
    if ($desc.Length -gt 100) { $desc = $desc.Substring(0, 97) + '...' }
    # Escape pipe characters in description
    $desc = $desc -replace '\|', '–'

    $totalFormatted = Format-Stars $r.totalStars
    $todayMatch = if ($r.todayStars -match '([\d,]+)\s*stars?\s*today') { $Matches[1] } else { '' }
    $starDisplay = if ($todayMatch) { "⭐ $totalFormatted (+$todayMatch today)" } else { "⭐ $totalFormatted" }

    [void]$sb.AppendLine("| $rank | $link | $desc | $starDisplay |")
}

$trendingContent = $sb.ToString().TrimEnd()

# --- Inject into diary entry ---
$entry = Get-Content $EntryPath -Raw

$sectionPattern = '(#{2,3}\s+🔥\s+Top 5 Trending GitHub Repos\s*\r?\n)([\s\S]*?)(\r?\n---)'
$regex = [regex]::new($sectionPattern)
$m = $regex.Match($entry)
if ($m.Success) {
    $before = $entry.Substring(0, $m.Index)
    $after = $entry.Substring($m.Index + $m.Length)
    $entry = $before + $m.Groups[1].Value + "`n" + $trendingContent + "`n" + $m.Groups[3].Value + $after
    [System.IO.File]::WriteAllText($EntryPath, $entry, $utf8NoBom)
    Write-Information "`e[1;32mTrending GitHub repos injected into diary entry.`e[0m"
    foreach ($r in $repos) {
        Write-Information "`e[90m  $($r.repo) — $(Format-Stars $r.totalStars) stars`e[0m"
    }
}
else {
    Write-Information "`e[1;31mTrending repos section (## 🔥 Top 5 Trending GitHub Repos) not found in entry. Cannot inject.`e[0m"
}
