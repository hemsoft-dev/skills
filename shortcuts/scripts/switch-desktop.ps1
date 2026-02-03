param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Previous", "Next")]
    [string]$Direction,
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 9)]
    [int]$DesktopNumber = -1
)

# Use VirtualDesktop.exe compiled from https://github.com/MScholtes/VirtualDesktop
# This uses Windows COM interfaces and bypasses ALL keyboard hooks including Wispr Flow

$exePath = Join-Path $PSScriptRoot "VirtualDesktop.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "VirtualDesktop.exe not found at $exePath"
    exit 1
}

# Switch to specific desktop number or cycle
if ($DesktopNumber -ge 0) {
    & $exePath /Switch:$DesktopNumber /Quiet
} elseif ($Direction -eq "Next") {
    & $exePath /Right /Quiet
} elseif ($Direction -eq "Previous") {
    & $exePath /Left /Quiet
} else {
    Write-Error "Must specify either -Direction or -DesktopNumber"
    exit 1
}
