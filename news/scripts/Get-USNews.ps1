# Get-USNews.ps1 - Fetches US news headlines from RSS feeds
# Usage: .\Get-USNews.ps1 [-Count 7] [-HoursBack 24]

param(
    [int]$Count = 7,
    [int]$HoursBack = 24
)

$date = Get-Date -Format "yyyy-MM-dd"
$cutoffTime = (Get-Date).AddHours(-$HoursBack)

# RSS feed sources
$sources = @(
    @{ Name = "Associated Press"; Url = "https://rss.app.com/api/v1/feeds/apnews-us.rss" }
    @{ Name = "Reuters"; Url = "https://www.reutersagency.com/feed/?taxonomy=best-topics&post_type=best" }
    @{ Name = "NPR"; Url = "https://feeds.npr.org/1001/rss.xml" }
    @{ Name = "PBS NewsHour"; Url = "https://www.pbs.org/newshour/feeds/rss/headlines" }
    @{ Name = "Politico"; Url = "https://www.politico.com/rss/politics08.xml" }
    @{ Name = "USA Today"; Url = "https://rssfeeds.usatoday.com/usatoday-NewsTopStories" }
)

# Collect all articles
$allArticles = @()

foreach ($source in $sources) {
    try {
        $feed = Invoke-RestMethod -Uri $source.Url -ErrorAction Stop
        
        foreach ($item in $feed) {
            # Parse pub date (RSS feeds use different formats)
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

# Ensure minimum source diversity (3-4 sources)
$uniqueSources = ($selected | Select-Object -Unique Source).Count
if ($uniqueSources -lt 3 -and $allArticles.Count -gt 0) {
    Write-Warning "Only $uniqueSources sources represented. Consider widening search."
}

# Generate output
$output = @()
$output += "### 🇺🇸 US News"
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

Write-Information "US News: $($selected.Count) articles from $uniqueSources sources appended to $outputFile" -InformationAction Continue
