# Get-AINews.ps1 - Compatibility wrapper for JSON news cache generation.
# Usage: .\Get-AINews.ps1 [-Count 7] [-HoursBack 24]

[CmdletBinding()]
param(
    [int]$Count = 7,
    [int]$HoursBack = 24
)

& (Join-Path $PSScriptRoot 'Get-AllNews.ps1') -Count $Count -HoursBack $HoursBack
