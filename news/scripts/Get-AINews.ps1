# Get-AINews.ps1 - Fetches AI news headlines from RSS feeds
# Usage: .\Get-AINews.ps1 [-Count 7] [-HoursBack 24]

param(
    [int]$Count = 7,
    [int]$HoursBack = 24
)

$date = Get-Date -Format "yyyy-MM-dd"
$cutoffTime = (Get-Date).AddHours(-$HoursBack)

# RSS feed sources
$sources = @(
    @{ Name = "Simon Willison's Weblog"; Url = "https://simonwillison.net/atom/everything/" }
    @{ Name = "The Verge"; Url = "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml" }
    @{ Name = "TechCrunch"; Url = "https://techcrunch.com/category/artificial-intelligence/feed/" }
    @{ Name = "Ars Technica"; Url = "https://feeds.arstechnica.com/arstechnica/technology-lab" }
    @{ Name = "Wired"; Url = "https://www.wired.com/feed/tag/ai/latest/rss" }
    @{ Name = "VentureBeat"; Url = "https://venturebeat.com/category/ai/feed/" }
    @{ Name = "MIT Technology Review"; Url = "https://www.technologyreview.com/feed/" }
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
            if ($item.updated) {
                try { $pubDate = [DateTime]::Parse($item.updated) } catch { $null }
            }
            
            # Skip if too old or no date
            if (-not $pubDate -or $pubDate -lt $cutoffTime) { continue }
            
            # Handle title parsing (some RSS feeds use objects)
            $title = if ($item.title -is [string]) { 
                $item.title 
            } elseif ($item.title.'#text') { 
                $item.title.'#text' 
            } elseif ($item.title.InnerText) { 
                $item.title.InnerText 
            } else { 
                "Untitled" 
            }
            
            # Handle link parsing
            $link = if ($item.link -is [string]) { 
                $item.link 
            } elseif ($item.link.href) { 
                $item.link.href 
            } else { 
                "" 
            }
            
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
# PRIORITY: Simon Willison's Weblog first
$selected = @()
$sourceCounts = @{}

# First pass: Simon Willison articles (up to 2)
foreach ($article in ($allArticles | Where-Object { $_.Source -eq "Simon Willison's Weblog" } | Sort-Object PubDate -Descending | Select-Object -First 2)) {
    $selected += $article
    $current = if ($sourceCounts[$article.Source]) { $sourceCounts[$article.Source] } else { 0 }
    $sourceCounts[$article.Source] = $current + 1
}

# Second pass: Other sources
foreach ($article in ($allArticles | Where-Object { $_.Source -ne "Simon Willison's Weblog" } | Sort-Object PubDate -Descending)) {
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
$output += "### 🤖 AI News"
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

Write-Information "AI News: $($selected.Count) articles from $uniqueSources sources appended to $outputFile" -InformationAction Continue
