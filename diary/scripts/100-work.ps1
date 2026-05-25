#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the Work section of a diary entry (weekdays only).

.DESCRIPTION
    Uses WorkIQ to extract meetings with transcript summaries and important
    work emails. Parses Slack briefing for work-related activity. Inserts
    a Work section before the Personal section if one doesn't exist.
    Skips entirely on weekends (Saturday/Sunday).

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\100-work.ps1 -Date 2026-02-27
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

. (Join-Path $PSScriptRoot 'HtmlDiaryHelpers.ps1')

# --- Resolve entry path ---
if (-not $EntryPath) {
    $EntryPath = Get-DiaryHtmlEntryPath -ScriptRoot $PSScriptRoot -Date $Date
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

Write-Information "`e[90mWork section is legacy markdown-era automation and is not part of the current HTML diary contract. Skipping.`e[0m"
exit 0

# --- Weekend check ---
$dateObj = [DateTime]::Parse($Date)
$dayOfWeek = $dateObj.DayOfWeek
if ($dayOfWeek -eq 'Saturday' -or $dayOfWeek -eq 'Sunday') {
    Write-Information "`e[90mWeekend — skipping work section.`e[0m"
    exit 0
}

$entry = Get-Content $EntryPath -Raw
$friendlyDate = $dateObj.ToString('MMMM d, yyyy')

# --- Helper: Clean WorkIQ output ---
function ConvertTo-WorkIqCleanText {
    param([string]$raw)
    if (-not $raw) { return '' }

    # Remove reference links [N](url)
    $cleaned = $raw -replace '\[?\d+\]\(https?://[^\)]+\)', ''

    # Remove horizontal rules
    $cleaned = $cleaned -replace '(?m)^---\s*$', ''

    $lines = $cleaned -split "`n"

    # Find first substantive content line (bullet, heading, or bold)
    $startIdx = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()
        if ($trimmed -match '^[-•*]\s' -or $trimmed -match '^#{1,4}\s' -or $trimmed -match '^\*\*') {
            $startIdx = $i
            break
        }
    }

    # Trim trailing blank lines
    $endIdx = $lines.Count - 1
    while ($endIdx -ge $startIdx -and -not $lines[$endIdx].Trim()) { $endIdx-- }

    # Remove outro offers ("If you'd like...", "Would you like...", etc.)
    while ($endIdx -ge $startIdx -and $lines[$endIdx] -match 'If you.d like|I can also|Would you like|Let me know|Do you want') { $endIdx-- }
    while ($endIdx -ge $startIdx -and -not $lines[$endIdx].Trim()) { $endIdx-- }

    if ($endIdx -lt $startIdx) { return '' }

    return ($lines[$startIdx..$endIdx] -join "`n").Trim()
}

# --- 1. Fetch meetings from WorkIQ (two-pass: list, then per-meeting transcript) ---
Write-Information "`e[1;36mFetching meetings from WorkIQ...`e[0m"
$meetingsContent = ''
try {
    # Pass 1: Get the meeting list with basic info
    $listPrompt = @"
List all my meetings on $friendlyDate. For each meeting, format as a bullet point:

- **{start time} - {end time}** - {Meeting Title} (Organizer: {name})
  - Attendees: {comma-separated attendee names}

Output ONLY the formatted bullet list. No introduction, no conclusion.
If I had no meetings, output exactly: "No meetings scheduled."
"@
    $rawList = & workiq ask -q $listPrompt 2>&1 | Out-String
    $meetingsContent = ConvertTo-WorkIqCleanText $rawList
    if ($meetingsContent -and $meetingsContent -notmatch 'No meetings scheduled') {
        Write-Information "`e[1;32mMeetings retrieved. Fetching transcripts per meeting...`e[0m"

        # Pass 2: Extract meeting titles and query each for transcript/notes
        $titleMatches = [regex]::Matches($meetingsContent, '\*\*[\d:]+\s*[AP]M\s*-\s*[\d:]+\s*[AP]M\*\*\s*-\s*(.+?)(?:\s*\(Organizer:)')
        foreach ($tm in $titleMatches) {
            $meetingTitle = $tm.Groups[1].Value.Trim()
            Write-Information "`e[90m  Querying transcript for: $meetingTitle`e[0m"
            try {
                $transcriptPrompt = "Show me the transcript or notes from the `"$meetingTitle`" meeting on $friendlyDate. Include key discussion points and action items. Output ONLY the content — no introduction or conclusion."
                $rawTranscript = & workiq ask -q $transcriptPrompt 2>&1 | Out-String
                $transcriptClean = ConvertTo-WorkIqCleanText $rawTranscript
                if ($transcriptClean -and $transcriptClean -notmatch 'no transcript|not available|could not find|no notes|not surfaced|didn.t find') {
                    # Append transcript summary under the meeting entry
                    $escapedTitle = [regex]::Escape($meetingTitle)
                    $meetingsContent = $meetingsContent -replace "($escapedTitle[^\n]*\n(?:\s+-[^\n]*\n)*)", "`$1    - Transcript: $($transcriptClean -replace "`n", ' ' -replace '\s{2,}', ' ')`n"
                    Write-Information "`e[1;32m  Transcript found for $meetingTitle.`e[0m"
                } else {
                    Write-Information "`e[90m  No transcript surfaced for $meetingTitle.`e[0m"
                }
            } catch {
                Write-Information "`e[1;33m  Transcript query failed for $meetingTitle`: $($_.Exception.Message)`e[0m"
            }
        }
    }
    if ($meetingsContent) {
        Write-Information "`e[1;32mMeetings complete.`e[0m"
    }
} catch {
    Write-Information "`e[1;33mWorkIQ meetings query failed: $($_.Exception.Message)`e[0m"
}

# --- 2. Fetch important work emails from WorkIQ ---
Write-Information "`e[1;36mFetching work emails from WorkIQ...`e[0m"
$emailsContent = ''
try {
    $emailPrompt = @"
List the most important work emails I sent or received on $friendlyDate using only details you can retrieve directly from Microsoft 365 data. Format each as a bullet point:

- **{Sender Name}**: {Subject} - {one-line source-backed summary of the email content or action needed}

Skip automated notifications, calendar invites, newsletters, and routine messages.
If no important emails, output exactly: "No significant work emails."
Output ONLY the formatted bullet list. No introduction or conclusion.
"@
    $rawEmails = & workiq ask -q $emailPrompt 2>&1 | Out-String
    $emailsContent = ConvertTo-WorkIqCleanText $rawEmails
    if ($emailsContent) {
        Write-Information "`e[1;32mEmails retrieved.`e[0m"
    }
} catch {
    Write-Information "`e[1;33mWorkIQ emails query failed: $($_.Exception.Message)`e[0m"
}

# --- 3. Parse Slack briefing for work activity ---
Write-Information "`e[1;36mParsing Slack briefing...`e[0m"
$slackSummary = ''
$slackOutputDir = Join-Path $env:USERPROFILE '.agents' 'skills' 'slack' 'output'
$slackFile = Join-Path $slackOutputDir "$Date-slack-briefing.json"

if (Test-Path $slackFile) {
    $slackContent = Get-Content $slackFile -Raw

    # Extract DM contacts (non-bot)
    $dmContacts = @()
    if ($slackContent -match '(?s)Direct Messages.*?\n(.*?)(?=\n####|\z)') {
        $dmSection = $Matches[1]
        $dmContacts = [regex]::Matches($dmSection, '@([^:]+?)\s*:') |
            ForEach-Object { $_.Groups[1].Value.Trim() } |
            Where-Object { $_ -ne 'Slack Skill Bot' -and $_ -ne 'Slackbot' -and $_ -ne 'datadog' } |
            Sort-Object -Unique
    }

    # Extract work channels with message counts
    $workChannels = @()
    $channelMatches = [regex]::Matches($slackContent, '\*\*#([\w-]+)\*\*\s*\((\d+)\s*messages?\)')
    foreach ($cm in $channelMatches) {
        $chName = $cm.Groups[1].Value
        $chCount = $cm.Groups[2].Value
        if ($chName -notmatch 'food|social|random|fun|off-topic') {
            $workChannels += "#${chName} (${chCount})"
        }
    }

    # Build summary
    $parts = @()
    if ($dmContacts.Count -gt 0) {
        $contactList = ($dmContacts | Select-Object -First 6) -join ', '
        $parts += "Work DMs with $contactList"
    }
    if ($workChannels.Count -gt 0) {
        $chanList = ($workChannels | Select-Object -First 5) -join ', '
        $parts += "Active channels: $chanList"
    }

    if ($parts.Count -gt 0) {
        $slackSummary = ($parts | ForEach-Object { "- $_" }) -join "`n"
        Write-Information "`e[1;32mSlack activity parsed.`e[0m"
    }
} else {
    Write-Information "`e[90mNo Slack briefing for $Date.`e[0m"
}

# --- 4. Build work section content ---
$workDone = ""

# Meetings
$noMeetings = ($meetingsContent -match 'No meetings scheduled' -or -not $meetingsContent.Trim())
if (-not $noMeetings) {
    $workDone += $meetingsContent + "`n"
}

# Emails
$noEmails = ($emailsContent -match 'No significant work emails' -or -not $emailsContent.Trim())
if (-not $noEmails) {
    if ($workDone.Trim()) { $workDone += "`n" }
    $workDone += "**Key Emails:**`n`n$emailsContent`n"
}

# Slack highlights
if ($slackSummary.Trim()) {
    if ($workDone.Trim()) { $workDone += "`n" }
    $workDone += "**Slack Highlights:**`n`n$slackSummary`n"
}

# Fallback if nothing was collected
if (-not $workDone.Trim()) {
    $workDone = "- {user to provide}`n"
}

$fullWorkContent = "### Work Done`n`n$workDone`n### Work Goals for Tomorrow and Beyond`n`n- {user to provide}"

# --- 5. Inject into diary entry ---
# Try to find existing Work section heading (with or without emoji)
$workHeadingPattern = '##\s+💼?\s*Work[^\r\n]*'
$workRegex = [regex]::new($workHeadingPattern)
$wm = $workRegex.Match($entry)

if ($wm.Success) {
    # Found existing Work section — find where it ends (next ## heading or ---)
    $sectionStart = $wm.Index
    $contentStart = $sectionStart + $wm.Length

    $nextSectionRegex = [regex]::new('\r?\n##\s')
    $nm = $nextSectionRegex.Match($entry, $contentStart)

    $sectionEnd = if ($nm.Success) { $nm.Index } else { $entry.Length }

    $before = $entry.Substring(0, $sectionStart)
    $after = $entry.Substring($sectionEnd)

    $entry = $before + "## 💼 Work`n`n" + $fullWorkContent + "`n`n---`n" + $after
    Write-Information "`e[1;32mWork section updated.`e[0m"
} else {
    # Insert before Personal section
    $personalPattern = '(##\s+🏠\s+Personal|##\s+💭\s+Personal\s+Reflections)'
    $pRegex = [regex]::new($personalPattern)
    $pm = $pRegex.Match($entry)

    if ($pm.Success) {
        $before = $entry.Substring(0, $pm.Index)
        $after = $entry.Substring($pm.Index)
        $entry = $before + "## 💼 Work`n`n" + $fullWorkContent + "`n`n---`n`n" + $after
        Write-Information "`e[1;32mWork section inserted before Personal section.`e[0m"
    } else {
        # Last resort: append at end
        Write-Information "`e[1;33mNo Personal section found. Appending Work section at end.`e[0m"
        $entry = $entry.TrimEnd() + "`n`n---`n`n## 💼 Work`n`n" + $fullWorkContent + "`n"
    }
}

# --- Write output ---
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($EntryPath, $entry, $utf8NoBom)
Write-Information "`e[1;32m✅ Work section complete.`e[0m"
