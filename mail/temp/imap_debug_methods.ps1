$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'

$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$client = Connect-Imap
try {
    $inbox = $client.Inbox
    $inbox.Open([MailKit.FolderAccess]::ReadWrite) | Out-Null
    Write-Information "Inbox type: $($inbox.GetType().FullName)"
    Write-Information 'Available methods (sample):'
    $inbox | Get-Member -MemberType Method | Select-Object -Property Name | Sort-Object Name | Select-Object -First 200 | Format-Table -AutoSize
    Write-Information "\nReflection methods (sample):"
    $inbox.GetType().GetMethods() | Where-Object { $_.IsPublic -and -not $_.IsStatic } | Select-Object -Property Name, ReturnType | Sort-Object Name | Select-Object -First 200 | Format-Table -AutoSize
}
finally { Disconnect-Imap -Client $client }
