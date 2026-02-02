# Search-Confluence.ps1
param(
    [Parameter(Mandatory)]
    [string]$Query,
    [string]$SpaceKey,
    [string]$Type,
    [string]$Title,
    [int]$Year,
    [int]$Limit = 50,
    [switch]$CountOnly,
    [switch]$RawCql
)

Add-Type -AssemblyName System.Web

$baseUrl = "https://relias.atlassian.net/wiki"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

# Build CQL query
# - If caller provides explicit CQL (contains operators or quotes) treat it as raw CQL.
# - Otherwise wrap the Query safely as `text ~ "..."`.
# - Support -RawCql switch for explicit raw CQL usage.

if (-not $PSBoundParameters.ContainsKey('RawCql')) {
    # Heuristic: if Query looks like CQL (contains AND/OR/=/~/() or quotes), treat as raw
    if ($Query -and ($Query -match '\b(AND|OR)\b' -or $Query -match '[=~\(\)]' -or $Query -match '"')) {
        $assumeRaw = $true
    } else {
        $assumeRaw = $false
    }
} else {
    $assumeRaw = $RawCql.IsPresent
}

$cqlParts = @()
if ($Query) {
    if ($assumeRaw) {
        # caller supplied CQL-like expression; use as-is
        $cqlParts += $Query
    } else {
        # escape any double-quotes inside the phrase and wrap safely
        $escaped = $Query -replace '"', '""'
        $cqlParts += "text ~ `"$escaped`""
    }
}
if ($SpaceKey) { $cqlParts += "space = $SpaceKey" }
if ($Type) { $cqlParts += "type = $Type" }
if ($Title) {
    $titleEsc = $Title -replace '"', '""'
    $cqlParts += "title ~ `"$titleEsc`""
}

$cql = $cqlParts -join ' AND '
if (-not $cql -or $cql.Trim().Length -eq 0) {
    Write-Error "No query specified after CQL construction. Provide -Query or -RawCql with a valid clause."
    return 0
}

# Call API with robust error handling
$encodedCql = [System.Web.HttpUtility]::UrlEncode($cql)
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/rest/api/content/search?cql=$encodedCql&limit=$Limit&expand=space,version,history" -Headers $headers -Method Get -ErrorAction Stop
} catch {
    # Try to extract a helpful message from the response body when available
    $err = $_.Exception
    $msg = $err.Message
    if ($err.Response) {
        try {
            $body = [System.IO.StreamReader]::new($err.Response.GetResponseStream()).ReadToEnd()
            $msgDetail = ($body | ConvertFrom-Json -ErrorAction SilentlyContinue)
            if ($msgDetail -and $msgDetail.message) { $msg = "$($msg): $($msgDetail.message)" }
        } catch { }
    }
    Write-Error "Confluence API error: $msg"
    return 0
}

# Safely project results (tolerant of missing version.when)
$results = @()
if ($response.results) {
    foreach ($r in $response.results) {
        $updated = $null
        if ($r.version -and $r.version.when) {
            try { $updated = [DateTime]::Parse($r.version.when) } catch { $updated = $null }
        }

        $results += [PSCustomObject]@{
            ID      = $r.id
            Title   = $r.title
            Type    = $r.type
            Space   = ($r.space.name -as [string])
            Year    = if ($updated) { $updated.Year } else { $null }
            Updated = if ($updated) { $updated.ToString('yyyy-MM-dd') } else { '' }
            URL     = "$baseUrl$($r._links.webui)"
        }
    }
}

# Filter by year if specified
if ($Year) {
    $results = $results | Where-Object { $_.Year -eq $Year }
}

# Output results
$foundTotal = if ($response.size) { $response.size } elseif ($response.total) { $response.total } else { $results.Count }
Write-Host "`nFound $foundTotal total results (CQL: $cql)" -ForegroundColor Cyan
if ($Year) {
    Write-Host "Filtered to year $Year`: $($results.Count) results" -ForegroundColor Yellow
}

if ($CountOnly) {
    Write-Host "`nCount: $($results.Count)" -ForegroundColor Green
} else {
    if ($results.Count -eq 0) { Write-Host "(no results returned)" -ForegroundColor DarkYellow }
    $results | Format-Table -AutoSize
}

# Return count for scripting
return $results.Count
