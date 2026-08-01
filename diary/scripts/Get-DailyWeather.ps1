# Get-DailyWeather.ps1 - Generates daily weather report for diary integration
# Usage: .\Get-DailyWeather.ps1 [-Location "28117"]

param(
    [string]$Location = "28117"
)

# Get current timestamp
$now = Get-Date
$date = $now.ToString("yyyy-MM-dd")
$weekday = $now.ToString("dddd")
$time = $now.ToString("h:mm tt")
$timezone = [System.TimeZoneInfo]::Local.StandardName -replace '\s*Standard\s*Time', '' -replace '\s*Daylight\s*Time', ''

# Initialize output
$output = @()

# Get weather data from today skill script
try {
    $todayScript = "$env:USERPROFILE\.agents\skills\today\scripts\Get-Today.ps1"
    if (Test-Path $todayScript) {
        $rawOutput = & $todayScript -Location $Location 2>&1 | Out-String
        
        # Extract the weather section (everything between location header and news)
        if ($rawOutput -match '(?s)(###\s*📍.*?)(---\s*\*News gathered|$)') {
            $weatherSection = $matches[1].Trim()
            $output += $weatherSection
        } else {
            throw "Could not parse weather data from today skill output"
        }
    } else {
        throw "Today skill script not found at: $todayScript"
    }
} catch {
    Write-Error "Failed to get weather data: $_"
    
    # Fallback output
    $output += "### 📍 Mooresville, US"
    $output += ""
    $output += "| 📅 Date | 📆 Day | 🕐 Time |"
    $output += "|---------|--------|---------|"
    $output += "| $date | $weekday | $time $timezone |"
    $output += ""
    $output += "### Current Weather"
    $output += ""
    $output += "⚠️ **Weather data unavailable** - Check manually or retry"
    $output += ""
}

# Save to output file
$outputDir = "$PSScriptRoot\..\output"
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$outputFile = Join-Path $outputDir "$date.json"
$payload = [pscustomobject]@{
    Date        = $date
    GeneratedAt = (Get-Date).ToString('o')
    Location    = $Location
    Report      = $output
}
$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $outputFile -Encoding UTF8

# Output to console
$output | ForEach-Object { Write-Output $_ }

Write-Information "Saved to: $outputFile" -InformationAction Continue
