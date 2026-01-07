<#
.SYNOPSIS
    Generate Markdown budget report from normalized CSV files.
.PARAMETER AccountName
    Specific account to report on (optional - defaults to all accounts)
.EXAMPLE
    .\statement-report.ps1
    .\statement-report.ps1 -AccountName "Chase Credit Card"
#>
$InformationPreference = 'Continue'

param(
    [string]$AccountName
)

$StatementsRoot = "F:\OneDrive\Documents\Budget\Statements"
$ReportDate = Get-Date -Format "yyyy-MM-dd"

function Get-AccountReport {
    param([string]$Account, [string]$Path)
    
    $NormalizedFiles = Get-ChildItem "$Path\*.csv" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '^\d{4}-\d{2}\.csv$' }
    
    if (-not $NormalizedFiles) { return $null }
    
    $AllTransactions = @()
    foreach ($File in $NormalizedFiles) {
        $Csv = Import-Csv $File.FullName
        $AllTransactions += $Csv
    }
    
    if ($AllTransactions.Count -eq 0) { return $null }
    
    # Calculate totals
    $TotalIncome = 0
    $TotalExpense = 0
    $ByCategory = @{}
    $ByMonth = @{}
    
    foreach ($Txn in $AllTransactions) {
        $Amount = [decimal]$Txn.Amount
        $Category = $Txn.Category
        $Month = $Txn.Date.Substring(0, 7)  # YYYY-MM
        
        if ($Amount -gt 0) {
            $TotalIncome += $Amount
        } else {
            $TotalExpense += $Amount
        }
        
        # By category
        if (-not $ByCategory[$Category]) {
            $ByCategory[$Category] = @{ Income = 0; Expense = 0; Count = 0 }
        }
        $ByCategory[$Category].Count++
        if ($Amount -gt 0) {
            $ByCategory[$Category].Income += $Amount
        } else {
            $ByCategory[$Category].Expense += $Amount
        }
        
        # By month
        if (-not $ByMonth[$Month]) {
            $ByMonth[$Month] = @{ Income = 0; Expense = 0; Count = 0 }
        }
        $ByMonth[$Month].Count++
        if ($Amount -gt 0) {
            $ByMonth[$Month].Income += $Amount
        } else {
            $ByMonth[$Month].Expense += $Amount
        }
    }
    
    return @{
        Account = $Account
        TotalTransactions = $AllTransactions.Count
        TotalIncome = $TotalIncome
        TotalExpense = $TotalExpense
        NetCashFlow = $TotalIncome + $TotalExpense
        ByCategory = $ByCategory
        ByMonth = $ByMonth
        DateRange = ($NormalizedFiles | Sort-Object Name | Select-Object -First 1).BaseName + " to " + 
                    ($NormalizedFiles | Sort-Object Name | Select-Object -Last 1).BaseName
    }
}

function Format-Currency {
    param([decimal]$Value)
    if ($Value -lt 0) {
        return "-`${0:N2}" -f [Math]::Abs($Value)
    }
    return "`${0:N2}" -f $Value
}

function Write-AccountReport {
    param($Report)
    
    $Md = @()
    $Md += "# $($Report.Account)"
    $Md += ""
    $Md += "**Period:** $($Report.DateRange)"
    $Md += "**Transactions:** $($Report.TotalTransactions)"
    $Md += ""
    $Md += "## Summary"
    $Md += ""
    $Md += "| Metric | Amount |"
    $Md += "|--------|-------:|"
    $Md += "| **Total Income** | $(Format-Currency $Report.TotalIncome) |"
    $Md += "| **Total Expenses** | $(Format-Currency $Report.TotalExpense) |"
    $Md += "| **Net Cash Flow** | $(Format-Currency $Report.NetCashFlow) |"
    $Md += ""
    
    # Monthly breakdown
    $Md += "## Monthly Breakdown"
    $Md += ""
    $Md += "| Month | Income | Expenses | Net | Txns |"
    $Md += "|-------|-------:|---------:|----:|-----:|"
    foreach ($Month in $Report.ByMonth.Keys | Sort-Object) {
        $M = $Report.ByMonth[$Month]
        $Net = $M.Income + $M.Expense
        $Md += "| $Month | $(Format-Currency $M.Income) | $(Format-Currency $M.Expense) | $(Format-Currency $Net) | $($M.Count) |"
    }
    $Md += ""
    
    # Category breakdown (sorted by expense amount)
    $Md += "## By Category"
    $Md += ""
    $Md += "| Category | Expenses | Income | Count |"
    $Md += "|----------|----------:|-------:|------:|"
    $SortedCategories = $Report.ByCategory.GetEnumerator() | 
        Sort-Object { $_.Value.Expense } | 
        ForEach-Object { $_.Key }
    foreach ($Cat in $SortedCategories) {
        $C = $Report.ByCategory[$Cat]
        $Md += "| $Cat | $(Format-Currency $C.Expense) | $(Format-Currency $C.Income) | $($C.Count) |"
    }
    $Md += ""
    
    return $Md -join "`n"
}

# Main
$Accounts = @()
if ($AccountName) {
    $Accounts = @($AccountName)
} else {
    $Accounts = Get-ChildItem $StatementsRoot -Directory | ForEach-Object { $_.Name }
}

$AllReports = @()
foreach ($Acct in $Accounts) {
    $Path = Join-Path $StatementsRoot $Acct
    $Report = Get-AccountReport -Account $Acct -Path $Path
    if ($Report) {
        $AllReports += $Report
    }
}

if ($AllReports.Count -eq 0) {
    Write-Information "No normalized data found." -ForegroundColor Yellow
    exit
}

# Generate combined report
$Output = @()
$Output += "# Budget Report"
$Output += ""
$Output += "Generated: $ReportDate"
$Output += ""

# Overall summary
$GrandIncome = ($AllReports | Measure-Object -Property TotalIncome -Sum).Sum
$GrandExpense = ($AllReports | Measure-Object -Property TotalExpense -Sum).Sum
$GrandNet = $GrandIncome + $GrandExpense
$GrandTxns = ($AllReports | Measure-Object -Property TotalTransactions -Sum).Sum

$Output += "## All Accounts Overview"
$Output += ""
$Output += "| Account | Income | Expenses | Net | Txns |"
$Output += "|---------|-------:|---------:|----:|-----:|"
foreach ($R in $AllReports | Sort-Object { $_.TotalExpense }) {
    $Output += "| $($R.Account) | $(Format-Currency $R.TotalIncome) | $(Format-Currency $R.TotalExpense) | $(Format-Currency $R.NetCashFlow) | $($R.TotalTransactions) |"
}
$Output += "| **TOTAL** | **$(Format-Currency $GrandIncome)** | **$(Format-Currency $GrandExpense)** | **$(Format-Currency $GrandNet)** | **$GrandTxns** |"
$Output += ""

# Per-account detail
foreach ($R in $AllReports | Sort-Object Account) {
    $Output += "---"
    $Output += ""
    $Output += (Write-AccountReport $R)
}

$ReportPath = Join-Path $StatementsRoot "budget-report.md"
$Output -join "`n" | Out-File $ReportPath -Encoding UTF8

Write-Information "Report generated: $ReportPath" -ForegroundColor Green
Write-Information ""
Write-Information "=== TOTALS ===" -ForegroundColor Cyan
Write-Information "Total Income:   $(Format-Currency $GrandIncome)" -ForegroundColor Green
Write-Information "Total Expenses: $(Format-Currency $GrandExpense)" -ForegroundColor Red
Write-Information "Net Cash Flow:  $(Format-Currency $GrandNet)" -ForegroundColor $(if ($GrandNet -ge 0) { 'Green' } else { 'Red' })
Write-Information "Transactions:   $GrandTxns"
