# Get-DanishNews.ps1 - Fetches Danish news headlines from RSS feeds
# Usage: .\Get-DanishNews.ps1 [-Count 7] [-HoursBack 24]

param(
    [int]$Count = 7,
    [int]$HoursBack = 24
)

$date = Get-Date -Format "yyyy-MM-dd"
$cutoffTime = (Get-Date).AddHours(-$HoursBack)

# RSS feed sources
$sources = @(
    @{ Name = "The Local"; Url = "https://www.thelocal.dk/feed" }
    @{ Name = "CPH Post"; Url = "https://cphpost.dk/feed/" }
    @{ Name = "Reuters"; Url = "https://www.reutersagency.com/feed/?best-regions=europe&post_type=best" }
    @{ Name = "DR News"; Url = "https://www.dr.dk/nyheder/service/feeds/allenyheder" }
    @{ Name = "Politiken"; Url = "https://politiken.dk/rss/" }
)

# Collect all articles
$allArticles = @()

foreach ($source in $sources) {
    try {
        $feed = Invoke-RestMethod -Uri $source.Url -ErrorAction Stop
        
        foreach ($item in $feed) {
            # Parse pub date
            $pubDate = $null
            if ($item.pubDate) {
                try { $pubDate = [DateTime]::Parse($item.pubDate) } catch { $null }
            }
            if ($item.published) {
                try { $pubDate = [DateTime]::Parse($item.published) } catch { $null }
            }
            
            # Skip if too old or no date
            if (-not $pubDate -or $pubDate -lt $cutoffTime) { continue }
            
            # Handle title parsing
            $title = if ($item.title -is [string]) { $item.title } elseif ($item.title.InnerText) { $item.title.InnerText } else { "Untitled" }
            $link = if ($item.link -is [string]) { $item.link } elseif ($item.link.href) { $item.link.href } else { "" }
            
            if (-not $link) { continue }
            
            # For Reuters, filter to Denmark/Greenland/Nordic keywords
            if ($source.Name -eq "Reuters") {
                if ($title -notmatch "Denmark|Danish|Greenland|Copenhagen|Nordic|Scandinavia") {
                    continue
                }
            }
            
            $allArticles += [PSCustomObject]@{
                Title = $title
                Link = $link
                Source = $source.Name
                PubDate = $pubDate
            }
        }
    } catch {
        Write-Warning "Failed to fetch from $($source.Name): $_"
    }
}

# Sort by date (newest first) and enforce source diversification
$selected = @()
$sourceCounts = @{}

foreach ($article in ($allArticles | Sort-Object PubDate -Descending)) {
    # Enforce max 2 items per source
    if ($sourceCounts[$article.Source] -ge 2) { continue }
    
    $selected += $article
    $current = if ($sourceCounts[$article.Source]) { $sourceCounts[$article.Source] } else { 0 }
    $sourceCounts[$article.Source] = $current + 1
    
    if ($selected.Count -ge $Count) { break }
}

# Ensure minimum source diversity
$uniqueSources = ($selected | Select-Object -Unique Source).Count
if ($uniqueSources -lt 3 -and $allArticles.Count -gt 0) {
    Write-Warning "Only $uniqueSources sources represented. Consider widening search."
}

# Generate output
$output = @()
$output += "### 🇩🇰 Danish News"
$output += "| # | Headline | Source |"
$output += "|---|----------|--------|"

$index = 1
foreach ($article in $selected) {
    $output += "| $index | [$($article.Title)]($($article.Link)) | $($article.Source) |"
    $index++
}

$output += ""

# Append to output file
$outputDir = "$PSScriptRoot\..\output"
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$outputFile = Join-Path $outputDir "$date.md"
$output | Out-File -FilePath $outputFile -Encoding UTF8 -Append

Write-Information "Danish News: $($selected.Count) articles from $uniqueSources sources appended to $outputFile" -InformationAction Continue
