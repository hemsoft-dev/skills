---
name: atlassian
description: V1.3 - Search and manage JIRA tickets, Confluence docs, and Cortex Internal Developer Portal with proper field configuration and full Confluence API support.
---

# Atlassian

Search JIRA and Confluence, create/modify JIRA tickets with proper team field configuration. Full Confluence API support for pages, spaces, attachments, and content management.

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## General Rules

- **Always provide convenience links** when returning JIRA/Confluence results
- **Confluence search**: Prioritize recent documents—older docs are less relevant

## JIRA API Script

Use this PowerShell script to query JIRA with proper JQL. Requires environment variables:

- `ATLASSIAN_EMAIL`: Your Atlassian email
- `ATLASSIAN_API_TOKEN`: API token from <https://id.atlassian.com/manage-profile/security/api-tokens>

```powershell
# Get-JiraTickets.ps1
param(
    [string]$JQL = 'assignee = currentUser() AND resolution = Unresolved ORDER BY priority DESC',
    [int]$MaxResults = 50
)

$baseUrl = "https://relias.atlassian.net"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; "Content-Type" = "application/json" }
$body = @{ jql = $JQL; maxResults = $MaxResults; fields = @('key','summary','status','priority','assignee') } | ConvertTo-Json

$response = Invoke-RestMethod -Uri "$baseUrl/rest/api/3/search/jql" -Headers $headers -Method Post -Body $body
Write-Host "Found $($response.total) tickets:"
$response.issues | ForEach-Object {
    [PSCustomObject]@{
        Key      = $_.key
        Summary  = $_.fields.summary
        Status   = $_.fields.status.name
        Priority = $_.fields.priority.name
        URL      = "$baseUrl/browse/$($_.key)"
    }
} | Format-Table -AutoSize
```

### Common JQL Queries

| Purpose | JQL |
|---------|-----|
| My open tickets | `assignee = currentUser() AND resolution = Unresolved` |
| My in-progress | `assignee = currentUser() AND status = "In Progress"` |
| Tickets I reported | `reporter = currentUser() AND resolution = Unresolved` |
| My current sprint | `assignee = currentUser() AND sprint in openSprints()` |
| Watching | `watcher = currentUser()` |
| Open PE epics | `project = PE AND type = Epic AND resolution = Unresolved` |

### Usage Examples

```powershell
# My open assigned tickets
.\Get-JiraTickets.ps1

# Tickets I reported (not assigned)
.\Get-JiraTickets.ps1 -JQL 'reporter = currentUser() AND resolution = Unresolved'

# My in-progress work
.\Get-JiraTickets.ps1 -JQL 'assignee = currentUser() AND status = "In Progress"'

# DevEx team tickets
.\Get-JiraTickets.ps1 -JQL '"Team[Team]" = "Productivity Engineering - DevEx" AND resolution = Unresolved'
```

## Confluence API Scripts

Use these PowerShell scripts to interact with Confluence. Requires environment variables:

- `ATLASSIAN_EMAIL`: Your Atlassian email
- `ATLASSIAN_API_TOKEN`: API token from <https://id.atlassian.com/manage-profile/security/api-tokens>

### Get Confluence Pages

```powershell
# Get-ConfluencePages.ps1
param(
    [string]$SpaceKey,
    [string]$Title,
    [int]$Limit = 25
)

$baseUrl = "https://relias.atlassian.net/wiki"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

$query = "limit=$Limit"
if ($SpaceKey) { $query += "&spaceKey=$SpaceKey" }
if ($Title) { $query += "&title=$Title" }

$response = Invoke-RestMethod -Uri "$baseUrl/rest/api/content?$query&expand=space,version,history" -Headers $headers

$response.results | ForEach-Object {
    [PSCustomObject]@{
        ID      = $_.id
        Title   = $_.title
        Type    = $_.type
        Space   = $_.space.name
        Status  = $_.status
        Version = $_.version.number
        URL     = "$baseUrl$($_.links.webui)"
        Updated = $_.version.when
    }
} | Format-Table -AutoSize
```

### Get Page Content

```powershell
# Get-ConfluencePage.ps1
param(
    [Parameter(Mandatory)]
    [string]$PageId,
    [switch]$IncludeBody
)

$baseUrl = "https://relias.atlassian.net/wiki"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

$expand = "space,version,history,ancestors"
if ($IncludeBody) { $expand += ",body.storage,body.view" }

$response = Invoke-RestMethod -Uri "$baseUrl/rest/api/content/${PageId}?expand=$expand" -Headers $headers

[PSCustomObject]@{
    ID       = $response.id
    Title    = $response.title
    Type     = $response.type
    Space    = $response.space.name
    Status   = $response.status
    Version  = $response.version.number
    URL      = "$baseUrl$($response._links.webui)"
    Body     = if ($IncludeBody) { $response.body.storage.value } else { $null }
}
```

### Create Confluence Page

```powershell
# New-ConfluencePage.ps1
param(
    [Parameter(Mandatory)]
    [string]$SpaceKey,
    [Parameter(Mandatory)]
    [string]$Title,
    [Parameter(Mandatory)]
    [string]$Body,
    [string]$ParentPageId
)

$baseUrl = "https://relias.atlassian.net/wiki"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; "Content-Type" = "application/json" }

$payload = @{
    type = "page"
    title = $Title
    space = @{ key = $SpaceKey }
    body = @{
        storage = @{
            value = $Body
            representation = "storage"
        }
    }
}

if ($ParentPageId) {
    $payload.ancestors = @(@{ id = $ParentPageId })
}

$body = $payload | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "$baseUrl/rest/api/content" -Headers $headers -Method Post -Body $body
Write-Host "Created page: $baseUrl$($response._links.webui)"
$response
```

### Update Confluence Page

```powershell
# Update-ConfluencePage.ps1
param(
    [Parameter(Mandatory)]
    [string]$PageId,
    [Parameter(Mandatory)]
    [string]$Title,
    [Parameter(Mandatory)]
    [string]$Body,
    [Parameter(Mandatory)]
    [int]$Version
)

$baseUrl = "https://relias.atlassian.net/wiki"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; "Content-Type" = "application/json" }

$payload = @{
    type = "page"
    title = $Title
    version = @{ number = $Version + 1 }
    body = @{
        storage = @{
            value = $Body
            representation = "storage"
        }
    }
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "$baseUrl/rest/api/content/$PageId" -Headers $headers -Method Put -Body $payload
Write-Host "Updated page: $baseUrl$($response._links.webui)"
$response
```

### Search Confluence Content

```powershell
# Search-Confluence.ps1
param(
    [Parameter(Mandatory)]
    [string]$Query,
    [string]$SpaceKey,
    [string]$Type,
    [string]$Title,
    [int]$Year,
    [int]$Limit = 50,
    [switch]$CountOnly
)

Add-Type -AssemblyName System.Web

$baseUrl = "https://relias.atlassian.net/wiki"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

# Build CQL query
$cqlParts = @()
if ($Query) { $cqlParts += "text ~ `"$Query`"" }
if ($SpaceKey) { $cqlParts += "space = $SpaceKey" }
if ($Type) { $cqlParts += "type = $Type" }
if ($Title) { $cqlParts += "title ~ `"$Title`"" }

$cql = $cqlParts -join " AND "
$encodedCql = [System.Web.HttpUtility]::UrlEncode($cql)
$response = Invoke-RestMethod -Uri "$baseUrl/rest/api/content/search?cql=$encodedCql&limit=$Limit&expand=space,version,history" -Headers $headers

$results = $response.results | ForEach-Object {
    $updated = [DateTime]::Parse($_.version.when)
    [PSCustomObject]@{
        ID      = $_.id
        Title   = $_.title
        Type    = $_.type
        Space   = $_.space.name
        Year    = $updated.Year
        Updated = $updated.ToString("yyyy-MM-dd")
        URL     = "$baseUrl$($_._links.webui)"
    }
}

# Filter by year if specified
if ($Year) {
    $results = $results | Where-Object { $_.Year -eq $Year }
}

# Output results
Write-Host "`nFound $($response.size) total results" -ForegroundColor Cyan
if ($Year) {
    Write-Host "Filtered to year $Year`: $($results.Count) results" -ForegroundColor Yellow
}

if ($CountOnly) {
    Write-Host "`nCount: $($results.Count)" -ForegroundColor Green
} else {
    $results | Format-Table -AutoSize
}

# Return count for scripting
return $results.Count
```

### Get Space Information

```powershell
# Get-ConfluenceSpace.ps1
param(
    [string]$SpaceKey,
    [switch]$ListAll
)

$baseUrl = "https://relias.atlassian.net/wiki"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
    exit 1
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

if ($ListAll) {
    $response = Invoke-RestMethod -Uri "$baseUrl/rest/api/space?limit=100" -Headers $headers
    $response.results | ForEach-Object {
        [PSCustomObject]@{
            Key         = $_.key
  Search by title and year | `.\Search-Confluence.ps1 -Title "AI Chapter" -Year 2025` |
| Count results only | `.\Search-Confluence.ps1 -Query "meeting notes" -CountOnly` |
| Multiple criteria | `.\Search-Confluence.ps1 -Query "API" -Title "documentation" -Type "page" -Year 2025` |
|           Name        = $_.name
            Type        = $_.type
            Status      = $_.status
            URL         = "$baseUrl$($_._links.webui)"
        }
    } | Format-Table -AutoSize
} else {
    $response = Invoke-RestMethod -Uri "$baseUrl/rest/api/space/${SpaceKey}?expand=description,homepage" -Headers $headers
    [PSCustomObject]@{
        Key         = $response.key
        Name        = $response.name
        Type        = $response.type
        Status      = $response.status
        Description = $response.description.plain.value
        Homepage    = $response.homepage.title
        URL         = "$baseUrl$($response._links.webui)"
    }
}
```

### Common Confluence Operations

| Operation | Command |
|-----------|---------|
| List pages in space | `.\Get-ConfluencePages.ps1 -SpaceKey "DEV"` |
| Search by title | `.\Get-ConfluencePages.ps1 -Title "API Documentation"` |
| Get page details | `.\Get-ConfluencePage.ps1 -PageId "123456"` |
| Get page with body | `.\Get-ConfluencePage.ps1 -PageId "123456" -IncludeBody` |
| Create page | `.\New-ConfluencePage.ps1 -SpaceKey "DEV" -Title "New Page" -Body "<p>Content</p>"` |
| Create child page | `.\New-ConfluencePage.ps1 -SpaceKey "DEV" -Title "Child" -Body "<p>Content</p>" -ParentPageId "123456"` |
| Update page | `.\Update-ConfluencePage.ps1 -PageId "123456" -Title "Updated" -Body "<p>New content</p>" -Version 5` |
| Search content | `.\Search-Confluence.ps1 -Query "kubernetes"` |
| Search in space | `.\Search-Confluence.ps1 -Query "deployment" -SpaceKey "DEV"` |
| List all spaces | `.\Get-ConfluenceSpace.ps1 -ListAll` |
| Get space details | `.\Get-ConfluenceSpace.ps1 -SpaceKey "DEV"` |

### Confluence Content Format

Confluence uses **Storage Format** (XHTML) for page content:

```html
<h1>Heading 1</h1>
<h2>Heading 2</h2>
<p>Paragraph with <strong>bold</strong> and <em>italic</em> text.</p>
<ul>
  <li>Bullet point 1</li>
  <li>Bullet point 2</li>
</ul>
<ac:structured-macro ac:name="code">
  <

### Key Takeaways

**Search Best Practices:**
- Use CQL (Confluence Query Language) for precise filtering
- `text ~` searches page content, `title ~` searches titles only
- Combine multiple criteria with `AND` operator
- Always use `[uri]::EscapeDataString()` or `[System.Web.HttpUtility]::UrlEncode()` for CQL queries
- Expand results with `&expand=space,version,history` to get metadata

**Date Filtering:**
- API returns dates in ISO 8601 format (e.g., `2025-12-17T10:30:00.000Z`)
- Parse with `[DateTime]::Parse($_.version.when)` to filter by year/date
- The `version.when` field shows last update time

**Efficient Queries:**
- Set appropriate limits (default 50, max varies)
- Use specific CQL filters to reduce result set
- Filter post-query for complex date/field criteria
- Return counts when only totals are needed

**Authentication:**
- Store credentials in environment variables (`ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`)
- Use Basic Auth with Base64-encoded `email:token`
- API tokens from: https://id.atlassian.com/manage-profile/security/api-tokensac:parameter ac:name="language">javascript</ac:parameter>
  <ac:plain-text-body><![CDATA[console.log('Hello');]]></ac:plain-text-body>
</ac:structured-macro>
```

## Rovo Search (Semantic)

The `mcp_atlassian_mcp_search` tool uses **Rovo Search**—semantic/natural language across JIRA and Confluence. It cannot execute JQL or filter by `currentUser()`.

### When to Use Rovo vs API

| Use Case | Tool |
|----------|------|
| Precise JQL queries (my tickets, sprint, etc.) | JIRA API Script |
| Precise Confluence queries (space, page ID, etc.) | Confluence API Script |
| Find docs mentioning a topic | Rovo Search |
| Search across JIRA + Confluence | Rovo Search |
| Filter by assignee/reporter accurately | JIRA API Script |
| Create/update Confluence pages | Confluence API Script |
| Get page hierarchy | Confluence API Script |

## Creating Epics (Model after PE-939)

Ask for:

1. Is the epic capitalizable?
2. Who is the Stakeholder?
3. Flip from TODO to IN PROGRESS?
4. Which team should it be assigned to?
5. Should we create acceptance criteria?

Note: You may get an error on creation—modify the ticket after creation to update fields.

## Creating Tickets (Model after PE-940)

Ask for:

1. Story or Task?
2. Status: Backlog (default), TODO, or IN PROGRESS?
3. Assignee?
4. Title and description?

### CRITICAL: Team Fields (Required for Board Visibility)

**Always set these fields after creating a ticket:**

| Field | Value |
|-------|-------|
| `customfield_13400` (Team Group) | `{"name": "Productivity Engineering"}` |
| `customfield_15700` (Team) | `ab77423c-95e2-4bd8-96ca-6dfc081d2996` |
| `customfield_15201` (Squad) | `{"id": "21834"}` |

Without these fields, tickets will NOT appear on the team board or backlog.

## Cortex (Internal Developer Portal)

Use Cortex MCP connector for all Cortex-related queries. Exception: If searching for "Cortex" in JIRA/Confluence, use Atlassian tools instead.
