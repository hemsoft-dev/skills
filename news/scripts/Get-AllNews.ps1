# Get-AllNews.ps1 - Fetches all news categories (US, World, AI, Danish)
# Usage: .\Get-AllNews.ps1 [-Count 7] [-HoursBack 24]

param(
    [int]$Count = 7,
    [int]$HoursBack = 24
)

$date = Get-Date -Format "yyyy-MM-dd"

# Clear any existing output file for today
$outputFile = "$PSScriptRoot\..\output\$date.md"
if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
    Write-Information "Cleared existing output file for $date" -InformationAction Continue
}

Write-Information "Fetching all news categories for $date..." -InformationAction Continue
Write-Information "" -InformationAction Continue

# Fetch US News
Write-Host "Fetching US News..." -ForegroundColor Cyan
& "$PSScriptRoot\Get-USNews.ps1" -Count $Count -HoursBack $HoursBack

# Fetch World News
Write-Host "Fetching World News..." -ForegroundColor Cyan
& "$PSScriptRoot\Get-WorldNews.ps1" -Count $Count -HoursBack $HoursBack

# Fetch AI News
Write-Host "Fetching AI News..." -ForegroundColor Cyan
& "$PSScriptRoot\Get-AINews.ps1" -Count $Count -HoursBack $HoursBack

# Fetch Danish News
Write-Host "Fetching Danish News..." -ForegroundColor Cyan
& "$PSScriptRoot\Get-DanishNews.ps1" -Count $Count -HoursBack $HoursBack

Write-Information "" -InformationAction Continue
Write-Information "All news categories fetched and saved to: $outputFile" -InformationAction Continue

# Display the output
if (Test-Path $outputFile) {
    Write-Information "" -InformationAction Continue
    Write-Information "=== PREVIEW ===" -InformationAction Continue
    Get-Content $outputFile | Select-Object -First 20
    Write-Information "..." -InformationAction Continue
    Write-Information "(Full output in $outputFile)" -InformationAction Continue
}
