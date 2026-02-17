---
name: jira
description: V2.0 - Query and search JIRA tickets via REST API PowerShell scripts. Replaces the deprecated .NET JiraService connector. Also tracks active JIRA epics for Productivity Engineering.
---

# JIRA Skill

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Query JIRA tickets, search by JQL, and retrieve comments using the Atlassian REST API v3.
Replaces the deprecated .NET `JiraService` / `JiraServiceFactory` connector.

## Authentication

Requires these environment variables:

- `ATLASSIAN_EMAIL` — your Atlassian account email
- `ATLASSIAN_API_TOKEN` — API token from <https://id.atlassian.com/manage-profile/security/api-tokens>

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

### Common JQL Queries

| Purpose | JQL |
|---------|-----|
| My open tickets | `assignee = currentUser() AND resolution = Unresolved` |
| My in-progress | `assignee = currentUser() AND status = "In Progress"` |
| Tickets I reported | `reporter = currentUser() AND resolution = Unresolved` |
| My current sprint | `assignee = currentUser() AND sprint in openSprints()` |
| Open PE epics | `project = PE AND type = Epic AND resolution = Unresolved` |
| DevEx team tickets | `"Team[Team]" = "Productivity Engineering - DevEx" AND resolution = Unresolved` |

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

## Usage

Reference these epics when working on related tasks or discussing project priorities.
