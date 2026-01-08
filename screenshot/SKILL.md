---
name: screenshot
description: V1.1 - Expert in taking screenshots of windows, full screens, or partial regions. Supports multi-monitor setups with proper DPI handling using python-mss.
---

# Screenshot

Capture screenshots of specific windows or full monitors with proper DPI scaling.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
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

Capture entire monitors using python-mss (handles DPI scaling correctly):

```powershell
# Map user monitor number to MSS index
$monitorMap = @{1=3; 2=1; 3=2}
$mssIndex = $monitorMap[$userMonitorNumber]

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

$outputPath = Join-Path $env:TEMP "screenshot-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"
$script | Out-File "$env:TEMP\capture.py" -Encoding UTF8
py "$env:TEMP\capture.py" $mssIndex $outputPath
```

### Partial Screen Capture

Capture a specific region of a monitor using custom coordinates:

```powershell
# Example: Capture right 50% of Monitor 2 (MSS index 1)
$monitorMap = @{1=3; 2=1; 3=2}
$mssIndex = $monitorMap[$userMonitorNumber]
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $env:TEMP "screenshot-partial-$timestamp.png"

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
    mss.tools.to_png(screenshot.rgb, screenshot.size, output='$($outputPath.Replace('\','\\'))')
    print(f'Captured: {screenshot.width}x{screenshot.height}')
"@

$script | Out-File "$env:TEMP\capture-partial.py" -Encoding UTF8
py "$env:TEMP\capture-partial.py"
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

## Dependencies

- Python 3.x with `mss` package: `py -m pip install mss`
- PowerShell (for window capture)
- Directory Opus (for viewing)

## Examples

**Capture Monitor 2:**

```powershell
# User's Monitor 2 = MSS Index 1
$script = @"
import mss
with mss.mss() as sct:
    screenshot = sct.grab(sct.monitors[1])
    mss.tools.to_png(screenshot.rgb, screenshot.size, output='monitor2.png')
"@
$script | Out-File "$env:TEMP\cap.py" -Encoding UTF8
py "$env:TEMP\cap.py"
```

**Capture Right 50% of Monitor 2:**

```powershell
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $env:TEMP "screenshot-monitor2-right50-$timestamp.png"
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
    mss.tools.to_png(screenshot.rgb, screenshot.size, output='$($outputPath.Replace('\','\\'))')
"@
$script | Out-File "$env:TEMP\cap.py" -Encoding UTF8
py "$env:TEMP\cap.py"
```

**Capture Slack Window:**

```powershell
powershell.exe -NoProfile -File capture-window.ps1 -WindowTitle "Slack"
```
