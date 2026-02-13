#Requires -Version 7.0

<#
.SYNOPSIS
    Gets Dow Jones and S&P 500 market data from Yahoo Finance.

.DESCRIPTION
    Retrieves the latest closing prices, daily change, and percent change for
    the Dow Jones Industrial Average (^DJI) and S&P 500 (^GSPC) using the
    Yahoo Finance chart API. Returns actual index values, not ETF proxies.
    Outputs a formatted text file to the diary output folder for caching.

.EXAMPLE
    Get-DailyFinancialNumbers

.NOTES
    Uses Yahoo Finance v8 chart API which supports index symbols directly.
    No API key required.
    Weekends/holidays will return the most recent trading day's data;
    the script notes when data isn't from today.
#>
[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path $scriptDir "..\output"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$today = Get-Date -Format "yyyy-MM-dd"
$outputFile = Join-Path $outputDir "$today-daily-financial-numbers.txt"

# Use actual index symbols via Yahoo Finance chart API
$symbols = @(
    @{ Ticker = "%5EDJI"; Name = "Dow Jones" }
    @{ Ticker = "%5EGSPC"; Name = "S&P 500" }
)

$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
}

$results = @()
$tradingDay = $null

foreach ($sym in $symbols) {
    $url = "https://query1.finance.yahoo.com/v8/finance/chart/$($sym.Ticker)?interval=1d&range=5d"

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $chart = $response.chart.result[0]
        $meta = $chart.meta
        $quotes = $chart.indicators.quote[0]

        if (-not $meta -or -not $meta.regularMarketPrice) {
            Write-Warning "No data returned for $($sym.Name)"
            $results += "$($sym.Name): unavailable"
            continue
        }

        $currentPrice = [decimal]$meta.regularMarketPrice

        # Get previous trading day's close for change calculation
        $closes = $quotes.close
        $timestamps = $chart.timestamp

        # Find most recent complete trading day close (second-to-last entry)
        $prevClose = $null
        if ($closes.Count -ge 2) {
            $prevClose = [decimal]$closes[$closes.Count - 2]
        }

        # Determine trading day from the last timestamp
        if ($timestamps -and $timestamps.Count -gt 0) {
            $lastTimestamp = $timestamps[$timestamps.Count - 1]
            $tradingDate = [DateTimeOffset]::FromUnixTimeSeconds($lastTimestamp).DateTime.ToString("yyyy-MM-dd")
            if (-not $tradingDay) {
                $tradingDay = $tradingDate
            }
        }

        # Format price with commas and 2 decimal places
        $priceFormatted = $currentPrice.ToString("N2")

        if ($prevClose -and $prevClose -gt 0) {
            $change = $currentPrice - $prevClose
            $changePct = ($change / $prevClose) * 100

            # Format change with sign
            $changeSign = if ($change -ge 0) { "+" } else { "" }
            $changeFormatted = "$changeSign$($change.ToString("N2"))"

            # Format percent with sign
            $pctSign = if ($changePct -ge 0) { "+" } else { "" }
            $pctFormatted = "$pctSign$([math]::Round($changePct, 2).ToString("N2"))%"

            $results += "$($sym.Name): $priceFormatted ($changeFormatted, $pctFormatted)"
        }
        else {
            $results += "$($sym.Name): $priceFormatted"
        }
    }
    catch {
        Write-Error "Failed to fetch $($sym.Name): $_"
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
