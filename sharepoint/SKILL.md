---
name: sharepoint
description: V1.2 - Access and manage SharePoint sites, lists, libraries, and files using PnP PowerShell. Supports Relias corporate SharePoint and other SharePoint Online sites. Includes streamlined scripts for AI Chapter document access.
dependencies: PnP.PowerShell>=3.1.0
---

# SharePoint

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Access and manage SharePoint sites, lists, libraries, and files using PnP PowerShell. Supports Relias corporate SharePoint and other SharePoint Online sites.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## ALWAYS: Retrospective Check

Before completing, reflect on this interaction:

1. Were new patterns or edge cases discovered?
2. Could instructions be clearer?
3. Do scripts need improvements or bug fixes?
4. Should new capabilities be added?

If improvements identified:

- Present proposed changes with clear rationale
- Wait for user approval before applying
- Keep skill concise (remove/condense when adding if possible)
- Version bump SKILL.md if changes applied

## Default SharePoint Site

**Relias Corporate SharePoint:**

- URL: `https://reliaslearning.sharepoint.com/`
- Site Title: Relias
- Authentication: Interactive login with default Microsoft client ID

## Authentication

PnP PowerShell requires authentication. Use the default Microsoft client ID for interactive authentication:

```powershell
$defaultClientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"  # Microsoft's default SharePoint client ID
# -PersistLogin stores refresh token for reuse between sessions (PnP PowerShell v3.0+)
Connect-PnPOnline -Url "https://reliaslearning.sharepoint.com/" -Interactive -ClientId $defaultClientId -PersistLogin
```

**Alternative:** Use environment variable client IDs if available:

- `$env:GRAPH_WORK_CLIENT_ID` (preferred for work accounts)
- `$env:GRAPH_CLIENT_ID` (fallback)

**Authentication Methods:**

- `-Interactive`: Opens browser for login (supports MFA). **Requires `-PersistLogin`** for token caching (PnP PowerShell v3.0+)
- `-DeviceLogin`: Device code flow (for remote/headless scenarios). Supports `-PersistLogin` for token caching.
- `-OSLogin`: Windows authentication (requires client ID)
- Certificate-based: For automation (requires Azure AD app registration, no user interaction)

**Token Caching (PnP PowerShell v3.0+):**
PnP PowerShell v3.0+ includes `-PersistLogin` parameter for token persistence:

- **Cache Location**: `%LOCALAPPDATA%\.m365pnppowershell` (Windows) or `$HOME/.m365pnppowershell` (Mac/Linux)
- **Encryption**: DPAPI on Windows, Keychain on Mac/Linux
- **Token Refresh**: Automatically refreshes expired tokens using stored refresh token
- **Persistence**: Tokens persist between PowerShell sessions when `-PersistLogin` is used
- **CRITICAL**: You MUST use `-PersistLogin` on the first connection to enable token caching

**Example with Token Caching:**

```powershell
# First connection - will prompt for authentication and cache token
Connect-PnPOnline -Url "https://reliaslearning.sharepoint.com/" -Interactive -ClientId $clientId -PersistLogin

# Subsequent connections - will reuse cached token automatically
Connect-PnPOnline -Url "https://reliaslearning.sharepoint.com/" -Interactive -ClientId $clientId
```

**Troubleshooting Repeated Authentication:**
If you're prompted to authenticate every time:

1. **Ensure you're using `-PersistLogin`** - This is REQUIRED for token persistence in PnP PowerShell v3.0+
2. Check PnP PowerShell version: `Get-Module PnP.PowerShell | Select-Object Version` (must be 3.0+)
3. Verify token cache directory exists: `$env:LOCALAPPDATA\.m365pnppowershell`
4. Clear old tokens if needed: `Disconnect-PnPOnline -ClearPersistedLogin`
5. Some organizations require periodic re-authentication due to security policies

## Core Operations

### Connect to SharePoint

```powershell
Import-Module PnP.PowerShell

# Connect to Relias SharePoint
# Check for existing connection first to avoid re-authentication
$siteUrl = "https://reliaslearning.sharepoint.com/"
$existingConnection = Get-PnPConnection -ErrorAction SilentlyContinue
if (-not $existingConnection -or $existingConnection.Url -ne $siteUrl) {
    $clientId = $env:GRAPH_WORK_CLIENT_ID
    if (-not $clientId) {
        $clientId = $env:GRAPH_CLIENT_ID
    }
    if (-not $clientId) {
        $clientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"  # Default Microsoft client ID
    }
    # -PersistLogin stores refresh token for reuse between sessions (PnP PowerShell v3.0+)
    Connect-PnPOnline -Url $siteUrl -Interactive -ClientId $clientId -PersistLogin
}
```

**Note**: To avoid repeated authentication:

1. Use `-PersistLogin` parameter (PnP PowerShell v3.0+) to cache tokens between sessions
2. Check for existing connections before connecting to reuse active sessions
3. Token cache location: `%LOCALAPPDATA%\.m365pnppowershell` (not Azure.Identity cache)
4. Some organizations may require periodic re-authentication due to security policies

### Get Site Information

```powershell
$web = Get-PnPWeb
Write-Host "Title: $($web.Title)"
Write-Host "URL: $($web.Url)"
Write-Host "Description: $($web.Description)"
```

### List Libraries and Lists

```powershell
# Get all lists (excluding hidden)
Get-PnPList | Where-Object { $_.Hidden -eq $false } | Select-Object Title, ItemCount, BaseTemplate

# Get specific list
$list = Get-PnPList -Identity "Documents"
```

### Work with Files

```powershell
# List files in a library
Get-PnPListItem -List "Documents" | Select-Object Title, FileSystemObjectType, Created

# Download a file
Get-PnPFile -Url "/sites/YourSite/Shared Documents/file.pdf" -Path "C:\Downloads\file.pdf" -AsFile

# Upload a file
Add-PnPFile -Path "C:\file.pdf" -Folder "Shared Documents"

# Search for files
Find-PnPFile -Match "keyword" -List "Documents"
```

### REST API Calls

```powershell
# Get site title via REST API
$result = Invoke-PnPSPRestMethod -Url "/_api/web/title" -Method Get
Write-Host "Site Title: $($result.value)"

# Get lists via REST API
$lists = Invoke-PnPSPRestMethod -Url "/_api/web/lists?$select=Id,Title,ItemCount" -Method Get
$lists.value | Format-Table
```

### Disconnect

```powershell
Disconnect-PnPOnline
```

## Common Scripts

### Test Connection

Use `scripts/Test-SharePointConnection.ps1` to test connectivity:

```powershell
.\scripts\Test-SharePointConnection.ps1 -SiteUrl "https://reliaslearning.sharepoint.com/"
```

This script:

- Connects using appropriate authentication
- Displays site information
- Lists available libraries/lists
- Tests REST API connectivity

### Get AI Chapter Documents

Use `scripts/Get-AIChapterDocuments.ps1` to list all documents from AI Engineering Chapter or AI Foundation Chapter folders:

```powershell
# List documents from both chapters
.\scripts\Get-AIChapterDocuments.ps1

# List only Engineering Chapter documents
.\scripts\Get-AIChapterDocuments.ps1 -Chapter Engineering

# List only Foundation Chapter documents
.\scripts\Get-AIChapterDocuments.ps1 -Chapter Foundation
```

This script:

- Recursively searches all subfolders
- Lists all files with metadata (size, modified date, modified by)
- Provides direct SharePoint URLs for each document
- Reuses existing connections to minimize authentication prompts

## Best Practices

1. **Always disconnect** - Call `Disconnect-PnPOnline` when done to free resources
2. **Handle errors** - Wrap operations in try-catch blocks
3. **Check connection** - Use `Get-PnPConnection` to verify active connection
4. **Use REST API** - For complex queries, use `Invoke-PnPSPRestMethod` with SharePoint REST API
5. **Filter results** - Use `Where-Object` to filter lists/files before processing
6. **Batch operations** - Use `Invoke-PnPQuery` for batch operations when possible

## File Structure

```
sharepoint/
├── SKILL.md
├── scripts/
│   ├── Test-SharePointConnection.ps1
│   ├── Get-AIChapterFolders.ps1
│   ├── Get-AIChapterDocuments.ps1
│   ├── Get-AIFoundationChapter.ps1
│   ├── Find-AIChapter.ps1
│   └── Search-SharePointDocuments.ps1
└── History/
    └── {YYYY-MM-DD}.md
```

## Known Relias SharePoint Lists

From initial connection test:

- **Documents** (4,485 items) - Main document library
- **Diversity Calendar** (134 items) - Calendar list
- **All Hands Recordings** (9 items) - Video/recording library
- **Diversity, Equity, and Inclusion** (27 items) - DEI resources
- **Culture Club** (1 item) - Culture resources
- And more...

## Common Scripts

### Get AI Chapter Documents

Use `scripts/Get-AIChapterDocuments.ps1` to list all documents from AI Engineering Chapter or AI Foundation Chapter folders:

```powershell
# List documents from both chapters
.\scripts\Get-AIChapterDocuments.ps1

# List only Engineering Chapter documents
.\scripts\Get-AIChapterDocuments.ps1 -Chapter Engineering

# List only Foundation Chapter documents
.\scripts\Get-AIChapterDocuments.ps1 -Chapter Foundation
```

This script:

- Recursively searches all subfolders
- Lists all files with metadata (size, modified date, modified by)
- Provides direct SharePoint URLs for each document
- Reuses existing connections to minimize authentication prompts

## Troubleshooting

**"Please specify a valid client id"**

- Use the default Microsoft client ID: `9bc3ab49-b65d-410a-85ad-de819febfddc`
- Or set `$env:GRAPH_WORK_CLIENT_ID` environment variable

**"Unable to connect using provided arguments"**

- Try `-Interactive` instead of `-DeviceLogin`
- Verify site URL is correct
- Ensure you have access to the site

**"PowerShell is in NonInteractive mode"**

- Use `-Interactive` authentication method
- Or use certificate-based authentication for automation

**Connection timeout**

- Check network connectivity
- Verify site URL is accessible
- Try reconnecting

**Repeated authentication prompts**

- **Root cause**: `-PersistLogin` parameter is REQUIRED for token persistence in PnP PowerShell v3.0+. Without it, tokens are NOT cached between sessions.
- **Solution**:
  1. **Use `-PersistLogin` on first connection** - This stores the refresh token in `%LOCALAPPDATA%\.m365pnppowershell`
  2. Verify PnP PowerShell version is 3.0+: `Get-Module PnP.PowerShell | Select-Object Version`
  3. Check token cache directory exists: `$env:LOCALAPPDATA\.m365pnppowershell`
  4. Clear old tokens if switching accounts: `Disconnect-PnPOnline -ClearPersistedLogin`
  5. Some organizations require periodic re-authentication due to security policies
  6. For automation, consider certificate-based authentication instead
