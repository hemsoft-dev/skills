$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'
$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$client = Connect-Imap
try {
    $inbox = $client.Inbox
    $inbox.Open([MailKit.FolderAccess]::ReadWrite) | Out-Null

    $asm = $inbox.GetType().Assembly
    Write-Information "Assembly: $($asm.FullName)"

    $types = $asm.GetTypes() | Where-Object { $_.Name -match 'Store' -or $_.Name -match 'IStore' }
    foreach ($t in $types) { Write-Information $t.FullName }

    # Find any type that implements IStoreFlagsRequest
    $iface = $asm.GetTypes() | Where-Object { $_.Name -eq 'IStoreFlagsRequest' } | Select-Object -First 1
    if ($iface) {
        Write-Information "Found interface: $($iface.FullName)"
        $implementations = $asm.GetTypes() | Where-Object { $_.GetInterfaces() -contains $iface }
        foreach ($impl in $implementations) { Write-Information "Impl: $($impl.FullName)" }
    }
    else { Write-Information 'IStoreFlagsRequest not found in assembly.' }
}
finally { Disconnect-Imap -Client $client }
