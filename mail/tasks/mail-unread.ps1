<#
.SYNOPSIS
    List unread emails across accounts.
.DESCRIPTION
    Parent orchestrator - calls child scripts for each account.
    Output is in TOON format for token efficiency.
.PARAMETER Account
    Specific account to query. If omitted, queries ALL configured accounts.
.PARAMETER Count
    Number of messages per account (default: 10, max: 50).
#>
param(
    [ValidateSet("outlook", "gmail", "work", "hemmer.us")]
    [string]$Account,
    [int]$Count = 10
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

# Active accounts (work is blocked awaiting org admin consent)
$AllAccounts = @('outlook', 'gmail', 'hemmer.us')
$Accounts = if ($Account) { @($Account) } else { $AllAccounts }

$Results = @()
$AllMessages = @()

foreach ($acct in $Accounts) {
    $childScript = Join-Path $PSScriptRoot "$acct\mail-unread.ps1"
    
    if (-not (Test-Path $childScript)) {
        $Results += @{ account = $acct; configured = $false; count = 0 }
        continue
    }
    
    try {
        $result = & $childScript -Count $Count
        
        if ($result.configured -eq $false) {
            $Results += @{ account = $acct; configured = $false; count = 0 }
            continue
        }
        
        $Results += @{
            account = $acct
            configured = $true
            count = $result.count
        }
        
        if ($result.messages) {
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
            count = 0
            error = $_.Exception.Message
        }
    }
}

# Output in TOON format
$configuredResults = @($Results | Where-Object { $_.configured })
$totalUnread = ($configuredResults | Measure-Object -Property count -Sum).Sum

Write-Output "summary[$($configuredResults.Count)]{account,count}:"
foreach ($r in $configuredResults) {
    Write-Output "  $($r.account),$($r.count)"
}
Write-Output "total: $totalUnread"

if ($AllMessages.Count -gt 0) {
    Write-Output ""
    Write-Output "emails[$($AllMessages.Count)]{status,date,from,subject,id,account}:"
    foreach ($m in $AllMessages) {
        $from = $m.from -replace ',', ';'
        $subject = $m.subject -replace ',', ';'
        Write-Output "  $($m.status),$($m.date),$from,$subject,$($m.id),$($m.account)"
    }
}

# Show unconfigured accounts
$unconfigured = @($Results | Where-Object { -not $_.configured })
if ($unconfigured.Count -gt 0) {
    Write-Output ""
    Write-Output "unconfigured: $(($unconfigured.account) -join ',')"
}
