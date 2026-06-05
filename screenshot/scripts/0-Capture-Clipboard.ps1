param(
    [Parameter(Mandatory=$false)]
    [string]$DestinationSkill = "screenshot",

    [Parameter(Mandatory=$false)]
    [string[]]$Tags = @(),

    [Parameter(Mandatory=$false)]
    [bool]$AutoDescription = $true,

    [Parameter(Mandatory=$false)]
    [string]$CustomDescription = "",

    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory = "D:\tmp\screenshot-skill",

    [Parameter(Mandatory=$false)]
    [switch]$PersistToLibrary
)

$ErrorActionPreference = "Stop"
Write-Host "`n=== Screenshot Clipboard Capture ===" -ForegroundColor Cyan

New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$clipboardImagePath = Join-Path $OutputDirectory "clipboard-$timestamp.png"

$clipboardScript = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) {
    Write-Output "NO_CLIPBOARD_IMAGE"
    exit 2
}
`$image = [System.Windows.Forms.Clipboard]::GetImage()
`$image.Save("$clipboardImagePath", [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "CLIPBOARD_IMAGE_PATH=$clipboardImagePath"
Write-Output "CLIPBOARD_IMAGE_SIZE=`$(`$image.Width)x`$(`$image.Height)"
"@

$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($clipboardScript))
$clipboardOutput = & powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -EncodedCommand $encodedCommand 2>&1
$clipboardExitCode = $LASTEXITCODE
$clipboardOutput | ForEach-Object { Write-Host $_ }

if ($clipboardExitCode -ne 0 -or -not (Test-Path $clipboardImagePath)) {
    if (Test-Path $clipboardImagePath) {
        Remove-Item $clipboardImagePath -Force -ErrorAction SilentlyContinue
    }
    Write-Host "No image found on clipboard." -ForegroundColor Yellow
    exit 2
}

if (-not $PersistToLibrary) {
    Write-Host "Temporary clipboard image is ready for agent inspection." -ForegroundColor Green
    Write-Host "Delete after inspection: Remove-Item -LiteralPath '$clipboardImagePath' -Force" -ForegroundColor Gray
    exit 0
}

$processScript = Join-Path $PSScriptRoot "2-Process-Image.ps1"
if (-not (Test-Path $processScript)) {
    Write-Host "ERROR: Process script not found: $processScript" -ForegroundColor Red
    Remove-Item $clipboardImagePath -Force -ErrorAction SilentlyContinue
    exit 1
}

$importParams = @{
    ImagePath = $clipboardImagePath
    DestinationSkill = $DestinationSkill
    Tags = $Tags
    SuggestedFilename = "clipboard-$timestamp"
    Source = "Clipboard"
    SourceLibrary = "Windows Clipboard"
}

if ($AutoDescription) {
    $importParams["AutoDescription"] = $true
} elseif ($CustomDescription) {
    $importParams["CustomDescription"] = $CustomDescription
}

& $processScript @importParams
$processExitCode = $LASTEXITCODE
Remove-Item $clipboardImagePath -Force -ErrorAction SilentlyContinue
exit $processExitCode
