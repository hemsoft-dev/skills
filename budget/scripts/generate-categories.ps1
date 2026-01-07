# generate-categories.ps1
# One-time script to generate category-choices.txt by analyzing all CSV files

$StatementsRoot = "F:\OneDrive\Documents\Budget\Statements"
$Year = "2025"
$CategoryFile = Join-Path $StatementsRoot "category-choices.txt"

# Collect sample transactions from all accounts
$SampleContent = @()

Get-ChildItem -Path $StatementsRoot -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName $Year)
} | ForEach-Object {
    $AccountName = $_.Name
    $YearFolder = Join-Path $_.FullName $Year
    
    Get-ChildItem -Path $YearFolder -Filter "*.csv" -File | Select-Object -First 2 | ForEach-Object {
        $SampleContent += "=== $AccountName ==="
        $SampleContent += Get-Content $_.FullName -TotalCount 30
        $SampleContent += ""
    }
}

$SampleText = $SampleContent -join "`n"

$Prompt = @"
Analyze these bank/credit card statement CSV samples and create a comprehensive list of spending categories.

Requirements:
- Output ONLY the category names, one per line
- Include common categories like: Income, Groceries, Utilities, Rent/Mortgage, Transportation, Dining, Entertainment, Healthcare, Insurance, Subscriptions, Shopping, Travel, Fees, Transfer, etc.
- Add any specific categories you see in the data
- Keep categories broad enough to be useful but specific enough to be meaningful
- Sort alphabetically

Statement samples:
$SampleText
"@

Write-Host "Generating categories using Copilot CLI..." -ForegroundColor Cyan
$Categories = & copilot --model claude-haiku-4.5 -p $Prompt

# Save to file
$Categories | Out-File -FilePath $CategoryFile -Encoding UTF8

Write-Host "`nCategories saved to: $CategoryFile" -ForegroundColor Green
Write-Host "`nGenerated categories:"
Get-Content $CategoryFile
