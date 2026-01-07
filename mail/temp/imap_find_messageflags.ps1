$ErrorActionPreference = 'Stop'
$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$client = Connect-Imap
try {
    $f = $client.Inbox
    $f.Open([MailKit.FolderAccess]::ReadWrite) | Out-Null
    $matches = $f.GetType().GetMethods() | Where-Object { $_.GetParameters() | Where-Object { $_.ParameterType.FullName -eq 'MailKit.MessageFlags' } }
    foreach ($m in $matches) {
        $paramNames = ($m.GetParameters() | ForEach-Object { $_.ParameterType.Name }) -join ', '
        Write-Host "$($m.Name)   Params: $paramNames"
    }
}
finally { Disconnect-Imap -Client $client }
