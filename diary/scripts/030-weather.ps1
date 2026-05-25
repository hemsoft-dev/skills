#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the Weather section of a diary entry using OpenWeather API.

.DESCRIPTION
    Fetches current weather and 3-day forecast for Mooresville, NC (zip 28117)
    using the OpenWeather API, formats it as markdown tables, and injects into
    the diary entry. Requires OPENWEATHER_API_KEY environment variable.

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\030-weather.ps1 -Date 2026-02-28 -EntryPath ..\entries\2026-02-28.html
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

. (Join-Path $PSScriptRoot 'HtmlDiaryHelpers.ps1')

# --- Configuration ---
$ZipCode = '28117'
$Units = 'imperial'
$TempUnit = '°F'
$SpeedUnit = 'mph'

# --- Resolve entry path ---
if (-not $EntryPath) {
    $EntryPath = Get-DiaryHtmlEntryPath -ScriptRoot $PSScriptRoot -Date $Date
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

# --- Validate API key ---
$apiKey = Get-DiaryEnvironmentVariable -Name 'OPENWEATHER_API_KEY'
if (-not $apiKey) {
    Write-Error "OPENWEATHER_API_KEY environment variable is not set."
    exit 1
}

# --- Weather condition to emoji mapping ---
function Get-WeatherIcon {
    param([string]$Condition)
    switch -Wildcard ($Condition.ToLower()) {
        '*thunderstorm*' { return '⛈️' }
        '*drizzle*'      { return '🌦️' }
        '*rain*'         { return '🌧️' }
        '*snow*'         { return '🌨️' }
        '*mist*'         { return '🌫️' }
        '*fog*'          { return '🌫️' }
        '*haze*'         { return '🌫️' }
        '*clear*'        { return '☀️' }
        '*few clouds*'   { return '🌤️' }
        '*scattered*'    { return '⛅' }
        '*broken*'       { return '🌥️' }
        '*overcast*'     { return '☁️' }
        default          { return '🌡️' }
    }
}

# --- Fetch current weather ---
Write-Information "`e[1;36mFetching current weather for zip $ZipCode...`e[0m"

$currentUrl = "https://api.openweathermap.org/data/2.5/weather?zip=$ZipCode,us&appid=$apiKey&units=$Units"
try {
    $current = Invoke-RestMethod -Uri $currentUrl -Method Get -ErrorAction Stop
}
catch {
    Write-Information "`e[1;31mFailed to fetch current weather: $_`e[0m"
    return
}

# --- Fetch 5-day/3-hour forecast ---
Write-Information "`e[1;36mFetching forecast...`e[0m"

$forecastUrl = "https://api.openweathermap.org/data/2.5/forecast?zip=$ZipCode,us&appid=$apiKey&units=$Units"
try {
    $forecast = Invoke-RestMethod -Uri $forecastUrl -Method Get -ErrorAction Stop
}
catch {
    Write-Information "`e[1;31mFailed to fetch forecast: $_`e[0m"
    return
}

# --- Parse current conditions ---
$parsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$weekday = $parsedDate.ToString('dddd')
$currentTime = Get-Date -Format 'h:mm tt'
$location = "$($current.name), $($current.sys.country)"

$temp = [math]::Round($current.main.temp)
$feelsLike = [math]::Round($current.main.feels_like)
$condition = (Get-Culture).TextInfo.ToTitleCase($current.weather[0].description)
$wind = [math]::Round($current.wind.speed)
$humidity = $current.main.humidity

# --- Parse 3-day forecast from 5-day/3-hour data ---
# Group forecast entries by date, compute daily low/high/dominant condition
$forecastDays = @()
$forecastByDay = $forecast.list | Group-Object { ($_ | Select-Object -ExpandProperty dt_txt).Substring(0, 10) }

$dayCount = 0
foreach ($dayGroup in $forecastByDay) {
    if ($dayCount -ge 3) { break }

    $dayDateStr = $dayGroup.Name
    $dayDate = [datetime]::ParseExact($dayDateStr, 'yyyy-MM-dd', $null)

    $temps = $dayGroup.Group | ForEach-Object { $_.main.temp }
    $low = [math]::Round(($temps | Measure-Object -Minimum).Minimum)
    $high = [math]::Round(($temps | Measure-Object -Maximum).Maximum)

    # Dominant condition: most frequent weather description across the day
    $conditions = $dayGroup.Group | ForEach-Object { $_.weather[0].description }
    $dominant = ($conditions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
    $dominantTitle = (Get-Culture).TextInfo.ToTitleCase($dominant)

    # Max wind speed for the day
    $winds = $dayGroup.Group | ForEach-Object { $_.wind.speed }
    $maxWind = [math]::Round(($winds | Measure-Object -Maximum).Maximum)

    $dayLabel = if ($dayDate.Date -eq $parsedDate.Date) {
        "$($dayDate.ToString('dddd')) (Today)"
    } else {
        $dayDate.ToString('dddd')
    }

    $icon = Get-WeatherIcon $dominant

    $forecastDays += [PSCustomObject]@{
        Label     = $dayLabel
        Icon      = $icon
        Condition = $dominantTitle
        Low       = $low
        High      = $high
        Wind      = $maxWind
    }

    $dayCount++
}

# --- Build markdown ---
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("### 📍 $location")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| 📅 Date | 📆 Day | 🕐 Time |")
[void]$sb.AppendLine("|---------|--------|---------|")
[void]$sb.AppendLine("| $Date | $weekday | $currentTime Eastern |")
[void]$sb.AppendLine()
[void]$sb.AppendLine("### Current Weather")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| 🌡️ Temp | 🤔 Feels Like | ☁️ Condition | 💨 Wind | 💧 Humidity |")
[void]$sb.AppendLine("|---------|---------------|-------------|---------|-------------|")
[void]$sb.AppendLine("| $temp$TempUnit | $feelsLike$TempUnit | $condition | $wind $SpeedUnit | $humidity% |")
[void]$sb.AppendLine()
[void]$sb.AppendLine("### 3-Day Forecast")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| Day | Icon | Condition | Low | High | Wind |")
[void]$sb.AppendLine("|-----|------|-----------|-----|------|------|")
foreach ($day in $forecastDays) {
    [void]$sb.AppendLine("| $($day.Label) | $($day.Icon) | $($day.Condition) | $($day.Low)$TempUnit | $($day.High)$TempUnit | $($day.Wind) $SpeedUnit |")
}

$weatherContent = $sb.ToString().TrimEnd()

$sectionHtml = ConvertTo-DiaryHtmlCard -Markdown $weatherContent -Eyebrow "OpenWeather snapshot for $Date"
Set-DiarySectionInnerHtml -EntryPath $EntryPath -SectionTitle '🌤 Weather' -InnerHtml $sectionHtml
Write-Information "`e[1;32mWeather section injected into diary entry.`e[0m"
Write-Information "  Location: $location | Temp: $temp$TempUnit | Condition: $condition"
