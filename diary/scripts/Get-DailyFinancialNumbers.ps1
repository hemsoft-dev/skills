#Requires -Version 7.0

<#
.SYNOPSIS
    Gets Dow Jones and S&P 500 market data from Alpha Vantage API.

.DESCRIPTION
    Retrieves the latest closing prices, daily change, and percent change for
    the Dow Jones Industrial Average and S&P 500 using their ETF proxies
    (DIA and SPY) via the Alpha Vantage GLOBAL_QUOTE endpoint. Alpha Vantage
    only supports equities/ETFs, not raw index symbols.
    Outputs a formatted text file to the diary output folder for caching.

    Requires the ALPHA_VANTAGE_API_KEY environment variable to be set.

.PARAMETER ApiKey
    Alpha Vantage API key. Defaults to $env:ALPHA_VANTAGE_API_KEY.

.EXAMPLE
    Get-DailyFinancialNumbers

.EXAMPLE
    Get-DailyFinancialNumbers -ApiKey "your-api-key"

.NOTES
    Alpha Vantage free tier allows 25 requests/day — this script uses 2.
    Weekends/holidays will return the most recent trading day's data;
    the script notes when data isn't from today.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiKey
)

if (-not $ApiKey) {
    $ApiKey = $env:ALPHA_VANTAGE_API_KEY
}

# Fall back to Machine-level environment variable if not in process scope
if (-not $ApiKey) {
    $ApiKey = [System.Environment]::GetEnvironmentVariable("ALPHA_VANTAGE_API_KEY", "Machine")
}

if (-not $ApiKey) {
    Write-Error "ALPHA_VANTAGE_API_KEY environment variable is not set. Get a free key at https://www.alphavantage.co/support/#api-key"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path $scriptDir "..\output"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$today = Get-Date -Format "yyyy-MM-dd"
$outputFile = Join-Path $outputDir "$today-daily-financial-numbers.txt"

# Alpha Vantage GLOBAL_QUOTE only supports equities/ETFs, not index symbols.
# Use ETF proxies: DIA tracks Dow Jones, SPY tracks S&P 500.
$symbols = @(
    @{ Ticker = "DIA"; Name = "Dow Jones (DIA)" }
    @{ Ticker = "SPY"; Name = "S&P 500 (SPY)" }
)

$results = @()
$tradingDay = $null
$isFirstRequest = $true

foreach ($sym in $symbols) {
    # Alpha Vantage free tier: max 1 request per second — wait between calls
    if (-not $isFirstRequest) {
        Start-Sleep -Seconds 2
    }
    $isFirstRequest = $false

    $url = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$($sym.Ticker)&apikey=$ApiKey"

    try {
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop
        $quote = $response.'Global Quote'

        # If rate-limited, wait and retry once
        if ((-not $quote -or -not $quote.'05. price') -and ($response.Information -or $response.Note)) {
            Write-Information "Rate limited on $($sym.Ticker), retrying in 3 seconds..." -InformationAction Continue
            Start-Sleep -Seconds 3
            $response = Invoke-RestMethod -Uri $url -ErrorAction Stop
            $quote = $response.'Global Quote'
        }

        if (-not $quote -or -not $quote.'05. price') {
            # Alpha Vantage may return a note about rate limiting
            if ($response.Note) {
                Write-Warning "Alpha Vantage rate limit hit: $($response.Note)"
            }
            elseif ($response.Information) {
                Write-Warning "Alpha Vantage: $($response.Information)"
            }
            else {
                Write-Warning "No data returned for $($sym.Ticker)"
            }
            $results += "$($sym.Name): unavailable"
            continue
        }

        $price = [decimal]$quote.'05. price'
        $change = [decimal]$quote.'09. change'
        $changePct = $quote.'10. change percent' -replace '%', ''
        $changePct = [decimal]$changePct
        $latestDay = $quote.'07. latest trading day'

        if (-not $tradingDay) {
            $tradingDay = $latestDay
        }

        # Format price with commas and 2 decimal places
        $priceFormatted = $price.ToString("N2")

        # Format change with sign
        $changeSign = if ($change -ge 0) { "+" } else { "" }
        $changeFormatted = "$changeSign$($change.ToString("N2"))"

        # Format percent with sign
        $pctSign = if ($changePct -ge 0) { "+" } else { "" }
        $pctFormatted = "$pctSign$($changePct.ToString("N2"))%"

        $results += "$($sym.Name): $priceFormatted ($changeFormatted, $pctFormatted)"
    }
    catch {
        Write-Error "Failed to fetch $($sym.Ticker): $_"
        $results += "$($sym.Name): error"
    }
}

# Build output
$outputLines = @()

# Note if data is not from today (weekend/holiday)
if ($tradingDay -and $tradingDay -ne $today) {
    $outputLines += "Trading day: $tradingDay"
}

$outputLines += $results

$output = $outputLines -join "`n"

# Save to output file
$output | Set-Content $outputFile -Encoding UTF8
Write-Information "Output saved to: $outputFile" -InformationAction Continue

# Output to stdout
Write-Output $output
