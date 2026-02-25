$e=$env:ATLASSIAN_EMAIL; $t=$env:ATLASSIAN_API_TOKEN
$a=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${e}:${t}"))
$h=@{Authorization="Basic $a";Accept="application/json"}
$base="https://relias.atlassian.net/wiki"
$pageId="6011944963"

$page = Invoke-RestMethod -Uri "$base/rest/api/content/${pageId}?expand=body.storage,version,ancestors" -Headers $h
Write-Host "=== PAGE INFO ==="
Write-Host "ID:      $($page.id)"
Write-Host "Title:   $($page.title)"
Write-Host "Version: $($page.version.number)"
Write-Host "Parent:  $($page.ancestors[-1].id) | $($page.ancestors[-1].title)"
Write-Host ""
Write-Host "=== BODY (raw) ==="
Write-Host $page.body.storage.value
