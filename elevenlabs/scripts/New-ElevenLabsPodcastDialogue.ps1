<#
.SYNOPSIS
    Builds a two-host podcast dialogue from sources, with optional audio generation.

.DESCRIPTION
    Reads one or more sources (URLs, local files, or raw text), extracts concise
    key points, and generates a digestible back-and-forth dialogue in
    "Speaker: text" format for the ElevenLabs podcast workflow.

    Optionally invokes Invoke-ElevenLabsPodcast.ps1 to synthesize final audio.

.PARAMETER Source
    One or more sources. Each item can be:
    - URL (http/https)
    - Local file path
    - Raw pasted text

.PARAMETER OutputDialogueFile
    Where to save the generated dialogue transcript.

.PARAMETER Length
    Podcast length profile: short, medium, long.

.PARAMETER StylePreset
    Style profile: casual, formal, news-reporting.

.PARAMETER FocusHint
    Optional coverage hint (topics to emphasize).

.PARAMETER Host1Name
    Host 1 speaker label.

.PARAMETER Host2Name
    Host 2 speaker label.

.PARAMETER GenerateAudio
    If set, immediately synthesizes audio via Invoke-ElevenLabsPodcast.ps1.

.PARAMETER OutputAudioFile
    Required when -GenerateAudio is used.

.PARAMETER Host1Voice
    Host 1 voice (used only when -GenerateAudio is set).

.PARAMETER Host2Voice
    Host 2 voice (used only when -GenerateAudio is set).

.PARAMETER Model
    ElevenLabs model (used only when -GenerateAudio is set).

.EXAMPLE
    .\scripts\New-ElevenLabsPodcastDialogue.ps1 `
      -Source "https://example.com/article", ".\notes.md" `
      -Length medium -StylePreset casual `
      -FocusHint "focus on practical takeaways" `
      -OutputDialogueFile "C:\audio\episode-01-dialogue.txt"

.EXAMPLE
    .\scripts\New-ElevenLabsPodcastDialogue.ps1 `
      -Source ".\notes.md" `
      -Length short -StylePreset news-reporting `
      -OutputDialogueFile "C:\audio\briefing-dialogue.txt" `
      -GenerateAudio -OutputAudioFile "C:\audio\briefing.mp3"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Source,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDialogueFile,

    [Parameter()]
    [ValidateSet('short', 'medium', 'long')]
    [string]$Length = 'medium',

    [Parameter()]
    [ValidateSet('casual', 'formal', 'news-reporting')]
    [string]$StylePreset = 'casual',

    [Parameter()]
    [string]$FocusHint,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Host1Name = 'Host 1',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Host2Name = 'Host 2',

    [Parameter()]
    [switch]$GenerateAudio,

    [Parameter()]
    [string]$OutputAudioFile,

    [Parameter()]
    [string]$Host1Voice = 'Sarah',

    [Parameter()]
    [string]$Host2Voice = 'Adam',

    [Parameter()]
    [string]$Model = 'eleven_v3'
)

$ErrorActionPreference = 'Stop'

if ($Source.Count -lt 1) {
    throw 'At least one source is required.'
}

if ($GenerateAudio -and [string]::IsNullOrWhiteSpace($OutputAudioFile)) {
    throw 'When -GenerateAudio is set, -OutputAudioFile is required.'
}

function Test-IsUrl {
    param([string]$Value)

    return ($Value -match '^https?://')
}

function Get-SpokenSourceLabel {
    param([string]$InputSource)

    if (Test-IsUrl -Value $InputSource) {
        try {
            $uri = [System.Uri]$InputSource
            $sourceHost = $uri.Host.ToLowerInvariant()

            if ($sourceHost -eq 'setitfreeloop.org' -or $sourceHost -eq 'www.setitfreeloop.org') {
                return 'the Set it Free Loop website'
            }

            if ($sourceHost -eq 'github.com') {
                $segments = $uri.AbsolutePath.Trim('/').Split('/')
                if ($segments.Length -ge 2) {
                    return ('the {0} GitHub repository' -f $segments[1])
                }
                return 'the GitHub repository'
            }

            $domain = $sourceHost -replace '^www\.', ''
            return ('the {0} site' -f $domain)
        }
        catch {
            return 'a web source'
        }
    }

    if (Test-Path -LiteralPath $InputSource) {
        return ('the file {0}' -f ([System.IO.Path]::GetFileNameWithoutExtension($InputSource)))
    }

    return 'the provided notes'
}

function Get-GitHubRepoReadmeText {
    param([string]$RepoUrl)

    try {
        $uri = [System.Uri]$RepoUrl
        if ($uri.Host.ToLowerInvariant() -ne 'github.com') {
            return $null
        }

        $segments = $uri.AbsolutePath.Trim('/').Split('/')
        if ($segments.Length -lt 2) {
            return $null
        }

        $owner = $segments[0]
        $repo = $segments[1]
        $api = "https://api.github.com/repos/$owner/$repo/readme"
        $headers = @{ 'User-Agent' = 'skills-elevenlabs-podcast-generator' }
        $resp = Invoke-RestMethod -Uri $api -Method Get -Headers $headers -TimeoutSec 30

        if (-not $resp.content) {
            return $null
        }

        $bytes = [System.Convert]::FromBase64String($resp.content)
        $md = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ([string]::IsNullOrWhiteSpace($md)) {
            return $null
        }

        return $md
    }
    catch {
        return $null
    }
}

function Get-PlainTextFromHtml {
    param([string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ''
    }

    $clean = $Html
    $clean = [regex]::Replace($clean, '(?is)<script[^>]*>.*?</script>', ' ')
    $clean = [regex]::Replace($clean, '(?is)<style[^>]*>.*?</style>', ' ')
    $clean = [regex]::Replace($clean, '(?is)<[^>]+>', ' ')
    $clean = [System.Net.WebUtility]::HtmlDecode($clean)
    $clean = [regex]::Replace($clean, '\s+', ' ').Trim()

    return $clean
}

function Convert-MarkdownToPlainText {
    param([string]$Markdown)

    if ([string]::IsNullOrWhiteSpace($Markdown)) {
        return ''
    }

    $text = $Markdown
    $text = [regex]::Replace($text, '(?m)^\s{0,3}#{1,6}\s*', '')
    $text = [regex]::Replace($text, '(?m)^\s*>\s?', '')
    $text = [regex]::Replace($text, '(?m)^\s*[-*+]\s+', '')
    $text = [regex]::Replace($text, '\[(?<label>[^\]]+)\]\((?<url>[^\)]+)\)', '${label}')
    $text = [regex]::Replace($text, '`{1,3}[^`]*`{1,3}', ' ')
    $text = [regex]::Replace($text, '\s+', ' ').Trim()

    return $text
}

function Get-SourcePacket {
    param([string]$InputSource)

    $spokenLabel = Get-SpokenSourceLabel -InputSource $InputSource

    if (Test-IsUrl -Value $InputSource) {
        try {
            $text = $null

            # Prefer README extraction for GitHub repo URLs to avoid page UI/nav noise.
            $readme = Get-GitHubRepoReadmeText -RepoUrl $InputSource
            if ($readme) {
                $text = Convert-MarkdownToPlainText -Markdown $readme
            }

            if (-not $text) {
                $resp = Invoke-WebRequest -Uri $InputSource -Method Get -TimeoutSec 30
                $text = Get-PlainTextFromHtml -Html $resp.Content
            }

            return [pscustomobject]@{
                Label = $spokenLabel
                Text = $text
            }
        }
        catch {
            return [pscustomobject]@{
                Label = $spokenLabel
                Text = "Unable to fetch source content: $($_.Exception.Message)"
            }
        }
    }

    if (Test-Path -LiteralPath $InputSource) {
        $raw = Get-Content -LiteralPath $InputSource -Raw
        return [pscustomobject]@{
            Label = $spokenLabel
            Text = $raw
        }
    }

    return [pscustomobject]@{
        Label = $spokenLabel
        Text = $InputSource
    }
}

function Get-SourceSentence {
    param(
        [string]$Text,
        [int]$Count
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $normalized = [regex]::Replace($Text, '\s+', ' ').Trim()
    $parts = [regex]::Split($normalized, '(?<=[\.!\?])\s+')

    $selected = [System.Collections.ArrayList]::new()
    foreach ($part in $parts) {
        $candidate = $part.Trim()
        # Drop links and nav fragments that sound bad when spoken.
        $candidate = [regex]::Replace($candidate, 'https?://\S+', '')
        $candidate = [regex]::Replace($candidate, '\bwww\.\S+', '')
        $candidate = [regex]::Replace($candidate, '\s+', ' ').Trim()

        if ($candidate.Length -lt 35) { continue }
        if ($candidate.Length -gt 260) { continue }
        if ($candidate -match '^(cookie|privacy|terms|sign up|log in|skip to|navigation|menu|search|github|pricing|contact sales)\b') { continue }
        if ($candidate -match '(?i)\b(http|https|www\.|\.com\b|\.org\b|\.io\b)') { continue }
        if ($candidate -match '(?i)\b(star|fork|issues|pull request|actions|marketplace|docs|discord)\b' -and $candidate.Length -lt 90) { continue }

        [void]$selected.Add($candidate)
        if ($selected.Count -ge $Count) { break }
    }

    return @($selected)
}

function Get-CleanSpokenText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $clean = $Text
    $clean = [regex]::Replace($clean, 'https?://\S+', '')
    $clean = [regex]::Replace($clean, '\bwww\.\S+', '')
    $clean = [regex]::Replace($clean, '\s+', ' ').Trim(' ', '.', ';', ',', ':', '-')
    return $clean
}

function Test-IsBoilerplateSentence {
    param([string]$Sentence)

    if ([string]::IsNullOrWhiteSpace($Sentence)) {
        return $true
    }

    $s = $Sentence.ToLowerInvariant()
    $noiseTerms = @(
        'cookie', 'privacy policy', 'terms of service', 'sign up', 'log in',
        'skip to content', 'main menu', 'navigation', 'search', 'contact sales',
        'all rights reserved', 'copyright', 'github marketplace', 'stars',
        'fork', 'issues', 'pull requests', 'actions', 'releases', 'watchers'
    )

    foreach ($term in $noiseTerms) {
        if ($s.Contains($term)) {
            return $true
        }
    }

    # Reject any remaining domain-like artifacts in spoken text.
    if ($s -match '(https?://|www\.|\.com\b|\.org\b|\.io\b|/[a-z0-9\-_/]+)') {
        return $true
    }

    return $false
}

function Get-TextTokenCollection {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return ([regex]::Matches($Text.ToLowerInvariant(), '[a-z][a-z0-9]{2,}') | ForEach-Object { $_.Value })
}

function Get-SentenceScore {
    param(
        [string]$Sentence,
        [string[]]$FocusTokens
    )

    $score = 0
    $s = $Sentence.ToLowerInvariant()

    if ($s -match '\b(set it free loop|autonomy|autonomous|feedback|learning|iteration|decision|agent|loop)\b') {
        $score += 3
    }

    foreach ($t in $FocusTokens) {
        if ($t.Length -ge 4 -and $s.Contains($t)) {
            $score += 2
        }
    }

    if ($s -match '\b(why|because|so that|allows|enables|helps|purpose|value|outcome)\b') {
        $score += 1
    }

    return $score
}

function Get-QuotedHintValue {
    param(
        [string]$Hint,
        [string]$Keyword
    )

    if ([string]::IsNullOrWhiteSpace($Hint)) {
        return $null
    }

    $doubleQuotedPattern = [string]::Format('(?i){0}\s*"(?<value>[^"]+)"', [regex]::Escape($Keyword))
    $singleQuotedPattern = [string]::Format("(?i){0}\s*'(?<value>[^']+)'", [regex]::Escape($Keyword))

    $match = [regex]::Match($Hint, $doubleQuotedPattern)
    if (-not $match.Success) {
        $match = [regex]::Match($Hint, $singleQuotedPattern)
    }
    if ($match.Success) {
        return $match.Groups['value'].Value.Trim()
    }

    return $null
}

function Get-RankedFactSet {
    param(
        [object[]]$KeyPoints,
        [string]$FocusHint,
        [int]$MaxFacts = 14
    )

    $focusTokens = Get-TextTokenCollection -Text $FocusHint
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $ranked = [System.Collections.ArrayList]::new()

    foreach ($item in $KeyPoints) {
        $point = Get-CleanSpokenText -Text $item.Point
        if ([string]::IsNullOrWhiteSpace($point)) { continue }
        if (Test-IsBoilerplateSentence -Sentence $point) { continue }
        if ($point.Length -lt 45 -or $point.Length -gt 260) { continue }

        $dedupeKey = ($point.ToLowerInvariant() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
        if ($seen.Contains($dedupeKey)) { continue }
        $null = $seen.Add($dedupeKey)

        $score = Get-SentenceScore -Sentence $point -FocusTokens $focusTokens
        [void]$ranked.Add([pscustomobject]@{
                SourceLabel = $item.SourceLabel
                Point = $point
                Score = $score
            })
    }

    $top = $ranked | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Point';Descending=$false} | Select-Object -First $MaxFacts
    return @($top)
}

function Add-ConversationLine {
    param(
        [System.Collections.ArrayList]$LineList,
        [string]$Speaker,
        [string]$Text
    )

    $spoken = Get-CleanSpokenText -Text $Text
    if ([string]::IsNullOrWhiteSpace($spoken)) {
        return
    }
    if (Test-IsBoilerplateSentence -Sentence $spoken) {
        return
    }

    [void]$LineList.Add(('{0}: {1}' -f $Speaker, $spoken))
}

function Get-TurnTarget {
    param([string]$LengthPreset)

    switch ($LengthPreset) {
        'short' { return 14 }
        'medium' { return 26 }
        'long' { return 40 }
        default { return 26 }
    }
}

$sourcePackets = @()
foreach ($s in $Source) {
    $packet = Get-SourcePacket -InputSource $s
    $sourcePackets += $packet
}

$keyPoints = [System.Collections.ArrayList]::new()
foreach ($packet in $sourcePackets) {
    $sentences = Get-SourceSentence -Text $packet.Text -Count 4
    foreach ($sentence in $sentences) {
        [void]$keyPoints.Add([pscustomobject]@{
                SourceLabel = $packet.Label
                Point = $sentence
            })
    }
}

if ($keyPoints.Count -eq 0) {
    throw 'Unable to extract useful points from provided sources. Add richer sources or raw notes.'
}

$rankedFacts = Get-RankedFactSet -KeyPoints $keyPoints -FocusHint $FocusHint -MaxFacts 16
if ($rankedFacts.Count -eq 0) {
    throw 'Unable to derive meaningful spoken facts after filtering boilerplate. Try richer narrative sources.'
}

$turnTarget = Get-TurnTarget -LengthPreset $Length
$lines = [System.Collections.ArrayList]::new()

$titleFromHint = Get-QuotedHintValue -Hint $FocusHint -Keyword 'name'
$subtitleFromHint = Get-QuotedHintValue -Hint $FocusHint -Keyword 'subtitle'

$projectTitle = if ($titleFromHint) { $titleFromHint } else { 'Set it Free Loop' }
$projectSubtitle = if ($subtitleFromHint) { $subtitleFromHint } else { 'Learning to fly' }

if ($StylePreset -eq 'formal') {
    Add-ConversationLine -LineList $lines -Speaker $Host1Name -Text ("Welcome. Today we are discussing {0}, subtitled {1}." -f $projectTitle, $projectSubtitle)
    Add-ConversationLine -LineList $lines -Speaker $Host2Name -Text 'We will focus on purpose, autonomy, and practical implications rather than technical clutter.'
}
elseif ($StylePreset -eq 'news-reporting') {
    Add-ConversationLine -LineList $lines -Speaker $Host1Name -Text ("[thoughtful] This is your briefing on {0}, with the theme {1}." -f $projectTitle, $projectSubtitle)
    Add-ConversationLine -LineList $lines -Speaker $Host2Name -Text '[curious] We will focus on why autonomy matters and what listeners should take away.'
}
else {
    Add-ConversationLine -LineList $lines -Speaker $Host1Name -Text ("[curious] Welcome back. Today we are unpacking {0}, also described as {1}." -f $projectTitle, $projectSubtitle)
    Add-ConversationLine -LineList $lines -Speaker $Host2Name -Text '[thoughtful] This is a conversational breakdown focused on meaning and autonomy, not menus or links.'
}

if (-not [string]::IsNullOrWhiteSpace($FocusHint)) {
    Add-ConversationLine -LineList $lines -Speaker $Host1Name -Text ('[thoughtful] Special focus for this episode: autonomy in how the loop senses, decides, and adapts.')
    Add-ConversationLine -LineList $lines -Speaker $Host2Name -Text 'Great. We will keep circling back to concrete outcomes for teams using this approach.'
}

$index = 0
while ($lines.Count -lt ($turnTarget - 2)) {
    $fact = $rankedFacts[$index % $rankedFacts.Count]
    $factText = $fact.Point

    $host1Line = "[curious] From $($fact.SourceLabel), one meaningful idea is: $factText"
    $host2Line = '[thoughtful] The practical takeaway is to use that as a loop decision signal, then iterate based on feedback.'

    if (($index % 4) -eq 3) {
        $host2Line = '[thoughtful] Quick recap: the pattern is clear intent, autonomous action, and learning from outcomes.'
    }

    Add-ConversationLine -LineList $lines -Speaker $Host1Name -Text $host1Line
    Add-ConversationLine -LineList $lines -Speaker $Host2Name -Text $host2Line
    $index++
}

if ($StylePreset -eq 'news-reporting') {
    Add-ConversationLine -LineList $lines -Speaker $Host1Name -Text '[thoughtful] That wraps our briefing. The headline is disciplined autonomy guided by feedback.'
    Add-ConversationLine -LineList $lines -Speaker $Host2Name -Text '[curious] We will be back with the next source-driven update soon.'
}
else {
    Add-ConversationLine -LineList $lines -Speaker $Host1Name -Text '[thoughtful] Let us close with one simple takeaway: autonomy works when the loop stays grounded in clear purpose and measured feedback.'
    Add-ConversationLine -LineList $lines -Speaker $Host2Name -Text '[curious] If you want a deeper cut next time, share richer source notes and we can go one layer further without losing clarity.'
}

# Final quality gate: reject transcript if any URL artifact survives.
$joined = ($lines -join [Environment]::NewLine)
if ($joined -match '(https?://|www\.|\.com\b|\.org\b|\.io\b|URL:)') {
    throw 'Generated dialogue failed quality gate: URL-like text remained in spoken lines.'
}

$outputDir = Split-Path -Path $OutputDialogueFile -Parent
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$lines -join [Environment]::NewLine | Set-Content -Path $OutputDialogueFile -Encoding UTF8
Write-Information "Dialogue saved to: $OutputDialogueFile" -InformationAction Continue

$audioFile = $null
if ($GenerateAudio) {
    $podcastScript = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-ElevenLabsPodcast.ps1'
    if (-not (Test-Path -LiteralPath $podcastScript)) {
        throw "Podcast synthesis script not found: $podcastScript"
    }

    $dialogueText = Get-Content -Path $OutputDialogueFile -Raw
    & $podcastScript `
        -DialogueText $dialogueText `
        -Host1Name $Host1Name `
        -Host2Name $Host2Name `
        -Host1Voice $Host1Voice `
        -Host2Voice $Host2Voice `
        -Model $Model `
        -OutputFile $OutputAudioFile

    $audioFile = $OutputAudioFile
}

[pscustomobject]@{
    DialogueFile = $OutputDialogueFile
    AudioFile = $audioFile
    SourceCount = $Source.Count
    Length = $Length
    StylePreset = $StylePreset
}
