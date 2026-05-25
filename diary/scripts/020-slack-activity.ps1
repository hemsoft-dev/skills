#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the Slack Activity section of a diary entry.

.DESCRIPTION
    Reads the Slack daily briefing output file, uses Copilot CLI to curate
    it into an 8-12 item bulleted summary, and injects it into the diary entry.
    Falls back to raw briefing if LLM curation fails.

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\020-slack-activity.ps1 -Date 2026-02-28 -EntryPath ..\entries\2026-02-28.html
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

. (Join-Path $PSScriptRoot 'HtmlDiaryHelpers.ps1')

# Resolve entry path
if (-not $EntryPath) {
    $EntryPath = Get-DiaryHtmlEntryPath -ScriptRoot $PSScriptRoot -Date $Date
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

# Locate Slack briefing output
$slackOutputDir = Join-Path $env:USERPROFILE '.agents' 'skills' 'slack' 'output'
$slackFile = Join-Path $slackOutputDir "$Date-slack-briefing.json"

if (-not (Test-Path $slackFile)) {
    # Try to generate it
    $slackScript = Join-Path $env:USERPROFILE '.agents' 'skills' 'slack' 'scripts' 'Get-SlackDailyBriefing.ps1'
    if (Test-Path $slackScript) {
        Write-Information "`e[1;33mSlack briefing not found for $Date. Generating...`e[0m"
        & $slackScript -Date $Date -OutputFormat Detailed 6>&1 | Out-Null
    }

    if (-not (Test-Path $slackFile)) {
        Write-Information "`e[1;31mNo Slack briefing available for $Date. Skipping.`e[0m"
        return
    }
}

# Read the structured briefing
$briefing = Get-Content $slackFile -Raw | ConvertFrom-Json
$rawBriefing = $briefing | ConvertTo-Json -Depth 12

Write-Information "`e[1;36mCurating Slack activity via Copilot CLI...`e[0m"

# Build the prompt — prescriptive format with example
$prompt = @"
You are a concise summarizer. I will give you a raw Slack daily briefing. Produce a markdown bulleted list of the 8-12 most important items from the day. If there are fewer than 8 genuinely substantive items, return the smaller justified set rather than inventing filler. Rules:

- Each bullet starts with the channel name in bold: **#channel-name**
- After the channel name, write a brief 1-2 sentence summary of what happened
- Combine related messages from the same channel into one bullet
- Focus on: decisions, announcements, problems/solutions, deployments, important discussions
- Skip: bot noise, simple reactions, pleasantries, empty messages, SSL alerts
- Output ONLY the bulleted list, nothing else — no headers, no intro, no commentary

Example output format:
- **#next-deployment**: Platform 26.Q1.03 deployed to STG and verified successfully overnight. US verification completed by midnight.
- **#dev-tribe**: Team identified 5 defunct Azure databases for cleanup. Multiple engineers confirmed safe to delete.
- **#ai-chapter**: Franz shared Steve Sanderson presentation on AI development patterns, received positive feedback.

Here is the raw Slack briefing:

$rawBriefing
"@

# Try LLM curation via Copilot CLI
$curated = $null
try {
    # Write prompt to temp file to avoid command-line length/escaping issues
$tempPromptFile = Join-Path ([System.IO.Path]::GetTempPath()) "diary-slack-prompt-$Date.txt"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($tempPromptFile, $prompt, $utf8NoBom)

    # Use Copilot CLI with the prompt file as context
    $filePrompt = "Read the file at $tempPromptFile and follow the instructions in it exactly. Output ONLY the bulleted list, nothing else."
    $curatedRaw = copilot -p $filePrompt -s --model claude-opus-4.6 --allow-all --no-custom-instructions 2>$null
    Remove-Item $tempPromptFile -ErrorAction SilentlyContinue

    if ($curatedRaw) {
        # Strip any non-bullet lines (LLM preamble/commentary)
        $bulletLines = ($curatedRaw | Out-String) -split "`n" |
            Where-Object { $_ -match '^\s*-\s' } |
            ForEach-Object { $_.TrimEnd() }
        $curated = $bulletLines -join "`n"
    }

    # Validate we got something useful (at least 1 bullet point)
    if ($curated) {
        $bulletCount = ([regex]::Matches($curated, '^\s*-\s', 'Multiline')).Count
        if ($bulletCount -lt 1) {
            Write-Information "`e[1;33mLLM output empty (0 bullets). Falling back to raw briefing.`e[0m"
            $curated = $null
        }
    }
}
catch {
    Write-Information "`e[1;33mCopilot CLI failed: $_. Falling back to raw briefing.`e[0m"
    Remove-Item $tempPromptFile -ErrorAction SilentlyContinue
}

# Build the replacement content
if ($curated) {
    $slackContent = $curated.Trim()
    Write-Information "`e[1;32mSlack activity curated successfully.`e[0m"
}
else {
    $items = @()
    foreach ($mention in @($briefing.Mentions)) {
        $items += "<li><strong>#$([System.Net.WebUtility]::HtmlEncode($mention.Channel))</strong>: $([System.Net.WebUtility]::HtmlEncode($mention.From)) mentioned you: $([System.Net.WebUtility]::HtmlEncode($mention.Text))</li>"
    }
    foreach ($announcement in @($briefing.Announcements)) {
        $items += "<li><strong>#$([System.Net.WebUtility]::HtmlEncode($announcement.Channel))</strong>: $([System.Net.WebUtility]::HtmlEncode($announcement.Text))</li>"
    }
    foreach ($channel in $briefing.ChannelActivity.PSObject.Properties) {
        foreach ($message in @($channel.Value.RecentMessages)) {
            $items += "<li><strong>#$([System.Net.WebUtility]::HtmlEncode($channel.Name))</strong>: $([System.Net.WebUtility]::HtmlEncode($message.From)) - $([System.Net.WebUtility]::HtmlEncode($message.Text))</li>"
        }
    }

    if ($items.Count -gt 0) {
        $slackContent = '<ul>' + ($items -join "`n") + '</ul>'
    } else {
        $slackContent = '<p>No substantive Slack activity was captured for this date; automated Slack Skill Bot notifications were excluded.</p>'
    }
    Write-Information "`e[1;33mUsing raw Slack briefing as fallback.`e[0m"
}

if ($curated) {
    $sectionHtml = ConvertTo-DiaryHtmlCard -Markdown $slackContent -Eyebrow "Source: Slack briefing for $Date"
} else {
    $sectionHtml = @(
        '<div class="card diary-generated-markdown">',
        "  <div class=""eyebrow"">Source: Slack briefing for $Date</div>",
        $slackContent,
        '</div>'
    ) -join "`n"
}
Set-DiarySectionInnerHtml -EntryPath $EntryPath -SectionTitle '💬 Slack Activity' -InnerHtml $sectionHtml
Write-Information "`e[1;32mSlack activity injected into diary entry.`e[0m"
