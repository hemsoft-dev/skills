# Neo4j Scripts

PowerShell scripts for working with Neo4j graph database.

## Sync-SkillsToNeo4j.ps1

**Recommended for regular use** - Incrementally syncs only modified skills.

**What it does:**

- Tracks last sync time
- Only processes skills modified since last sync
- Runs full import (which is idempotent with MERGE)
- Updates sync timestamp

**Usage:**

```powershell
# Sync modified skills only
.\Sync-SkillsToNeo4j.ps1

# Force full re-sync
.\Sync-SkillsToNeo4j.ps1 -Force
```

**Typical workflow:**

1. Make changes to your skills
2. Run `.\Sync-SkillsToNeo4j.ps1`
3. It detects and syncs only what changed

## Import-SkillsToNeo4j.ps1

**For initial setup** - Imports all Claude skills markdown files into Neo4j as a knowledge graph.

**What it does:**

- Parses SKILL.md files from `~\.claude\skills\`
- Extracts frontmatter metadata (name, description, version)
- Creates graph nodes for Skills, Files, Sections, Code Blocks, and Keywords
- Establishes relationships between entities
- Creates indexes and constraints for performance

**Prerequisites:**

- Neo4j running on <http://localhost:7474>
- Default credentials (neo4j/password)

**Usage:**

```powershell
# Default usage (current user's skills)
.\Import-SkillsToNeo4j.ps1

# Custom skills path
.\Import-SkillsToNeo4j.ps1 -SkillsPath "C:\custom\skills"

# Custom Neo4j password
.\Import-SkillsToNeo4j.ps1 -Password "mypassword"

# All custom parameters
.\Import-SkillsToNeo4j.ps1 -SkillsPath "C:\custom\skills" -Neo4jUri "bolt://localhost:7687" -Username "neo4j" -Password "mypassword"
```

**Parameters:**

- `SkillsPath`: Path to skills directory (default: `$env:USERPROFILE\.claude\skills`)
- `Neo4jUri`: Neo4j Bolt connection (default: `bolt://localhost:7687`)
- `Username`: Neo4j username (default: `neo4j`)
- `Password`: Neo4j password (default: `password`)

**Graph Schema:**

Nodes:

- `:Skill` - A skill with metadata
- `:MarkdownFile` - SKILL.md file
- `:Section` - Document sections
- `:CodeBlock` - Code snippets
- `:Keyword` - Technologies/tools mentioned

Relationships:

- `(Skill)-[:HAS_FILE]->(MarkdownFile)`
- `(MarkdownFile)-[:HAS_SECTION]->(Section)`
- `(MarkdownFile)-[:HAS_CODE]->(CodeBlock)`
- `(Skill)-[:MENTIONS]->(Keyword)`

**After Import:**

Query your skills graph:

```cypher
// Find all skills
MATCH (s:Skill) RETURN s.name, s.version ORDER BY s.name;

// Find skills using Docker
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword {term: 'Docker'})
RETURN s.name, s.description;

// Full-text search
CALL db.index.fulltext.queryNodes('skillSearch', 'graph database')
YIELD node, score
RETURN node.name, node.description, score
ORDER BY score DESC;
```

---

## Automation Setup Scripts

### Setup-GitHook.ps1

Automatically sync after every git commit.

**Usage:**

```powershell
.\Setup-GitHook.ps1
```

Creates a post-commit hook that runs `Sync-SkillsToNeo4j.ps1` after each commit.

**Remove hook:**

```powershell
Remove-Item "$env:USERPROFILE\.claude\skills\.git\hooks\post-commit"
```

### Setup-ScheduledSync.ps1

Sync daily at a scheduled time (requires admin).

**Usage:**

```powershell
# Default: 9am daily
.\Setup-ScheduledSync.ps1

# Custom time
.\Setup-ScheduledSync.ps1 -Time "2pm"
```

**Manage task:**

```powershell
# View task
Get-ScheduledTask -TaskName "Neo4j Skills Sync"

# Run now
Start-ScheduledTask -TaskName "Neo4j Skills Sync"

# Remove task
Unregister-ScheduledTask -TaskName "Neo4j Skills Sync"
```

### Setup-ProfileAlias.ps1

Add a quick `Sync-Skills` command to your PowerShell profile.

**Usage:**

```powershell
.\Setup-ProfileAlias.ps1

# Reload profile
. $PROFILE

# Now just type:
Sync-Skills
```
