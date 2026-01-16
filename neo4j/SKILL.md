---
name: neo4j
description: V1.1 - Expert in Neo4j graph database installation, Docker configuration, graph modeling, Cypher queries, and data import for document knowledge graphs.
compatibility: Requires Docker Desktop on Windows
---

# Neo4j

Manage Neo4j graph database via Docker for local development and build knowledge graphs from documents.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Prerequisites

- Docker Desktop installed and running
- Available ports: 7474 (HTTP), 7687 (Bolt)

## Installation

### Pull Neo4j Image

```powershell
docker pull neo4j:latest
```

### Run Neo4j Container

```powershell
docker run -d `
  --name neo4j `
  -p 7474:7474 -p 7687:7687 `
  -e NEO4J_AUTH=neo4j/password `
  -v neo4j_data:/data `
  -v neo4j_logs:/logs `
  neo4j:latest
```

**Environment Variables:**

- `NEO4J_AUTH=neo4j/password` - Default credentials (change on first login)
- Add `-e NEO4J_AUTH=none` to disable authentication (dev only)

**Volumes:**

- `neo4j_data` - Graph database files
- `neo4j_logs` - Application logs

## Access Neo4j

**Neo4j Browser:**

- URL: <http://localhost:7474>
- Username: `neo4j`
- Password: `password` (change on first login)

**Connection Details:**

- Bolt protocol: `bolt://localhost:7687`
- HTTP: `http://localhost:7474`
- HTTPS: `https://localhost:7473` (if enabled)

## Container Management

### Check Status

```powershell
docker ps -a --filter name=neo4j
```

### Access Cypher Shell (CLI)

Run interactive Cypher queries from the command line:

```powershell
# Connect to cypher-shell in the running container
docker exec -it neo4j cypher-shell -u neo4j -p password
```

**Inside cypher-shell**:

```cypher
// Run queries directly
MATCH (s:Skill) RETURN s.name LIMIT 5;

// Multi-line queries work
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword)
RETURN s.name, k.term
LIMIT 10;

// Exit
:exit
```

**Run single query from PowerShell**:

```powershell
# Execute one-off query without interactive shell
docker exec neo4j cypher-shell -u neo4j -p password "MATCH (s:Skill) RETURN count(s) AS total;"

# Pipe query from file
Get-Content query.cypher | docker exec -i neo4j cypher-shell -u neo4j -p password
```

**Export query results to CSV**:

```powershell
docker exec neo4j cypher-shell -u neo4j -p password --format plain "MATCH (s:Skill) RETURN s.name, s.version ORDER BY s.name;" > skills.csv
```

### View Logs

```powershell
docker logs neo4j

# Follow logs in real-time
docker logs -f neo4j
```

### Stop Neo4j

```powershell
docker stop neo4j
```

### Start Neo4j

```powershell
docker start neo4j
```

### Restart Neo4j

```powershell
docker restart neo4j
```

### Remove Container

Preserves data volumes:

```powershell
docker rm neo4j
```

### Remove All Data

#### WARNING: Deletes all graph data

```powershell
docker volume rm neo4j_data neo4j_logs
```

## Configuration

### Custom neo4j.conf

Create a custom configuration file:

```powershell
# Create config directory
$configDir = "$env:USERPROFILE\.neo4j\conf"
New-Item -ItemType Directory -Path $configDir -Force

# Download default config
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/neo4j/neo4j/5.x/conf/neo4j.conf" -OutFile "$configDir\neo4j.conf"

# Run with custom config
docker run -d `
  --name neo4j `
  -p 7474:7474 -p 7687:7687 `
  -e NEO4J_AUTH=neo4j/password `
  -v neo4j_data:/data `
  -v neo4j_logs:/logs `
  -v "$configDir:/conf" `
  neo4j:latest
```

### Memory Settings

Adjust heap size for larger datasets:

```powershell
docker run -d `
  --name neo4j `
  -p 7474:7474 -p 7687:7687 `
  -e NEO4J_AUTH=neo4j/password `
  -e NEO4J_server_memory_heap_initial__size=512m `
  -e NEO4J_server_memory_heap_max__size=2g `
  -e NEO4J_server_memory_pagecache_size=1g `
  -v neo4j_data:/data `
  -v neo4j_logs:/logs `
  neo4j:latest
```

## Backup and Restore

### Backup Data

```powershell
# Create backup directory
$backupDir = "$env:USERPROFILE\.neo4j\backups\$(Get-Date -Format 'yyyy-MM-dd')"
New-Item -ItemType Directory -Path $backupDir -Force

# Backup data volume
docker run --rm `
  -v neo4j_data:/data `
  -v "$backupDir:/backup" `
  busybox tar czf /backup/neo4j-data.tar.gz /data
```

### Restore Data

```powershell
# Stop Neo4j if running
docker stop neo4j

# Restore from backup
docker run --rm `
  -v neo4j_data:/data `
  -v "$backupDir:/backup" `
  busybox tar xzf /backup/neo4j-data.tar.gz -C /

# Start Neo4j
docker start neo4j
```

## Cypher Query Examples

### Basic Queries

```cypher
// Create a node
CREATE (p:Person {name: 'Alice', age: 30})

// Create relationship
MATCH (a:Person {name: 'Alice'}), (b:Person {name: 'Bob'})
CREATE (a)-[:KNOWS]->(b)

// Find all people
MATCH (p:Person) RETURN p

// Find relationships
MATCH (a:Person)-[r:KNOWS]->(b:Person)
RETURN a.name, b.name
```

## Troubleshooting

### Container Won't Start

Check if ports are already in use:

```powershell
netstat -ano | findstr ":7474"
netstat -ano | findstr ":7687"
```

### Can't Connect to Browser

1. Verify container is running: `docker ps`
2. Check logs: `docker logs neo4j`
3. Ensure Docker Desktop is running
4. Test connectivity: `Test-NetConnection -ComputerName localhost -Port 7474`

### Permission Errors

Run PowerShell as Administrator or adjust Docker Desktop permissions.

### Out of Memory

Increase Docker Desktop memory allocation:

1. Open Docker Desktop → Settings → Resources
2. Increase Memory limit (minimum 4GB recommended for Neo4j)
3. Click "Apply & Restart"

## Version-Specific Images

### Use Specific Version

```powershell
# Neo4j 5.x
docker pull neo4j:5

# Neo4j 4.x (LTS)
docker pull neo4j:4.4
```

### Enterprise Edition

Requires Neo4j license:

```powershell
docker run -d `
  --name neo4j-enterprise `
  -p 7474:7474 -p 7687:7687 `
  -e NEO4J_AUTH=neo4j/password `
  -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes `
  -v neo4j_data:/data `
  neo4j:enterprise
```

## Additional Resources

- Neo4j Browser: <http://localhost:7474>
- Documentation: <https://neo4j.com/docs/>
- Cypher Reference: <https://neo4j.com/docs/cypher-manual/>
- Docker Hub: <https://hub.docker.com/_/neo4j>

---

## Graph Database Concepts

### Core Elements

**Nodes**: Entities in your graph (e.g., Skill, File, Section, Keyword)

- Have labels (types): `(:Person)`, `(:Skill)`, `(:File)`
- Can have multiple labels: `(:Person:Actor)`
- Store properties as key-value pairs

**Relationships**: Connections between nodes with direction

- Have a type: `-[:KNOWS]->`, `-[:CONTAINS]->`, `-[:REFERENCES]->`
- Always have direction (can be queried bidirectionally)
- Can store properties: `-[:ACTED_IN {roles: ['Forrest']}]->`

**Properties**: Data stored on nodes and relationships

- Supported types: String, Integer, Float, Boolean, Lists
- Cannot be nested objects (flatten complex data)

### Property Types

```cypher
// String and Boolean
CREATE (:Example {name: 'Neo4j', active: true})

// Numbers
CREATE (:Example {count: 42, price: 19.99})

// Lists (arrays)
CREATE (:Example {tags: ['docker', 'database', 'graph'], scores: [1, 2, 3]})
```

### Schema Optional

Neo4j is **schema optional** - you can create data without defining structure first. However, indexes and constraints improve:

- Query performance
- Data quality (uniqueness, existence)
- Model clarity

---

## Skills Knowledge Graph Schema

### Node Labels

**`:Skill`** - A Claude skill

- `name` (String): Skill name (e.g., "neo4j", "todoist")
- `description` (String): Full description from frontmatter
- `version` (String): Version (e.g., "V1.0")
- `license` (String, optional): License type
- `compatibility` (String, optional): Requirements
- `path` (String): Absolute file path
- `created` (DateTime): File creation timestamp
- `modified` (DateTime): Last modification timestamp

**`:MarkdownFile`** - Any markdown file

- `filename` (String): File name with extension
- `path` (String): Absolute file path
- `type` (String): "SKILL", "History", "Support", "Data", "Template"
- `created` (DateTime): File creation timestamp
- `modified` (DateTime): Last modification timestamp
- `size` (Integer): File size in bytes
- `lineCount` (Integer): Number of lines

**`:Section`** - A section within a markdown file

- `heading` (String): Section title (e.g., "Installation", "Usage")
- `level` (Integer): Heading level (1-6)
- `content` (String): Section text content
- `order` (Integer): Position in document

**`:CodeBlock`** - Code snippet from markdown

- `language` (String): Programming language (e.g., "powershell", "cypher")
- `code` (String): The actual code
- `order` (Integer): Position in document

**`:Keyword`** - Important terms and topics

- `term` (String): The keyword/phrase
- `category` (String): "Tool", "Technology", "Concept", "Command"

**`:HistoryEntry`** - A logged interaction

- `date` (Date): Entry date
- `time` (String): Entry time (HH:MM format)
- `action` (String): What was done
- `summary` (String): One-line description

### Relationships

**Skill Structure**:

- `(:Skill)-[:HAS_FILE]->(:MarkdownFile)` - Skill to its SKILL.md file
- `(:MarkdownFile)-[:HAS_SECTION]->(:Section)` - File contains sections
- `(:Section)-[:HAS_CODE]->(:CodeBlock)` - Section contains code
- `(:Skill)-[:HAS_HISTORY]->(:MarkdownFile)` - Skill to history files
- `(:MarkdownFile)-[:HAS_ENTRY]->(:HistoryEntry)` - History file entries

**Content Relationships**:

- `(:Skill)-[:MENTIONS]->(:Keyword)` - Skill references a technology/tool
- `(:Section)-[:ABOUT]->(:Keyword)` - Section focuses on a topic
- `(:CodeBlock)-[:USES]->(:Keyword)` - Code uses a tool/technology

**Cross-References**:

- `(:Skill)-[:REFERENCES]->(:Skill)` - One skill mentions another
- `(:Skill)-[:DEPENDS_ON]->(:Skill)` - Skill has dependencies
- `(:Skill)-[:RELATED_TO]->(:Skill)` - Similar or complementary skills

**Temporal**:

- `(:HistoryEntry)-[:NEXT]->(:HistoryEntry)` - Chronological order
- `(:HistoryEntry)-[:MODIFIED]->(:Skill)` - Entry describes skill change

### Example Graph Structure

```cypher
// Create skill node
CREATE (neo4j:Skill {
  name: 'neo4j',
  description: 'Expert in Neo4j graph database...',
  version: 'V1.1',
  path: 'C:\\Users\\User\\.claude\\skills\\neo4j\\SKILL.md',
  created: datetime(),
  modified: datetime()
})

// Create SKILL.md file
CREATE (skillFile:MarkdownFile {
  filename: 'SKILL.md',
  path: 'C:\\Users\\User\\.claude\\skills\\neo4j\\SKILL.md',
  type: 'SKILL',
  created: datetime(),
  modified: datetime()
})

// Link skill to file
CREATE (neo4j)-[:HAS_FILE]->(skillFile)

// Create sections
CREATE (installSection:Section {
  heading: 'Installation',
  level: 2,
  content: 'Pull Neo4j Image...',
  order: 1
})

CREATE (skillFile)-[:HAS_SECTION]->(installSection)

// Create code blocks
CREATE (pullCode:CodeBlock {
  language: 'powershell',
  code: 'docker pull neo4j:latest',
  order: 1
})

CREATE (installSection)-[:HAS_CODE]->(pullCode)

// Create keywords
CREATE (docker:Keyword {term: 'Docker', category: 'Tool'})
CREATE (graph:Keyword {term: 'Graph Database', category: 'Concept'})

CREATE (neo4j)-[:MENTIONS]->(docker)
CREATE (neo4j)-[:MENTIONS]->(graph)
CREATE (pullCode)-[:USES]->(docker)

// Create skill references
MATCH (neo4j:Skill {name: 'neo4j'})
MATCH (installs:Skill {name: 'installs'})
CREATE (neo4j)-[:REFERENCES]->(installs)
```

---

## Importing Skills Data

### Initial Import

Use the full import script for first-time setup:

```powershell
cd "$env:USERPROFILE\.claude\skills\neo4j\scripts"
.\Import-SkillsToNeo4j.ps1
```

### Keeping Data in Sync

As your skills repository evolves, use the sync script to update only modified skills:

```powershell
# Sync modified skills (checks file timestamps)
.\Sync-SkillsToNeo4j.ps1

# Force full re-sync
.\Sync-SkillsToNeo4j.ps1 -Force
```

The sync script:

- Tracks last sync time in `~/.neo4j/last-sync.txt`
- Only processes files modified since last sync
- Shows which skills will be updated before syncing
- Safe to run repeatedly (uses MERGE for idempotency)

**Recommended workflow:**

1. Make changes to your skills
2. Run `.\Sync-SkillsToNeo4j.ps1`
3. Query updated graph data

### Automation Options

Use the setup scripts in `scripts/` folder for easy automation:

**Option 1: Git Hook** - Auto-sync after commits:

```powershell
cd "$env:USERPROFILE\.claude\skills\neo4j\scripts"
.\Setup-GitHook.ps1
```

Automatically runs sync after every git commit in the skills repository.

**Option 2: Scheduled Task** - Sync daily (requires admin):

```powershell
# Daily at 9am (default)
.\Setup-ScheduledSync.ps1

# Custom time
.\Setup-ScheduledSync.ps1 -Time "2pm"
```

Runs sync automatically every day at specified time.

**Option 3: PowerShell Alias** - Quick manual sync:

```powershell
.\Setup-ProfileAlias.ps1

# Reload profile
. $PROFILE

# Now just type anywhere:
Sync-Skills
```

Adds `Sync-Skills` command to your PowerShell profile for quick access.

See [scripts/README.md](scripts/README.md) for full documentation.

### Step 1: Create Constraints and Indexes

```cypher
// Unique constraints (also create indexes)
CREATE CONSTRAINT skill_name IF NOT EXISTS
FOR (s:Skill) REQUIRE s.name IS UNIQUE;

CREATE CONSTRAINT file_path IF NOT EXISTS
FOR (f:MarkdownFile) REQUIRE f.path IS UNIQUE;

CREATE CONSTRAINT keyword_term IF NOT EXISTS
FOR (k:Keyword) REQUIRE k.term IS UNIQUE;

// Performance indexes
CREATE INDEX skill_version IF NOT EXISTS
FOR (s:Skill) ON (s.version);

CREATE INDEX file_type IF NOT EXISTS
FOR (f:MarkdownFile) ON (f.type);

CREATE TEXT INDEX section_content IF NOT EXISTS
FOR (s:Section) ON (s.content);

CREATE TEXT INDEX code_text IF NOT EXISTS
FOR (c:CodeBlock) ON (c.code);

// Full-text search indexes
CREATE FULLTEXT INDEX skillSearch IF NOT EXISTS
FOR (s:Skill) ON EACH [s.name, s.description];

CREATE FULLTEXT INDEX contentSearch IF NOT EXISTS
FOR (s:Section) ON EACH [s.heading, s.content];

// Wait for indexes to populate
CALL db.awaitIndexes(300);
```

### Step 2: Load Skills from CSV

Generate CSV files from the skills directory, then import:

```powershell
# PowerShell script to generate skills.csv
$skills = Get-ChildItem "$env:USERPROFILE\.claude\skills\*\SKILL.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $frontmatter = $content -match '(?ms)^---\s*\n(.*?)\n---' 
    
    if ($frontmatter) {
        $yaml = $Matches[1]
        $name = if ($yaml -match 'name:\s*(.+)') { $Matches[1].Trim() }
        $desc = if ($yaml -match 'description:\s*(.+)') { $Matches[1].Trim() }
        $ver = if ($desc -match '^(V[\d.]+)') { $Matches[1] } else { 'V1.0' }
        
        [PSCustomObject]@{
            Name = $name
            Description = $desc
            Version = $ver
            Path = $_.FullName
            Created = $_.CreationTime
            Modified = $_.LastWriteTime
        }
    }
} | Export-Csv -Path "$env:USERPROFILE\.neo4j\skills.csv" -NoTypeInformation
```

```cypher
// Import skills from CSV
LOAD CSV WITH HEADERS FROM 'file:///skills.csv' AS row
MERGE (s:Skill {name: row.Name})
ON CREATE SET 
  s.description = row.Description,
  s.version = row.Version,
  s.path = row.Path,
  s.created = datetime(row.Created),
  s.modified = datetime(row.Modified);
```

### Step 3: Parse and Import Content

Use PowerShell to parse markdown and generate CSVs for sections, code blocks, etc., then import with
similar `LOAD CSV` queries.

---

## Querying the Skills Graph

### Find All Skills

```cypher
MATCH (s:Skill)
RETURN s.name, s.version, s.description
ORDER BY s.name;
```

### Find Skills Mentioning Docker

```cypher
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword {term: 'Docker'})
RETURN s.name, s.description;
```

### Find Related Skills

```cypher
MATCH (s:Skill {name: 'neo4j'})-[:REFERENCES]->(related:Skill)
RETURN related.name, related.description;
```

### Full-Text Search

```cypher
// Search skill names and descriptions
CALL db.index.fulltext.queryNodes('skillSearch', 'graph database')
YIELD node, score
RETURN node.name, node.description, score
ORDER BY score DESC
LIMIT 5;

// Search section content
CALL db.index.fulltext.queryNodes('contentSearch', 'Docker configuration')
YIELD node, score
MATCH (s:Section)<-[:HAS_SECTION]-(f:MarkdownFile)<-[:HAS_FILE]-(skill:Skill)
WHERE node = s
RETURN skill.name, s.heading, score
ORDER BY score DESC;
```

### Find Code Examples

```cypher
// Find all PowerShell code blocks
MATCH (c:CodeBlock {language: 'powershell'})
MATCH (c)<-[:HAS_CODE]-(s:Section)<-[:HAS_SECTION]-(f:MarkdownFile)
RETURN f.path, s.heading, c.code
LIMIT 10;

// Find code using specific tools
MATCH (c:CodeBlock)-[:USES]->(k:Keyword {term: 'Docker'})
MATCH (c)<-[:HAS_CODE]-(s:Section)<-[:HAS_SECTION]-(f:MarkdownFile)<-[:HAS_FILE]-(skill:Skill)
RETURN skill.name, s.heading, c.code;
```

### Skill Evolution (History)

```cypher
// Find recent changes to a skill
MATCH (s:Skill {name: 'neo4j'})-[:HAS_HISTORY]->(h:MarkdownFile)-[:HAS_ENTRY]->(e:HistoryEntry)
RETURN e.date, e.time, e.action, e.summary
ORDER BY e.date DESC, e.time DESC
LIMIT 10;
```

### Skill Dependencies

```cypher
// Find dependency chain
MATCH path = (s:Skill {name: 'neo4j'})-[:DEPENDS_ON*]->(dep:Skill)
RETURN [node IN nodes(path) | node.name] AS dependency_chain;
```

### Complex Pattern Matching

```cypher
// Find skills that reference each other (circular references)
MATCH (s1:Skill)-[:REFERENCES]->(s2:Skill)-[:REFERENCES]->(s1)
RETURN s1.name, s2.name;

// Find skill clusters (skills that reference common skills)
MATCH (s1:Skill)-[:REFERENCES]->(common:Skill)<-[:REFERENCES]-(s2:Skill)
WHERE s1 <> s2
RETURN common.name AS hub, collect(DISTINCT s1.name) AS referencing_skills
ORDER BY size(referencing_skills) DESC;
```

### Aggregation and Statistics

```cypher
// Count skills by version
MATCH (s:Skill)
RETURN s.version, count(*) AS skill_count
ORDER BY s.version;

// Find most referenced keywords
MATCH (k:Keyword)<-[:MENTIONS]-(s:Skill)
RETURN k.term, k.category, count(s) AS mention_count
ORDER BY mention_count DESC
LIMIT 10;

// Skills with most code examples
MATCH (s:Skill)-[:HAS_FILE]->()-[:HAS_SECTION]->()-[:HAS_CODE]->(c:CodeBlock)
RETURN s.name, count(c) AS code_block_count
ORDER BY code_block_count DESC;
```

---

## Advanced Features

### Vector Indexes for Semantic Search

**Requires embeddings** (from OpenAI, Azure, or local models):

```cypher
// Create vector index on skill descriptions
CREATE VECTOR INDEX skillDescriptionVector IF NOT EXISTS
FOR (s:Skill) ON (s.descriptionEmbedding)
OPTIONS {indexConfig: {
  `vector.dimensions`: 1536,
  `vector.similarity_function`: 'cosine'
}};

// Query similar skills (requires embedding vector)
MATCH (s:Skill)
WHERE s.descriptionEmbedding IS NOT NULL
CALL db.index.vector.queryNodes('skillDescriptionVector', 5, $queryEmbedding)
YIELD node, score
RETURN node.name, node.description, score;
```

### Graph Algorithms (Requires GDS Plugin)

```cypher
// PageRank to find most important skills
CALL gds.pageRank.stream({
  nodeProjection: 'Skill',
  relationshipProjection: 'REFERENCES'
})
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).name AS skill, score
ORDER BY score DESC;
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).name AS skill, score
ORDER BY score DESC;

// Community detection
CALL gds.louvain.stream({
  nodeProjection: 'Skill',
  relationshipProjection: {
    REFERENCES: {orientation: 'UNDIRECTED'}
  }
})
YIELD nodeId, communityId
RETURN communityId, collect(gds.util.asNode(nodeId).name) AS skills;
```

---

## Data Export and Backup

### Export to JSON

```cypher
// Export all skills as JSON
CALL apoc.export.json.query(
  "MATCH (s:Skill) RETURN s",
  "skills-export.json",
  {}
);

// Export entire graph
CALL apoc.export.json.all("skills-graph-full.json", {});
```

### Export to CSV

```cypher
// Export skill list
CALL apoc.export.csv.query(
  "MATCH (s:Skill) RETURN s.name, s.version, s.description",
  "skills-list.csv",
  {}
);
```

---

## Best Practices

### Modeling

1. **Use meaningful relationship types**: `-[:REFERENCES]->` is clearer than `-[:RELATES_TO]->`
2. **Store searchable content**: Full section text, not just headings
3. **Index frequently queried properties**: Name, type, category
4. **Use constraints for uniqueness**: Prevents duplicate skills/files
5. **Consider query patterns**: Model based on how you'll search

### Performance

1. **Create indexes before bulk imports**: Speeds up MERGE operations
2. **Use MERGE for upserts**: Prevents duplicates
3. **Batch large imports**: Use `IN TRANSACTIONS OF 500 ROWS`
4. **Profile slow queries**: `PROFILE` shows execution plan
5. **Use parameters**: Prevents query plan cache misses

### Maintenance

1. **Regular backups**: Use Docker volume backups
2. **Monitor index health**: `SHOW INDEXES`
3. **Update timestamps**: Track when data changes
4. **Prune old history**: Archive or delete old entries
5. **Validate relationships**: Ensure referential integrity
