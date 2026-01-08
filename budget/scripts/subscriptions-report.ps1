<#
.SYNOPSIS
    Generates a comprehensive subscription expense report from normalized budget data.

.DESCRIPTION
    Analyzes subscription transactions across all accounts (Chase Credit Card, USAA Checking, 
    USAA Spending Checking) to identify recurring charges, calculate monthly/annual costs,
    and generate a detailed Markdown report.

.PARAMETER OutputPath
    The path where the subscriptions-report.md file will be saved.
    If not specified, the user will be prompted.

.EXAMPLE
    & "c:\Users\franz\.claude\skills\budget\scripts\subscriptions-report.ps1"
    
.EXAMPLE
    & "c:\Users\franz\.claude\skills\budget\scripts\subscriptions-report.ps1" -OutputPath "C:\Reports\subscriptions-report.md"
#>

$InformationPreference = 'Continue'

param(
    [string]$OutputPath
)

$StatementsPath = "F:\OneDrive\Documents\Budget\Statements"

# Subscription-related categories
$SubscriptionCategories = @(
    'Subscriptions',
    'Software & Subscriptions',
    'Streaming',
    'Membership',
    'Credit Report Monitoring',
    'Gaming'
)

# Known subscription patterns for better identification
$KnownSubscriptions = @{
    'APPLE.COM/BILL' = @{ Name = 'Apple Services'; Type = 'Entertainment/Cloud'; CancelUrl = 'https://appleid.apple.com/account/subscriptions' }
    'APPLE.COM/US' = @{ Name = 'Apple Hardware/Services'; Type = 'Technology'; CancelUrl = 'https://appleid.apple.com/account/subscriptions' }
    'Microsoft*Additional 1 TB' = @{ Name = 'Microsoft 365 (1TB)'; Type = 'Productivity'; CancelUrl = 'https://account.microsoft.com/subscriptions' }
    'Microsoft*Store' = @{ Name = 'Microsoft Store'; Type = 'Software'; CancelUrl = 'https://account.microsoft.com/subscriptions' }
    'YOUTUBE' = @{ Name = 'YouTube Premium'; Type = 'Streaming'; CancelUrl = 'https://www.youtube.com/paid_memberships' }
    'GOOGLE.*PLAY' = @{ Name = 'Google Play'; Type = 'Entertainment'; CancelUrl = 'https://play.google.com/store/account/subscriptions' }
    'ESPN' = @{ Name = 'ESPN+'; Type = 'Streaming'; CancelUrl = 'https://www.espn.com/watch/espnplus' }
    'SXM*SIRIUSXM' = @{ Name = 'SiriusXM Radio'; Type = 'Entertainment'; CancelUrl = 'https://www.siriusxm.com/account' }
    'Prime Video' = @{ Name = 'Amazon Prime Video'; Type = 'Streaming'; CancelUrl = 'https://www.amazon.com/gp/video/settings/subscriptions' }
    'CURSOR AI' = @{ Name = 'Cursor AI IDE'; Type = 'Developer Tools'; CancelUrl = 'https://accounts.cursor.so/settings' }
    'COGNITION LABS' = @{ Name = 'Devin AI'; Type = 'Developer Tools'; CancelUrl = 'https://devin.ai/account' }
    'T3 CHAT' = @{ Name = 'T3 Chat AI'; Type = 'AI Tools'; CancelUrl = 'https://t3.chat/account/subscriptions' }
    'GITKRAKEN' = @{ Name = 'GitKraken'; Type = 'Developer Tools'; CancelUrl = 'https://www.gitkraken.com/account/subscriptions' }
    'TODOIST' = @{ Name = 'Todoist'; Type = 'Productivity'; CancelUrl = 'https://todoist.com/app/settings/account' }
    'THE ATLANTIC' = @{ Name = 'The Atlantic'; Type = 'News/Media'; CancelUrl = 'https://www.theatlantic.com/account/settings' }
    'THE ECONOMIST' = @{ Name = 'The Economist'; Type = 'News/Media'; CancelUrl = 'https://www.economist.com/my-account' }
    'NORDVPN' = @{ Name = 'NordVPN'; Type = 'Security'; CancelUrl = 'https://account.nordvpn.com/billing' }
    'MEE6' = @{ Name = 'MEE6 Discord Bot'; Type = 'Entertainment'; CancelUrl = 'https://mee6.xyz/account' }
    'MAP GENIE' = @{ Name = 'MapGenie+'; Type = 'Gaming'; CancelUrl = 'https://mapgenie.io/account' }
    'chessbase' = @{ Name = 'ChessBase'; Type = 'Gaming/Education'; CancelUrl = 'https://my.chessbase.com/account/subscriptions' }
    'xrealm' = @{ Name = 'xRealm Gaming'; Type = 'Gaming'; CancelUrl = 'https://xrealm.io/account' }
    'ABACUS.AI' = @{ Name = 'Abacus AI'; Type = 'AI Tools'; CancelUrl = 'https://abacus.ai/account' }
    'AUGMENT CODE' = @{ Name = 'Augment Code AI'; Type = 'Developer Tools'; CancelUrl = 'https://augment.code/account' }
}

# Patterns to exclude - generic/uncategorized transaction descriptions
$ExclusionPatterns = @(
    '^RECURRING DEB CARD PURCH',
    '^DEBIT CARD PURCHASE',
    '^DEBIT CARD REFUND',
    '^POS DEBIT',
    '^RECURRING POS DEBIT',
    '^ACH WITHDRAWAL',
    '^ACH PAYMENT',
    '^ACH CREDIT',
    '^VISA PURCHASE',
    '^ONLINE BANKING TRANSFER',
    '^WIRE TRANSFER'
)

function Get-SubscriptionName {
    param([string]$Description)
    
    foreach ($pattern in $KnownSubscriptions.Keys) {
        if ($Description -match [regex]::Escape($pattern)) {
            return $KnownSubscriptions[$pattern]
        }
    }
    return $null
}

function Get-RecurrencePattern {
    param($Transactions)
    
    if ($Transactions.Count -eq 1) {
        $amount = [math]::Abs([decimal]$Transactions[0].Amount)
        if ($amount -gt 100) {
            return "Annual (Estimated)"
        }
        return "One-time or New"
    }
    
    $dates = $Transactions | ForEach-Object { [datetime]$_.Date } | Sort-Object
    $gaps = @()
    
    for ($i = 1; $i -lt $dates.Count; $i++) {
        $gap = ($dates[$i] - $dates[$i-1]).TotalDays
        $gaps += $gap
    }
    
    if ($gaps.Count -eq 0) { return "One-time or New" }
    
    $avgGap = $gaps | Measure-Object -Average | Select-Object -ExpandProperty Average
    
    if ($avgGap -ge 25 -and $avgGap -le 35) {
        return "Monthly"
    } elseif ($avgGap -ge 85 -and $avgGap -le 95) {
        return "Quarterly"
    } elseif ($avgGap -ge 355 -and $avgGap -le 375) {
        return "Annual"
    }
    
    return "Irregular"
}

# Load all normalized CSV data
Write-Information "[36mLoading transaction data...`e[0m"
$csvFiles = Get-ChildItem "$StatementsPath\*\*.csv" -Recurse | Where-Object { $_.Name -match '^\d{4}-\d{2}\.csv$' }
$allData = @()

foreach ($file in $csvFiles) {
    $data = Import-Csv $file.FullName
    $allData += $data
}

Write-Information "[32mLoaded $($allData.Count) total transactions`e[0m"

# First, find all known subscription vendors across ALL transactions (not just subscription categories)
# This catches subscriptions that might be miscategorized
Write-Information "[36mScanning all transactions for known subscription vendors...`e[0m"
$vendorMatches = @()
foreach ($pattern in $KnownSubscriptions.Keys) {
    $matchedTransactions = $allData | Where-Object { $_.Description -match [regex]::Escape($pattern) }
    if ($matchedTransactions) {
        $vendorMatches += $matchedTransactions
    }
}

# Then also get subscription-category transactions that aren't excluded
$categoryMatches = $allData | Where-Object { $_.Category -in $SubscriptionCategories }

# Combine both sources, remove duplicates by date+description
$allSubscriptionCandidates = @($vendorMatches + $categoryMatches)
$subscriptions = @()
$seen = @{}

foreach ($tx in $allSubscriptionCandidates) {
    $key = "$($tx.Date)|$($tx.Description)"
    if (-not $seen.Contains($key)) {
        $subscriptions += $tx
        $seen[$key] = $true
    }
}

Write-Information "[32mFound $($subscriptions.Count) potential subscription transactions`e[0m"

# Check for excluded patterns
$subscriptions = $subscriptions | Where-Object {
    $desc = $_.Description
    $excluded = $false
    foreach ($pattern in $ExclusionPatterns) {
        if ($desc -match $pattern) {
            $excluded = $true
            break
        }
    }
    -not $excluded
}

Write-Information "[32mAfter exclusions: $($subscriptions.Count) transactions`e[0m"

# Group and analyze
$analyzed = $subscriptions | Group-Object Description | ForEach-Object {
    $totalAmount = ($_.Group | Measure-Object -Property Amount -Sum).Sum
    $subInfo = Get-SubscriptionName $_.Name
    
    # Skip if not a recognized subscription
    if ($null -eq $subInfo) { return }
    
    $recurrence = Get-RecurrencePattern $_.Group
    $accounts = ($_.Group | Select-Object -ExpandProperty Account -Unique) -join ", "
    $lastDate = ($_.Group | ForEach-Object { [datetime]$_.Date } | Sort-Object -Descending | Select-Object -First 1)
    $firstDate = ($_.Group | ForEach-Object { [datetime]$_.Date } | Sort-Object | Select-Object -First 1)
    
    [PSCustomObject]@{
        ServiceName = $subInfo.Name
        Category = $subInfo.Type
        RawDescription = $_.Name
        TotalSpent = [math]::Round([math]::Abs($totalAmount), 2)
        TransactionCount = $_.Count
        AvgAmount = [math]::Round([math]::Abs($totalAmount / $_.Count), 2)
        Recurrence = $recurrence
        Accounts = $accounts
        FirstSeen = $firstDate.ToString('yyyy-MM-dd')
        LastSeen = $lastDate.ToString('yyyy-MM-dd')
        EstMonthly = if ($recurrence -eq 'Monthly') { [math]::Round([math]::Abs($totalAmount / $_.Count), 2) }
                     elseif ($recurrence -match 'Annual') { [math]::Round([math]::Abs($totalAmount / $_.Count / 12), 2) }
                     elseif ($recurrence -eq 'Quarterly') { [math]::Round([math]::Abs($totalAmount / $_.Count / 3), 2) }
                     else { [math]::Round([math]::Abs($totalAmount / $_.Count), 2) }
    }
} | Sort-Object TotalSpent -Descending

# Calculate summaries
$totalSubscriptionSpend = ($analyzed | Measure-Object -Property TotalSpent -Sum).Sum
$estimatedMonthly = ($analyzed | Measure-Object -Property EstMonthly -Sum).Sum
$estimatedAnnual = $estimatedMonthly * 12

# Categorize by type
$byCategory = $analyzed | Group-Object Category | ForEach-Object {
    [PSCustomObject]@{
        Category = $_.Name
        Count = $_.Count
        TotalSpent = [math]::Round(($_.Group | Measure-Object -Property TotalSpent -Sum).Sum, 2)
        EstMonthly = [math]::Round(($_.Group | Measure-Object -Property EstMonthly -Sum).Sum, 2)
    }
} | Sort-Object TotalSpent -Descending

# By account
$byAccount = $subscriptions | Group-Object Account | ForEach-Object {
    $total = [math]::Abs(($_.Group | Measure-Object -Property Amount -Sum).Sum)
    [PSCustomObject]@{
        Account = $_.Name
        TransactionCount = $_.Count
        TotalSpent = [math]::Round($total, 2)
    }
} | Sort-Object TotalSpent -Descending

# Identify recently added and high-value subscriptions
$recentlyAdded = $analyzed | Where-Object { [datetime]$_.FirstSeen -gt (Get-Date).AddMonths(-2) } | Sort-Object FirstSeen -Descending
$highValue = $analyzed | Where-Object { $_.EstMonthly -gt 25 } | Sort-Object EstMonthly -Descending
$irregular = $analyzed | Where-Object { $_.Recurrence -eq 'Irregular' } | Sort-Object TotalSpent -Descending

# Generate report
$reportDate = Get-Date -Format 'yyyy-MM-dd HH:mm'
$dataRange = ($allData | ForEach-Object { [datetime]$_.Date } | Sort-Object)
$startDate = $dataRange | Select-Object -First 1
$endDate = $dataRange | Select-Object -Last 1

$totalSpendFormatted = ($totalSubscriptionSpend).ToString('N2')
$monthlyFormatted = ($estimatedMonthly).ToString('N2')
$annualFormatted = ($estimatedAnnual).ToString('N2')
$subsCount = $analyzed.Count

$report = @"
# 📊 Subscription Expense Report

**Generated:** $reportDate  
**Data Range:** $($startDate.ToString('MMMM yyyy')) - $($endDate.ToString('MMMM yyyy'))

---

## 💰 Summary

| Metric | Value |
|--------|-------|
| **Total Subscription Spend** | `$$totalSpendFormatted` |
| **Estimated Monthly Cost** | `$$monthlyFormatted` |
| **Projected Annual Cost** | `$$annualFormatted` |
| **Active Subscriptions** | $subsCount |

---

## 📋 All Active Subscriptions

| Service | Category | Monthly | Annual | Recurrence | Last Seen |
|---------|----------|---------|--------|-----------|-----------|
$(
    $analyzed | ForEach-Object {
        $monthlyFormatted = [decimal]$_.EstMonthly
        $annualFormatted = $monthlyFormatted * 12
        "| $($_.ServiceName) | $($_.Category) | `$$($monthlyFormatted.ToString('N2'))` | `$$($annualFormatted.ToString('N2'))` | $($_.Recurrence) | $($_.LastSeen) |"
    } | Out-String
)

---

## 📊 By Category

| Category | Count | Total Spend | Est Monthly |
|----------|-------|-------------|-------------|
$(
    $byCategory | ForEach-Object {
        "| $($_.Category) | $($_.Count) | `$$($_.TotalSpent.ToString('N2'))` | `$$($_.EstMonthly.ToString('N2'))` |"
    } | Out-String
)

---

## 🏦 By Account

| Account | Transactions | Total Spend |
|---------|-------------|------------|
$(
    $byAccount | ForEach-Object {
        "| $($_.Account) | $($_.TransactionCount) | `$$($_.TotalSpent.ToString('N2'))` |"
    } | Out-String
)

---

## 💡 Recommendations

### 🆕 Recently Added (Last 2 Months)
$(
    if ($recentlyAdded.Count -gt 0) {
        $recentlyAdded | ForEach-Object {
            "- **$($_.ServiceName)** - `$$($_.EstMonthly.ToString('N2'))`/month (added $($_.FirstSeen))"
        } | Out-String
    } else {
        "No new subscriptions added in the last 2 months."
    }
)

### 💸 High-Value Subscriptions (>$25/month)
$(
    if ($highValue.Count -gt 0) {
        "| Service | Monthly | Manage | Consider |" | Out-String
        "|---------|---------|--------|----------|" | Out-String
        $highValue | ForEach-Object {
            $rawDesc = $_.RawDescription
            $cancelUrl = $null
            foreach ($pattern in $KnownSubscriptions.Keys) {
                if ($rawDesc -match [regex]::Escape($pattern)) {
                    $cancelUrl = $KnownSubscriptions[$pattern].CancelUrl
                    break
                }
            }
            $cancelLink = if ($cancelUrl) { "[$($_.ServiceName)]($cancelUrl)" } else { "Manual" }
            "| $($_.ServiceName) | `$$($_.EstMonthly.ToString('N2'))` | $cancelLink | Review for necessity |"
        } | Out-String
    } else {
        "No subscriptions exceed \$25/month."
    }
)

### ⚠️ Irregular Subscriptions
$(
    if ($irregular.Count -gt 0) {
        $irregular | ForEach-Object {
            "- **$($_.ServiceName)** - Recurring irregularly (avg `$$($_.AvgAmount.ToString('N2'))`)"
        } | Out-String
    } else {
        "All subscriptions follow regular patterns."
    }
)

---

## 🔗 Subscription Management Links

Quick access to cancel or manage each subscription:

$(
    $analyzed | Sort-Object ServiceName | ForEach-Object {
        $rawDesc = $_.RawDescription
        $cancelUrl = $null
        foreach ($pattern in $KnownSubscriptions.Keys) {
            if ($rawDesc -match [regex]::Escape($pattern)) {
                $cancelUrl = $KnownSubscriptions[$pattern].CancelUrl
                break
            }
        }
        if ($cancelUrl) {
            "- **$($_.ServiceName)**: [$cancelUrl]($cancelUrl)"
        } else {
            "- **$($_.ServiceName)**: Manual cancellation (search provider support)"
        }
    } | Out-String
)

---

**Report Generated by Subscriptions Analyzer**
"@

# Save or display report
if ($OutputPath) {
    $report | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Information "[32m`n✅ Report saved to: $OutputPath`e[0m"
    Write-Information "[36m`nQuick Summary:`e[0m"
    Write-Information "[33m  • Total Spend: `$$totalSpendFormatted`e[0m"
    Write-Information "[33m  • Monthly Cost: `$$monthlyFormatted`e[0m"
    Write-Information "[33m  • Annual Cost: `$$annualFormatted`e[0m"
    Write-Information "[33m  • Active Subscriptions: $subsCount`e[0m"
} else {
    Write-Information "[36m`n`e[0m"
    Write-Information "[36mWhere would you like to save the report?`e[0m"
    $OutputPath = Read-Host "Enter full path (e.g., C:\Reports\subscriptions-report.md)"
    
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = "$Home\Desktop\subscriptions-report.md"
    }
    
    $report | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Information "[32m`n✅ Report saved to: $OutputPath`e[0m"
    Write-Information "[36m`nQuick Summary:`e[0m"
    Write-Information "[33m  • Total Spend: `$$totalSpendFormatted`e[0m"
    Write-Information "[33m  • Monthly Cost: `$$monthlyFormatted`e[0m"
    Write-Information "[33m  • Annual Cost: `$$annualFormatted`e[0m"
    Write-Information "[33m  • Active Subscriptions: $subsCount`e[0m"
}
