<#
.SYNOPSIS
    Parent: Set message status (Read/Unread) for a given account.
.DESCRIPTION
    Routes to account-specific implementations (e.g., Gmail) to set message read/unread.
.PARAMETER Account
    Account key (gmail, outlook, hemmer.us). If omitted, `gmail` will be used by default for this initial implementation.
.PARAMETER Status
    "Read" or "Unread" (case-insensitive)
.PARAMETER MessageId
    One or more message IDs to set status for. For Gmail, use message id returned by mail scripts (e.g. 19b3828cfee82924).
.EXAMPLE
    pwsh -File tasks\mail-setstatus.ps1 -Account gmail -Status Unread -MessageId 19b3828cfee82924
#>

param(
    [string]$Account = 'gmail',
    [ValidateSet('Read','Unread')][string]$Status,
    [Parameter(Mandatory=$true)][string[]]$MessageId
)

$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'
$account = $Account.ToLower()

switch ($account) {
    'gmail' {
        $scriptPath = Join-Path $PSScriptRoot 'gmail\mail-setstatus.ps1'
        if (-not (Test-Path $scriptPath)) { throw "Gmail implementation not found: $scriptPath" }
        & $scriptPath -Status $Status -MessageId $MessageId
        return
    }
    'hemmer.us' {
        $scriptPath = Join-Path $PSScriptRoot 'hemmer.us\mail-setstatus.ps1'
        if (-not (Test-Path $scriptPath)) { throw "hemmer.us implementation not found: $scriptPath" }
        & $scriptPath -Status $Status -MessageId $MessageId
        return
    }
    'outlook' {
        Write-Information "[33mOutlook (Graph) set-status is not implemented yet. Will add Graph based support in a follow-up.`e[0m"
        return
    }
    default {
        throw "Account '$Account' is not supported. Supported: gmail (for now)."
    }
}
