$ErrorActionPreference = 'Stop'
$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$asm = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'MailKit' } | Select-Object -First 1
$t = $asm.GetType('MailKit.StoreFlagsRequest')
Write-Host 'Constructors for StoreFlagsRequest:'
foreach ($c in $t.GetConstructors()) {
    $ps = $c.GetParameters()
    foreach ($p in $ps) { Write-Host "Param: $($p.Name) Type: $($p.ParameterType.FullName)" }
    Write-Host '---'
}

Write-Host '\nProperties:'
$t.GetProperties() | Select-Object Name, PropertyType | Format-Table -AutoSize

Write-Host '\nEnum StoreAction values:'
[Enum]::GetNames([MailKit.StoreAction]) | ForEach-Object { Write-Host $_ }
