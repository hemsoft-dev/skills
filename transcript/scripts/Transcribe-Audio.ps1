<#
.SYNOPSIS
    Transcribes an audio file to timestamped text using faster-whisper on GPU.

.DESCRIPTION
    Uses the faster-whisper library with CUDA GPU acceleration to transcribe
    audio files. Outputs a .txt file with timestamped segments next to the
    source audio file.

.PARAMETER AudioPath
    Full path to the audio file (MP3, WAV, M4A, FLAC, OGG).

.PARAMETER Model
    Whisper model size. Options: tiny, base, small, medium, large-v3.
    Default: medium.

.PARAMETER Language
    Language code for transcription. Default: en.

.PARAMETER OutputPath
    Custom output path for the transcript. Default: same directory as audio.

.EXAMPLE
    .\Transcribe-Audio.ps1 -AudioPath "D:\Podcasts\episode.mp3"
    .\Transcribe-Audio.ps1 -AudioPath "D:\Podcasts\episode.mp3" -Model "large-v3"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$AudioPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('tiny', 'base', 'small', 'medium', 'large-v3')]
    [string]$Model = 'medium',

    [Parameter(Mandatory = $false)]
    [string]$Language = 'en',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Validate input file
if (-not (Test-Path $AudioPath)) {
    Write-Error "Audio file not found: $AudioPath"
    exit 1
}

$audioFile = Get-Item $AudioPath
$supportedExtensions = @('.mp3', '.wav', '.m4a', '.flac', '.ogg', '.wma', '.aac', '.webm')
if ($audioFile.Extension.ToLower() -notin $supportedExtensions) {
    Write-Error "Unsupported audio format: $($audioFile.Extension). Supported: $($supportedExtensions -join ', ')"
    exit 1
}

# Determine output path
if (-not $OutputPath) {
    $OutputPath = Join-Path $audioFile.DirectoryName "$($audioFile.BaseName)_transcript.vtt"
}

# Ensure NVIDIA cuBLAS is on PATH for CUDA support
$cublasBin = "C:\Users\User\miniconda3\Lib\site-packages\nvidia\cublas\bin"
$nvrtcBin = "C:\Users\User\miniconda3\Lib\site-packages\nvidia\cuda_nvrtc\bin"
if (Test-Path $cublasBin) {
    $env:PATH = "$cublasBin;$nvrtcBin;$env:PATH"
}

Write-Information "`e[36m🎙️ Transcribing: $($audioFile.Name)`e[0m"
Write-Information "   Model: $Model | Language: $Language | GPU: CUDA"
Write-Information "   Output: $OutputPath"
Write-Information ""

$pythonScript = @"
import sys, time
from faster_whisper import WhisperModel

audio_path = r'$($AudioPath -replace "'", "''")'
output_path = r'$($OutputPath -replace "'", "''")'
model_name = '$Model'
language = '$Language'

print(f'Loading model ({model_name}) on CUDA...')
sys.stdout.flush()
start = time.time()

try:
    model = WhisperModel(model_name, device='cuda', compute_type='float16')
except Exception as e:
    print(f'CUDA failed ({e}), falling back to CPU with int8...')
    sys.stdout.flush()
    model = WhisperModel(model_name, device='cpu', compute_type='int8')

load_time = time.time() - start
print(f'Model loaded in {load_time:.1f}s. Transcribing...')
sys.stdout.flush()

start = time.time()
segments, info = model.transcribe(audio_path, language=language, beam_size=5)
duration = info.duration
print(f'Audio duration: {duration:.0f}s ({duration/60:.1f} min)')
sys.stdout.flush()

def format_vtt_time(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = seconds % 60
    return f'{h:02d}:{m:02d}:{s:06.3f}'

count = 0
last_progress = -1
with open(output_path, 'w', encoding='utf-8') as f:
    f.write('WEBVTT\n\n')
    for segment in segments:
        count += 1
        start_ts = format_vtt_time(segment.start)
        end_ts = format_vtt_time(segment.end)
        f.write(f'{count}\n')
        f.write(f'{start_ts} --> {end_ts}\n')
        f.write(f'{segment.text.strip()}\n\n')
        progress_pct = int((segment.start / duration) * 100) if duration > 0 else 0
        if progress_pct >= last_progress + 10:
            elapsed = time.time() - start
            print(f'  {progress_pct}% ({segment.start:.0f}s / {duration:.0f}s) - elapsed: {elapsed:.0f}s')
            sys.stdout.flush()
            last_progress = progress_pct

elapsed = time.time() - start
print(f'\n✓ Complete! {count} segments in {elapsed:.1f}s')
print(f'  Speed: {duration/elapsed:.1f}x realtime')
print(f'  Output: {output_path}')
"@

$tempScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.py'
$pythonScript | Set-Content -Path $tempScript -Encoding UTF8

try {
    python $tempScript
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Transcription failed with exit code $LASTEXITCODE"
        exit 1
    }
} finally {
    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}

Write-Information ""
Write-Information "`e[32m✅ Transcript saved: $OutputPath`e[0m"
return $OutputPath
