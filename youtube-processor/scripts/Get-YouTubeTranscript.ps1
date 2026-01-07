param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    [Parameter(Mandatory=$true)]
    [string]$BaseFilename,
    [Parameter(Mandatory=$false)]
    [string]$VideoPath,
    [Parameter(Mandatory=$false)]
    [string]$WhisperEnvPath
)

# Ensure output directory exists
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$transcriptPath = Join-Path $OutputDir "$BaseFilename.en.vtt"

Write-Host "Attempting to download YouTube transcript for $Url..."
# Try downloading transcript using ytd
& ytd "$Url" --write-auto-subs --sub-lang en --sub-format vtt --skip-download --output "$OutputDir\%(id)s" 2>$null

# ytd outputs as [video-id].en.vtt, need to find and rename it
# We need the video ID. We can extract it from the URL or metadata.
# For now, let's look for any .en.vtt in the output dir that was just created.
$vttFiles = Get-ChildItem $OutputDir -Filter "*.en.vtt" | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) }

if ($vttFiles.Count -gt 0) {
    $sourceVtt = $vttFiles[0].FullName
    if ($sourceVtt -ne $transcriptPath) {
        Move-Item -Path $sourceVtt -Destination $transcriptPath -Force
    }
    Write-Host "✓ YouTube transcript saved: $transcriptPath"
    return $transcriptPath
}

Write-Host "⚠️ No YouTube transcript available. Falling back to Whisper..."

# Try to find Whisper environment
$pythonExe = $null
if ($WhisperEnvPath -and (Test-Path (Join-Path $WhisperEnvPath "Scripts\python.exe"))) {
    $pythonExe = Join-Path $WhisperEnvPath "Scripts\python.exe"
} elseif (Test-Path "f:\github\HemSoft\summarist\whisper-env\Scripts\python.exe") {
    $pythonExe = "f:\github\HemSoft\summarist\whisper-env\Scripts\python.exe"
}

if ($null -eq $pythonExe) {
    Write-Error "Whisper environment not found. Cannot transcribe."
    exit 1
}

if (!(Test-Path $VideoPath)) {
    Write-Error "Video file not found for transcription: $VideoPath"
    exit 1
}

Write-Host "🎤 Transcribing with Whisper AI (medium model)..."
$whisperArgs = @(
    "-m", "whisper",
    $VideoPath,
    "--output_format", "vtt",
    "--output_dir", $OutputDir,
    "--model", "medium",
    "--language", "en",
    "--device", "cuda",
    "--fp16", "True",
    "--verbose", "True"
)

& $pythonExe @whisperArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Whisper transcription failed."
    exit 1
}

# Whisper outputs as [video-filename-without-ext].vtt
$whisperOutput = Join-Path $OutputDir "$([System.IO.Path]::GetFileNameWithoutExtension($VideoPath)).vtt"

if (Test-Path $whisperOutput) {
    Move-Item -Path $whisperOutput -Destination $transcriptPath -Force
    Write-Host "✓ Whisper transcript saved: $transcriptPath"
    return $transcriptPath
} else {
    Write-Error "Whisper transcription failed to produce output."
    exit 1
}
