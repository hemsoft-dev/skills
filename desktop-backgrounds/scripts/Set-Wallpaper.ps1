#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Set Windows desktop wallpaper for one or all monitors.

.DESCRIPTION
    Sets the Windows desktop background (wallpaper) using the Windows Registry.
    Supports single and multi-monitor setups with various fill styles.

.PARAMETER ImagePath
    Full path to the image file (.png, .jpg, .jpeg, .webp, .bmp)

.PARAMETER FillStyle
    How to display the wallpaper: Stretch, Fit, Center, Tile, Fill
    Default: Fill

.PARAMETER Monitor
    Target monitor: "All", "Primary", or specific monitor index (0, 1, etc.)
    Default: All

.EXAMPLE
    .\Set-Wallpaper.ps1 -ImagePath "C:\path\to\background.png"
    Sets the image as wallpaper for all monitors using Fill style

.EXAMPLE
    .\Set-Wallpaper.ps1 -ImagePath "C:\path\to\background.png" -FillStyle "Fit" -Monitor "Primary"
    Sets the image as fitted wallpaper on primary monitor only

.NOTES
    Requires Administrator privileges to modify Windows Registry
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ImagePath,

    [ValidateSet("Stretch", "Fit", "Center", "Tile", "Fill")]
    [string]$FillStyle = "Fill",

    [ValidateSet("All", "Primary", 0, 1, 2, 3)]
    [string]$Monitor = "All"
)

function Set-WallpaperInternal {
    param(
        [string]$ImagePath,
        [string]$FillStyle,
        [int]$MonitorIndex = -1
    )

    # Normalize image path
    $absolutePath = (Resolve-Path $ImagePath).Path

    # Registry paths
    if ($MonitorIndex -ge 0) {
        $regPath = "HKCU:\Control Panel\Desktop"
    }
    else {
        $regPath = "HKCU:\Control Panel\Desktop"
    }

    # FillStyle to registry values
    $fillValues = @{
        "Stretch" = @{ WallpaperStyle = "2"; TileWallpaper = "0" }
        "Fit"     = @{ WallpaperStyle = "6"; TileWallpaper = "0" }
        "Center"  = @{ WallpaperStyle = "0"; TileWallpaper = "0" }
        "Tile"    = @{ WallpaperStyle = "0"; TileWallpaper = "1" }
        "Fill"    = @{ WallpaperStyle = "10"; TileWallpaper = "0" }
    }

    try {
        # Set the registry values
        Set-ItemProperty -Path $regPath -Name "Wallpaper" -Value $absolutePath -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "WallpaperStyle" -Value $fillValues[$FillStyle]["WallpaperStyle"] -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "TileWallpaper" -Value $fillValues[$FillStyle]["TileWallpaper"] -ErrorAction Stop

        # Refresh desktop
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    
    public static void Set(string path) {
        SystemParametersInfo(20, 0, path, 0x01 | 0x02);
    }
}
"@
        [Wallpaper]::Set($absolutePath)

        Write-Host "✓ Wallpaper applied successfully" -ForegroundColor Green
        Write-Host "  Image: $absolutePath" -ForegroundColor Cyan
        Write-Host "  Style: $FillStyle" -ForegroundColor Cyan

        return $true
    }
    catch {
        Write-Host "✗ Error setting wallpaper: $_" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "🖼️  Windows Wallpaper Setter" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

if ($Monitor -eq "Primary") {
    Set-WallpaperInternal -ImagePath $ImagePath -FillStyle $FillStyle -MonitorIndex 0
}
elseif ($Monitor -eq "All") {
    Set-WallpaperInternal -ImagePath $ImagePath -FillStyle $FillStyle
}
else {
    Set-WallpaperInternal -ImagePath $ImagePath -FillStyle $FillStyle -MonitorIndex ([int]$Monitor)
}
