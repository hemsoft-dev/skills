$ErrorActionPreference = 'Stop'
$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$client = Connect-Imap
try {
    $f = $client.Inbox
    $f.Open([MailKit.FolderAccess]::ReadWrite) | Out-Null
    $f.GetType().GetMethods() | Where-Object { $_.Name -match 'Flags' } | Select-Object Name, ReturnType | Format-Table -AutoSize
}
finally { Disconnect-Imap -Client $client }
