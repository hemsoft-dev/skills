# Get-AllNews.ps1 - Fetches all news categories as structured JSON.
# Usage: .\Get-AllNews.ps1 [-Count 7] [-HoursBack 24]

[CmdletBinding()]
param(
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

    if ($Value -is [string]) { return $Value }
    if ($Value.'#text') { return $Value.'#text' }
    if ($Value.InnerText) { return $Value.InnerText }
    if ($Value.href) { return $Value.href }
    return $null
}

function Get-NewsCategory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [array]$Sources,

        [string]$PrioritySource,

        [scriptblock]$Filter
    )

    $articles = @()
    foreach ($source in $Sources) {
        try {
            $feed = Invoke-RestMethod -Uri $source.Url -ErrorAction Stop

            foreach ($item in $feed) {
                $published = $null
                foreach ($field in 'pubDate', 'published', 'updated') {
                    if ($item.$field) {
                        try {
                            $published = [datetime]::Parse((Get-FeedValue -Value $item.$field))
                            break
                        } catch {
                            $published = $null
                        }
                    }
                }

                if (-not $published -or $published -lt $script:cutoffTime) { continue }

                $titleText = Get-FeedValue -Value $item.title
                $link = Get-FeedValue -Value $item.link
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
            Write-Warning "Failed to fetch from $($source.Name): $_"
        }
    }

    $selected = @()
    $sourceCounts = @{}

    if ($PrioritySource) {
        foreach ($article in ($articles | Where-Object Source -eq $PrioritySource | Sort-Object Published -Descending | Select-Object -First 2)) {
            $selected += $article
            $current = if ($sourceCounts.ContainsKey($article.Source)) { $sourceCounts[$article.Source] } else { 0 }
            $sourceCounts[$article.Source] = $current + 1
        }
    }

    foreach ($article in ($articles | Where-Object { $_.Source -ne $PrioritySource } | Sort-Object Published -Descending)) {
        $current = if ($sourceCounts.ContainsKey($article.Source)) { $sourceCounts[$article.Source] } else { 0 }
        if ($current -ge 2) { continue }
        $selected += $article
        $sourceCounts[$article.Source] = $current + 1
        if ($selected.Count -ge $Count) { break }
    }

    [pscustomobject]@{
        Title    = $Title
        Articles = @($selected | Select-Object -First $Count)
    }
}

$date = Get-Date -Format 'yyyy-MM-dd'
$script:cutoffTime = (Get-Date).AddHours(-$HoursBack)

$categories = @(
    Get-NewsCategory -Title '🇺🇸 US News' -Sources @(
        @{ Name = 'Associated Press'; Url = 'https://rss.app.com/api/v1/feeds/apnews-us.rss' },
        @{ Name = 'Reuters'; Url = 'https://www.reutersagency.com/feed/?taxonomy=best-topics&post_type=best' },
        @{ Name = 'NPR'; Url = 'https://feeds.npr.org/1001/rss.xml' },
        @{ Name = 'PBS NewsHour'; Url = 'https://www.pbs.org/newshour/feeds/rss/headlines' },
        @{ Name = 'Politico'; Url = 'https://www.politico.com/rss/politics08.xml' },
        @{ Name = 'USA Today'; Url = 'https://rssfeeds.usatoday.com/usatoday-NewsTopStories' }
    )

    Get-NewsCategory -Title '🌍 World News' -Sources @(
        @{ Name = 'Reuters'; Url = 'https://www.reutersagency.com/feed/?best-regions=international&post_type=best' },
        @{ Name = 'BBC'; Url = 'http://feeds.bbci.co.uk/news/world/rss.xml' },
        @{ Name = 'Al Jazeera'; Url = 'https://www.aljazeera.com/xml/rss/all.xml' },
        @{ Name = 'France 24'; Url = 'https://www.france24.com/en/rss' },
        @{ Name = 'The Guardian'; Url = 'https://www.theguardian.com/world/rss' },
        @{ Name = 'DW News'; Url = 'https://rss.dw.com/xml/rss-en-world' }
    )

    Get-NewsCategory -Title '🤖 AI News' -PrioritySource "Simon Willison's Weblog" -Sources @(
        @{ Name = "Simon Willison's Weblog"; Url = 'https://simonwillison.net/atom/everything/' },
        @{ Name = 'The Verge'; Url = 'https://www.theverge.com/rss/ai-artificial-intelligence/index.xml' },
        @{ Name = 'TechCrunch'; Url = 'https://techcrunch.com/category/artificial-intelligence/feed/' },
        @{ Name = 'Ars Technica'; Url = 'https://feeds.arstechnica.com/arstechnica/technology-lab' },
        @{ Name = 'Wired'; Url = 'https://www.wired.com/feed/tag/ai/latest/rss' },
        @{ Name = 'VentureBeat'; Url = 'https://venturebeat.com/category/ai/feed/' },
        @{ Name = 'MIT Technology Review'; Url = 'https://www.technologyreview.com/feed/' }
    )

    Get-NewsCategory -Title '🇩🇰 Danish News' -Sources @(
        @{ Name = 'The Local'; Url = 'https://www.thelocal.dk/feed' },
        @{ Name = 'CPH Post'; Url = 'https://cphpost.dk/feed/' },
        @{ Name = 'Reuters'; Url = 'https://www.reutersagency.com/feed/?best-regions=europe&post_type=best' },
        @{ Name = 'DR News'; Url = 'https://www.dr.dk/nyheder/service/feeds/allenyheder' },
        @{ Name = 'Politiken'; Url = 'https://politiken.dk/rss/' }
    ) -Filter {
        param($Title)
        $Title -match 'Denmark|Danish|Greenland|Copenhagen|Nordic|Scandinavia|Danmark|dansk|Grønland|København|Ukraine|Trump'
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
