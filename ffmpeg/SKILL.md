---
name: ffmpeg
description: V1.4 - Universal media processing toolkit with Appender workflow for concatenating video segments with smooth transitions. Use for transcoding, filtering, streaming, and format conversion.
disable-model-invocation: true
---

# FFmpeg

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

FFmpeg is a universal media converter that reads, filters, and transcodes virtually any multimedia format.

## Terminology

- **"!" folder** - Shorthand for `D:\AI\Media\Videos\!\`
- **"!!" folder** - Shorthand for `D:\AI\Media\Videos\!\!!`

## Appender Workflow

**Purpose**: Append video segments to `!! Best.mp4` with smooth transitions.

**When to use**: User requests "use ffmpeg with Appender" or "append to Best.mp4"

**Requirements**:

- Source filename (searches in `!` folder)
- Time range (e.g., "2:31-2:52")

**Automated workflow**:

1. **Backup** `!! Best.mp4` with timestamp: `Best_backup_YYYYMMDD_HHmmss.mp4`
2. **Extract** segment from source file using `-ss` and `-to` with stream copy
3. **Scale** segment to match Best.mp4 format:
   - Resolution: 1280x720
   - Frame rate: 30 fps
   - Audio: 48000 Hz, stereo
   - Use: `scale=1280:720:flags=lanczos,fps=30` and `-ar 48000`
4. **Get duration** of Best.mp4 using `ffprobe`
5. **Apply transitions**:
   - **Try crossfade first** (xfade + acrossfade filters)
   - **Fallback to fade effects** if crossfade fails due to timebase/format mismatches:
     - Add 1-second fade-out to end of Best.mp4 (`st=duration-1`)
     - Add 1-second fade-in to start of segment (`st=0`)
     - Concatenate using concat demuxer
6. **Replace** original Best.mp4 with new version
7. **Cleanup** temp files (`temp_*.mp4`, `concat_list.txt`)
8. **Log** to history

**Example commands**:

```powershell
# Backup
Copy-Item "D:\AI\Media\Videos\!\!!\Best.mp4" "D:\AI\Media\Videos\!\!!\Best_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4"

# Extract segment (e.g., 2:31 to 2:52)
ffmpeg -ss 00:02:31 -i $sourceFile -to 00:00:21 -c copy temp_segment.mp4 -y

# Scale to match format
ffmpeg -i temp_segment.mp4 -vf "scale=1280:720:flags=lanczos,fps=30" -c:v libx264 -crf 23 -preset fast -c:a aac -ar 48000 temp_segment_scaled.mp4 -y

# Get Best.mp4 duration
$duration = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 Best.mp4

# Add fade transitions (fallback method)
ffmpeg -i Best.mp4 -vf "fade=out:st=$($duration-1):d=1" -af "afade=out:st=$($duration-1):d=1" -c:v libx264 -crf 23 -preset fast -c:a aac temp_best_faded.mp4 -y
ffmpeg -i temp_segment_scaled.mp4 -vf "fade=in:st=0:d=1" -af "afade=in:st=0:d=1" -c:v libx264 -crf 23 -preset fast -c:a aac temp_segment_faded.mp4 -y

# Concatenate
"file 'temp_best_faded.mp4'`nfile 'temp_segment_faded.mp4'" | Out-File concat_list.txt -Encoding utf8
ffmpeg -f concat -safe 0 -i concat_list.txt -c copy Best_new.mp4 -y

# Replace and cleanup
Move-Item Best_new.mp4 Best.mp4 -Force
Remove-Item temp_*.mp4, concat_list.txt
```

**Why crossfade often fails**: Different source videos have different timebases, frame rates, and color spaces. The fade-out/fade-in approach is more reliable as it processes each video independently before concatenation.

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Command Syntax

```
ffmpeg [global_options] {[input_options] -i input} ... {[output_options] output} ...
```

Options apply to the **next** file specified. Order matters.

## Core Operations

### Format Conversion

```powershell
# Basic conversion (auto-detects formats)
ffmpeg -i input.avi output.mp4

# Force output format
ffmpeg -i input.mkv -f mp4 output.mp4
```

### Stream Copy (No Re-encoding)

```powershell
# Copy all streams without transcoding (fast, lossless)
ffmpeg -i input.mkv -c copy output.mp4

# Copy video, re-encode audio
ffmpeg -i input.mkv -c:v copy -c:a aac output.mp4
```

### Transcoding

```powershell
# Re-encode with specific codecs
ffmpeg -i input.avi -c:v libx264 -c:a aac output.mp4

# Set video bitrate
ffmpeg -i input.avi -c:v libx264 -b:v 2M output.mp4

# Set quality (CRF: 0=lossless, 23=default, 51=worst)
ffmpeg -i input.avi -c:v libx264 -crf 23 output.mp4
```

## Video Options

| Option | Description | Example |
|--------|-------------|---------|
| `-c:v codec` | Video codec | `-c:v libx264` |
| `-b:v bitrate` | Video bitrate | `-b:v 2M` |
| `-r fps` | Frame rate | `-r 30` |
| `-s WxH` | Resolution | `-s 1920x1080` |
| `-aspect ratio` | Aspect ratio | `-aspect 16:9` |
| `-vn` | Disable video | |
| `-vframes n` | Output n frames | `-vframes 100` |

### Common Video Codecs

- `libx264` - H.264 (most compatible)
- `libx265` - H.265/HEVC (better compression)
- `libvpx-vp9` - VP9 (WebM)
- `libaom-av1` - AV1 (best compression, slow)
- `copy` - Stream copy (no re-encoding)

## Audio Options

| Option | Description | Example |
|--------|-------------|---------|
| `-c:a codec` | Audio codec | `-c:a aac` |
| `-b:a bitrate` | Audio bitrate | `-b:a 192k` |
| `-ar rate` | Sample rate | `-ar 44100` |
| `-ac channels` | Channel count | `-ac 2` |
| `-an` | Disable audio | |
| `-af filter` | Audio filter | `-af volume=2` |

### Common Audio Codecs

- `aac` - AAC (MP4 default)
- `libmp3lame` - MP3
- `libopus` - Opus (best quality)
- `flac` - FLAC (lossless)
- `pcm_s16le` - WAV PCM
- `copy` - Stream copy

## Time Options

```powershell
# Start at position
ffmpeg -ss 00:01:30 -i input.mp4 output.mp4

# Duration limit
ffmpeg -i input.mp4 -t 00:00:30 output.mp4

# End position
ffmpeg -i input.mp4 -to 00:02:00 output.mp4

# Extract from 1:30 to 2:00 (30 seconds)
ffmpeg -ss 00:01:30 -i input.mp4 -t 00:00:30 -c copy output.mp4
```

## Stream Selection

```powershell
# Map specific streams
ffmpeg -i input.mkv -map 0:v:0 -map 0:a:1 output.mp4

# Map all streams
ffmpeg -i input.mkv -map 0 output.mp4

# Combine streams from multiple inputs
ffmpeg -i video.mp4 -i audio.m4a -map 0:v -map 1:a -c copy output.mp4
```

### Stream Specifiers

- `0:v` - All video streams from input 0
- `0:a:1` - Second audio stream from input 0
- `0:s` - All subtitle streams from input 0
- `-map 0 -map -0:s` - All streams except subtitles

## Video Filters (`-vf` or `-filter:v`)

### Scaling

```powershell
# Scale to specific size
ffmpeg -i input.mp4 -vf "scale=1280:720" output.mp4

# Scale preserving aspect ratio (-1 auto-calculates)
ffmpeg -i input.mp4 -vf "scale=1280:-1" output.mp4

# Scale to fit within bounds
ffmpeg -i input.mp4 -vf "scale='min(1280,iw)':'min(720,ih)'" output.mp4
```

### Cropping

```powershell
# Crop to WxH at position X,Y
ffmpeg -i input.mp4 -vf "crop=640:480:100:50" output.mp4

# Crop center
ffmpeg -i input.mp4 -vf "crop=in_w/2:in_h/2" output.mp4
```

### Rotation & Flipping

```powershell
# Rotate 90° clockwise
ffmpeg -i input.mp4 -vf "transpose=1" output.mp4
# transpose: 0=90°CCW+vflip, 1=90°CW, 2=90°CCW, 3=90°CW+vflip

# Horizontal flip
ffmpeg -i input.mp4 -vf "hflip" output.mp4

# Vertical flip
ffmpeg -i input.mp4 -vf "vflip" output.mp4

# Rotate arbitrary angle
ffmpeg -i input.mp4 -vf "rotate=PI/4" output.mp4
```

### Speed Adjustment

```powershell
# 2x speed (video)
ffmpeg -i input.mp4 -vf "setpts=0.5*PTS" output.mp4

# 0.5x speed (slow motion)
ffmpeg -i input.mp4 -vf "setpts=2*PTS" output.mp4
```

### Common Video Filters

| Filter | Description | Example |
|--------|-------------|---------|
| `scale=W:H` | Resize | `scale=1920:1080` |
| `crop=W:H:X:Y` | Crop region | `crop=640:480:0:0` |
| `pad=W:H:X:Y:color` | Add padding | `pad=1920:1080:0:0:black` |
| `overlay=X:Y` | Overlay video | `overlay=10:10` |
| `fade=t=in:d=1` | Fade effect | `fade=t=in:st=0:d=1` |
| `drawtext=text=Hi` | Add text | `drawtext=text='Hello':fontsize=24` |
| `eq=brightness=0.1` | Adjust levels | `eq=brightness=0.1:contrast=1.2` |
| `hue=s=0` | Grayscale | `hue=s=0` |
| `unsharp` | Sharpen | `unsharp=5:5:1.0` |
| `boxblur=5` | Blur | `boxblur=5:1` |
| `deinterlace` | Deinterlace | `yadif` |
| `fps=30` | Change framerate | `fps=30` |
| `reverse` | Reverse video | `reverse` |
| `loop=3` | Loop video | `loop=3:size=999` |

### Filter Chains

```powershell
# Multiple filters (comma-separated)
ffmpeg -i input.mp4 -vf "scale=1280:720,fps=30,eq=brightness=0.1" output.mp4
```

## Audio Filters (`-af` or `-filter:a`)

```powershell
# Volume adjustment
ffmpeg -i input.mp4 -af "volume=2.0" output.mp4
ffmpeg -i input.mp4 -af "volume=6dB" output.mp4

# Normalize audio
ffmpeg -i input.mp4 -af "loudnorm" output.mp4

# Speed adjustment
ffmpeg -i input.mp4 -af "atempo=2.0" output.mp4
# Note: atempo range 0.5-2.0, chain for more: atempo=2.0,atempo=2.0

# Fade in/out
ffmpeg -i input.mp4 -af "afade=t=in:d=3,afade=t=out:st=57:d=3" output.mp4

# Audio compression
ffmpeg -i input.mp4 -af "acompressor=threshold=-20dB:ratio=4" output.mp4

# Noise reduction
ffmpeg -i input.mp4 -af "afftdn=nf=-25" output.mp4

# High/low pass
ffmpeg -i input.mp4 -af "highpass=f=200,lowpass=f=3000" output.mp4
```

## Complex Filtergraphs (`-filter_complex`)

```powershell
# Picture-in-picture
ffmpeg -i main.mp4 -i overlay.mp4 -filter_complex "[1:v]scale=320:-1[pip];[0:v][pip]overlay=10:10" output.mp4

# Side-by-side
ffmpeg -i left.mp4 -i right.mp4 -filter_complex "[0:v][1:v]hstack" output.mp4

# Vertical stack
ffmpeg -i top.mp4 -i bottom.mp4 -filter_complex "[0:v][1:v]vstack" output.mp4

# Grid layout
ffmpeg -i 1.mp4 -i 2.mp4 -i 3.mp4 -i 4.mp4 -filter_complex "[0:v][1:v][2:v][3:v]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0" output.mp4

# Concatenate videos
ffmpeg -i part1.mp4 -i part2.mp4 -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1" output.mp4

# Crossfade transition
ffmpeg -i first.mp4 -i second.mp4 -filter_complex "[0:v][1:v]xfade=transition=fade:duration=1:offset=4" output.mp4

# Add audio to video
ffmpeg -i video.mp4 -i audio.mp3 -filter_complex "[0:a][1:a]amix=inputs=2" output.mp4

# Mix multiple audio tracks
ffmpeg -i input1.mp3 -i input2.mp3 -filter_complex "[0:a][1:a]amix=inputs=2:duration=first" output.mp3
```

## Image Operations

### Extract Frames

```powershell
# Extract all frames
ffmpeg -i input.mp4 frames/frame_%04d.png

# Extract 1 frame per second
ffmpeg -i input.mp4 -vf "fps=1" frames/frame_%04d.png

# Extract single frame at timestamp
ffmpeg -ss 00:01:30 -i input.mp4 -frames:v 1 thumbnail.png

# Extract thumbnail (best frame from first 100)
ffmpeg -i input.mp4 -vf "thumbnail=100" -frames:v 1 thumb.png
```

### Create Video from Images

```powershell
# Image sequence to video
ffmpeg -framerate 30 -i image_%04d.png -c:v libx264 -pix_fmt yuv420p output.mp4

# Slideshow with duration per image
ffmpeg -framerate 1/5 -i image_%04d.png -c:v libx264 -r 30 -pix_fmt yuv420p slideshow.mp4
```

### Image Conversion

```powershell
# Convert image format
ffmpeg -i input.png output.jpg

# Resize image
ffmpeg -i input.png -vf "scale=800:-1" output.png
```

## GIF Operations

```powershell
# Video to GIF (basic)
ffmpeg -i input.mp4 -vf "fps=10,scale=320:-1" output.gif

# High-quality GIF (with palette)
ffmpeg -i input.mp4 -vf "fps=10,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" output.gif

# GIF to video
ffmpeg -i input.gif -movflags faststart -pix_fmt yuv420p output.mp4
```

## Audio Extraction & Manipulation

```powershell
# Extract audio from video
ffmpeg -i video.mp4 -vn -c:a copy audio.m4a
ffmpeg -i video.mp4 -vn -c:a libmp3lame -q:a 2 audio.mp3

# Remove audio from video
ffmpeg -i input.mp4 -an -c:v copy output.mp4

# Replace audio
ffmpeg -i video.mp4 -i new_audio.mp3 -c:v copy -c:a aac -map 0:v -map 1:a output.mp4

# Merge audio tracks
ffmpeg -i input.mp4 -i audio.mp3 -c:v copy -c:a aac -map 0 -map 1:a output.mp4

# Audio format conversion
ffmpeg -i input.flac -c:a libmp3lame -b:a 320k output.mp3
```

## Subtitles

```powershell
# Extract subtitles
ffmpeg -i input.mkv -map 0:s:0 subtitles.srt

# Burn subtitles (hardcode)
ffmpeg -i input.mp4 -vf "subtitles=subs.srt" output.mp4

# Add subtitle stream
ffmpeg -i video.mp4 -i subs.srt -c copy -c:s mov_text output.mp4
```

## Screen & Audio Recording

```powershell
# Windows screen capture (gdigrab)
ffmpeg -f gdigrab -framerate 30 -i desktop output.mp4

# Capture specific window
ffmpeg -f gdigrab -framerate 30 -i title="Window Title" output.mp4

# Capture region
ffmpeg -f gdigrab -framerate 30 -offset_x 100 -offset_y 100 -video_size 1280x720 -i desktop output.mp4

# Record audio (Windows)
ffmpeg -f dshow -i audio="Microphone" output.mp3
# List devices: ffmpeg -list_devices true -f dshow -i dummy
```

## Streaming

```powershell
# Stream to RTMP
ffmpeg -re -i input.mp4 -c:v libx264 -c:a aac -f flv rtmp://server/live/stream

# Receive RTMP stream
ffmpeg -i rtmp://server/live/stream -c copy output.mp4

# Create HLS stream
ffmpeg -i input.mp4 -c:v libx264 -c:a aac -hls_time 10 -hls_list_size 0 stream.m3u8
```

## Hardware Acceleration

```powershell
# NVIDIA NVENC encoding
ffmpeg -i input.mp4 -c:v h264_nvenc -preset fast output.mp4

# NVIDIA NVDEC decoding
ffmpeg -hwaccel cuda -i input.mp4 -c:v h264_nvenc output.mp4

# Intel Quick Sync
ffmpeg -i input.mp4 -c:v h264_qsv output.mp4

# AMD AMF
ffmpeg -i input.mp4 -c:v h264_amf output.mp4
```

## Two-Pass Encoding

```powershell
# Better quality for target bitrate
ffmpeg -i input.mp4 -c:v libx264 -b:v 2M -pass 1 -f null NUL
ffmpeg -i input.mp4 -c:v libx264 -b:v 2M -pass 2 output.mp4
```

## Metadata

```powershell
# View metadata
ffprobe -v quiet -print_format json -show_format -show_streams input.mp4

# Set metadata
ffmpeg -i input.mp4 -c copy -metadata title="My Video" -metadata artist="Author" output.mp4

# Copy metadata
ffmpeg -i input.mp4 -i metadata_source.mp4 -map 0 -map_metadata 1 -c copy output.mp4

# Strip metadata
ffmpeg -i input.mp4 -map_metadata -1 -c copy output.mp4
```

## Common Recipes

### Compress Video for Web

```powershell
ffmpeg -i input.mp4 -c:v libx264 -crf 28 -preset slow -c:a aac -b:a 128k -movflags +faststart output.mp4
```

### Create Thumbnail Grid

```powershell
ffmpeg -i input.mp4 -vf "select='not(mod(n,100))',scale=160:-1,tile=5x5" -frames:v 1 grid.png
```

### Loop Video

```powershell
# Loop 3 times
ffmpeg -stream_loop 3 -i input.mp4 -c copy output.mp4
```

### Reverse Video

```powershell
ffmpeg -i input.mp4 -vf "reverse" -af "areverse" output.mp4
```

### Create Test Patterns

```powershell
# Color bars
ffmpeg -f lavfi -i testsrc2=duration=10:size=1920x1080:rate=30 test.mp4

# Sine wave audio
ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" tone.wav
```

### Detect Scene Changes

```powershell
ffmpeg -i input.mp4 -vf "select='gt(scene,0.4)',showinfo" -f null -
```

### Stabilize Shaky Video

```powershell
# Analyze
ffmpeg -i input.mp4 -vf "vidstabdetect=shakiness=5:accuracy=15" -f null -
# Apply
ffmpeg -i input.mp4 -vf "vidstabtransform=smoothing=10" output.mp4
```

## Common Flags

| Flag | Description |
|------|-------------|
| `-y` | Overwrite output without asking |
| `-n` | Never overwrite output |
| `-hide_banner` | Suppress version/config info |
| `-loglevel quiet` | Suppress all output except errors |
| `-stats` | Show encoding progress |
| `-progress file` | Write progress to file |

## Useful Probing Commands

```powershell
# Get duration
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 input.mp4

# Get resolution
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 input.mp4

# Get codec info
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 input.mp4

# Full stream info (JSON)
ffprobe -v quiet -print_format json -show_streams input.mp4
```

## Filter Reference

### Video Filters Summary

- **Transform**: scale, crop, pad, rotate, transpose, hflip, vflip, shear
- **Overlay**: overlay, blend, alphamerge
- **Color**: eq, hue, colorbalance, curves, lut, colorkey, chromakey
- **Blur/Sharp**: boxblur, gblur, unsharp, smartblur, bilateral
- **Noise**: noise, atadenoise, nlmeans, fftdnoiz, hqdn3d
- **Effects**: fade, drawbox, drawtext, drawgrid, vignette
- **Analysis**: cropdetect, blackdetect, scdet, showinfo
- **Time**: fps, setpts, framerate, minterpolate, tblend, reverse
- **Deinterlace**: yadif, bwdif, w3fdif, estdif

### Audio Filters Summary

- **Volume**: volume, loudnorm, dynaudnorm, compand
- **EQ**: bass, treble, equalizer, bandpass, highpass, lowpass
- **Effects**: afade, acrossfade, aecho, chorus, flanger, tremolo
- **Dynamics**: acompressor, alimiter, agate
- **Noise**: afftdn, anlmdn, adeclick
- **Time**: atempo, asetpts, aresample, areverse
- **Spatial**: pan, channelmap, channelsplit, join, amerge

## Error Handling

```powershell
# Continue on errors
ffmpeg -err_detect ignore_err -i broken.mp4 -c copy fixed.mp4

# Analyze without output
ffmpeg -v error -i input.mp4 -f null -
```
