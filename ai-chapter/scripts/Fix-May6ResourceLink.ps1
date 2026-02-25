$e=$env:ATLASSIAN_EMAIL; $t=$env:ATLASSIAN_API_TOKEN
$a=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${e}:${t}"))
$h=@{Authorization="Basic $a";Accept="application/json";"Content-Type"="application/json"}
$base="https://relias.atlassian.net/wiki"
$pageId="6011944963"

$page = Invoke-RestMethod -Uri "$base/rest/api/content/${pageId}?expand=body.storage,version" -Headers $h
$body = $page.body.storage.value

Write-Host "Version before fix: $($page.version.number)"

# Step 1: Put the link into the Resource Link table cell (replace empty cell)
$emptyCell = '<tr><td><p>Resource Link</p></td><td><p /></td></tr>'
$filledCell = '<tr><td><p>Resource Link</p></td><td><p><a href="https://reliaslearning.sharepoint.com/sites/ProductivityEngineering">Productivity Engineering - Recordings and Quick Tutorials</a></p></td></tr>'

if ($body -notmatch [regex]::Escape($emptyCell)) {
    Write-Host "❌ Could not find empty Resource Link cell — aborting"
    exit 1
}

$newBody = $body.Replace($emptyCell, $filledCell)

# Step 2: Remove the floating paragraph that was incorrectly appended at the bottom
$floatingPara = '<p><a href="https://reliaslearning.sharepoint.com/sites/ProductivityEngineering">Productivity Engineering - Recordings and Quick Tutorials</a></p>'
if ($newBody.Contains($floatingPara)) {
    $newBody = $newBody.Replace($floatingPara, '')
    Write-Host "✂️  Removed floating paragraph"
} else {
    Write-Host "⚠️  Floating paragraph not found (OK if already removed)"
}

# Step 3: Push the update
$payload = @{
    version = @{ number = ($page.version.number + 1) }
    title   = $page.title
    type    = "page"
    body    = @{ storage = @{ value = $newBody; representation = "storage" } }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "$base/rest/api/content/$pageId" -Method PUT -Headers $h -Body $payload | Out-Null
Write-Host "✅ May 6 page fixed — link is now in the Resource Link table cell"
