<#
.SYNOPSIS
    Gets Cloudflare usage statistics for managed domains.
.DESCRIPTION
    Queries Cloudflare GraphQL Analytics API for page views, unique visitors,
    and email routing stats. Returns markdown-formatted output.
.PARAMETER Date
    The date to query (YYYY-MM-DD). Defaults to yesterday.
#>
param(
    [string]$Date = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
)

$token = [System.Environment]::GetEnvironmentVariable('CLOUDFLARE_API_TOKEN', 'Machine')
if (-not $token) {
    $token = $env:CLOUDFLARE_API_TOKEN
}
if (-not $token) {
    Write-Error "CLOUDFLARE_API_TOKEN not found. Set it as a system-level environment variable."
    return
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

$nextDate = ([datetime]::ParseExact($Date, "yyyy-MM-dd", $null)).AddDays(1).ToString("yyyy-MM-dd")

# Domain configuration
$domains = @(
    @{ Name = "nowleadershipgroup.com"; ZoneId = "23882174cdf6c55620b0c186e4e3aaf2"; Email = $true }
    @{ Name = "setitfreeloop.org";      ZoneId = "c4fb19a03acf1631cc846cea7b6040b0"; Email = $false }
)

$results = @()

foreach ($domain in $domains) {
    $zoneId = $domain.ZoneId

    # Web analytics query
    $webQuery = "{ viewer { zones(filter: {zoneTag: `"$zoneId`"}) { httpRequests1dGroups(limit: 1, filter: {date_geq: `"$Date`", date_lt: `"$nextDate`"}) { sum { requests pageViews } uniq { uniques } } } } }"
    $webBody = (@{ query = $webQuery } | ConvertTo-Json -Compress)

    try {
        $webResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/graphql" -Headers $headers -Method Post -Body $webBody
        $webData = $webResponse.data.viewer.zones[0].httpRequests1dGroups
        if ($webData -and $webData.Count -gt 0) {
            $pageViews = $webData[0].sum.pageViews
            $uniques = $webData[0].uniq.uniques
        }
        else {
            $pageViews = 0
            $uniques = 0
        }
    }
    catch {
        Write-Warning "Failed to get web analytics for $($domain.Name): $_"
        $pageViews = 0
        $uniques = 0
    }

    # Email routing query (nowleadershipgroup.com only)
    $forwarded = 0
    $dropped = 0
    if ($domain.Email) {
        $emailQuery = "{ viewer { zones(filter: {zoneTag: `"$zoneId`"}) { emailRoutingAdaptiveGroups(limit: 10, filter: {date_geq: `"$Date`", date_lt: `"$nextDate`"}) { count dimensions { action } } } } }"
        $emailBody = (@{ query = $emailQuery } | ConvertTo-Json -Compress)

        try {
            $emailResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/graphql" -Headers $headers -Method Post -Body $emailBody
            $emailData = $emailResponse.data.viewer.zones[0].emailRoutingAdaptiveGroups
            if ($emailData) {
                foreach ($group in $emailData) {
                    switch ($group.dimensions.action) {
                        "forward" { $forwarded += $group.count }
                        "drop"    { $dropped += $group.count }
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to get email stats for $($domain.Name): $_"
        }
    }

    # Build result line
    $line = "- **$($domain.Name)**: $pageViews page views, $uniques unique visitors"
    if ($domain.Email) {
        $line += ", $forwarded emails forwarded"
        if ($dropped -gt 0) {
            $line += ", $dropped dropped"
        }
    }
    $results += $line
}

# Output
Write-Information "📊 Cloudflare Usage ($Date)" 6>&1
$results | ForEach-Object { Write-Information $_ 6>&1 }
