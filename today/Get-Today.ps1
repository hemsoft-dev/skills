# Get-Today.ps1 - Fetches current date/time and weather for the today skill
# Usage: .\Get-Today.ps1 [-Location "28117"]

param(
    [string]$Location = "28117,us"
)

# Ensure API key is available
$apiKey = $env:OPENWEATHER_API_KEY
if (-not $apiKey) {
    Write-Error "OPENWEATHER_API_KEY environment variable not set"
    exit 1
}

# Get current date/time from system
$now = Get-Date
$date = $now.ToString("yyyy-MM-dd")
$weekday = $now.ToString("dddd")
$time = $now.ToString("h:mm tt")
$timezone = [System.TimeZoneInfo]::Local.StandardName -replace '\s*Standard\s*Time', '' -replace '\s*Daylight\s*Time', ''

# Determine if location is ZIP code or city name
if ($Location -match '^\d{5}') {
    $locationParam = "zip=$Location"
} else {
    $locationParam = "q=$Location"
}

# Fetch current weather
try {
    $currentUrl = "https://api.openweathermap.org/data/2.5/weather?$locationParam&appid=$apiKey&units=imperial"
    $current = Invoke-RestMethod -Uri $currentUrl -ErrorAction Stop
} catch {
    Write-Error "Failed to fetch current weather: $_"
    exit 1
}

# Fetch forecast
try {
    $forecastUrl = "https://api.openweathermap.org/data/2.5/forecast?$locationParam&appid=$apiKey&units=imperial&cnt=40"
    $forecast = Invoke-RestMethod -Uri $forecastUrl -ErrorAction Stop
} catch {
    Write-Error "Failed to fetch forecast: $_"
    exit 1
}

# Weather icon mapping
function Get-WeatherIcon {
    param([string]$condition)
    switch -Regex ($condition.ToLower()) {
        'clear'         { return '☀️' }
        'few clouds'    { return '🌤️' }
        'scattered'     { return '⛅' }
        'broken|overcast' { return '☁️' }
        'rain|drizzle'  { return '🌧️' }
        'thunderstorm'  { return '⛈️' }
        'snow'          { return '🌨️' }
        'mist|fog|haze' { return '🌫️' }
        default         { return '🌡️' }
    }
}

# Extract city name
$cityName = $current.name
$country = $current.sys.country

# Current conditions
$currentTemp = [math]::Round($current.main.temp)
$currentCondition = $current.weather[0].description
$currentIcon = Get-WeatherIcon -condition $currentCondition -icon $current.weather[0].icon
$currentWind = [math]::Round($current.wind.speed)
$feelsLike = [math]::Round($current.main.feels_like)
$humidity = $current.main.humidity

# Process forecast - group by day and extract daily highs/lows
$dailyForecast = @{}
foreach ($item in $forecast.list) {
    $itemDate = [DateTimeOffset]::FromUnixTimeSeconds($item.dt).LocalDateTime.Date
    $dayKey = $itemDate.ToString("yyyy-MM-dd")
    
    if (-not $dailyForecast.ContainsKey($dayKey)) {
        $dailyForecast[$dayKey] = @{
            Date = $itemDate
            DayName = $itemDate.ToString("dddd")
            Temps = @()
            Conditions = @()
            Winds = @()
            Icons = @()
        }
    }
    
    $dailyForecast[$dayKey].Temps += $item.main.temp
    $dailyForecast[$dayKey].Conditions += $item.weather[0].description
    $dailyForecast[$dayKey].Winds += $item.wind.speed
    $dailyForecast[$dayKey].Icons += $item.weather[0].icon
}

# Build 3-day forecast (skip today if we have enough data, or include today)
$sortedDays = $dailyForecast.Keys | Sort-Object | Select-Object -First 4
$forecastDays = @()

foreach ($dayKey in $sortedDays) {
    $day = $dailyForecast[$dayKey]
    $low = [math]::Round(($day.Temps | Measure-Object -Minimum).Minimum)
    $high = [math]::Round(($day.Temps | Measure-Object -Maximum).Maximum)
    $avgWind = [math]::Round(($day.Winds | Measure-Object -Average).Average)
    
    # Get most common condition
    $conditionGroups = $day.Conditions | Group-Object | Sort-Object Count -Descending
    $mainCondition = $conditionGroups[0].Name
    $icon = Get-WeatherIcon -condition $mainCondition -icon $day.Icons[0]
    
    $isToday = ($day.Date.Date -eq $now.Date)
    $dayLabel = if ($isToday) { "$($day.DayName) (Today)" } else { $day.DayName }
    
    $forecastDays += [PSCustomObject]@{
        DayLabel = $dayLabel
        Icon = $icon
        Condition = (Get-Culture).TextInfo.ToTitleCase($mainCondition)
        Low = $low
        High = $high
        Wind = $avgWind
    }
}

# Take only 3 days for forecast
$forecastDays = $forecastDays | Select-Object -First 3

# Output as structured object for easy consumption
$output = [PSCustomObject]@{
    # Header
    Date = $date
    Weekday = $weekday
    Time = $time
    Timezone = $timezone
    
    # Location
    City = $cityName
    Country = $country
    
    # Current
    CurrentTemp = $currentTemp
    CurrentCondition = (Get-Culture).TextInfo.ToTitleCase($currentCondition)
    CurrentIcon = $currentIcon
    CurrentWind = $currentWind
    FeelsLike = $feelsLike
    Humidity = $humidity
    
    # Forecast
    Forecast = $forecastDays
}

# Output as JSON for easy parsing, or formatted tables
if ($env:TODAY_OUTPUT -eq 'json') {
    $output | ConvertTo-Json -Depth 5
} else {
    # Formatted markdown output
    Write-Output ""
    Write-Output "### 📍 $cityName, $country"
    Write-Output ""
    Write-Output "| 📅 Date | 📆 Day | 🕐 Time |"
    Write-Output "|---------|--------|---------|"
    Write-Output "| $date | $weekday | $time $timezone |"
    Write-Output ""
    Write-Output "### Current Weather"
    Write-Output ""
    Write-Output "| 🌡️ Temp | 🤔 Feels Like | $currentIcon Condition | 💨 Wind | 💧 Humidity |"
    Write-Output "|---------|---------------|-------------|---------|-------------|"
    Write-Output "| $currentTemp°F | $feelsLike°F | $($output.CurrentCondition) | $currentWind mph | $humidity% |"
    Write-Output ""
    Write-Output "### 3-Day Forecast"
    Write-Output ""
    Write-Output "| Day | Icon | Condition | Low | High | Wind |"
    Write-Output "|-----|------|-----------|-----|------|------|"
    foreach ($day in $forecastDays) {
        Write-Output "| $($day.DayLabel) | $($day.Icon) | $($day.Condition) | $($day.Low)°F | $($day.High)°F | $($day.Wind) mph |"
    }
    Write-Output ""
}
