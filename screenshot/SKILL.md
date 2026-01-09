---
name: screenshot
description: V1.2 - Expert in taking screenshots of windows, full screens, or partial regions. Supports multi-monitor setups with proper DPI handling using python-mss. Automatically compresses to WebP for AI-optimized images.
---

# Screenshot

Capture screenshots of specific windows or full monitors with proper DPI scaling.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Screenshot Storage

All screenshots are saved to `$env:TEMP` (typically `C:\Users\User\AppData\Local\Temp`):

- **Pattern**: `screenshot-*.png`, `screenshot-*.webp`
- **Temporary**: Files persist until system cleanup or manual deletion
- **Cleanup**: Use the cleanup command below to remove old screenshots

```powershell
# Clean up all screenshots older than 7 days
Get-ChildItem $env:TEMP | Where-Object { 
  ($_.Name -like "screenshot-*" -or $_.Name -like "test*.webp" -or $_.Name -like "test*.jpg" -or $_.Name -like "monitor-index-*") -and 
  $_.LastWriteTime -lt (Get-Date).AddDays(-7) 
} | Remove-Item -Force

# Or clean up ALL screenshots immediately
Get-ChildItem $env:TEMP | Where-Object { 
  $_.Name -like "screenshot-*" -or $_.Name -like "test*.webp" -or $_.Name -like "test*.jpg" -or $_.Name -like "monitor-index-*" 
} | Remove-Item -Force
```

## Monitor Mapping

The user has 3 monitors with the following mapping:

| User's Monitor # | MSS Index | Usage            |
|------------------|-----------|------------------|
| Monitor 1        | 3         | User's Monitor 1 |
| Monitor 2        | 1         | User's Monitor 2 |
| Monitor 3        | 2         | User's Monitor 3 |

**When the user says "Monitor 1"**, capture MSS index 3.
**When the user says "Monitor 2"**, capture MSS index 1.
**When the user says "Monitor 3"**, capture MSS index 2.

## Capabilities

### Full Screen Capture

Capture entire monitors using python-mss and compress to WebP for AI:

```powershell
# Map user monitor number to MSS index
$monitorMap = @{1=3; 2=1; 3=2}
$mssIndex = $monitorMap[$userMonitorNumber]
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Capture to PNG first
$pngPath = Join-Path $env:TEMP "screenshot-$timestamp.png"
$script = @"
import mss
import sys
screen_index = int(sys.argv[1])
output_path = sys.argv[2]
with mss.mss() as sct:
    screenshot = sct.grab(sct.monitors[screen_index])
    mss.tools.to_png(screenshot.rgb, screenshot.size, output=output_path)
    print(f'{screenshot.width}x{screenshot.height}')
"@
$script | Out-File "$env:TEMP\capture.py" -Encoding UTF8
py "$env:TEMP\capture.py" $mssIndex $pngPath

# Compress to WebP (82% size reduction, excellent quality for AI)
$webpPath = Join-Path $env:TEMP "screenshot-$timestamp.webp"
ffmpeg -i $pngPath -vf "scale=1024:-1" -c:v libwebp -quality 85 $webpPath -y 2>&1 | Out-Null
Remove-Item $pngPath -Force  # Clean up original PNG
Write-Host "Screenshot saved: $webpPath" -ForegroundColor Green
```

### Partial Screen Capture

Capture a specific region of a monitor and compress to WebP:

```powershell
# Example: Capture right 50% of Monitor 2 (MSS index 1)
$monitorMap = @{1=3; 2=1; 3=2}
$mssIndex = $monitorMap[$userMonitorNumber]
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$pngPath = Join-Path $env:TEMP "screenshot-partial-$timestamp.png"

$script = @"
import mss

with mss.mss() as sct:
    monitor = sct.monitors[$mssIndex]
    
    # Calculate region (example: right 50%)
    width = monitor['width']
    height = monitor['height']
    left = monitor['left'] + (width // 2)  # Start from middle
    top = monitor['top']
    
    # Create custom region
    region = {
        'left': left,
        'top': top,
        'width': width // 2,
        'height': height
    }
    
    # Capture the region
    screenshot = sct.grab(region)
    mss.tools.to_png(screenshot.rgb, screenshot.size, output='$($pngPath.Replace('\','\\'))')
    print(f'Captured: {screenshot.width}x{screenshot.height}')
"@

$script | Out-File "$env:TEMP\capture-partial.py" -Encoding UTF8
py "$env:TEMP\capture-partial.py"

# Compress to WebP
$webpPath = Join-Path $env:TEMP "screenshot-partial-$timestamp.webp"
ffmpeg -i $pngPath -vf "scale=1024:-1" -c:v libwebp -quality 85 $webpPath -y 2>&1 | Out-Null
Remove-Item $pngPath -Force
Write-Host "Screenshot saved: $webpPath" -ForegroundColor Green
```

**Common region calculations:**

- Left 50%: `left = monitor['left']`, `width = width // 2`
- Right 50%: `left = monitor['left'] + (width // 2)`, `width = width // 2`
- Top 50%: `top = monitor['top']`, `height = height // 2`
- Bottom 50%: `top = monitor['top'] + (height // 2)`, `height = height // 2`
- Center 50%: `left = monitor['left'] + (width // 4)`, `width = width // 2`,
  `top = monitor['top'] + (height // 4)`, `height = height // 2`
- Custom percentage: Multiply width/height by fraction (e.g., `0.33` for 33%)

### Window Capture

Capture specific windows by title using PowerShell:

```powershell
$script = @'
param([string]$WindowTitle)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
public struct RECT {
    public int Left; public int Top; public int Right; public int Bottom;
}
"@

$process = Get-Process | Where-Object { 
    $_.MainWindowTitle -ne "" -and $_.MainWindowTitle -like "*$WindowTitle*" 
} | Select-Object -First 1

if (-not $process) {
    Write-Host "Window not found: $WindowTitle" -ForegroundColor Red
    exit 1
}

$rect = New-Object RECT
[Win32]::GetWindowRect($process.MainWindowHandle, [ref]$rect) | Out-Null
[Win32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 200

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
$bitmap = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$point = New-Object System.Drawing.Point $rect.Left, $rect.Top
$graphics.CopyFromScreen($point, [System.Drawing.Point]::Empty, (New-Object System.Drawing.Size $width, $height))

$outputPath = Join-Path $env:TEMP "screenshot-$($process.ProcessName)-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"
$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
Write-Output $outputPath
'@

$scriptPath = Join-Path $env:TEMP "capture-window.ps1"
$script | Set-Content $scriptPath
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -WindowTitle "Slack"
```

## Display Screenshots

After capturing, use the display-image skill with zoom-to-fit:

```powershell
& "C:\Program Files\GPSoftware\Directory Opus\d8viewer.exe" /fittopage $screenshotPath
```

## Default Compression

All screenshots are automatically compressed to **WebP Q85 @ 1024px** for optimal AI vision quality:

- **Size reduction**: ~82% smaller than original PNG
- **Quality**: Excellent for AI interpretation
- **Token usage**: ~765 tokens vs 1400+ for original

### Alternative: Aggressive Compression

For maximum compression (UI/layout analysis only):

```powershell
# WebP Q75 @ 512px (95% smaller, acceptable quality)
ffmpeg -i $inputPath -vf "scale=512:-1" -c:v libwebp -quality 75 $outputPath -y 2>&1 | Out-Null
```

### Keep Original PNG

To skip compression and keep full-resolution PNG, comment out the ffmpeg and Remove-Item lines in the capture scripts.

## Dependencies

- Python 3.x with `mss` package: `py -m pip install mss`
- PowerShell (for window capture)
- Directory Opus (for viewing)
- FFmpeg (for compression): Available system-wide

## Examples

**Capture Monitor 2 (Compressed):**

```powershell
# User's Monitor 2 = MSS Index 1
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$pngPath = Join-Path $env:TEMP "screenshot-$timestamp.png"
$script = @"
import mss
with mss.mss() as sct:
    screenshot = sct.grab(sct.monitors[1])
    mss.tools.to_png(screenshot.rgb, screenshot.size, output='$($pngPath.Replace('\','\\'))')
"@
$script | Out-File "$env:TEMP\cap.py" -Encoding UTF8
py "$env:TEMP\cap.py"

# Compress
$webpPath = Join-Path $env:TEMP "screenshot-$timestamp.webp"
ffmpeg -i $pngPath -vf "scale=1024:-1" -c:v libwebp -quality 85 $webpPath -y 2>&1 | Out-Null
Remove-Item $pngPath -Force
```

**Capture Right 50% of Monitor 2 (Compressed):**

```powershell
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$pngPath = Join-Path $env:TEMP "screenshot-monitor2-right50-$timestamp.png"
$script = @"
import mss
with mss.mss() as sct:
    monitor = sct.monitors[1]
    width = monitor['width']
    height = monitor['height']
    region = {
        'left': monitor['left'] + (width // 2),
        'top': monitor['top'],
        'width': width // 2,
        'height': height
    }
    screenshot = sct.grab(region)
    mss.tools.to_png(screenshot.rgb, screenshot.size, output='$($pngPath.Replace('\','\\'))')
"@
$script | Out-File "$env:TEMP\cap.py" -Encoding UTF8
py "$env:TEMP\cap.py"

# Compress
$webpPath = Join-Path $env:TEMP "screenshot-monitor2-right50-$timestamp.webp"
ffmpeg -i $pngPath -vf "scale=1024:-1" -c:v libwebp -quality 85 $webpPath -y 2>&1 | Out-Null
Remove-Item $pngPath -Force
```

**Capture Slack Window:**

```powershell
powershell.exe -NoProfile -File capture-window.ps1 -WindowTitle "Slack"
```
