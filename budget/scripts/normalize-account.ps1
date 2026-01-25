<#
.SYNOPSIS
    Normalizes bank statement CSVs with AI categorization

.DESCRIPTION
    Processes all CSV files across all year folders for a given account and 
    categorizes transactions using Claude Sonnet via copilot CLI tool.
    
    Creates normalized monthly CSV files (YYYY-MM.csv) with format:
    Date,Account,Category,Description,Amount

.PARAMETER AccountName
    Name of the account folder (e.g., "USAA Classic Checking")
    Must match a folder name under the Statements root directory.

.EXAMPLE
    .\normalize-account.ps1 -AccountName "USAA Classic Checking"
    Processes all years for USAA Classic Checking account

.EXAMPLE
    .\normalize-account.ps1 -AccountName "Chase Credit Card"
    Processes all years for Chase Credit Card account

.REQUIREMENTS
    - copilot CLI tool installed and configured
    - category-choices.txt in statements root directory
    - CSV files in {AccountName}/YYYY/ folders (year subfolders)
    
.NOTES
    Version: 2.0
    - Processes all year folders dynamically (2024, 2025, 2026, etc.)
    - Validates all required paths and files before processing
    - Single batched AI call per account reduces costs
    - Output files created in account root (not year folders)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AccountName
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

# ============================================================================
# Configuration & Validation
# ============================================================================

$StatementsRoot = "D:\OneDrive\Documents\Budget\Statements"
$AccountRoot = "$StatementsRoot\$AccountName"
$CategoryFile = "$StatementsRoot\category-choices.txt"

# Validate statements root
if (-not (Test-Path $StatementsRoot)) {
    Write-Information "`e[31mERROR: Statements root not found: $StatementsRoot`e[0m"
    Write-Information "Fix: Verify OneDrive path is correct"
    exit 1
}

# Validate account folder
if (-not (Test-Path $AccountRoot)) {
    Write-Information "`e[31mERROR: Account folder not found: $AccountRoot`e[0m"
    Write-Information "Available accounts:"
    Get-ChildItem $StatementsRoot -Directory | ForEach-Object { Write-Information "  - $($_.Name)" }
    exit 1
}

# Validate category file
if (-not (Test-Path $CategoryFile)) {
    Write-Information "`e[31mERROR: Category file not found: $CategoryFile`e[0m"
    Write-Information "Fix: Create category-choices.txt with transaction categories"
    exit 1
}

# Load categories
$CategoriesContent = Get-Content $CategoryFile
$Categories = $CategoriesContent -join "`n"

# Find all year folders (2024, 2025, 2026, etc.)
$YearFolders = Get-ChildItem $AccountRoot -Directory | Where-Object { $_.Name -match '^\d{4}$' } | Sort-Object Name
if ($YearFolders.Count -eq 0) {
    Write-Information "`e[33mNo year folders found in $AccountRoot`e[0m"
    Write-Information "Expected folders: 2024/, 2025/, 2026/, etc."
    exit 0
}

Write-Information "`e[36m[$AccountName] Found $($YearFolders.Count) year folder(s): $($YearFolders.Name -join ', ')`e[0m"

# ============================================================================
# Collect Transactions from All Years
# ============================================================================

$AllLines = @()
$FileCount = 0

foreach ($YearFolder in $YearFolders) {
    # Get source CSVs (exclude already-normalized YYYY-MM.csv files)
    $Files = Get-ChildItem "$($YearFolder.FullName)\*.csv" | 
             Where-Object { $_.Name -notmatch '^\d{4}-\d{2}\.csv$' -and $_.Name -ne 'all_transactions.csv' } | 
             Sort-Object Name
    
    if ($Files.Count -eq 0) {
        Write-Information "  [$($YearFolder.Name)] No source CSV files found, skipping..."
        continue
    }
    
    Write-Information "`e[36m  [$($YearFolder.Name)] Loading $($Files.Count) source files...`e[0m"
    
    foreach ($File in $Files) {
        $Lines = Get-Content $File.FullName | Select-Object -Skip 1  # Skip header
        if ($Lines.Count -gt 0) {
            $AllLines += $Lines
            $FileCount++
            Write-Information "    $($File.Name): $($Lines.Count) lines"
        }
    }
}

$TotalInput = $AllLines.Count
Write-Information "`e[36m[$AccountName] $TotalInput total transactions from $FileCount files`e[0m"

if ($TotalInput -eq 0) {
    Write-Information "`e[33mNo transactions found to process`e[0m"
    exit 0
}

# ============================================================================
# AI Categorization (Single Batched Call)
# ============================================================================

# Build combined CSV
$CombinedCsv = "Date,Description,Amount`n" + ($AllLines -join "`n")

# Build prompt
$Prompt = @"
Convert to normalized CSV. Output ONLY CSV data lines, no headers, no markdown, no explanations.

Format per line: Date,Account,Category,Description,Amount
- Date: YYYY-MM-DD
- Account: $AccountName  
- Category: from list below
- Description: clean merchant name
- Amount: negative=expense, POSITIVE for payments/credits

Categories:
$Categories

CSV data:
$CombinedCsv
"@

# Write prompt to temp file (avoids escaping issues)
$TempFile = [System.IO.Path]::GetTempFileName()
$Prompt | Out-File -FilePath $TempFile -Encoding utf8

Write-Information "`e[33m[$AccountName] Calling AI (1 request for $TotalInput transactions)...`e[0m"

try {
    # Call copilot with piped input
    $Result = Get-Content $TempFile | Out-String | copilot --model claude-sonnet-4
}
catch {
    Write-Information "`e[31mERROR: Failed to call copilot CLI`e[0m"
    Write-Information "Fix: Ensure 'copilot' is installed and in PATH"
    Remove-Item $TempFile -Force
    exit 1
}
finally {
    Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
}

# Parse output - only lines starting with YYYY-MM-DD,
$NormalizedLines = $Result -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2},' }

Write-Information "`e[36m[$AccountName] Got $($NormalizedLines.Count) normalized transactions`e[0m"

if ($NormalizedLines.Count -eq 0) {
    Write-Information "`e[31mERROR: No transactions parsed from AI output`e[0m"
    Write-Information "Raw output (first 500 chars):"
    Write-Information ($Result.Substring(0, [Math]::Min(500, $Result.Length)))
    exit 1
}

# Validate we didn't lose transactions
$LostTransactions = $TotalInput - $NormalizedLines.Count
if ($LostTransactions -gt 0) {
    Write-Information "`e[33mWARNING: $LostTransactions transactions were not categorized by AI`e[0m"
    Write-Information "This may indicate parsing issues in source CSVs or AI filtering"
}

# ============================================================================
# Group by Month & Write Output Files
# ============================================================================

$AllData = @{}
foreach ($Line in $NormalizedLines) {
    if ($Line -match "^(\d{4}-\d{2})") {
        $Month = $Matches[1]
        if (-not $AllData[$Month]) { $AllData[$Month] = @() }
        $AllData[$Month] += $Line
    }
}

# Write output files to account root
$Header = "Date,Account,Category,Description,Amount"
$MonthsProcessed = 0

Write-Information ""
foreach ($Month in $AllData.Keys | Sort-Object) {
    $OutFile = "$AccountRoot\$Month.csv"
    (@($Header) + $AllData[$Month]) -join "`n" | Out-File $OutFile -Encoding UTF8
    Write-Information "`e[32m  Created: $Month.csv ($($AllData[$Month].Count) transactions)`e[0m"
    $MonthsProcessed++
}

# ============================================================================
# Summary
# ============================================================================

Write-Information ""
Write-Information "`e[36m========================================`e[0m"
Write-Information "`e[36m[$AccountName] Processing Complete`e[0m"
Write-Information "`e[36m========================================`e[0m"
Write-Information "  Years processed: $($YearFolders.Count) ($($YearFolders.Name -join ', '))"
Write-Information "  Source files: $FileCount"
Write-Information "  Total transactions: $TotalInput"
Write-Information "  Normalized transactions: $($NormalizedLines.Count)"
Write-Information "  Monthly CSV files created: $MonthsProcessed"
Write-Information "`e[36m========================================`e[0m"
