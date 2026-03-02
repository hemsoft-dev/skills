<#
.SYNOPSIS
    Generates speech audio from text using the ElevenLabs API.

.DESCRIPTION
    Converts text to speech using ElevenLabs TTS API with production-quality
    chunked generation for long-form content. Text is split into paragraphs,
    each generated with previous_text/next_text context and previous_request_ids
    for prosody continuity, then concatenated with ffmpeg.

    Short text (<= 500 chars) is generated in a single API call.

.PARAMETER Text
    The text to convert to speech.

.PARAMETER Voice
    Voice name or voice ID. Defaults to "Hope" (preferred V3 voice).

.PARAMETER OutputFile
    Path to save the output audio file. Required.

.PARAMETER Model
    ElevenLabs model ID. Defaults to "eleven_v3".

.PARAMETER Play
    Play the audio after generation using ffplay.

.PARAMETER Stability
    Voice stability setting (0.0-1.0). Default: 0.5.

.PARAMETER SimilarityBoost
    Voice similarity boost (0.0-1.0). Default: 0.75.

.PARAMETER Style
    Style exaggeration (0.0-1.0). Default: 0.0.

.EXAMPLE
    .\Invoke-ElevenLabsTts.ps1 -Text "Hello, world!" -OutputFile "C:\audio\hello.mp3" -Play
    .\Invoke-ElevenLabsTts.ps1 -Text "Good morning" -Voice "Adam" -OutputFile "C:\audio\greeting.mp3"
    .\Invoke-ElevenLabsTts.ps1 -Text (Get-Content story.txt -Raw) -OutputFile "C:\audio\story.mp3"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Text,

    [Parameter()]
    [string]$Voice = "Hope",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFile,

    [Parameter()]
    [string]$Model = "eleven_v3",

    [Parameter()]
    [switch]$Play,

    [Parameter()]
    [ValidateRange(0.0, 1.0)]
    [double]$Stability = 0.5,

    [Parameter()]
    [ValidateRange(0.0, 1.0)]
    [double]$SimilarityBoost = 0.75,

    [Parameter()]
    [ValidateRange(0.0, 1.0)]
    [double]$Style = 0.0
)

$ErrorActionPreference = 'Stop'

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

# Resolve voice name to voice ID if not already an ID
function Resolve-VoiceId {
    param([string]$VoiceName)

    # If it looks like a voice ID (alphanumeric, 20+ chars), use directly
    if ($VoiceName -match '^[a-zA-Z0-9]{20,}$') {
        return $VoiceName
    }

    Write-Host "Resolving voice name '$VoiceName' to ID..."
    $voiceHeaders = @{ "xi-api-key" = $apiKey }
    $response = Invoke-RestMethod -Uri "$baseUrl/v1/voices" -Headers $voiceHeaders -Method Get

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

# Split text into chunks by double-newlines (paragraphs), merging short ones
function Split-TextIntoChunkList {
    param(
        [string]$InputText,
        [int]$MaxChunkChars = 1000
    )

    # Split on double-newlines to get paragraphs
    $paragraphs = $InputText -split '(\r?\n\s*\r?\n)' | Where-Object { $_.Trim().Length -gt 0 }

    $chunks = [System.Collections.ArrayList]::new()
    $current = ""

    foreach ($para in $paragraphs) {
        $para = $para.Trim()
        if ($para.Length -eq 0) { continue }

        if ($current.Length -eq 0) {
            $current = $para
        }
        elseif (($current.Length + $para.Length + 2) -le $MaxChunkChars) {
            $current = "$current`n`n$para"
        }
        else {
            [void]$chunks.Add($current)
            $current = $para
        }
    }
    if ($current.Length -gt 0) {
        [void]$chunks.Add($current)
    }

    return $chunks
}

# Generate a single TTS chunk, returns the request_id from response headers
function Invoke-TtsChunk {
    param(
        [string]$ChunkText,
        [string]$VoiceId,
        [string]$OutPath,
        [string]$PreviousText,
        [string]$NextText,
        [string[]]$PreviousRequestIds
    )

    $body = @{
        text     = $ChunkText
        model_id = $Model
        voice_settings = @{
            stability         = $Stability
            similarity_boost  = $SimilarityBoost
            style             = $Style
            use_speaker_boost = $true
        }
    }

    # V3 doesn't support previous_text/next_text or request_ids yet
    if ($Model -ne "eleven_v3") {
        if ($PreviousText) { $body["previous_text"] = $PreviousText }
        if ($NextText) { $body["next_text"] = $NextText }
        if ($PreviousRequestIds -and $PreviousRequestIds.Count -gt 0) {
            $ids = $PreviousRequestIds | Select-Object -Last 3
            $body["previous_request_ids"] = @($ids)
        }
    }

    $jsonBody = $body | ConvertTo-Json -Depth 4
    $uri = "$baseUrl/v1/text-to-speech/$VoiceId"

    # Use WebRequest to capture response headers (request_id)
    $tempResponse = $null
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

        $tempResponse = $webRequest.GetResponse()
        $requestId = $tempResponse.Headers["request-id"]

        # Save audio to file
        $responseStream = $tempResponse.GetResponseStream()
        $fileStream = [System.IO.FileStream]::new($OutPath, [System.IO.FileMode]::Create)
        $responseStream.CopyTo($fileStream)
        $fileStream.Close()
        $responseStream.Close()
        $tempResponse.Close()

        return $requestId
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
                    return $null
                }
            }
            catch { Write-Debug "Error parse failed: $_" }
            Write-Error "API request failed (HTTP $statusCode): $errorBody"
        }
        else {
            Write-Error "API request failed: $($_.Exception.Message)"
        }
        return $null
    }
    finally {
        if ($tempResponse) {
            try { $tempResponse.Dispose() } catch { Write-Debug "Dispose cleanup: $_" }
        }
    }
}

# --- Main execution ---

# Resolve voice
$voiceId = Resolve-VoiceId -VoiceName $Voice
if (-not $voiceId) { return }

# Ensure output directory exists
$outputDir = Split-Path $OutputFile -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Determine if chunking is needed
$charCount = $Text.Length
$chunkThreshold = 500

if ($charCount -le $chunkThreshold) {
    # --- Short text: single API call ---
    Write-Host "Generating speech ($charCount chars, single request)..."
    $requestId = Invoke-TtsChunk -ChunkText $Text -VoiceId $voiceId -OutPath $OutputFile
    if (-not $requestId -and -not (Test-Path $OutputFile)) {
        Write-Error "TTS generation failed."
        return
    }
}
else {
    # --- Long text: chunked generation with context stitching ---
    $chunks = Split-TextIntoChunkList -InputText $Text
    $chunkCount = $chunks.Count

    Write-Host "Generating speech ($charCount chars, $chunkCount chunks with context stitching)..."

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "elevenlabs-chunks-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $chunkFiles = [System.Collections.ArrayList]::new()
    $previousRequestIds = [System.Collections.ArrayList]::new()

    for ($i = 0; $i -lt $chunkCount; $i++) {
        $chunkNum = $i + 1
        $chunkText = $chunks[$i]
        $chunkFile = Join-Path $tempDir "chunk-$($chunkNum.ToString('D3')).mp3"

        # Build context: previous_text = end of last chunk, next_text = start of next chunk
        $prevText = $null
        $nextText = $null

        if ($i -gt 0) {
            # Last ~200 chars of previous chunk for prosody context
            $prev = $chunks[$i - 1]
            $prevText = if ($prev.Length -gt 200) { $prev.Substring($prev.Length - 200) } else { $prev }
        }

        if ($i -lt ($chunkCount - 1)) {
            # First ~200 chars of next chunk for prosody context
            $next = $chunks[$i + 1]
            $nextText = if ($next.Length -gt 200) { $next.Substring(0, 200) } else { $next }
        }

        $prevIds = @()
        if ($previousRequestIds.Count -gt 0) {
            $prevIds = @($previousRequestIds | Select-Object -Last 3)
        }

        Write-Host "  Chunk $chunkNum/$chunkCount ($($chunkText.Length) chars)..."

        $requestId = Invoke-TtsChunk `
            -ChunkText $chunkText `
            -VoiceId $voiceId `
            -OutPath $chunkFile `
            -PreviousText $prevText `
            -NextText $nextText `
            -PreviousRequestIds $prevIds

        if (-not (Test-Path $chunkFile)) {
            Write-Error "Chunk $chunkNum failed to generate."
            # Clean up
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            return
        }

        [void]$chunkFiles.Add($chunkFile)
        if ($requestId) {
            [void]$previousRequestIds.Add($requestId)
        }
    }

    # Concatenate chunks with ffmpeg
    Write-Host "Concatenating $chunkCount chunks with ffmpeg..."
    $concatFile = Join-Path $tempDir "concat.txt"
    $concatLines = $chunkFiles | ForEach-Object { "file '$($_.Replace("'", "'\''"))'" }
    $concatLines | Set-Content -Path $concatFile -Encoding UTF8

    $ffmpegArgs = @("-y", "-f", "concat", "-safe", "0", "-i", $concatFile, "-c", "copy", $OutputFile)
    $ffmpegResult = & ffmpeg @ffmpegArgs 2>&1

    if (-not (Test-Path $OutputFile)) {
        Write-Error "ffmpeg concatenation failed: $ffmpegResult"
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    # Clean up temp files
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

$fileSize = (Get-Item $OutputFile).Length
Write-Host "Audio saved to: $OutputFile ($([math]::Round($fileSize / 1KB, 1)) KB)"

# Play audio if requested
if ($Play) {
    $ffplay = Get-Command ffplay -ErrorAction SilentlyContinue
    if ($ffplay) {
        Write-Host "Playing audio..."
        & ffplay -nodisp -autoexit -loglevel quiet $OutputFile
    }
    else {
        Write-Warning "ffplay not found. Install ffmpeg for playback support."
    }
}

# Output the file path for pipeline use
Write-Output $OutputFile
