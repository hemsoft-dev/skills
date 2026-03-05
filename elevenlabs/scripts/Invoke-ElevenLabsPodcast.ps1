<#
.SYNOPSIS
    Generates a two-host podcast from dialogue text using ElevenLabs TTS.

.DESCRIPTION
    Parses dialogue lines in "Speaker: text" format, assigns each line to one of
    two hosts, synthesizes each turn with the host's configured voice, and
    concatenates all turns into a single podcast audio file.

.PARAMETER DialogueText
    The full two-host dialogue text. Each spoken line must be in:
    Speaker: Spoken text

.PARAMETER OutputFile
    Path to save the final podcast audio file.

.PARAMETER Host1Name
    Display/speaker name for host 1 in dialogue labels. Default: "Host 1".

.PARAMETER Host2Name
    Display/speaker name for host 2 in dialogue labels. Default: "Host 2".

.PARAMETER Host1Voice
    Voice name or voice ID for host 1. Default: "Sarah".

.PARAMETER Host2Voice
    Voice name or voice ID for host 2. Default: "Adam".

.PARAMETER Model
    ElevenLabs model ID. Default: "eleven_v3".

.PARAMETER Play
    Play output audio with ffplay after generation.

.PARAMETER Stability
    Voice stability setting (0.0-1.0). Default: 0.35.

.PARAMETER SimilarityBoost
    Voice similarity setting (0.0-1.0). Default: 0.80.

.PARAMETER Style
    Voice style setting (0.0-1.0). Default: 0.35.

.EXAMPLE
    .\Invoke-ElevenLabsPodcast.ps1 -DialogueText (Get-Content .\dialogue.txt -Raw) -OutputFile C:\audio\podcast.mp3
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$DialogueText,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFile,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Host1Name = "Host 1",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Host2Name = "Host 2",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Host1Voice = "Sarah",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Host2Voice = "Adam",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Model = "eleven_v3",

    [Parameter()]
    [switch]$Play,

    [Parameter()]
    [ValidateRange(0.0, 1.0)]
    [double]$Stability = 0.35,

    [Parameter()]
    [ValidateRange(0.0, 1.0)]
    [double]$SimilarityBoost = 0.80,

    [Parameter()]
    [ValidateRange(0.0, 1.0)]
    [double]$Style = 0.35
)

$ErrorActionPreference = 'Stop'

$resolvedModel = $Model
$resolvedStability = $Stability
$resolvedSimilarityBoost = $SimilarityBoost
$resolvedStyle = $Style

# Validate API key (check session, then Machine-level)
$apiKey = $env:ELEVENLABS_API_KEY
if (-not $apiKey) {
    $apiKey = [System.Environment]::GetEnvironmentVariable("ELEVENLABS_API_KEY", "Machine")
    if ($apiKey) {
        $env:ELEVENLABS_API_KEY = $apiKey
    }
}
if (-not $apiKey) {
    Write-Error "ELEVENLABS_API_KEY environment variable is not set (checked session and Machine scope)."
    return
}

$baseUrl = "https://api.elevenlabs.io"

function Resolve-VoiceId {
    param([string]$VoiceName)

    if ($VoiceName -match '^[a-zA-Z0-9]{20,}$') {
        return $VoiceName
    }

    Write-Host "Resolving voice '$VoiceName'..."
    $headers = @{ "xi-api-key" = $apiKey }
    $response = Invoke-RestMethod -Uri "$baseUrl/v1/voices" -Headers $headers -Method Get

    $match = $response.voices | Where-Object { $_.name -eq $VoiceName } | Select-Object -First 1
    if (-not $match) {
        $match = $response.voices | Where-Object { $_.name -like "$VoiceName - *" -or $_.name -like "$VoiceName *" } | Select-Object -First 1
    }

    if (-not $match) {
        $available = ($response.voices | Select-Object -ExpandProperty name | Sort-Object) -join ", "
        Write-Error "Voice '$VoiceName' not found. Available voices: $available"
        return $null
    }

    Write-Host "Resolved '$VoiceName' to ID: $($match.voice_id)"
    return $match.voice_id
}

function Invoke-TtsLine {
    param(
        [string]$Text,
        [string]$VoiceId,
        [string]$OutPath
    )

    $body = @{
        text = $Text
        model_id = $resolvedModel
        voice_settings = @{
            stability = $resolvedStability
            similarity_boost = $resolvedSimilarityBoost
            style = $resolvedStyle
            use_speaker_boost = $true
        }
    }

    $jsonBody = $body | ConvertTo-Json -Depth 4
    $uri = "$baseUrl/v1/text-to-speech/$VoiceId"

    try {
        $webRequest = [System.Net.HttpWebRequest]::Create($uri)
        $webRequest.Method = "POST"
        $webRequest.ContentType = "application/json"
        $webRequest.Accept = "audio/mpeg"
        $webRequest.Headers.Add("xi-api-key", $apiKey)
        $webRequest.Timeout = 120000

        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        $webRequest.ContentLength = $bodyBytes.Length
        $requestStream = $webRequest.GetRequestStream()
        $requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
        $requestStream.Close()

        $response = $webRequest.GetResponse()
        $responseStream = $response.GetResponseStream()
        $fileStream = [System.IO.FileStream]::new($OutPath, [System.IO.FileMode]::Create)
        $responseStream.CopyTo($fileStream)
        $fileStream.Close()
        $responseStream.Close()
        $response.Close()
    }
    catch [System.Net.WebException] {
        $errorResponse = $_.Exception.Response
        if ($errorResponse) {
            $statusCode = [int]$errorResponse.StatusCode
            $errorStream = $errorResponse.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($errorStream)
            $errorBody = $reader.ReadToEnd()
            $reader.Close()
            $errorResponse.Close()

            try {
                $parsed = $errorBody | ConvertFrom-Json
                $msg = $parsed.detail.message
                $status = $parsed.detail.status
                if ($msg) {
                    Write-Error "$status - $msg (HTTP $statusCode)"
                    return
                }
            }
            catch {
                Write-Debug "Could not parse ElevenLabs API error body."
            }

            Write-Error "API request failed (HTTP $statusCode): $errorBody"
        }
        else {
            Write-Error "API request failed: $($_.Exception.Message)"
        }
    }
}

function Get-DialogueTurn {
    param(
        [string]$InputText,
        [string]$PrimaryHost1,
        [string]$PrimaryHost2
    )

    $host1Aliases = @($PrimaryHost1, "Host 1", "Host1", "Speaker 1", "A", "Host A")
    $host2Aliases = @($PrimaryHost2, "Host 2", "Host2", "Speaker 2", "B", "Host B")

    $turns = [System.Collections.ArrayList]::new()
    $lines = $InputText -split "`r?`n"

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }

        if ($trimmed -notmatch '^\s*(?<speaker>[^:]{1,80})\s*:\s*(?<text>.+)$') {
            continue
        }

        $speaker = $matches['speaker'].Trim()
        $text = $matches['text'].Trim()
        if (-not $text) { continue }

        $hostIndex = $null
        if ($host1Aliases | Where-Object { $_.ToLowerInvariant() -eq $speaker.ToLowerInvariant() }) {
            $hostIndex = 1
        }
        elseif ($host2Aliases | Where-Object { $_.ToLowerInvariant() -eq $speaker.ToLowerInvariant() }) {
            $hostIndex = 2
        }
        else {
            Write-Warning "Skipping unrecognized speaker '$speaker'. Expected '$PrimaryHost1' or '$PrimaryHost2' (or standard aliases)."
            continue
        }

        [void]$turns.Add([pscustomobject]@{
                HostIndex = $hostIndex
                Speaker = $speaker
                Text = $text
            })
    }

    return $turns
}

$turns = Get-DialogueTurn -InputText $DialogueText -PrimaryHost1 $Host1Name -PrimaryHost2 $Host2Name
if (-not $turns -or $turns.Count -lt 2) {
    Write-Error "No usable dialogue turns found. Provide lines in 'Speaker: text' format for both hosts."
    return
}

$hasHost1 = $turns | Where-Object { $_.HostIndex -eq 1 } | Select-Object -First 1
$hasHost2 = $turns | Where-Object { $_.HostIndex -eq 2 } | Select-Object -First 1
if (-not $hasHost1 -or -not $hasHost2) {
    Write-Error "Dialogue must contain at least one line from each host."
    return
}

$voice1Id = Resolve-VoiceId -VoiceName $Host1Voice
if (-not $voice1Id) { return }
$voice2Id = Resolve-VoiceId -VoiceName $Host2Voice
if (-not $voice2Id) { return }

$outputDir = Split-Path $OutputFile -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "elevenlabs-podcast-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$segmentFiles = [System.Collections.ArrayList]::new()

Write-Host "Generating podcast segments ($($turns.Count) turns)..."
for ($i = 0; $i -lt $turns.Count; $i++) {
    $turnNumber = $i + 1
    $turn = $turns[$i]
    $voiceId = if ($turn.HostIndex -eq 1) { $voice1Id } else { $voice2Id }

    $segmentPath = Join-Path $tempDir ("segment-{0:D3}.mp3" -f $turnNumber)
    Write-Host "  Turn $turnNumber/$($turns.Count): $($turn.Speaker)"

    Invoke-TtsLine -Text $turn.Text -VoiceId $voiceId -OutPath $segmentPath

    if (-not (Test-Path $segmentPath)) {
        Write-Error "Failed to generate audio for turn $turnNumber."
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    [void]$segmentFiles.Add($segmentPath)
}

Write-Host "Concatenating segments with ffmpeg..."
$concatFile = Join-Path $tempDir "concat.txt"
$concatLines = $segmentFiles | ForEach-Object { "file '$($_.Replace("'", "'\''"))'" }
$concatLines | Set-Content -Path $concatFile -Encoding UTF8

$ffmpegArgs = @("-y", "-f", "concat", "-safe", "0", "-i", $concatFile, "-c", "copy", $OutputFile)
$ffmpegResult = & ffmpeg @ffmpegArgs 2>&1

if (-not (Test-Path $OutputFile)) {
    Write-Error "ffmpeg concatenation failed: $ffmpegResult"
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}

# Save normalized transcript beside output for easy review/regeneration.
$transcriptPath = [System.IO.Path]::ChangeExtension($OutputFile, ".transcript.txt")
$normalizedTranscript = $turns | ForEach-Object { "{0}: {1}" -f $_.Speaker, $_.Text }
$normalizedTranscript | Set-Content -Path $transcriptPath -Encoding UTF8

Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

$fileSize = (Get-Item $OutputFile).Length
Write-Host "Podcast saved to: $OutputFile ($([math]::Round($fileSize / 1MB, 2)) MB)"
Write-Host "Transcript saved to: $transcriptPath"

if ($Play) {
    $ffplay = Get-Command ffplay -ErrorAction SilentlyContinue
    if ($ffplay) {
        Write-Host "Playing podcast..."
        & ffplay -nodisp -autoexit -loglevel quiet $OutputFile
    }
    else {
        Write-Warning "ffplay not found. Install ffmpeg for playback support."
    }
}

Write-Output $OutputFile
