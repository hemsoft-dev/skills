<#
.SYNOPSIS
    Get current weather by US zip code using OpenWeather API.

.DESCRIPTION
    Retrieves current weather conditions for a US zip code using the OpenWeather API.
    Requires OPENWEATHER_API_KEY environment variable to be set.

.PARAMETER ZipCode
    US zip code (e.g., "28117", "28202", "10001")

.PARAMETER Units
    Temperature units: imperial (Fahrenheit), metric (Celsius), or standard (Kelvin). Default: imperial

.EXAMPLE
    Get-OpenWeatherByZip -ZipCode "28117"

.EXAMPLE
    Get-OpenWeatherByZip -ZipCode "28202" -Units imperial
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^\d{5}(-\d{4})?$")]
    [string]$ZipCode,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("imperial", "metric", "standard")]
    [string]$Units = "imperial"
)

$ErrorActionPreference = "Stop"

# Get API key from environment variable
$apiKey = $env:OPENWEATHER_API_KEY
if (-not $apiKey) {
    Write-Error "OPENWEATHER_API_KEY environment variable is not set."
    exit 1
}

# Format zip code for API (remove dash if present, add ",us")
$zipFormatted = $ZipCode -replace "-", ""
$zipQuery = "$zipFormatted,us"

# Build API URL
$baseUrl = "https://api.openweathermap.org/data/2.5/weather"
$url = "$baseUrl`?zip=$zipQuery&appid=$apiKey&units=$Units"

try {
    Write-Information "Fetching weather for zip code $ZipCode..." -InformationAction Continue
    
    # Make API request
    $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
    
    # Extract and format data
    $tempUnit = if ($Units -eq "imperial") { "°F" } elseif ($Units -eq "metric") { "°C" } else { "K" }
    $speedUnit = if ($Units -eq "imperial") { "mph" } elseif ($Units -eq "metric") { "m/s" } else { "m/s" }
    
    # Format output
    $output = @{
        Location = "$($response.name), $($response.sys.country)"
        ZipCode = $ZipCode
        Coordinates = "$($response.coord.lat), $($response.coord.lon)"
        Temperature = "$([math]::Round($response.main.temp, 1))$tempUnit"
        FeelsLike = "$([math]::Round($response.main.feels_like, 1))$tempUnit"
        Condition = $response.weather[0].main
        Description = $response.weather[0].description
        Humidity = "$($response.main.humidity)%"
        Pressure = "$($response.main.pressure) hPa"
        WindSpeed = "$([math]::Round($response.wind.speed, 1)) $speedUnit"
        WindDirection = if ($response.wind.deg) { "$($response.wind.deg)°" } else { "N/A" }
        Visibility = if ($response.visibility) { "$([math]::Round($response.visibility / 1000, 1)) km" } else { "N/A" }
        CloudCover = "$($response.clouds.all)%"
        Sunrise = (Get-Date -Date "1970-01-01 00:00:00").AddSeconds($response.sys.sunrise).ToLocalTime().ToString("HH:mm")
        Sunset = (Get-Date -Date "1970-01-01 00:00:00").AddSeconds($response.sys.sunset).ToLocalTime().ToString("HH:mm")
        Timestamp = (Get-Date -Date "1970-01-01 00:00:00").AddSeconds($response.dt).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Display formatted output
    Write-Output ""
    Write-Output "Current Weather - $($output.Location) (Zip: $($output.ZipCode))"
    Write-Output ("=" * 50)
    Write-Output "Temperature: $($output.Temperature) (Feels like: $($output.FeelsLike))"
    Write-Output "Condition: $($output.Condition) - $($output.Description)"
    Write-Output "Humidity: $($output.Humidity)"
    Write-Output "Pressure: $($output.Pressure)"
    Write-Output "Wind: $($output.WindSpeed) from $($output.WindDirection)"
    Write-Output "Visibility: $($output.Visibility)"
    Write-Output "Cloud Cover: $($output.CloudCover)"
    Write-Output "Sunrise: $($output.Sunrise)"
    Write-Output "Sunset: $($output.Sunset)"
    Write-Output "Data Timestamp: $($output.Timestamp)"
    Write-Output ""
    
    # Return object for programmatic use
    return $output
    
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Error "Zip code not found: $ZipCode"
    } elseif ($_.Exception.Response.StatusCode -eq 401) {
        Write-Error "Invalid API key. Please check your OPENWEATHER_API_KEY environment variable."
    } else {
        Write-Error "Error fetching weather data: $($_.Exception.Message)"
    }
    exit 1
}
