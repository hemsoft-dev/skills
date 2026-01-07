$ErrorActionPreference = 'Stop'

$scriptPath = 'c:\Users\franz\.claude\skills\mail\tasks\gmail\mail-today.ps1'
$r = & $scriptPath -List -Count 50
$r.messages | ConvertTo-Json -Depth 6
