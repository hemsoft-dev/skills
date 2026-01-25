---
name: openweather
description: V1.0 - Get current weather conditions using OpenWeather API by US city name or zip code. Provides temperature, conditions, humidity, wind, visibility, and other weather metrics. Requires OPENWEATHER_API_KEY environment variable.
compatibility: Requires OPENWEATHER_API_KEY environment variable and PowerShell with Invoke-RestMethod
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the openweather directory (path contains 'openweather'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if openweather was used (check if any files in openweather directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in openweather directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# OpenWeather API Integration

Get current weather conditions using the OpenWeather API for US cities or zip codes.

## Prerequisites

- **OPENWEATHER_API_KEY** environment variable must be set
- PowerShell with `Invoke-RestMethod` cmdlet

## Available Scripts

Scripts are located in the `scripts/` subfolder:

### Get-OpenWeatherByCity.ps1

Get current weather by US city name.

**Usage:**

```powershell
# Basic usage
.\scripts\Get-OpenWeatherByCity.ps1 -City "Charlotte"

# With state for better accuracy
.\scripts\Get-OpenWeatherByCity.ps1 -City "Charlotte" -State "NC"

# Specify units (imperial/metric/standard)
.\scripts\Get-OpenWeatherByCity.ps1 -City "Mooresville" -Units imperial
```

**Parameters:**

- `-City` (required): City name (e.g., "Charlotte", "New York")
- `-State` (optional): State abbreviation (e.g., "NC", "NY") for better accuracy
- `-Units` (optional): Temperature units - `imperial` (Fahrenheit), `metric` (Celsius), or `standard` (Kelvin). Default: `imperial`

### Get-OpenWeatherByZip.ps1

Get current weather by US zip code.

**Usage:**

```powershell
# Basic usage
.\scripts\Get-OpenWeatherByZip.ps1 -ZipCode "28117"

# Specify units
.\scripts\Get-OpenWeatherByZip.ps1 -ZipCode "28202" -Units imperial
```

**Parameters:**

- `-ZipCode` (required): US zip code (5 digits, optionally with 4-digit extension)
- `-Units` (optional): Temperature units - `imperial` (Fahrenheit), `metric` (Celsius), or `standard` (Kelvin). Default: `imperial`

## API Information

**Endpoint:** `https://api.openweathermap.org/data/2.5/weather`

**Query Methods:**

- By city: `?q={city},{state},us&appid={key}&units={units}`
- By zip: `?zip={zipcode},us&appid={key}&units={units}`

**Response Format:** JSON

**Rate Limits:** Check your OpenWeather API plan for rate limits

## Output

Both scripts return:

- Location (city name and country)
- Temperature (current and feels-like)
- Weather condition and description
- Humidity, pressure, wind speed/direction
- Visibility and cloud cover
- Sunrise/sunset times
- Data timestamp

Output is formatted for display and also returned as a PowerShell object for programmatic use.

## Error Handling

Scripts handle common errors:

- Missing API key
- City/zip code not found (404)
- Invalid API key (401)
- Network errors

## Examples

```powershell
# Get weather for Mooresville, NC
.\scripts\Get-OpenWeatherByCity.ps1 -City "Mooresville" -State "NC"

# Get weather for Charlotte zip code
.\scripts\Get-OpenWeatherByZip.ps1 -ZipCode "28202"

# Get weather in Celsius
.\scripts\Get-OpenWeatherByCity.ps1 -City "Charlotte" -Units metric
```

## When to Use This Skill

Use this skill when:

- User asks for current weather for a US city or zip code
- Need quick weather lookup via API
- Want programmatic access to weather data
- Need weather data for automation or scripts
