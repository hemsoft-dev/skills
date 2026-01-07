$ErrorActionPreference = 'Stop'

$asm = [Reflection.Assembly]::LoadFile((Join-Path (Split-Path -Parent $PSScriptRoot) 'packages\MailKit.dll'))
$asm.GetTypes() | Where-Object { $_.Name -match 'Store.*' -or $_.Name -match 'IStore.*' } | Select-Object FullName | Format-Table -AutoSize
