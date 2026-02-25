$e=$env:ATLASSIAN_EMAIL; $t=$env:ATLASSIAN_API_TOKEN
$a=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${e}:${t}"))
$h=@{Authorization="Basic $a";Accept="application/json"}
$base="https://relias.atlassian.net/wiki"

# Show Resource Link row for March 11
$page = Invoke-RestMethod -Uri "$base/rest/api/content/6012272642?expand=body.storage" -Headers $h
$body = $page.body.storage.value

# Extract just the Resource Link row
if ($body -match '(<tr><td><p>Resource Link</p></td><td>.*?</tr>)') {
    Write-Host "=== March 11 Resource Link row ==="
    Write-Host $matches[1]
} else {
    Write-Host "Row not found with basic regex"
    # Show a snippet around "Resource Link"
    $idx = $body.IndexOf("Resource Link")
    if ($idx -ge 0) {
        Write-Host $body.Substring([Math]::Max(0,$idx-20), [Math]::Min(300,$body.Length-$idx+20))
    }
}

Write-Host ""
Write-Host "=== Does it have floating paragraph? ==="
if ($body -match 'ProductivityEngineering') {
    Write-Host "YES — found ProductivityEngineering in body"
    # Find where
    $idx2 = $body.IndexOf("ProductivityEngineering")
    Write-Host $body.Substring([Math]::Max(0,$idx2-50), [Math]::Min(200,$body.Length-$idx2+50))
} else {
    Write-Host "NO — ProductivityEngineering not found in body at all"
}
