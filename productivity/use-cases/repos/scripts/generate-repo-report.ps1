#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates repository activity graphs and contributor statistics from collected commit data.

.DESCRIPTION
    Analyzes JSON data files for a specific repository and creates visual
    representations of team productivity including LOC trends, commit patterns,
    and contributor activity breakdown. Uses HTML templates for consistent design.

.PARAMETER RepoName
    Name of the repository to analyze (required). Must match a subfolder in data directory.

.PARAMETER StartDate
    Start date for analysis in YYYY-MM-DD format (default: earliest available)

.PARAMETER EndDate
    End date for analysis in YYYY-MM-DD format (default: latest available)

.PARAMETER Days
    Number of days to include (alternative to date range, uses most recent N days)

.PARAMETER Template
    Template file to use (default: repo-analytics.html)

.PARAMETER DataPath
    Path to the data directory (default: ..\data)

.PARAMETER OutputPath
    Path where graphs and reports will be saved (default: ..\output)

.PARAMETER TemplatePath
    Path to templates directory (default: ..\templates)

.EXAMPLE
    .\generate-repo-report.ps1 -RepoName "relias-assistant"

.EXAMPLE
    .\generate-repo-report.ps1 -RepoName "relias-assistant" -StartDate "2026-01-01" -EndDate "2026-01-31"

.EXAMPLE
    .\generate-repo-report.ps1 -RepoName "relias-assistant" -Days 30 -Template "repo-analytics-dark.html"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [string]$StartDate,
    [string]$EndDate,
    [int]$Days,
    [string]$Template = "repo-analytics.html",
    [string]$DataPath = "$PSScriptRoot\..\data",
    [string]$OutputPath = "$PSScriptRoot\..\output",
    [string]$TemplatePath = "$PSScriptRoot\..\templates"
)

# Validate template exists
$templateFile = Join-Path $TemplatePath $Template
if (!(Test-Path $templateFile)) {
    Write-Error "Template not found: $templateFile"
    Write-Host "Available templates:" -ForegroundColor Yellow
    Get-ChildItem -Path $TemplatePath -Filter "*.html" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  - $($_.Name)" }
    exit 1
}

# Validate repo data exists
$repoDataPath = Join-Path $DataPath $RepoName
if (!(Test-Path $repoDataPath)) {
    Write-Error "No data found for repository '$RepoName'. Expected path: $repoDataPath"
    Write-Host "Available repositories:" -ForegroundColor Yellow
    Get-ChildItem -Path $DataPath -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    exit 1
}

# Ensure output directory exists
$repoOutputPath = Join-Path $OutputPath $RepoName
if (!(Test-Path $repoOutputPath)) {
    New-Item -ItemType Directory -Path $repoOutputPath -Force | Out-Null
}

# Get all JSON data files, sorted by date
$dataFiles = Get-ChildItem -Path $repoDataPath -Filter "commits-*.json" | Sort-Object Name

# Apply date filters
if ($StartDate) {
    $startDt = [DateTime]::Parse($StartDate)
    $dataFiles = $dataFiles | Where-Object {
        $dateStr = $_.Name -replace 'commits-(\d{4}-\d{2}-\d{2})\.json', '$1'
        [DateTime]::Parse($dateStr) -ge $startDt
    }
}

if ($EndDate) {
    $endDt = [DateTime]::Parse($EndDate)
    $dataFiles = $dataFiles | Where-Object {
        $dateStr = $_.Name -replace 'commits-(\d{4}-\d{2}-\d{2})\.json', '$1'
        [DateTime]::Parse($dateStr) -le $endDt
    }
}

if ($Days -and $Days -lt $dataFiles.Count) {
    $dataFiles = $dataFiles | Select-Object -Last $Days
}

if ($dataFiles.Count -eq 0) {
    Write-Error "No data files found for the specified date range."
    exit 1
}

Write-Host "📊 Analyzing $($dataFiles.Count) days of data for '$RepoName'..." -ForegroundColor Cyan
Write-Host "📄 Using template: $Template" -ForegroundColor Cyan

# Also look for issues/PRs data files
$issuesPrsFiles = Get-ChildItem -Path $repoDataPath -Filter "issues-prs-*.json" -ErrorAction SilentlyContinue | Sort-Object Name

# Apply date filters to issues/PRs files
if ($StartDate -and $issuesPrsFiles) {
    $startDt = [DateTime]::Parse($StartDate)
    $issuesPrsFiles = $issuesPrsFiles | Where-Object {
        $dateStr = $_.Name -replace 'issues-prs-(\d{4}-\d{2}-\d{2})\.json', '$1'
        [DateTime]::Parse($dateStr) -ge $startDt
    }
}

if ($EndDate -and $issuesPrsFiles) {
    $endDt = [DateTime]::Parse($EndDate)
    $issuesPrsFiles = $issuesPrsFiles | Where-Object {
        $dateStr = $_.Name -replace 'issues-prs-(\d{4}-\d{2}-\d{2})\.json', '$1'
        [DateTime]::Parse($dateStr) -le $endDt
    }
}

if ($issuesPrsFiles -and $issuesPrsFiles.Count -gt 0) {
    Write-Host "📋 Found $($issuesPrsFiles.Count) issues/PRs data file(s)" -ForegroundColor Cyan
}

# Collect data from all files
$dailyData = @()
$allCommits = @()
$contributorStats = @{}
$allPullRequests = @()
$allIssues = @()
$dailyPRData = @{}
$dailyIssueData = @{}

foreach ($file in $dataFiles) {
    try {
        $data = Get-Content $file.FullName | ConvertFrom-Json

        # Extract date from filename
        $dateStr = $file.Name -replace 'commits-(\d{4}-\d{2}-\d{2})\.json', '$1'
        $fileDate = [DateTime]::Parse($dateStr)

        $commitCount = if ($data.commits) { $data.commits.Count } else { 0 }

        $dayData = [PSCustomObject]@{
            Date           = $fileDate
            NetLOC         = if ($data.summary.totalNetLOC) { $data.summary.totalNetLOC } else { 0 }
            TotalCommits   = $commitCount
            TotalAdditions = if ($data.summary.totalAdditions) { $data.summary.totalAdditions } else { 0 }
            TotalDeletions = if ($data.summary.totalDeletions) { $data.summary.totalDeletions } else { 0 }
            LinesAffected  = if ($data.summary.totalLinesAffected) { $data.summary.totalLinesAffected } else { 0 }
            Contributors   = if ($data.commits) { ($data.commits | Select-Object -Property author -Unique).Count } else { 0 }
        }

        $dailyData += $dayData

        # Collect individual commits and track contributors
        if ($data.commits) {
            foreach ($commit in $data.commits) {
                $allCommits += [PSCustomObject]@{
                    Date       = [DateTime]::Parse($commit.date)
                    Author     = $commit.author
                    Email      = $commit.authorEmail
                    Message    = $commit.message
                    Additions  = $commit.additions
                    Deletions  = $commit.deletions
                    NetLOC     = $commit.netLOC
                    Files      = $commit.filesChanged
                    SHA        = $commit.sha
                    URL        = $commit.url
                }

                # Track contributor statistics
                $author = $commit.author
                if (-not $contributorStats.ContainsKey($author)) {
                    $contributorStats[$author] = @{
                        Email      = $commit.authorEmail
                        Commits    = 0
                        Additions  = 0
                        Deletions  = 0
                        NetLOC     = 0
                        Files      = 0
                        FirstCommit = $commit.date
                        LastCommit  = $commit.date
                    }
                }
                $contributorStats[$author].Commits++
                $contributorStats[$author].Additions += $commit.additions
                $contributorStats[$author].Deletions += $commit.deletions
                $contributorStats[$author].NetLOC += $commit.netLOC
                $contributorStats[$author].Files += $commit.filesChanged
                if ([DateTime]::Parse($commit.date) -gt [DateTime]::Parse($contributorStats[$author].LastCommit)) {
                    $contributorStats[$author].LastCommit = $commit.date
                }
                if ([DateTime]::Parse($commit.date) -lt [DateTime]::Parse($contributorStats[$author].FirstCommit)) {
                    $contributorStats[$author].FirstCommit = $commit.date
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process $($file.Name): $($_.Exception.Message)"
    }
}

# Process issues/PRs files
if ($issuesPrsFiles -and $issuesPrsFiles.Count -gt 0) {
    foreach ($file in $issuesPrsFiles) {
        try {
            $data = Get-Content $file.FullName | ConvertFrom-Json
            
            # Collect pull requests
            if ($data.pullRequests) {
                foreach ($pr in $data.pullRequests) {
                    $allPullRequests += $pr
                    
                    # Track daily PR data
                    $actionDate = $pr.actionDate
                    if (-not $dailyPRData.ContainsKey($actionDate)) {
                        $dailyPRData[$actionDate] = @{
                            opened = 0
                            merged = 0
                            closed = 0
                        }
                    }
                    
                    switch ($pr.action) {
                        "opened" { $dailyPRData[$actionDate].opened++ }
                        "merged" { $dailyPRData[$actionDate].merged++ }
                        "closed" { $dailyPRData[$actionDate].closed++ }
                    }
                }
            }
            
            # Collect issues
            if ($data.issues) {
                foreach ($issue in $data.issues) {
                    $allIssues += $issue
                    
                    # Track daily issue data
                    $actionDate = $issue.actionDate
                    if (-not $dailyIssueData.ContainsKey($actionDate)) {
                        $dailyIssueData[$actionDate] = @{
                            opened = 0
                            closed = 0
                        }
                    }
                    
                    switch ($issue.action) {
                        "opened" { $dailyIssueData[$actionDate].opened++ }
                        "closed" { $dailyIssueData[$actionDate].closed++ }
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to process issues/PRs file $($file.Name): $($_.Exception.Message)"
        }
    }
}

if ($dailyData.Count -eq 0) {
    Write-Error "No valid data found to analyze."
    exit 1
}

# Sort data by date
$dailyData = $dailyData | Sort-Object Date

# Convert contributor stats to sorted array
$contributors = $contributorStats.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        Name       = $_.Key
        Email      = $_.Value.Email
        Commits    = $_.Value.Commits
        Additions  = $_.Value.Additions
        Deletions  = $_.Value.Deletions
        NetLOC     = $_.Value.NetLOC
        Files      = $_.Value.Files
        FirstCommit = $_.Value.FirstCommit
        LastCommit  = $_.Value.LastCommit
    }
} | Sort-Object Commits -Descending

# Calculate summary statistics
$summary = [PSCustomObject]@{
    Repository      = $RepoName
    TotalDays       = $dailyData.Count
    ActiveDays      = ($dailyData | Where-Object { $_.TotalCommits -gt 0 }).Count
    TotalNetLOC     = ($dailyData | Measure-Object -Property NetLOC -Sum).Sum
    TotalCommits    = ($dailyData | Measure-Object -Property TotalCommits -Sum).Sum
    TotalAdditions  = ($dailyData | Measure-Object -Property TotalAdditions -Sum).Sum
    TotalDeletions  = ($dailyData | Measure-Object -Property TotalDeletions -Sum).Sum
    AverageDailyLOC = [Math]::Round(($dailyData | Where-Object { $_.TotalCommits -gt 0 } | Measure-Object -Property NetLOC -Average).Average, 0)
    MaxDailyLOC     = ($dailyData | Measure-Object -Property NetLOC -Maximum).Maximum
    MinDailyLOC     = ($dailyData | Where-Object { $_.TotalCommits -gt 0 } | Measure-Object -Property NetLOC -Minimum).Minimum
    MostActiveDay   = ($dailyData | Sort-Object TotalCommits -Descending | Select-Object -First 1).Date.ToString("yyyy-MM-dd")
    TotalContributors = $contributors.Count
    TopContributor  = if ($contributors.Count -gt 0) { $contributors[0].Name } else { "N/A" }
    # PR stats
    TotalPRs        = $allPullRequests.Count
    PRsOpened       = ($allPullRequests | Where-Object { $_.action -eq "opened" }).Count
    PRsMerged       = ($allPullRequests | Where-Object { $_.action -eq "merged" }).Count
    PRsClosed       = ($allPullRequests | Where-Object { $_.action -eq "closed" }).Count
    # Issue stats
    TotalIssues     = $allIssues.Count
    IssuesOpened    = ($allIssues | Where-Object { $_.action -eq "opened" }).Count
    IssuesClosed    = ($allIssues | Where-Object { $_.action -eq "closed" }).Count
}

# Display summary
Write-Host "`n📈 REPOSITORY SUMMARY: $RepoName" -ForegroundColor Green
Write-Host ("=" * 40) -ForegroundColor Green
Write-Host "Period: $($dailyData[0].Date.ToString('MMM dd, yyyy')) - $($dailyData[-1].Date.ToString('MMM dd, yyyy'))"
Write-Host "Days Analyzed: $($summary.TotalDays) ($($summary.ActiveDays) active)"
Write-Host ("Total Net LOC: {0:N0}" -f $summary.TotalNetLOC)
Write-Host ("Total Commits: {0:N0}" -f $summary.TotalCommits)
Write-Host ("Total Additions: {0:N0}" -f $summary.TotalAdditions)
Write-Host ("Total Deletions: {0:N0}" -f $summary.TotalDeletions)
Write-Host ("Average Daily LOC (active days): {0:N0}" -f $summary.AverageDailyLOC)
Write-Host ("Peak Day: {0} ({1:N0} commits)" -f $summary.MostActiveDay, ($dailyData | Sort-Object TotalCommits -Descending | Select-Object -First 1).TotalCommits)
Write-Host ("Contributors: {0}" -f $summary.TotalContributors)
Write-Host ("Pull Requests: {0} ({1} opened, {2} merged, {3} closed)" -f $summary.TotalPRs, $summary.PRsOpened, $summary.PRsMerged, $summary.PRsClosed)
Write-Host ("Issues: {0} ({1} opened, {2} closed)" -f $summary.TotalIssues, $summary.IssuesOpened, $summary.IssuesClosed)

# Display contributor breakdown
Write-Host "`n👥 CONTRIBUTOR BREAKDOWN" -ForegroundColor Magenta
Write-Host ("=" * 40) -ForegroundColor Magenta
$contributors | ForEach-Object {
    $pct = [Math]::Round(($_.Commits / $summary.TotalCommits) * 100, 1)
    Write-Host ("{0,-25} {1,3} commits ({2,5}%) | {3,8:N0} LOC" -f $_.Name, $_.Commits, $pct, $_.NetLOC)
}

# ===== TEMPLATE PROCESSING =====

# Prepare chart data arrays
$dateLabels = ($dailyData | ForEach-Object { "'$($_.Date.ToString('MMM dd'))'" }) -join ','
$netLOCData = ($dailyData | ForEach-Object { $_.NetLOC }) -join ','
$commitsData = ($dailyData | ForEach-Object { $_.TotalCommits }) -join ','
$contributorsData = ($dailyData | ForEach-Object { $_.Contributors }) -join ','
$additionsData = ($dailyData | ForEach-Object { $_.TotalAdditions }) -join ','
$deletionsData = ($dailyData | ForEach-Object { $_.TotalDeletions }) -join ','

# Prepare PRs and Issues chart data (aligned with dates)
$prsOpenedData = @()
$prsMergedData = @()
$prsClosedData = @()
$issuesOpenedData = @()
$issuesClosedData = @()

foreach ($day in $dailyData) {
    $dateKey = $day.Date.ToString("yyyy-MM-dd")
    
    # PR data for this date
    if ($dailyPRData.ContainsKey($dateKey)) {
        $prsOpenedData += $dailyPRData[$dateKey].opened
        $prsMergedData += $dailyPRData[$dateKey].merged
        $prsClosedData += $dailyPRData[$dateKey].closed
    } else {
        $prsOpenedData += 0
        $prsMergedData += 0
        $prsClosedData += 0
    }
    
    # Issue data for this date
    if ($dailyIssueData.ContainsKey($dateKey)) {
        $issuesOpenedData += $dailyIssueData[$dateKey].opened
        $issuesClosedData += $dailyIssueData[$dateKey].closed
    } else {
        $issuesOpenedData += 0
        $issuesClosedData += 0
    }
}

$prsOpenedDataStr = $prsOpenedData -join ','
$prsMergedDataStr = $prsMergedData -join ','
$prsClosedDataStr = $prsClosedData -join ','
$issuesOpenedDataStr = $issuesOpenedData -join ','
$issuesClosedDataStr = $issuesClosedData -join ','

# Prepare contributor chart data
$contributorLabels = ($contributors | ForEach-Object { "'$($_.Name)'" }) -join ','
$contributorCommitsData = ($contributors | ForEach-Object { $_.Commits }) -join ','

# Generate colors for contributors
$colors = @(
    "'#007bff'", "'#28a745'", "'#ffc107'", "'#dc3545'", "'#6f42c1'",
    "'#17a2b8'", "'#fd7e14'", "'#20c997'", "'#e83e8c'", "'#6c757d'"
)
$contributorColors = @()
for ($i = 0; $i -lt $contributors.Count; $i++) {
    $contributorColors += $colors[$i % $colors.Count]
}
$contributorColorsData = $contributorColors -join ','

# Build contributor table rows
$contributorTableRows = ($contributors | ForEach-Object {
    $pct = [Math]::Round(($_.Commits / $summary.TotalCommits) * 100, 1)
    @"
                    <tr>
                        <td><strong>$($_.Name)</strong></td>
                        <td>$($_.Commits)</td>
                        <td>$($pct)%</td>
                        <td class="additions">+$($_.Additions.ToString("N0"))</td>
                        <td class="deletions">-$($_.Deletions.ToString("N0"))</td>
                        <td>$($_.NetLOC.ToString("N0"))</td>
                        <td>$($_.Files)</td>
                    </tr>
"@
}) -join "`n"

# Calculate derived values
$mostActiveDayCommits = ($dailyData | Sort-Object TotalCommits -Descending | Select-Object -First 1).TotalCommits
$topContributorPct = if ($contributors.Count -gt 0) { [Math]::Round(($contributors[0].Commits / $summary.TotalCommits) * 100, 1) } else { 0 }
$activityRate = [Math]::Round(($summary.ActiveDays / $summary.TotalDays) * 100, 1)
$churnRatio = if ($summary.TotalDeletions -gt 0) { [Math]::Round($summary.TotalAdditions / $summary.TotalDeletions, 2) } else { "∞" }
$topContributorCommits = if ($contributors.Count -gt 0) { $contributors[0].Commits } else { 0 }

# Read template
$htmlContent = Get-Content $templateFile -Raw

# Replace all placeholders
$replacements = @{
    '{{REPO_NAME}}'             = $RepoName
    '{{DATE_RANGE}}'            = "$($dailyData[0].Date.ToString('MMM dd, yyyy')) - $($dailyData[-1].Date.ToString('MMM dd, yyyy'))"
    '{{TOTAL_COMMITS}}'         = $summary.TotalCommits.ToString()
    '{{TOTAL_NET_LOC}}'         = $summary.TotalNetLOC.ToString("N0")
    '{{TOTAL_CONTRIBUTORS}}'    = $summary.TotalContributors.ToString()
    '{{ACTIVE_DAYS}}'           = $summary.ActiveDays.ToString()
    '{{TOTAL_ADDITIONS}}'       = $summary.TotalAdditions.ToString("N0")
    '{{TOTAL_DELETIONS}}'       = $summary.TotalDeletions.ToString("N0")
    '{{AVG_LOC_PER_DAY}}'       = $summary.AverageDailyLOC.ToString("N0")
    '{{TOTAL_DAYS}}'            = $summary.TotalDays.ToString()
    '{{MOST_ACTIVE_DAY}}'       = $summary.MostActiveDay
    '{{MOST_ACTIVE_DAY_COMMITS}}' = $mostActiveDayCommits.ToString()
    '{{TOP_CONTRIBUTOR}}'       = $summary.TopContributor
    '{{TOP_CONTRIBUTOR_COMMITS}}' = $topContributorCommits.ToString()
    '{{TOP_CONTRIBUTOR_PCT}}'   = $topContributorPct.ToString()
    '{{ACTIVITY_RATE}}'         = $activityRate.ToString()
    '{{CHURN_RATIO}}'           = $churnRatio.ToString()
    '{{GENERATED_DATE}}'        = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    '{{CONTRIBUTOR_TABLE_ROWS}}' = $contributorTableRows
    '{{DATE_LABELS}}'           = $dateLabels
    '{{NET_LOC_DATA}}'          = $netLOCData
    '{{COMMITS_DATA}}'          = $commitsData
    '{{CONTRIBUTORS_DATA}}'     = $contributorsData
    '{{ADDITIONS_DATA}}'        = $additionsData
    '{{DELETIONS_DATA}}'        = $deletionsData
    '{{CONTRIBUTOR_LABELS}}'    = $contributorLabels
    '{{CONTRIBUTOR_COMMITS}}'   = $contributorCommitsData
    '{{CONTRIBUTOR_COLORS}}'    = $contributorColorsData
    # PR/Issue summary placeholders
    '{{TOTAL_PRS}}'             = $summary.TotalPRs.ToString()
    '{{PRS_OPENED}}'            = $summary.PRsOpened.ToString()
    '{{PRS_MERGED}}'            = $summary.PRsMerged.ToString()
    '{{PRS_CLOSED}}'            = $summary.PRsClosed.ToString()
    '{{TOTAL_ISSUES}}'          = $summary.TotalIssues.ToString()
    '{{ISSUES_OPENED}}'         = $summary.IssuesOpened.ToString()
    '{{ISSUES_CLOSED}}'         = $summary.IssuesClosed.ToString()
    # PR/Issue chart data placeholders
    '{{PRS_OPENED_DATA}}'       = $prsOpenedDataStr
    '{{PRS_MERGED_DATA}}'       = $prsMergedDataStr
    '{{PRS_CLOSED_DATA}}'       = $prsClosedDataStr
    '{{ISSUES_OPENED_DATA}}'    = $issuesOpenedDataStr
    '{{ISSUES_CLOSED_DATA}}'    = $issuesClosedDataStr
}

foreach ($key in $replacements.Keys) {
    $htmlContent = $htmlContent.Replace($key, $replacements[$key])
}

# Save HTML report
$htmlPath = Join-Path $repoOutputPath "repo-analytics.html"
$htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8

Write-Host "`n📊 Dashboard saved to: $htmlPath" -ForegroundColor Cyan

# Generate text report
$textReport = @"
REPOSITORY ANALYTICS REPORT
===========================
Repository: $RepoName
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

ANALYSIS PERIOD
---------------
Start: $($dailyData[0].Date.ToString('yyyy-MM-dd'))
End: $($dailyData[-1].Date.ToString('yyyy-MM-dd'))
Days Analyzed: $($summary.TotalDays)
Active Days: $($summary.ActiveDays)

SUMMARY STATISTICS
------------------
Total Commits: $($summary.TotalCommits)
Total Net LOC: $($summary.TotalNetLOC.ToString("N0"))
Total Additions: $($summary.TotalAdditions.ToString("N0"))
Total Deletions: $($summary.TotalDeletions.ToString("N0"))
Average Daily LOC (active days): $($summary.AverageDailyLOC.ToString("N0"))
Peak Daily LOC: $($summary.MaxDailyLOC.ToString("N0"))
Total Contributors: $($summary.TotalContributors)

CONTRIBUTOR BREAKDOWN
---------------------
"@

foreach ($c in $contributors) {
    $pct = [Math]::Round(($c.Commits / $summary.TotalCommits) * 100, 1)
    $textReport += "`n$($c.Name):"
    $textReport += "`n  Commits: $($c.Commits) ($pct%)"
    $textReport += "`n  Additions: $($c.Additions.ToString("N0"))"
    $textReport += "`n  Deletions: $($c.Deletions.ToString("N0"))"
    $textReport += "`n  Net LOC: $($c.NetLOC.ToString("N0"))"
    $textReport += "`n  Files Changed: $($c.Files)"
}

$textReport += @"


DAILY BREAKDOWN
---------------
"@

foreach ($day in $dailyData) {
    if ($day.TotalCommits -gt 0) {
        $textReport += "`n$($day.Date.ToString('yyyy-MM-dd')): $($day.TotalCommits) commits, $($day.NetLOC.ToString("N0")) LOC, $($day.Contributors) contributors"
    }
}

# Save text report
$textPath = Join-Path $repoOutputPath "repo-analytics.txt"
$textReport | Out-File -FilePath $textPath -Encoding UTF8

Write-Host "📝 Text report saved to: $textPath" -ForegroundColor Green

# Open HTML report
Write-Host "`n🌐 Opening dashboard in browser..." -ForegroundColor Yellow
Start-Process $htmlPath

Write-Host "`n✅ Analysis complete!" -ForegroundColor Green
