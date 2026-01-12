#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks for open PRs that need your attention.

.DESCRIPTION
    Displays two lists:
    1. Open PRs you've created
    2. PRs awaiting your review

.EXAMPLE
    .\Get-MyPRs.ps1
    
.EXAMPLE
    & "c:\Users\User\.claude\skills\github\scripts\Get-MyPRs.ps1"
#>

[CmdletBinding()]
param()

Write-Host "`n=== Your Open PRs ===" -ForegroundColor Green

$myPRs = gh pr list --state open --author "@me" --json title,headRepository,number,url,isDraft,createdAt,updatedAt --limit 50 | ConvertFrom-Json

if ($myPRs.Count -eq 0) {
    Write-Host "  ✅ No open PRs" -ForegroundColor Gray
} else {
    $myPRs | ForEach-Object {
        [PSCustomObject]@{
            Repo    = $_.headRepository.nameWithOwner
            Number  = "#$($_.number)"
            Title   = $_.title
            Draft   = if ($_.isDraft) { "📝" } else { "✓" }
            Created = ([datetime]$_.createdAt).ToString("yyyy-MM-dd")
            Updated = ([datetime]$_.updatedAt).ToString("yyyy-MM-dd")
            URL     = $_.url
        }
    } | Format-Table -AutoSize
}

Write-Host "`n=== PRs Awaiting Your Review ===" -ForegroundColor Cyan

$reviewPRs = gh search prs --review-requested="@me" --state=open --json title,repository,author,createdAt,url,number --limit 50 | ConvertFrom-Json

if ($reviewPRs.Count -eq 0) {
    Write-Host "  ✅ No PRs awaiting review" -ForegroundColor Gray
} else {
    $reviewPRs | ForEach-Object {
        [PSCustomObject]@{
            Repo    = $_.repository.nameWithOwner
            Number  = "#$($_.number)"
            Author  = $_.author.login
            Title   = $_.title
            Created = ([datetime]$_.createdAt).ToString("yyyy-MM-dd")
            URL     = $_.url
        }
    } | Format-Table -AutoSize
}

# Summary
Write-Host "`n📊 Summary:" -ForegroundColor Yellow
Write-Host "   Your PRs: $($myPRs.Count)" -ForegroundColor White
Write-Host "   Reviews needed: $($reviewPRs.Count)" -ForegroundColor White

if ($myPRs.Count -eq 0 -and $reviewPRs.Count -eq 0) {
    Write-Host "`n🎉 All clear - no PRs need attention!`n" -ForegroundColor Green
} else {
    Write-Host ""
}
