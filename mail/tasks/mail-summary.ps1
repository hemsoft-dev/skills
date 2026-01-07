<#
.SYNOPSIS
    Get daily email summary/digest across accounts.
.DESCRIPTION
    Parent orchestrator - provides a comprehensive daily view including:
    - Today's email count per account
    - Unread count per account
    - Recent important emails (newest unread)
    Output is in TOON format for token efficiency.
.PARAMETER Account
    Specific account to query. If omitted, queries ALL configured accounts.
#>
param(
    [ValidateSet("outlook", "gmail", "work", "hemmer.us")]
    [string]$Account
)

$ErrorActionPreference = 'Stop'

# Active accounts (work is blocked awaiting org admin consent)
$AllAccounts = @('outlook', 'gmail', 'hemmer.us')
$Accounts = if ($Account) { @($Account) } else { $AllAccounts }

$Results = @()
$HighlightMessages = @()

foreach ($acct in $Accounts) {
    $childScript = Join-Path $PSScriptRoot "$acct\mail-summary.ps1"
    
    if (-not (Test-Path $childScript)) {
        $Results += @{ account = $acct; configured = $false }
        continue
    }
    
    try {
        $result = & $childScript
        
        if ($result.configured -eq $false) {
            $Results += @{ account = $acct; configured = $false }
            continue
        }
        
        $Results += @{
            account    = $acct
            configured = $true
            today      = $result.today
            unread     = $result.unread
            total      = $result.total
        }
        
        if ($result.highlights) {
            foreach ($m in $result.highlights) {
                $m.account = $acct
                $HighlightMessages += $m
            }
        }
    }
    catch {
        $Results += @{
            account    = $acct
            configured = $true
            today      = 0
            unread     = 0
            error      = $_.Exception.Message
        }
    }
}

# Output in TOON format
$configuredResults = $Results | Where-Object { $_.configured }
$todayDate = (Get-Date).ToString("yyyy-MM-dd")

Write-Output "date: $todayDate"
Write-Output ""
Write-Output "accounts[$($configuredResults.Count)]{account,today,unread,total}:"
foreach ($r in $configuredResults) {
    Write-Output "  $($r.account),$($r.today),$($r.unread),$($r.total)"
}

$totalToday = ($configuredResults | Measure-Object -Property today -Sum).Sum
$totalUnread = ($configuredResults | Measure-Object -Property unread -Sum).Sum
$totalAll = ($configuredResults | Measure-Object -Property total -Sum).Sum

Write-Output ""
Write-Output "totals{today,unread,inbox}:"
Write-Output "  $totalToday,$totalUnread,$totalAll"

if ($HighlightMessages.Count -gt 0) {
    Write-Output ""
    Write-Output "highlights[$($HighlightMessages.Count)]{status,date,from,subject,account}:"
    foreach ($m in $HighlightMessages) {
        $from = ($m.from -replace ',', ';' -replace '"', '') -replace '^(.{35}).*', '$1...'
        $subject = ($m.subject -replace ',', ';') -replace '^(.{45}).*', '$1...'
        $dateShort = if ($m.date -match '(\d+/\d+)\s+(\d+:\d+)') { "$($Matches[1]) $($Matches[2])" } else { $m.date }
        Write-Output "  $($m.status)`t$dateShort`t$from`t$subject`t$($m.account)"
    }
}

$unconfigured = $Results | Where-Object { -not $_.configured }
if ($unconfigured.Count -gt 0) {
    Write-Output ""
    Write-Output "unconfigured: $(($unconfigured.account) -join ',')"
}
