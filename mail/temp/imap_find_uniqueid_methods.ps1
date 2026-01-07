$ErrorActionPreference = 'Stop'
$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$client = Connect-Imap
try {
    $f = $client.Inbox
    $f.Open([MailKit.FolderAccess]::ReadWrite) | Out-Null
    $f.GetType().GetMethods() | Where-Object { $_.GetParameters() | Where-Object { $_.ParameterType.FullName -match 'UniqueId' } } | Select-Object Name, @{n='Params';e={ ($_.GetParameters() | ForEach-Object { $_.ParameterType.Name }) -join ', ' }} | Format-Table -AutoSize
}
finally { Disconnect-Imap -Client $client }
