<#
.SYNOPSIS
    Get today's email count/list across accounts.
.DESCRIPTION
    Parent orchestrator - calls child scripts for each account.
    Output is in TOON format for token efficiency.
.PARAMETER Account
    Specific account to query. If omitted, queries ALL configured accounts.
.PARAMETER List
    If specified, lists individual messages instead of just counts.
.PARAMETER Count
    Number of messages to list when using -List (default: 10, max: 50).
#>
param(
    [ValidateSet("outlook", "gmail", "work", "hemmer.us")]
    [string]$Account,
    [switch]$List,
    [int]$Count = 10
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

# Active accounts (work is blocked awaiting org admin consent)
$AllAccounts = @('outlook', 'gmail', 'hemmer.us')
$Accounts = if ($Account) { @($Account) } else { $AllAccounts }

$Results = @()
$AllMessages = @()
$TotalCount = 0
$TotalUnread = 0

foreach ($acct in $Accounts) {
    $childScript = Join-Path $PSScriptRoot "$acct\mail-today.ps1"
    
    if (-not (Test-Path $childScript)) {
        $Results += @{ account = $acct; configured = $false; today = 0; unread = 0 }
        continue
    }
    
    try {
        $result = & $childScript -List:$List -Count $Count
        
        if ($result.configured -eq $false) {
            $Results += @{ account = $acct; configured = $false; today = 0; unread = 0 }
            continue
        }
        
        $Results += @{
            account = $acct
            configured = $true
            today = $result.today
            unread = $result.unread
        }
        
        $TotalCount += $result.today
        $TotalUnread += $result.unread
        
        if ($List -and $result.messages) {
            foreach ($m in $result.messages) {
                $m.account = $acct
                $AllMessages += $m
            }
        }
    }
    catch {
        $Results += @{
            account = $acct
            configured = $true
            today = 0
            unread = 0
            error = $_.Exception.Message
        }
    }
}

# Output in TOON format
$configuredResults = $Results | Where-Object { $_.configured }
Write-Output "counts[$($configuredResults.Count)]{account,today,unread}:"
foreach ($r in $configuredResults) {
    Write-Output "  $($r.account),$($r.today),$($r.unread)"
}
Write-Output "total: $TotalCount"
Write-Output "unread: $TotalUnread"

if ($List -and $AllMessages.Count -gt 0) {
    $AllMessages = $AllMessages | Select-Object -First $Count
    Write-Output ""
    Write-Output "emails[$($AllMessages.Count)]{status,date,from,subject,id,account}:"
    foreach ($m in $AllMessages) {
        $from = ($m.from -replace ',', ';' -replace '"', '') -replace '^(.{40}).*', '$1...'
        $subject = ($m.subject -replace ',', ';') -replace '^(.{50}).*', '$1...'
        $dateShort = if ($m.date -match '(\d+/\d+/\d+)\s+(\d+:\d+)') { "$($Matches[1]) $($Matches[2])" } else { $m.date }
        Write-Output "  $($m.status)`t$dateShort`t$from`t$subject`t$($m.id)`t$($m.account)"
    }
}

# Show unconfigured accounts
$unconfigured = $Results | Where-Object { -not $_.configured }
if ($unconfigured.Count -gt 0) {
    Write-Output ""
    Write-Output "unconfigured: $(($unconfigured.account) -join ',')"
}
