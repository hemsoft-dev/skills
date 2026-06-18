# Get-AllNews.ps1 - Fetches all news categories as structured JSON.
# Usage: .\Get-AllNews.ps1 [-Date yyyy-MM-dd] [-Count 7] [-HoursBack 24]

[CmdletBinding()]
param(
    [string]$Date,
    [int]$Count = 7,
    [int]$HoursBack = 24
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

function Get-FeedValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) { return $Value }

    foreach ($propertyName in '#text', 'InnerText', 'href') {
        $property = $Value.PSObject.Properties[$propertyName]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }

    return $null
}

function Get-FeedItem {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Feed
    )

    foreach ($propertyPath in @(
        @('rss', 'channel', 'item'),
        @('channel', 'item'),
        @('feed', 'entry'),
        @('entry'),
        @('item')
    )) {
        $cursor = $Feed
        foreach ($propertyName in $propertyPath) {
            if ($null -eq $cursor) { break }
            $property = $cursor.PSObject.Properties[$propertyName]
            $cursor = if ($property) { $property.Value } else { $null }
        }

        if ($cursor) { return @($cursor) }
    }

    return @($Feed)
}

function Get-FeedPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $property = $Item.PSObject.Properties[$Name]
    if (-not $property) { return $null }

    return Get-FeedValue -Value $property.Value
}

function Get-FeedLink {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item
    )

    $linkProperty = $Item.PSObject.Properties['link']
    if (-not $linkProperty) { return $null }

    $linkValue = $linkProperty.Value
    if ($linkValue -is [array]) {
        $alternate = $linkValue | Where-Object {
            $rel = Get-FeedPropertyValue -Item $_ -Name 'rel'
            -not $rel -or $rel -eq 'alternate'
        } | Select-Object -First 1

        if ($alternate) { return Get-FeedValue -Value $alternate }
    }

    return Get-FeedValue -Value $linkValue
}

function Invoke-NewsFeed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (compatible; diary-news-scaffold/1.0; +https://agentskills.io)'
        'Accept'     = 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*'
    }

    return Invoke-RestMethod -Uri $Uri -Headers $headers -ErrorAction Stop
}

function Get-NormalizedHeadline {
    param(
        [string]$Title
    )

    if ([string]::IsNullOrWhiteSpace($Title)) { return '' }
    return ($Title -replace '\s+-\s+[^-]+$', '' -replace '\s+', ' ').Trim().ToLowerInvariant()
}

function Get-NewsCategory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [array]$Sources,

        [array]$FallbackSources = @(),

        [int]$MinArticles = 4,

        [string]$PrioritySource,

        [scriptblock]$Filter
    )

    $articles = @()
    $sourceGroups = @(
        @{ Name = 'primary'; Sources = $Sources },
        @{ Name = 'fallback'; Sources = $FallbackSources }
    )

    foreach ($sourceGroup in $sourceGroups) {
        if ($sourceGroup.Name -eq 'fallback' -and $articles.Count -ge $MinArticles) {
            continue
        }

        foreach ($source in $sourceGroup.Sources) {
        try {
            $feed = Invoke-NewsFeed -Uri $source.Url

            foreach ($item in (Get-FeedItem -Feed $feed)) {
                $published = $null
                foreach ($field in 'pubDate', 'published', 'updated') {
                    $publishedText = Get-FeedPropertyValue -Item $item -Name $field
                    if (-not $publishedText) { continue }

                    try {
                        $published = [datetime]::Parse($publishedText)
                        break
                    } catch {
                        $published = $null
                    }
                }

                if (-not $published -or $published -lt $script:cutoffTime -or $published -ge $script:endTime) {
                    continue
                }

                $titleText = Get-FeedPropertyValue -Item $item -Name 'title'
                $link = Get-FeedLink -Item $item
                if (-not $titleText -or -not $link) { continue }
                if ($Filter -and -not (& $Filter $titleText)) { continue }

                $articles += [pscustomobject]@{
                    Title     = $titleText
                    Link      = $link
                    Source    = $source.Name
                    Published = $published.ToString('o')
                }
            }
        } catch {
            Write-Warning "Failed to fetch from $($source.Name): $($_.Exception.Message)"
        }
        }
    }

    $selected = @()
    $sourceCounts = @{}
    $seenHeadlines = @{}

    if ($PrioritySource) {
        foreach ($article in ($articles | Where-Object Source -eq $PrioritySource | Sort-Object Published -Descending | Select-Object -First 2)) {
            $normalized = Get-NormalizedHeadline -Title $article.Title
            if ($seenHeadlines.ContainsKey($normalized)) { continue }
            $seenHeadlines[$normalized] = $true
            $selected += $article
            $current = if ($sourceCounts.ContainsKey($article.Source)) { $sourceCounts[$article.Source] } else { 0 }
            $sourceCounts[$article.Source] = $current + 1
        }
    }

    foreach ($article in ($articles | Where-Object { $_.Source -ne $PrioritySource } | Sort-Object Published -Descending)) {
        $normalized = Get-NormalizedHeadline -Title $article.Title
        if ($seenHeadlines.ContainsKey($normalized)) { continue }
        $current = if ($sourceCounts.ContainsKey($article.Source)) { $sourceCounts[$article.Source] } else { 0 }
        if ($current -ge 2) { continue }
        $seenHeadlines[$normalized] = $true
        $selected += $article
        $sourceCounts[$article.Source] = $current + 1
        if ($selected.Count -ge $script:headlineLimit) { break }
    }

    $minimumTarget = [Math]::Min($MinArticles, $script:headlineLimit)
    if ($selected.Count -lt $minimumTarget) {
        foreach ($article in ($articles | Sort-Object Published -Descending)) {
            $normalized = Get-NormalizedHeadline -Title $article.Title
            if ($seenHeadlines.ContainsKey($normalized)) { continue }
            $seenHeadlines[$normalized] = $true
            $selected += $article
            $current = if ($sourceCounts.ContainsKey($article.Source)) { $sourceCounts[$article.Source] } else { 0 }
            $sourceCounts[$article.Source] = $current + 1
            if ($selected.Count -ge $minimumTarget) { break }
        }
    }

    [pscustomobject]@{
        Title    = $Title
        Articles = @($selected | Select-Object -First $script:headlineLimit)
    }
}

if (-not $Date) {
    $Date = Get-Date -Format 'yyyy-MM-dd'
}

$date = $Date
$script:headlineLimit = $Count
$targetDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$script:endTime = $targetDate.AddDays(1)
$script:cutoffTime = $script:endTime.AddHours(-$HoursBack)

$categories = @(
    Get-NewsCategory -Title '🇺🇸 US News' -MinArticles 6 -Sources @(
        @{ Name = 'Associated Press'; Url = 'https://apnews.com/hub/ap-top-news?output=rss' },
        @{ Name = 'NPR Politics'; Url = 'https://feeds.npr.org/1014/rss.xml' },
        @{ Name = 'PBS Politics'; Url = 'https://www.pbs.org/newshour/feeds/rss/politics' },
        @{ Name = 'Politico'; Url = 'https://www.politico.com/rss/politics08.xml' },
        @{ Name = 'USA Today'; Url = 'https://rssfeeds.usatoday.com/usatoday-NewsTopStories' }
    ) -FallbackSources @(
        @{ Name = 'Google News US'; Url = 'https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en' },
        @{ Name = 'Google News US Search'; Url = 'https://news.google.com/rss/search?q=United%20States%20OR%20Congress%20OR%20White%20House%20OR%20Supreme%20Court%20when%3A2d&hl=en-US&gl=US&ceid=US:en' }
    ) -Filter {
        param($Title)
        $Title -match 'US|U\.S\.|United States|America|American|Trump|White House|Congress|Senate|House|Supreme Court|SCOTUS|DOJ|FBI|federal|governor|Pentagon|immigration|ICE|California|Texas|Florida|New York|Washington'
    }

    Get-NewsCategory -Title '🌍 World News' -MinArticles 6 -Sources @(
        @{ Name = 'BBC'; Url = 'http://feeds.bbci.co.uk/news/world/rss.xml' },
        @{ Name = 'Al Jazeera'; Url = 'https://www.aljazeera.com/xml/rss/all.xml' },
        @{ Name = 'France 24'; Url = 'https://www.france24.com/en/rss' },
        @{ Name = 'The Guardian'; Url = 'https://www.theguardian.com/world/rss' },
        @{ Name = 'DW News'; Url = 'https://rss.dw.com/xml/rss-en-world' }
    ) -FallbackSources @(
        @{ Name = 'Google News World'; Url = 'https://news.google.com/rss/headlines/section/topic/WORLD?hl=en-US&gl=US&ceid=US:en' },
        @{ Name = 'Google News World Search'; Url = 'https://news.google.com/rss/search?q=world%20OR%20international%20OR%20Europe%20OR%20Middle%20East%20OR%20Asia%20when%3A2d&hl=en-US&gl=US&ceid=US:en' }
    ) -Filter {
        param($Title)
        $Title -notmatch 'Reuters executive|ABC news director|Google employee charged|Polymarket'
    }

    Get-NewsCategory -Title '🤖 AI News' -MinArticles 5 -PrioritySource "Simon Willison's Weblog" -Sources @(
        @{ Name = "Simon Willison's Weblog"; Url = 'https://simonwillison.net/atom/everything/' },
        @{ Name = 'The Verge'; Url = 'https://www.theverge.com/rss/ai-artificial-intelligence/index.xml' },
        @{ Name = 'TechCrunch'; Url = 'https://techcrunch.com/category/artificial-intelligence/feed/' },
        @{ Name = 'Ars Technica'; Url = 'https://feeds.arstechnica.com/arstechnica/technology-lab' },
        @{ Name = 'Wired'; Url = 'https://www.wired.com/feed/tag/ai/latest/rss' },
        @{ Name = 'VentureBeat'; Url = 'https://venturebeat.com/category/ai/feed/' },
        @{ Name = 'MIT Technology Review'; Url = 'https://www.technologyreview.com/feed/' }
    ) -FallbackSources @(
        @{ Name = 'Google News AI'; Url = 'https://news.google.com/rss/search?q=artificial%20intelligence%20OR%20OpenAI%20OR%20Anthropic%20OR%20Gemini%20OR%20AI%20model%20when%3A2d&hl=en-US&gl=US&ceid=US:en' }
    ) -Filter {
        param($Title)
        $Title -match 'AI|artificial intelligence|OpenAI|Anthropic|Gemini|ChatGPT|Claude|Copilot|LLM|model|machine learning|Nvidia'
    }

    Get-NewsCategory -Title '🇩🇰 Danish News' -MinArticles 4 -Sources @(
        @{ Name = 'The Local'; Url = 'https://www.thelocal.dk/feed' },
        @{ Name = 'CPH Post'; Url = 'https://cphpost.dk/feed/' },
        @{ Name = 'DR News'; Url = 'https://www.dr.dk/nyheder/service/feeds/allenyheder' },
        @{ Name = 'Politiken'; Url = 'https://politiken.dk/rss/' },
        @{ Name = 'Google News Denmark'; Url = 'https://news.google.com/rss/search?q=Denmark%20OR%20Danish%20OR%20Copenhagen%20OR%20Greenland%20when%3A1d&hl=en-US&gl=US&ceid=US:en' }
    ) -FallbackSources @(
        @{ Name = 'Google News Denmark Search'; Url = 'https://news.google.com/rss/search?q=Denmark%20OR%20Danish%20OR%20Copenhagen%20OR%20Greenland%20OR%20Danmark%20OR%20K%C3%B8benhavn%20when%3A2d&hl=en-US&gl=US&ceid=US:en' }
    ) -Filter {
        param($Title)
        $null -ne $Title
    }
)

$payload = [pscustomobject]@{
    Date        = $date
    GeneratedAt = (Get-Date).ToString('o')
    Categories  = $categories
}

$outputDir = Join-Path $PSScriptRoot '..' 'output'
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$outputFile = Join-Path $outputDir "$date.json"
$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $outputFile -Encoding UTF8

$headlineCount = ($categories | ForEach-Object { $_.Articles.Count } | Measure-Object -Sum).Sum
Write-Information "All news categories fetched and saved to: $outputFile" -InformationAction Continue
Write-Information "Categories: $($categories.Count) | Headlines: $headlineCount" -InformationAction Continue
