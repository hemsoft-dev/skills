param(
    [Parameter(Mandatory = $false)]
    [string]$Date = (Get-Date).ToString("yyyy-MM-dd")
)

# Calculate week boundaries
$targetDate = Get-Date $Date
$dayOfWeek = $targetDate.DayOfWeek
$daysFromMonday = ($dayOfWeek.value__ + 6) % 7
$monday = $targetDate.AddDays(-$daysFromMonday)
$friday = $monday.AddDays(4)

Write-Information "Week: $($monday.ToString('yyyy-MM-dd')) to $($friday.ToString('yyyy-MM-dd'))" -InformationAction Continue

# Get account ID
$email = $env:ATLASSIAN_EMAIL
$jiraToken = $env:ATLASSIAN_API_TOKEN
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${jiraToken}"))
$headers = @{
    "Authorization" = "Basic $auth"
    "Accept"        = "application/json"
}

try {
    $userResponse = Invoke-RestMethod -Uri "https://relias.atlassian.net/rest/api/3/myself" -Headers $headers -Method Get
    $accountId = $userResponse.accountId
    $displayName = $userResponse.displayName
}
catch {
    Write-Error "Failed to get Jira user info: $_"
    exit 1
}

# Query Tempo for the week
$tempoToken = $env:TEMPO_API_TOKEN
$tempoHeaders = @{
    "Authorization" = "Bearer $tempoToken"
    "Accept"        = "application/json"
}

$from = $monday.ToString("yyyy-MM-dd")
$to = $friday.ToString("yyyy-MM-dd")
$tempoUrl = "https://api.tempo.io/4/worklogs/user/$accountId`?from=$from&to=$to"

try {
    $worklogs = Invoke-RestMethod -Uri $tempoUrl -Headers $tempoHeaders -Method Get
}
catch {
    Write-Error "Failed to get Tempo worklogs: $_"
    exit 1
}

# Calculate totals
$totalSeconds = ($worklogs.results | Measure-Object -Property timeSpentSeconds -Sum).Sum
$totalHours = [Math]::Round($totalSeconds / 3600, 2)

Write-Information "`nTempo Weekly Hours for $displayName" -InformationAction Continue
Write-Information "Week: $($monday.ToString('MMM dd')) - $($friday.ToString('MMM dd, yyyy'))" -InformationAction Continue
Write-Information "" -InformationAction Continue

# Daily breakdown
Write-Information "Daily Breakdown:" -InformationAction Continue
Write-Information "Date       Day Hours" -InformationAction Continue
Write-Information "----       --- -----" -InformationAction Continue

for ($i = 0; $i -lt 5; $i++) {
    $currentDay = $monday.AddDays($i)
    $dateStr = $currentDay.ToString("yyyy-MM-dd")
    $dayStr = $currentDay.ToString("ddd")
    $dayWorklogs = $worklogs.results | Where-Object { $_.startDate -eq $dateStr }
    $daySeconds = ($dayWorklogs | Measure-Object -Property timeSpentSeconds -Sum).Sum
    $dayHours = [Math]::Round($daySeconds / 3600, 2)
    Write-Information "$dateStr $dayStr  $($dayHours.ToString('0.00'))" -InformationAction Continue
}

Write-Information "" -InformationAction Continue
Write-Information "Total:  $($totalHours.ToString('0.00')) hours" -InformationAction Continue
Write-Information "Target: 40.00 hours" -InformationAction Continue
$diff = $totalHours - 40
$diffStr = if ($diff -ge 0) { "+$($diff.ToString('0.00'))" } else { $diff.ToString('0.00') }
Write-Information "Diff:   $diffStr hours" -InformationAction Continue
Write-Information "" -InformationAction Continue

if ($totalHours -ge 40) {
    Write-Information "✓ You have logged 40 or more hours this week!" -InformationAction Continue
    exit 0
}
else {
    $remaining = 40 - $totalHours
    Write-Information "✗ You have NOT logged 40 hours yet." -InformationAction Continue
    Write-Information "  Remaining: $($remaining.ToString('0.00')) hours" -InformationAction Continue
    exit 1
}
