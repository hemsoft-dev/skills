
$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'
$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$asm = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'MailKit' } | Select-Object -First 1
$t = $asm.GetType('MailKit.StoreFlagsRequest')
Write-Information 'Constructors for StoreFlagsRequest:'
foreach ($c in $t.GetConstructors()) {
    $ps = $c.GetParameters()
    foreach ($p in $ps) { Write-Information "Param: $($p.Name) Type: $($p.ParameterType.FullName)" }
    Write-Information '---'
}

Write-Information '\nProperties:'
$t.GetProperties() | Select-Object Name, PropertyType | Format-Table -AutoSize

Write-Information '\nEnum StoreAction values:'
[Enum]::GetNames([MailKit.StoreAction]) | ForEach-Object { Write-Information $_ }
