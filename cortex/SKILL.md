---
name: cortex
description: V1.2 - Expert in Cortex Internal Developer Portal setup, MCP server configuration, GitOps workflows, entity management, and direct API operations. Now with corrected Teams API vs Catalog API guidance.
---

# Cortex Internal Developer Portal

Expert guidance for Cortex IDP operations, MCP setup, entity management, and direct API manipulation.

## Cortex Instance

- **Web UI**: <https://app.getcortexapp.com>
- **API Documentation**: <https://docs.cortex.io/>
- **API Base**: <https://api.getcortexapp.com/api/v1>
- **GitOps Repository**: <https://bitbucket.org/relias/cortex-gitops/src/main/> (team changes and entity management)

## Key Learnings & Best Practices

### Authentication Methods

**API Key vs Personal Access Token**:

- **API Keys**: Used for direct REST API calls (`https://api.getcortexapp.com/api/v1/*`)
- **Personal Access Tokens (PAT)**: Required for MCP remote server (`https://mcp.cortex.io/mcp`)
- These are **different** authentication methods - do not confuse them
- Generate PATs from: Settings → API Keys → Personal Tokens

### Team Management Critical Rules

1. **No DELETE endpoint exists** for removing individual team members
2. **Always use PUT** with the complete members list
3. **Removing a member**: GET current team, filter out the member, PUT remaining members
4. **Adding a member**: GET current team, append new member, PUT full list
5. **Body structure must include** `type: "CORTEX"` and `members: []` array
6. **Member object structure for PUT requests**:

   ```json
   {
     "email": "user@example.com",
     "name": "Full Name",
     "roleTags": ["developer", "engineering-manager"],
     "notificationsEnabled": true,
     "description": "Optional description"
   }
   ```

7. **Important**: Use `roleTags` (array of strings) in PUT requests. GET responses return `roles`
   (array of objects with `tag`, `name`, `source`, `type` properties). Extract `.tag` from GET,
   send as `roleTags` in PUT.

### GitOps Workflow Known Issues

**Active Issue (Ticket 12171 - Reopened Jan 6, 2026)**:

- Team YAML file changes in `.cortex/teams/*.yaml` not syncing to Cortex portal
- Service changes process correctly
- Team changes marked as "Filtered out" during event processing
- **Workaround**: Use direct API calls to update team members until resolved
- **Impact**: Cannot rely on GitOps for team updates - manual API calls required

### MCP Server Configuration

**Remote server setup lessons**:

- Token substitution (`${input:CORTEX_TOKEN}`) may not work initially
- May need to hardcode token temporarily or reload VS Code after configuration
- Use `MCP: Restart All Servers` command after mcp.json changes
- Remote server specifically requires PAT, not API key

## Direct API Access

### Authentication

All API requests require an API key in the Authorization header:

```bash
Authorization: Bearer <CORTEX_API_KEY>
```

### API Endpoints Summary

Cortex has **two main APIs** for entity access:

| API             | Endpoint            | Use Case                                           |
|-----------------|---------------------|----------------------------------------------------|
| **Teams API**   | `/api/v1/teams`     | Full team details, members, Slack channels         |
| **Catalog API** | `/api/v1/catalog`   | Services, domains, resources with pagination       |

### Teams API (Recommended for Teams)

**List All Teams** (with full details including members):

```bash
GET https://api.getcortexapp.com/api/v1/teams
GET https://api.getcortexapp.com/api/v1/teams?includeTeamsWithoutMembers=true
```

**Get Specific Team**:

```bash
GET https://api.getcortexapp.com/api/v1/teams/{team-tag}
```

**Response includes**: teamTag, metadata (name, description), members array, slackChannels, links, isArchived

### Catalog API (For Services, Domains, Resources)

**List Services** (with pagination):

```bash
GET https://api.getcortexapp.com/api/v1/catalog?types=service&pageSize=250&page=0&includeOwners=true
```

**List Domains**:

```bash
GET https://api.getcortexapp.com/api/v1/catalog?types=domain&pageSize=250&page=0
```

**Get Entity Details**:

```bash
GET https://api.getcortexapp.com/api/v1/catalog/{entity-tag}
```

**Catalog Query Parameters**:

- `types` - Filter by entity type (service, domain, team, etc.)
- `pageSize` - Results per page (1-1000, default 250)
- `page` - Page number (0-indexed)
- `includeOwners` - Include ownership info (default false)
- `includeArchived` - Include archived entities (default false)
- `groups` - Filter by x-cortex-groups
- `query` - Search query across entity properties

### List Scorecards

```bash
GET https://api.getcortexapp.com/api/v1/scorecards
```

### Get Scorecard Scores

```bash
GET https://api.getcortexapp.com/api/v1/scorecards/{scorecard-tag}/scores
```

### API Documentation References

- **Teams API**: <https://docs.cortex.io/api/readme/teams>
- **Catalog API**: <https://docs.cortex.io/api/readme/catalog-entities>
- **Entity Types**: <https://docs.cortex.io/ingesting-data-into-cortex/entities>

### Remove Team Member

There is no direct DELETE endpoint for removing a single member. Instead, you must PUT the full
members list excluding the member to remove:

```powershell
# 1. Get current team
$team = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/{team-tag}" -Headers $headers -Method Get

# 2. Filter out the member to remove
$updatedMembers = @()
foreach ($member in $team.cortexTeam.members) {
    if ($member.email -ne "user@example.com") {
        $memberObj = @{
            email = $member.email
            name = $member.name
            notificationsEnabled = $member.notificationsEnabled
        }
        # Extract role tags from GET response, send as roleTags in PUT
        if ($member.roles -and $member.roles.Count -gt 0) {
            $memberObj.roleTags = $member.roles | ForEach-Object { $_.tag }
        } else {
            $memberObj.roleTags = @()
        }
        $updatedMembers += $memberObj
    }
}

# 3. PUT the updated members list
$body = @{
    type = "CORTEX"
    members = $updatedMembers
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/{team-tag}/members" -Headers $headers -Method Put -Body $body -ContentType "application/json"
```

**Add Team Member**:

To add a member, GET current members, append the new member to the array, then PUT the full list:

```powershell
# 1. Get current team
$team = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/{team-tag}" -Headers $headers -Method Get

# 2. Transform existing members to preserve roles
$currentMembers = @()
foreach ($member in $team.cortexTeam.members) {
    $memberObj = @{
        email = $member.email
        name = $member.name
        notificationsEnabled = $member.notificationsEnabled
    }
    # Extract role tags from GET response (roles objects), send as roleTags in PUT
    if ($member.roles -and $member.roles.Count -gt 0) {
        $memberObj.roleTags = $member.roles | ForEach-Object { $_.tag }
    } else {
        $memberObj.roleTags = @()
    }
    $currentMembers += $memberObj
}

# 3. Create new member
$newMember = @{
    email = "newuser@example.com"
    name = "New User"
    roleTags = @("developer", "engineering-manager")  # developer, manager, tester, cloud-engineer, product-manager, etc.
    notificationsEnabled = $true
    description = "Optional role description"
}

# 4. Combine and PUT
$body = @{
    type = "CORTEX"
    members = $currentMembers + $newMember
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/teams/{team-tag}/members" -Headers $headers -Method Put -Body $body -ContentType "application/json"
```

### Environment Variable

```powershell
$env:CORTEX_API_KEY = "eyJ6aXAiOiJHWklQIiwiYWxnIjoiSFM1MTIifQ..."
```

### PowerShell API Call Example

```powershell
$headers = @{
    "Authorization" = "Bearer $env:CORTEX_API_KEY"
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod -Uri "https://api.getcortexapp.com/api/v1/catalog?type=team" -Headers $headers -Method Get
$response | ConvertTo-Json -Depth 10
```

## MCP Server Configuration

### Option 1: Remote HTTP Server (Recommended)

**Address**: `https://mcp.cortex.io/mcp`

**Claude CLI Usage**:

```bash
claude mcp add --transport http cortex-remote https://mcp.cortex.io/mcp --header "Authorization: Bearer <CORTEX_TOKEN>"
```

**Environment Variable**:

```bash
# Set your Cortex token as an environment variable
CORTEX_TOKEN=eyJ6aXAiOiJHWklQIiwiYWxnIjoiSFM1MTIifQ...
```

**MCP Client Configuration** (for Claude Desktop, VS Code, etc.):

```json
{
  "mcpServers": {
    "cortex-remote": {
      "transport": "http",
      "url": "https://mcp.cortex.io/mcp",
      "headers": {
        "Authorization": "Bearer ${CORTEX_TOKEN}"
      }
    }
  }
}
```

### Option 2: Docker Image (Local Hosting)

**Image**: `ghcr.io/cortexapps/cortex-mcp:latest`

**MCP Client Configuration**:

```json
{
  "mcpServers": {
    "cortex": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "--pull",
        "always",
        "-i",
        "--env",
        "CORTEX_API_TOKEN=YOUR_TOKEN_HERE",
        "ghcr.io/cortexapps/cortex-mcp:latest"
      ]
    }
  }
}
```

**Self-Managed Instances**: Add `--env CORTEX_API_BASE_URL=https://<your-instance>`

### Prerequisites

- Docker installed and running
- Personal Access Token from Cortex (Settings → API Keys → Personal Tokens)
- MCP-compatible client (Claude Desktop, VS Code, Cursor, etc.)

### Available MCP Tools

The Cortex MCP provides read-only access to:

- Entity catalog and descriptors
- Dependencies and relationships
- Custom data
- On-call information
- Scorecards and scores
- Initiatives
- Engineering Intelligence metrics (AI Chief of Staff feature)

## GitOps Workflow

### Directory Structure

```text
.cortex/
├── catalog/          # Services and resources
│   └── {service-name}.yaml
└── teams/            # Team definitions
    └── {team-name}.yaml
```

### Entity Descriptor Template

Minimum required fields for a service:

```yaml
openapi: 3.0.1
info:
  title: {Service Name}
  description: "{Service Description}"
  x-cortex-git:
    bitbucket:
      repository: {org}/{repo-name}
  x-cortex-tag: {service-tag}
  x-cortex-type: service
```

### YAML Best Practices

- **Extension**: Use `.yaml` (not `.yml`)
- **Reserved Words**: Always lowercase (`email`, `group`, `type`, etc.)
- **File Naming**: Match repository name for services

### Common Entity Properties

**Ownership**:

```yaml
x-cortex-owners:
  - type: group
    name: {team-name}
    provider: CORTEX
  - type: email
    email: {user@domain.com}
    notificationsEnabled: true
    description: {Role/SME description}
```

**Groups/Tags**:

```yaml
x-cortex-groups:
  - framework-version:{value}
  - platform:{value}
  - service-type:{value}
```

**Dependencies**:

```yaml
x-cortex-dependency:
  - tag: {dependency-service-tag}
    description: {Description}
    metadata:
      tags: [{tag1}, {tag2}]
      prod: true
```

**Links**:

```yaml
x-cortex-link:
  - name: {Link Name}
    type: {OPENAPI|DOCUMENTATION|RUNBOOK|etc}
    url: {https://...}
```

**Domains**:

```yaml
x-cortex-parents:
  - tag: {domain-tag}
```

**SonarCloud**:

```yaml
x-cortex-static-analysis:
  sonarqube:
    project: {org_project-name}
```

## Service Bus Events

### Create Event Topic

File: `_sbustopic_{source}-{eventname}.yaml`

```yaml
openapi: 3.0.1
info:
  title: {topic.name}
  description: {Description}
  x-cortex-tag: {event-tag}
  x-cortex-type: service-bus-topic
```

### Publisher Relationship

In publishing service YAML:

```yaml
x-cortex-dependency:
  - tag: {event-tag}
    description: Publishes to {topic.name} topic
```

### Subscriber Relationship

In event topic YAML:

```yaml
x-cortex-dependency:
  - tag: {subscriber-service-tag}
    description: {Service Name} subscribes to {topic.name}
```

## LaunchDarkly Integration

```yaml
x-cortex-launch-darkly:
  projects:
    - key: {project-key}
      environments:
        - environmentName: {env-name}
      alias: {alias}  # Optional, for multi-account
  feature-flags:
    - tag: {flag-tag}
      environments:
        - environmentName: {env-name}
```

## Effective MCP Prompts

**Best Practices**:

- Be specific with service names, Scorecard names, and metrics
- Combine related questions for richer context
- Reference organization-specific constructs (custom Scorecards, Initiatives)
- Use follow-up questions to drill down from broad to specific

**Example Queries**:

- "Who owns {service-name}, when was it last deployed, and are there any open incidents?"
- "Show me all critical services failing the Production Readiness Scorecard"
- "What's going on with my {initiative-name}?"
- "Which services have concerning MTTR trends, and what scorecard gaps are contributing?"
- "Show me services owned by {team-name} that need attention"

## Support Ticket History

### Ticket 12171: Team Entity YAML Files Filtered Out During Event Processing

**Issue**: GitOps changes to `.cortex/teams/*.yaml` files being incorrectly filtered out during
Cortex event processing, despite PR merge and commit to main branch.

**Timeline**:

- **Nov 11, 2025 3:34 PM** - Franz Hemmer reported issue via Slack (#relias-cortex-external)
  - PR merged to `feature/pe-devex-team-update` branch in cortex-gitops repo
  - Services changes processed correctly
  - Two team YAML files excluded: `.cortex/teams/productivity-engineering.yaml` and `.cortex/teams/works-on-my-machine.yaml`
  - Screenshot showed "Service processed: 1" with team files marked "Filtered out"

- **Nov 11, 2025 3:34 PM** - Cortex Technical Support created Ticket 12171
  - Team offline for Veterans Day (Nov 11th)
  - Auto-response confirmed reopening

- **Nov 12, 2025 5:46 PM** - Chase Lancaster requested details
  - Asked for changes made to team entity YAML files
  - Inquired about `.cortex-properties.yaml` usage

- **Nov 12, 2025 10:30 PM** - Franz provided diff
  - Confirmed two omitted files
  - Not using `.cortex-properties.yaml` file

- **Nov 13, 2025 1:22 PM** - Chase requested commit SHA
  
- **Nov 13, 2025 1:45 PM** - Franz provided: `957b461162e64d1e7cc6bb584a4158e7e2ee94e8`

- **Nov 13, 2025 5:54 PM** - Chase escalated to engineering team
  - No hiccups found in logs for team entities at that SHA
  - Escalated for deeper investigation
  - Reacted with ❤️

- **Nov 18, 2025 8:42 AM** - Franz requested update

- **Nov 18, 2025 12:17 PM** - Cathleen Wright provided status
  - Engineering team actively reviewing
  - Raised as high severity
  - No new updates available

- **Nov 18, 2025 2:29 PM** - Franz confirmed holding pattern

- **Nov 18, 2025 3:05 PM** - Chase acknowledged and monitoring

- **Dec 17, 2025 12:35 PM** - Chase reported fix deployed
  - "Released a fix for the underlying issue here"
  - Expected team entity changes to no longer be filtered out

- **Jan 6, 2026** - **ISSUE RECURRED** - Franz reopened ticket
  - New PR: <https://bitbucket.org/relias/cortex-gitops/pull-requests/108>
  - Commit SHA: `1399772`
  - Merged to `main` branch via `feature/pe-devex-team-update`
  - `.cortex/teams/productivity-engineering.yaml` still being filtered out
  - PR shows "Omitted files: 1" in event processing
  - Changes not reflected in Cortex portal

**Status**: **REOPENED** - Issue persists after reported fix

**Impact**: Team entity updates in GitOps workflow not syncing to Cortex, requiring manual
intervention or alternative update methods.

**Workaround Applied (Jan 6, 2026)**: Used direct REST API calls to update Productivity
Engineering team members, bypassing GitOps workflow entirely. Successfully removed Ian Crowl and
Sagar Thakore, added back Bryan Halterman and Nick Peterson using
`PUT /api/v1/teams/productivity-engineering/members` endpoint.

## Lessons Learned (Jan 6, 2026 Session)

### What Worked Well

1. **Direct API approach** - REST API calls are reliable when GitOps fails
2. **Using Cortex query_docs MCP tool** - Found correct API documentation quickly
3. **PowerShell for API operations** - `Invoke-RestMethod` effective for Cortex API
4. **Iterative debugging** - Tried DELETE, PATCH, PUT methods systematically
5. **Full member list strategy** - Understanding PUT replaces entire list was key

### Critical Mistakes to Avoid

1. **Don't assume DELETE endpoint exists** - Many REST APIs don't support granular deletes
2. **Don't trust token substitution immediately** - Verify authentication is working
3. **Don't confuse API keys and PATs** - They serve different purposes in Cortex
4. **Don't rely on GitOps for teams** - Known issue (Ticket 12171) still unresolved
5. **Don't forget `type: "CORTEX"` in body** - Required field for team member updates
6. **Don't guess endpoint structure** - Consult documentation (use query_docs MCP)

### Problem-Solving Approach That Worked

1. Identified MCP server wasn't authenticating (403 Forbidden)
2. Researched API key vs PAT difference
3. Switched to direct API calls with API key
4. Listed teams successfully using `/api/v1/teams` endpoint
5. Retrieved specific team with `/api/v1/teams/productivity-engineering`
6. Attempted DELETE - failed with 404
7. Attempted PATCH - failed with 405
8. Consulted Cortex documentation via query_docs MCP
9. Learned PUT with full members list is correct approach
10. Successfully implemented team member updates

### Tools & Techniques

**Effective**:

- `Cortex query_docs MCP` - Official documentation retrieval
- `Invoke-RestMethod` - PowerShell HTTP client
- `$env:CORTEX_API_KEY` - Environment variable for token storage
- Filtering with `Where-Object { $_.email -ne "email@domain.com" }`
- Explicit foreach loops for building member arrays

**Less Effective**:

- MCP remote server (authentication issues)
- Token substitution in mcp.json (required hardcoding)
- Pipeline filtering with `-ne` operator (had mixed results, foreach more reliable)

## Resources

- **GitHub Repository**: <https://github.com/cortexapps/cortex-mcp>
- **MCP Prompt Library**: <https://docs.cortex.io/get-started/mcp/library>
- **API Reference**: <https://docs.cortex.io/api/>
- **Cortex Academy**: <https://academy.cortex.io/>

## Limitations

- **MCP is read-only**: Cannot write or modify data via MCP
- **Remote MCP**: Requires Personal Access Token (PAT), not API key
- **Free MCP clients**: May have smaller context windows
