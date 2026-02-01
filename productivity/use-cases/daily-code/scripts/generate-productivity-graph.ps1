#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates productivity graphs and reports from collected commit data.

.DESCRIPTION
    Analyzes all JSON data files in the data directory and creates visual
    representations of productivity metrics including LOC trends, commit patterns,
    and repository activity.

.PARAMETER DataPath
    Path to the data directory containing JSON files (default: ..\data)

.PARAMETER OutputPath
    Path where graphs and reports will be saved (default: ..\output)

.PARAMETER Days
    Number of days to include in the analysis (default: all available)

.EXAMPLE
    .\generate-productivity-graph.ps1

.EXAMPLE
    .\generate-productivity-graph.ps1 -Days 30
#>

param(
    [string]$DataPath = "$PSScriptRoot\..\data",
    [string]$OutputPath = "$PSScriptRoot\..\output",
    [int]$Days
)

# Ensure output directory exists
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Get all JSON data files, sorted by date
$dataFiles = Get-ChildItem -Path $DataPath -Filter "commits-*.json" | Sort-Object Name

if ($Days -and $Days -lt $dataFiles.Count) {
    $dataFiles = $dataFiles | Select-Object -Last $Days
}

Write-Host "📊 Analyzing $($dataFiles.Count) days of productivity data..." -ForegroundColor Cyan

# Collect data from all files
$productivityData = @()
$allCommits = @()

foreach ($file in $dataFiles) {
    try {
        $data = Get-Content $file.FullName | ConvertFrom-Json

        $dayData = [PSCustomObject]@{
            Date = [DateTime]::Parse($data.queryStartTimeLocal)
            NetLOC = $data.summary.totalNetLOC
            TotalCommits = $data.summary.commitsByRepository | Measure-Object -Property commits -Sum | Select-Object -ExpandProperty Sum
            TotalAdditions = $data.summary.totalAdditions
            TotalDeletions = $data.summary.totalDeletions
            Repositories = $data.summary.commitsByRepository.Count
            LinesAffected = $data.summary.totalLinesAffected
        }

        $productivityData += $dayData

        # Collect individual commits for detailed analysis
        if ($data.commits) {
            $allCommits += $data.commits | ForEach-Object {
                [PSCustomObject]@{
                    Date = [DateTime]::Parse($_.date)
                    Repository = $_.repositoryName
                    NetLOC = $_.netLOC
                    Subject = $_.subject
                    Author = $_.author
                    Time = $_.time
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process $($file.Name): $($_.Exception.Message)"
    }
}

if ($productivityData.Count -eq 0) {
    Write-Error "No valid data found to analyze."
    exit 1
}

# Sort data by date
$productivityData = $productivityData | Sort-Object Date

# Generate ASCII bar chart for Net LOC
function New-AsciiBarChart {
    param(
        [array]$Data,
        [string]$Title,
        [string]$ValueProperty,
        [int]$Width = 60
    )

    Write-Host "`n$Title" -ForegroundColor Yellow
    Write-Host ("=" * ($Title.Length)) -ForegroundColor Yellow

    $maxValue = ($Data | Measure-Object -Property $ValueProperty -Maximum).Maximum
    $minValue = ($Data | Measure-Object -Property $ValueProperty -Minimum).Minimum

    # Handle negative values
    $range = [Math]::Max([Math]::Abs($maxValue), [Math]::Abs($minValue))
    if ($range -eq 0) { $range = 1 }

    foreach ($item in $Data) {
        $value = $item.$ValueProperty
        $barLength = [Math]::Round([Math]::Abs($value) / $range * $Width)
        $barChar = if ($value -ge 0) { "█" } else { "░" }
        $bar = $barChar * $barLength

        $dateStr = $item.Date.ToString("MMM dd")
        $valueStr = "{0,8:N0}" -f $value

        Write-Host ("{0,-8} {1} {2}" -f $dateStr, $bar, $valueStr)
    }
}

# Generate summary statistics
$summary = [PSCustomObject]@{
    TotalDays = $productivityData.Count
    TotalNetLOC = ($productivityData | Measure-Object -Property NetLOC -Sum).Sum
    TotalCommits = ($productivityData | Measure-Object -Property TotalCommits -Sum).Sum
    AverageDailyLOC = [Math]::Round(($productivityData | Measure-Object -Property NetLOC -Average).Average, 0)
    MaxDailyLOC = ($productivityData | Measure-Object -Property NetLOC -Maximum).Maximum
    MinDailyLOC = ($productivityData | Measure-Object -Property NetLOC -Minimum).Minimum
    MostActiveDay = ($productivityData | Sort-Object NetLOC -Descending | Select-Object -First 1).Date.ToString("yyyy-MM-dd")
    TotalRepositories = ($allCommits | Select-Object -Property Repository -Unique).Count
}

# Display summary
Write-Host "`n📈 PRODUCTIVITY SUMMARY" -ForegroundColor Green
Write-Host ("=" * 25) -ForegroundColor Green
Write-Host "Period: $($productivityData[0].Date.ToString('MMM dd, yyyy')) - $($productivityData[-1].Date.ToString('MMM dd, yyyy'))"
Write-Host "Total Days Analyzed: $($summary.TotalDays)"
Write-Host ("Total Net LOC: {0:N0}" -f $summary.TotalNetLOC)
Write-Host ("Total Commits: {0:N0}" -f $summary.TotalCommits)
Write-Host ("Average Daily LOC: {0:N0}" -f $summary.AverageDailyLOC)
Write-Host ("Peak Day LOC: {0:N0} ({1})" -f $summary.MaxDailyLOC, $summary.MostActiveDay)
Write-Host ("Lowest Day LOC: {0:N0}" -f $summary.MinDailyLOC)
Write-Host ("Active Repositories: {0:N0}" -f $summary.TotalRepositories)

# Generate ASCII charts
New-AsciiBarChart -Data $productivityData -Title "Daily Net Lines of Code (LOC)" -ValueProperty "NetLOC"
New-AsciiBarChart -Data $productivityData -Title "Daily Commits" -ValueProperty "TotalCommits"
New-AsciiBarChart -Data $productivityData -Title "Daily Repositories Worked On" -ValueProperty "Repositories"

# Generate HTML chart for more sophisticated visualization
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Productivity Analytics</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; border-left: 4px solid #007bff; }
        .stat-value { font-size: 24px; font-weight: bold; color: #007bff; }
        .stat-label { color: #666; font-size: 14px; margin-top: 5px; }
        canvas { margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Productivity Analytics Dashboard</h1>

        <div class="summary">
            <div class="stat-card">
                <div class="stat-value">$($summary.TotalNetLOC.ToString("N0"))</div>
                <div class="stat-label">Total Net LOC</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($summary.TotalCommits)</div>
                <div class="stat-label">Total Commits</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($summary.AverageDailyLOC.ToString("N0"))</div>
                <div class="stat-label">Avg Daily LOC</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($summary.TotalRepositories)</div>
                <div class="stat-label">Active Repositories</div>
            </div>
        </div>

        <canvas id="locChart" width="400" height="200"></canvas>
        <canvas id="commitsChart" width="400" height="200"></canvas>
        <canvas id="repositoriesChart" width="400" height="200"></canvas>
    </div>

    <script>
        const dates = $(($productivityData | ForEach-Object { "'$($_.Date.ToString('MMM dd'))'" }) -join ',');
        const netLOC = $(($productivityData | ForEach-Object { $_.NetLOC }) -join ',');
        const commits = $(($productivityData | ForEach-Object { $_.TotalCommits }) -join ',');
        const repositories = $(($productivityData | ForEach-Object { $_.Repositories }) -join ',');

        // Net LOC Chart
        new Chart(document.getElementById('locChart'), {
            type: 'line',
            data: {
                labels: [dates],
                datasets: [{
                    label: 'Net Lines of Code',
                    data: [netLOC],
                    borderColor: '#007bff',
                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Daily Net Lines of Code (LOC) Trend'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: false
                    }
                }
            }
        });

        // Commits Chart
        new Chart(document.getElementById('commitsChart'), {
            type: 'bar',
            data: {
                labels: [dates],
                datasets: [{
                    label: 'Commits',
                    data: [commits],
                    backgroundColor: '#28a745',
                    borderColor: '#28a745',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Daily Commits'
                    }
                }
            }
        });

        // Repositories Chart
        new Chart(document.getElementById('repositoriesChart'), {
            type: 'line',
            data: {
                labels: [dates],
                datasets: [{
                    label: 'Repositories Worked On',
                    data: [repositories],
                    borderColor: '#ffc107',
                    backgroundColor: 'rgba(255, 193, 7, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Daily Repository Activity'
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

# Generate enhanced HTML chart with individual graphs for each metric
$enhancedHtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Productivity Trends - Four Metrics</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 1600px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .metric-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .metric-label {
            font-size: 0.9em;
            opacity: 0.9;
        }
        .charts-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 30px;
            margin: 30px 0;
        }
        .chart-wrapper {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
        }
        .chart-title {
            font-size: 1.3em;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
            text-align: center;
        }
        .chart-container {
            position: relative;
            height: 350px;
        }
        .insights {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin-top: 30px;
        }
        .insights h3 {
            color: #333;
            margin-bottom: 15px;
        }
        .insights ul {
            list-style: none;
            padding: 0;
        }
        .insights li {
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }
        .insights li:last-child {
            border-bottom: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📈 Productivity Trends Dashboard</h1>
        <div class="subtitle">Daily metrics from $($productivityData[0].Date.ToString('MMM dd, yyyy')) to $($productivityData[-1].Date.ToString('MMM dd, yyyy'))</div>

        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-value">$($summary.TotalNetLOC.ToString("N0"))</div>
                <div class="metric-label">Total Net LOC</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">$($summary.TotalCommits)</div>
                <div class="metric-label">Total Commits</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">$($summary.AverageDailyLOC.ToString("N0"))</div>
                <div class="metric-label">Avg Daily LOC</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">$($summary.TotalRepositories)</div>
                <div class="metric-label">Active Repos</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">$($summary.MaxDailyLOC.ToString("N0"))</div>
                <div class="metric-label">Peak Day LOC</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">$($summary.TotalDays)</div>
                <div class="metric-label">Days Analyzed</div>
            </div>
        </div>

        <div class="charts-grid">
            <div class="chart-wrapper">
                <div class="chart-title">📊 Net Lines of Code (LOC)</div>
                <div class="chart-container">
                    <canvas id="locChart"></canvas>
                </div>
            </div>
            <div class="chart-wrapper">
                <div class="chart-title">📝 Daily Commits</div>
                <div class="chart-container">
                    <canvas id="commitsChart"></canvas>
                </div>
            </div>
            <div class="chart-wrapper">
                <div class="chart-title">🏗️ Repositories Worked On</div>
                <div class="chart-container">
                    <canvas id="repositoriesChart"></canvas>
                </div>
            </div>
            <div class="chart-wrapper">
                <div class="chart-title">📈 Lines Affected (Total)</div>
                <div class="chart-container">
                    <canvas id="linesAffectedChart"></canvas>
                </div>
            </div>
        </div>

        <div class="insights">
            <h3>🔍 Key Insights</h3>
            <ul>
                <li><strong>Peak Performance:</strong> $($summary.MostActiveDay) with $($summary.MaxDailyLOC.ToString("N0")) lines of code</li>
                $(if ($repoActivity -and $repoActivity.Count -gt 0) {
                    "<li><strong>Most Active Repository:</strong> $($repoActivity[0].Name) ($($repoActivity[0].TotalLOC.ToString("N0")) LOC, $($repoActivity[0].Count) commits)</li>"
                } else {
                    "<li><strong>Most Active Repository:</strong> No repository data available</li>"
                })
                <li><strong>Consistency:</strong> Average $($summary.AverageDailyLOC.ToString("N0")) LOC per day across $($summary.TotalDays) days</li>
                <li><strong>Repository Diversity:</strong> Code contributed to $($summary.TotalRepositories) different repositories</li>
                <li><strong>Productivity Range:</strong> From $($summary.MinDailyLOC.ToString("N0")) to $($summary.MaxDailyLOC.ToString("N0")) LOC per day</li>
            </ul>
        </div>
    </div>

    <script>
        const dates = [$(($productivityData | ForEach-Object { "'$($_.Date.ToString('MMM dd'))'" }) -join ',')];
        const netLOC = [$(($productivityData | ForEach-Object { $_.NetLOC }) -join ',')];
        const commits = [$(($productivityData | ForEach-Object { $_.TotalCommits }) -join ',')];
        const repositories = [$(($productivityData | ForEach-Object { $_.Repositories }) -join ',')];
        const linesAffected = [$(($productivityData | ForEach-Object { $_.LinesAffected }) -join ',')];

        // Net LOC Chart
        const ctxLOC = document.getElementById('locChart').getContext('2d');
        new Chart(ctxLOC, {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Net LOC',
                    data: netLOC,
                    borderColor: '#007bff',
                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 5,
                    pointHoverRadius: 7,
                    borderWidth: 3
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0,0,0,0.8)',
                        titleColor: 'white',
                        bodyColor: 'white',
                        callbacks: {
                            label: function(context) {
                                return 'LOC: ' + new Intl.NumberFormat().format(context.parsed.y);
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: false,
                        ticks: {
                            callback: function(value) {
                                return new Intl.NumberFormat().format(value);
                            }
                        }
                    }
                }
            }
        });

        // Commits Chart
        const ctxCommits = document.getElementById('commitsChart').getContext('2d');
        new Chart(ctxCommits, {
            type: 'bar',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Commits',
                    data: commits,
                    backgroundColor: '#28a745',
                    borderColor: '#28a745',
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0,0,0,0.8)',
                        titleColor: 'white',
                        bodyColor: 'white',
                        callbacks: {
                            label: function(context) {
                                return 'Commits: ' + context.parsed.y;
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1
                        }
                    }
                }
            }
        });

        // Repositories Chart
        const ctxRepos = document.getElementById('repositoriesChart').getContext('2d');
        new Chart(ctxRepos, {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Repositories',
                    data: repositories,
                    borderColor: '#ffc107',
                    backgroundColor: 'rgba(255, 193, 7, 0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 5,
                    pointHoverRadius: 7,
                    borderWidth: 3
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0,0,0,0.8)',
                        titleColor: 'white',
                        bodyColor: 'white',
                        callbacks: {
                            label: function(context) {
                                return 'Repos: ' + context.parsed.y;
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1
                        }
                    }
                }
            }
        });

        // Lines Affected Chart
        const ctxLines = document.getElementById('linesAffectedChart').getContext('2d');
        new Chart(ctxLines, {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Lines Affected',
                    data: linesAffected,
                    borderColor: '#dc3545',
                    backgroundColor: 'rgba(220, 53, 69, 0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 5,
                    pointHoverRadius: 7,
                    borderWidth: 3
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0,0,0,0.8)',
                        titleColor: 'white',
                        bodyColor: 'white',
                        callbacks: {
                            label: function(context) {
                                return 'Lines: ' + new Intl.NumberFormat().format(context.parsed.y);
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            callback: function(value) {
                                return new Intl.NumberFormat().format(value);
                            }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

# Save enhanced HTML report
$enhancedHtmlPath = Join-Path $OutputPath "productivity-trends.html"
$enhancedHtmlContent | Out-File -FilePath $enhancedHtmlPath -Encoding UTF8

Write-Host "`n📈 Four-metric dashboard saved to: $enhancedHtmlPath" -ForegroundColor Cyan
Write-Host "🌐 Now showing 4 separate graphs with proper Y-axis scaling!" -ForegroundColor Green

# Generate text report
$textReport = @"
PRODUCTIVITY REPORT
===================

Analysis Period: $($productivityData[0].Date.ToString('yyyy-MM-dd')) to $($productivityData[-1].Date.ToString('yyyy-MM-dd'))
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

SUMMARY STATISTICS
------------------
Total Days Analyzed: $($summary.TotalDays)
Total Net LOC: $($summary.TotalNetLOC.ToString("N0"))
Total Commits: $($summary.TotalCommits)
Average Daily LOC: $($summary.AverageDailyLOC.ToString("N0"))
Peak Daily LOC: $($summary.MaxDailyLOC.ToString("N0")) ($($summary.MostActiveDay))
Lowest Daily LOC: $($summary.MinDailyLOC.ToString("N0"))
Active Repositories: $($summary.TotalRepositories)

DAILY BREAKDOWN
---------------
"@

foreach ($day in $productivityData) {
    $textReport += "`n$($day.Date.ToString('yyyy-MM-dd')):"
    $textReport += "`n  Net LOC: $($day.NetLOC.ToString("N0"))"
    $textReport += "`n  Commits: $($day.TotalCommits)"
    $textReport += "`n  Repositories: $($day.Repositories)"
    $textReport += "`n  Lines Affected: $($day.LinesAffected.ToString("N0"))"
}

# Save text report
$textPath = Join-Path $OutputPath "productivity-report.txt"
$textReport | Out-File -FilePath $textPath -Encoding UTF8

Write-Host "📝 Text report saved to: $textPath" -ForegroundColor Green

# Repository activity analysis
$repoActivity = $allCommits | Group-Object Repository | Sort-Object Count -Descending | Select-Object Name, Count, @{Name="TotalLOC"; Expression={($_.Group | Measure-Object NetLOC -Sum).Sum}}

Write-Host "`n🏆 TOP REPOSITORIES BY ACTIVITY" -ForegroundColor Magenta
Write-Host ("=" * 30) -ForegroundColor Magenta
$repoActivity | Select-Object -First 10 | ForEach-Object {
    Write-Host ("{0,-25} {1,3} commits, {2,8:N0} LOC" -f $_.Name, $_.Count, $_.TotalLOC)
}

Write-Host "`n✅ Analysis complete! Check the output directory for reports and graphs." -ForegroundColor Green