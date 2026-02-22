---
name: jira
description: V2.3 - Query JIRA tickets, boards, and sprints via REST API PowerShell scripts. Replaces the deprecated .NET JiraService connector. Also tracks active JIRA epics for Productivity Engineering.
---

# JIRA Skill

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Query JIRA tickets, search by JQL, retrieve comments, and view board/sprint information using the Atlassian REST API.
Replaces the deprecated .NET `JiraService` / `JiraServiceFactory` connector.

## Authentication

Requires these environment variables:

- `ATLASSIAN_EMAIL` — your Atlassian account email
- `ATLASSIAN_API_TOKEN` — API token from <https://id.atlassian.com/manage-profile/security/api-tokens>

## URL Parsing

When a user pastes a JIRA board URL like `https://relias.atlassian.net/jira/software/c/projects/PE/boards/729`, extract the board ID (729) from the URL and use `Get-JiraBoardSprints.ps1`.

## Operations

### Get-JiraTicket.ps1

Retrieve full details for a single ticket by key.

```powershell
.\Get-JiraTicket.ps1 -TicketKey "PE-123"
```

Returns: Key, Summary, Status, Type, Priority, Assignee, Reporter, Created, Updated, URL, Description.

### Search-JiraTickets.ps1

Search tickets using JQL. Defaults to 25 results.

```powershell
# My open tickets
.\Search-JiraTickets.ps1 -JQL 'assignee = currentUser() AND resolution = Unresolved ORDER BY priority DESC'

# PE epics in progress
.\Search-JiraTickets.ps1 -JQL 'project = PE AND type = Epic AND status = "In Progress"' -MaxResults 10

# Tickets in current sprint
.\Search-JiraTickets.ps1 -JQL 'assignee = currentUser() AND sprint in openSprints()'
```

Returns: Key, Summary, Status, Priority, Assignee, Updated, URL for each result, plus clickable links.

### Get-JiraTicketComments.ps1

Retrieve chronological comments for a ticket.

```powershell
.\Get-JiraTicketComments.ps1 -TicketKey "PE-123"
.\Get-JiraTicketComments.ps1 -TicketKey "PE-123" -MaxResults 50
```

### Get-JiraBoardSprints.ps1

Retrieve board details and sprint information using the JIRA Agile REST API.
Use this when a user asks about a board or sprint, or pastes a board URL.

```powershell
# Get active sprints for board 729
.\Get-JiraBoardSprints.ps1 -BoardId 729

# Get active sprints with all issues listed
.\Get-JiraBoardSprints.ps1 -BoardId 729 -IncludeIssues

# Get closed (completed) sprints
.\Get-JiraBoardSprints.ps1 -BoardId 729 -SprintState closed

# Get future sprints
.\Get-JiraBoardSprints.ps1 -BoardId 729 -SprintState future

# Get all sprints regardless of state
.\Get-JiraBoardSprints.ps1 -BoardId 729 -SprintState all
```

Returns: Board name, type, project info, sprint names, goals, dates, and optionally issues with status breakdown.

### Common JQL Queries

| Purpose | JQL |
|---------|-----|
| My open tickets | `assignee = currentUser() AND resolution = Unresolved` |
| My in-progress | `assignee = currentUser() AND status = "In Progress"` |
| Tickets I reported | `reporter = currentUser() AND resolution = Unresolved` |
| My current sprint | `assignee = currentUser() AND sprint in openSprints()` |
| Open PE epics | `project = PE AND type = Epic AND resolution = Unresolved` |
| DevEx team tickets | `"Team[Team]" = "Productivity Engineering - DevEx" AND resolution = Unresolved` |

### Create Child Ticket Under Epic (Reusable)

Use this when you need to create the first or next child ticket under an existing epic.

```powershell
# Create-ChildTicket.ps1
param(
 [Parameter(Mandatory)]
 [string]$EpicKey,
 [Parameter(Mandatory)]
 [string]$Summary,
 [string]$DescriptionText = "",
 [ValidateSet("Task","Story")]
 [string]$IssueType = "Task",
 [string]$AssigneeAccountId = "557058:7e5734b3-5967-46f8-a20c-977376190266"
)

$baseUrl = "https://relias.atlassian.net"
$email = $env:ATLASSIAN_EMAIL
$token = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
 throw "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables"
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; "Content-Type" = "application/json"; Accept = "application/json" }

$description = @{
 version = 1
 type = "doc"
 content = @(
  @{
   type = "paragraph"
   content = @(@{ type = "text"; text = $DescriptionText })
  }
 )
}

$fields = @{
 project           = @{ key = "PE" }
 summary           = $Summary
 issuetype         = @{ name = $IssueType }
 description       = $description
 assignee          = @{ accountId = $AssigneeAccountId }
 priority          = @{ name = "Unclassified" }
 customfield_15700 = "ab77423c-95e2-4bd8-96ca-6dfc081d2996"
 customfield_15201 = @{ id = "21834" }
 parent            = @{ key = $EpicKey }
}

$payload = @{ fields = $fields } | ConvertTo-Json -Depth 20

try {
 $created = Invoke-RestMethod -Uri "$baseUrl/rest/api/3/issue" -Headers $headers -Method Post -Body $payload
}
catch {
 # Fallback for projects/workflows that still require Epic Link field
 $fields.Remove("parent") | Out-Null
 $fields["customfield_10014"] = $EpicKey
 $payload = @{ fields = $fields } | ConvertTo-Json -Depth 20
 $created = Invoke-RestMethod -Uri "$baseUrl/rest/api/3/issue" -Headers $headers -Method Post -Body $payload
}

Write-Host "Created: $($created.key)"
Write-Host "URL: $baseUrl/browse/$($created.key)"

# Verification fallback via JQL (works even when immediate GET issue is blocked)
$verifyBody = @{
 jql = "key = $($created.key) OR parent = $EpicKey OR 'Epic Link' = $EpicKey"
 maxResults = 20
 fields = @("key","summary","status","parent")
} | ConvertTo-Json

$verify = Invoke-RestMethod -Uri "$baseUrl/rest/api/3/search/jql" -Headers $headers -Method Post -Body $verifyBody
$verify.issues | ForEach-Object {
 $parentKey = if ($_.fields.parent) { $_.fields.parent.key } else { "" }
 Write-Host "$($_.key) | $($_.fields.summary) | $($_.fields.status.name) | parent=$parentKey"
}
```

Example:

```powershell
.\Create-ChildTicket.ps1 -EpicKey "PE-1157" -Summary "SFL -- Team Forming and Brainstorming" -DescriptionText "Initial pilot ticket for Set It Free Loop (SFL) focused on team forming and brainstorming."
```

---

## Active Epics

Track active JIRA epics for Productivity Engineering team.

### Tracked Epics

### Quality Gating

- **Epic**: [PE-983] Improve Code Quality
- **Link**: <https://relias.atlassian.net/browse/PE-983>
- **Focus**: Code quality gating and standards

### Observability

- **Epic**: [PE-935] Improve Platform Observability
- **Link**: <https://relias.atlassian.net/browse/PE-935>
- **Focus**: Platform monitoring and observability improvements

### Legacy Release Process Documentation

- **Epic**: [PE-888] Legacy Release Tool
- **Link**: <https://relias.atlassian.net/browse/PE-888>
- **Focus**: Documentation for legacy release processes

### .NET 10 Upgrades

- **Epic**: [PE-597] Infrastructure OpEx
- **Link**: <https://relias.atlassian.net/browse/PE-597>
- **Focus**: Infrastructure operational excellence and .NET 10 upgrades

### Set It Free Loop Pilot

- **Epic**: [PE-1157] Epic: Set It Free Loop - Pilot
- **Link**: <https://relias.atlassian.net/browse/PE-1157>
- **Focus**: Pilot implementation of the Set It Free Loop approach

### First Child Ticket (Pilot)

- **Ticket**: [PE-1158] SFL -- Team Forming and Brainstorming
- **Link**: <https://relias.atlassian.net/browse/PE-1158>
- **Parent**: PE-1157

## Usage

Reference these epics when working on related tasks or discussing project priorities.
