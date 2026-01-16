# Search-Confluence.ps1
param(
    [Parameter(Mandatory)]
    [string]$Query,
    [string]$SpaceKey,
    [string]$Type,
    [string]$Title,
    [int]$Year,
    [int]$Limit = 50,
    [switch]$CountOnly
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
$cqlParts = @()
if ($Query) { $cqlParts += "text ~ `"$Query`"" }
if ($SpaceKey) { $cqlParts += "space = $SpaceKey" }
if ($Type) { $cqlParts += "type = $Type" }
if ($Title) { $cqlParts += "title ~ `"$Title`"" }

$cql = $cqlParts -join " AND "
$encodedCql = [System.Web.HttpUtility]::UrlEncode($cql)
$response = Invoke-RestMethod -Uri "$baseUrl/rest/api/content/search?cql=$encodedCql&limit=$Limit&expand=space,version,history" -Headers $headers

$results = $response.results | ForEach-Object {
    $updated = [DateTime]::Parse($_.version.when)
    [PSCustomObject]@{
        ID      = $_.id
        Title   = $_.title
        Type    = $_.type
        Space   = $_.space.name
        Year    = $updated.Year
        Updated = $updated.ToString("yyyy-MM-dd")
        URL     = "$baseUrl$($_._links.webui)"
    }
}

# Filter by year if specified
if ($Year) {
    $results = $results | Where-Object { $_.Year -eq $Year }
}

# Output results
Write-Host "`nFound $($response.size) total results" -ForegroundColor Cyan
if ($Year) {
    Write-Host "Filtered to year $Year`: $($results.Count) results" -ForegroundColor Yellow
}

if ($CountOnly) {
    Write-Host "`nCount: $($results.Count)" -ForegroundColor Green
} else {
    $results | Format-Table -AutoSize
}

# Return count for scripting
return $results.Count
