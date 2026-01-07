$ErrorActionPreference = 'Stop'
$asm = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -match 'MailKit' } | Select-Object -First 1
if (-not $asm) { Write-Host 'MailKit not loaded in AppDomain.'; return }
$asm.GetTypes() | Where-Object { $_.Name -match 'Store' } | Select-Object FullName | Format-Table -AutoSize
