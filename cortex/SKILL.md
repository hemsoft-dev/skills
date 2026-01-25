---
name: cortex
description: Read-only access to Cortex Internal Developer Portal for querying teams, services, scorecards, and entity information.
---

# Cortex Internal Developer Portal

V1.5 - Read-only access to query teams, services, scorecards, and entities in Cortex IDP.

**Note:** This deployed skill is read-only. Create/update operations are not available.

- **Deployment Type**: organization
- **Requires Auth**: Yes
- **Auth Env Var**: `CORTEX_API_KEY`

## Cortex Instance

- **Web UI**: <https://app.getcortexapp.com>
- **Teams UI**: <https://app.getcortexapp.com/admin/catalogs/teams>
- **API Documentation**: <https://docs.cortex.io/>
- **API Base**: <https://api.getcortexapp.com/api/v1>

## Key Learnings & Best Practices

### Authentication Methods

**API Key vs Personal Access Token**:

- **API Keys**: Used for direct REST API calls (`https://api.getcortexapp.com/api/v1/*`)
- **Personal Access Tokens (PAT)**: Required for MCP remote server (`https://mcp.cortex.io/mcp`)
- These are **different** authentication methods - do not confuse them
- Generate PATs from: Settings → API Keys → Personal Tokens

## Direct API Access (Read-Only)

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

### Environment Variable

```powershell
$env:CORTEX_API_KEY = "your-api-key-here"
```

## MCP Server Configuration

### Option 1: Remote HTTP Server (Recommended)

**Address**: `https://mcp.cortex.io/mcp`

**Claude CLI Usage**:

```bash
claude mcp add --transport http cortex-remote https://mcp.cortex.io/mcp --header "Authorization: Bearer <CORTEX_TOKEN>"
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

```json
{
  "mcpServers": {
    "cortex": {
      "command": "docker",
      "args": [
        "run", "--rm", "--pull", "always", "-i",
        "--env", "CORTEX_API_TOKEN=YOUR_TOKEN_HERE",
        "ghcr.io/cortexapps/cortex-mcp:latest"
      ]
    }
  }
}
```

### Available MCP Tools

The Cortex MCP provides read-only access to:

- Entity catalog and descriptors
- Dependencies and relationships
- Custom data
- On-call information
- Scorecards and scores
- Initiatives
- Engineering Intelligence metrics

## PowerShell Scripts

All scripts are located in the `scripts/` subfolder and require `CORTEX_API_KEY` environment variable.

### Listing & Querying

#### `List-CortexTeams.ps1`

Lists all teams with optional member details.

```powershell
.\scripts\List-CortexTeams.ps1                # List teams without member details
.\scripts\List-CortexTeams.ps1 -WithMembers   # Include member information
```

#### `Get-CortexTeams.ps1`

Gets detailed information for a specific team or all teams with members.

```powershell
.\scripts\Get-CortexTeams.ps1                      # List all teams with members
.\scripts\Get-CortexTeams.ps1 -TeamTag "my-team"   # Get specific team details
```

#### `Get-TeamMembers.ps1`

Gets team members for a specific team in a formatted table view.

```powershell
.\scripts\Get-TeamMembers.ps1 -TeamTag "productivity-engineering"
```

#### `Get-CortexServices.ps1`

Lists all services from the Catalog API with pagination.

```powershell
.\scripts\Get-CortexServices.ps1           # Default 100 per page
.\scripts\Get-CortexServices.ps1 -PageSize 250  # Custom page size
```

#### `Get-TeamServices.ps1`

Lists services owned by a specific team by checking the `ownersV2.teams` field.

**Note:** This script fetches all services and filters client-side, which may be slow for large catalogs. The Cortex API doesn't support server-side filtering by team ownership.

```powershell
.\scripts\Get-TeamServices.ps1 -TeamTag "productivity-engineering"
.\scripts\Get-TeamServices.ps1 -TeamTag "frontier" -PageSize 250
```

#### `Get-CortexEntity.ps1`

Gets detailed information about a specific entity (service, resource, domain).

```powershell
.\scripts\Get-CortexEntity.ps1 -EntityTag "my-service"
```

#### `Get-CortexScorecards.ps1`

Lists all scorecards or scores for a specific scorecard.

```powershell
.\scripts\Get-CortexScorecards.ps1                        # List all scorecards
.\scripts\Get-CortexScorecards.ps1 -ScorecardTag "prod-readiness"  # Get scores
```

#### `Search-CortexEntities.ps1`

Searches entities across the catalog by query and optional type filter.

```powershell
.\scripts\Search-CortexEntities.ps1 -Query "api"
.\scripts\Search-CortexEntities.ps1 -Query "payment" -Types "service"
```

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

## Example Queries

- "What teams are in Cortex?"
- "Show me the productivity-engineering team details"
- "List all services in Cortex"
- "What services does the Productivity Engineering team own?"
- "Which services does the Frontier team own?"
- "What's the scorecard score for relias-assistant?"
- "Search for entities related to 'api'"

## Resources

- **GitHub Repository**: <https://github.com/cortexapps/cortex-mcp>
- **MCP Prompt Library**: <https://docs.cortex.io/get-started/mcp/library>
- **API Reference**: <https://docs.cortex.io/api/>
- **Cortex Academy**: <https://academy.cortex.io/>

## Limitations

- **This skill is read-only**: Cannot create, update, or delete data
- **MCP is read-only**: Cannot write or modify data via MCP
- **Remote MCP**: Requires Personal Access Token (PAT), not API key
- **Rate limits apply**: Consult Cortex documentation for limits
