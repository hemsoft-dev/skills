$e=$env:ATLASSIAN_EMAIL; $t=$env:ATLASSIAN_API_TOKEN
$a=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${e}:${t}"))
$h=@{Authorization="Basic $a";Accept="application/json"}
$base="https://relias.atlassian.net/wiki"

$pageIds = @{
    "03/11/26" = "6012272642"
    "03/25/26" = "6012141571"
    "04/08/26" = "6012043283"
    "04/22/26" = "6012469260"
    "05/06/26" = "6011944963"
    "05/20/26" = "6012338179"
}

foreach ($entry in $pageIds.GetEnumerator()) {
    $page = Invoke-RestMethod -Uri "$base/rest/api/content/$($entry.Value)?expand=body.storage" -Headers $h
    $body = $page.body.storage.value

    # Check Resource Link cell content
    if ($body -match '<tr><td><p>Resource Link</p></td><td>(<p [^/]|<p/>|<p />)') {
        Write-Host "❌ $($entry.Key) — Resource Link cell is EMPTY (link in wrong place)"
    } elseif ($body -match '<tr><td><p>Resource Link</p></td><td><p><a href') {
        Write-Host "✅ $($entry.Key) — Resource Link cell is correct"
    } else {
        Write-Host "⚠️  $($entry.Key) — Unknown state"
    }

    # Check if floating paragraph exists at bottom
    if ($body -match 'ProductivityEngineering.*</p>\s*$') {
        Write-Host "   ^ also has floating paragraph appended at bottom"
    }
}
