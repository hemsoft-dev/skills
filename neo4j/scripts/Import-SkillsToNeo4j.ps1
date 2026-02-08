[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='User-facing script requires colored output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='Simple tool with default credentials')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification='Parse-*and Extract-* are clear names for private helper functions')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification='Function names accurately describe collections being parsed')]
<#
.SYNOPSIS
    Imports Claude skills markdown files into Neo4j graph database.

.DESCRIPTION
    Parses all SKILL.md files from the skills directory, extracts frontmatter,
    content structure, and creates nodes and relationships in Neo4j.

.PARAMETER SkillsPath
    Path to the skills directory. Defaults to $env:USERPROFILE\.agents\skills

.PARAMETER Neo4jUri
    Neo4j Bolt connection URI. Defaults to bolt://localhost:7687

.PARAMETER Username
    Neo4j username. Defaults to neo4j

.PARAMETER Password
    Neo4j password. Defaults to password

.EXAMPLE
    .\Import-SkillsToNeo4j.ps1

.EXAMPLE
    .\Import-SkillsToNeo4j.ps1 -SkillsPath "C:\custom\skills" -Password "mypassword"
# >

[CmdletBinding()]
param(
    [string]$SkillsPath = "$env:USERPROFILE\.agents\skills",
    [string]$Neo4jUri = "bolt://localhost:7687",
    [string]$Username = "neo4j",
    [string]$Password = "password"
)

# Function to parse frontmatter YAML

function Parse-Frontmatter {
    param([string]$Content)

    if ($Content -match '(?ms)^---\s*\n(.*?)\n---') {
        $yaml = $Matches[1]
        $properties = @{}

        foreach ($line in $yaml -split "`n") {
            if ($line -match '^(\w+):\s*(.+)$') {
                $key = $Matches[1].Trim()
                $value = $Matches[2].Trim()
                $properties[$key] = $value
            }
        }

        return $properties
    }

    return @{}
}

# Function to extract markdown sections

function Parse-Sections {
    param([string]$Content)

    $sections = @()
    $lines = $Content -split "`n"
    $currentSection = $null
    $order = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^(#{1,6})\s+(.+)$') {
            # Save previous section
            if ($currentSection) {
                $sections += $currentSection
            }

            $level = $Matches[1].Length
            $heading = $Matches[2].Trim()
            $order++

            $currentSection = @{
                heading = $heading
                level = $level
                content = ""
                order = $order
                startLine = $i
            }
        }
        elseif ($currentSection) {
            $currentSection.content += $line + "`n"
        }
    }

    # Add last section
    if ($currentSection) {
        $sections += $currentSection
    }

    return $sections
}

# Function to extract code blocks

function Parse-CodeBlocks {
    param([string]$Content)

    $codeBlocks = @()
    $order = 0

    if ($Content -match '(?ms)```(\w+)?\s*\n(.*?)```') {
        $codeMatches = [regex]::Matches($Content, '(?ms)```(\w+)?\s*\n(.*?)```')

        foreach ($match in $codeMatches) {
            $order++
            $language = if ($match.Groups[1].Value) { $match.Groups[1].Value } else { "text" }
            $code = $match.Groups[2].Value.Trim()

            $codeBlocks += @{
                language = $language
                code = $code
                order = $order
            }
        }
    }

    return $codeBlocks
}

# Function to extract keywords from content

function Extract-Keywords {
    param([string]$Content, [string]$Description)

    $keywords = @()

    # Common tools and technologies
    $tools = @(
        'Docker', 'PowerShell', 'Python', 'Node.js', 'npm', 'Git', 'GitHub',
        'Slack', 'Todoist', 'Neo4j', 'Cypher', 'Bun', 'VSCode', 'OpenAI',
        'Claude', 'Gemini', 'LangChain', 'Supabase', 'Vercel', 'Next.js',
        'React', 'TypeScript', 'JavaScript', 'C#', '.NET', 'Azure', 'AWS'
    )

    # Check description and content for tools
    foreach ($tool in $tools) {
        if (($Description -match "\b$tool\b") -or ($Content -match "\b$tool\b")) {
            $keywords += @{
                term = $tool
                category = 'Tool'
            }
        }
    }

    return $keywords
}

# Function to execute Cypher query

function Invoke-CypherQuery {
    param(
        [string]$Query,
        [hashtable]$Parameters = @{}
    )

    try {
        # Using curl/Invoke-RestMethod to execute Cypher via HTTP API
        $uri = "http://localhost:7474/db/neo4j/tx/commit"
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))

        $body = @{
            statements = @(
                @{
                    statement = $Query
                    parameters = $Parameters
                }
            )
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -Headers @{
            Authorization = "Basic $auth"
        }

        if ($response.errors -and $response.errors.Count -gt 0) {
            $error = $response.errors[0]
            Write-Warning "❌ Cypher query error: $($error.message)"
            if ($error.code) {
                Write-Warning "   Error code: $($error.code)"
            }
            return $null
        }

        return $response.results
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "Unable to connect") {
            Write-Warning "❌ Cannot connect to Neo4j at $uri"
            Write-Warning "   Ensure Neo4j container is running: docker ps --filter name=neo4j"
            Write-Warning "   If stopped, start it: docker start neo4j"
        } elseif ($errorMsg -match "401|Unauthorized") {
            Write-Warning "❌ Authentication failed. Check username/password."
            Write-Warning "   Default credentials: neo4j/password"
        } else {
            Write-Warning "❌ Failed to execute Cypher query: $errorMsg"
        }
        return $null
    }
}

# Main script

Write-Host "🚀 Starting Skills Import to Neo4j" -ForegroundColor Cyan
Write-Host "Skills Path: $SkillsPath" -ForegroundColor Gray
Write-Host "Neo4j URI: $Neo4jUri" -ForegroundColor Gray

# Pre-flight check: Verify Neo4j is accessible

Write-Host "`n🔍 Verifying Neo4j connection..." -ForegroundColor Cyan
try {
    $testQuery = "RETURN 1 AS test"
    $result = Invoke-CypherQuery -Query $testQuery
    if ($null -eq $result) {
        Write-Host "❌ Cannot connect to Neo4j. Please check:" -ForegroundColor Red
        Write-Host "   1. Docker Desktop is running: docker ps" -ForegroundColor Yellow
        Write-Host "   2. Neo4j container is running: docker ps --filter name=neo4j" -ForegroundColor Yellow
        Write-Host "   3. If stopped, start it: docker start neo4j" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Neo4j connection verified" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to verify Neo4j connection: $_" -ForegroundColor Red
    Write-Host "   Ensure Neo4j container is running: docker start neo4j" -ForegroundColor Yellow
    exit 1
}

# Step 1: Create constraints and indexes

Write-Host "`n📋 Creating constraints and indexes..." -ForegroundColor Yellow

$constraints = @(
    "CREATE CONSTRAINT skill_name IF NOT EXISTS FOR (s:Skill) REQUIRE s.name IS UNIQUE",
    "CREATE CONSTRAINT file_path IF NOT EXISTS FOR (f:MarkdownFile) REQUIRE f.path IS UNIQUE",
    "CREATE CONSTRAINT keyword_term IF NOT EXISTS FOR (k:Keyword) REQUIRE k.term IS UNIQUE"
)

$indexes = @(
    "CREATE INDEX skill_version IF NOT EXISTS FOR (s:Skill) ON (s.version)",
    "CREATE INDEX file_type IF NOT EXISTS FOR (f:MarkdownFile) ON (f.type)",
    "CREATE TEXT INDEX section_content IF NOT EXISTS FOR (s:Section) ON (s.content)",
    "CREATE TEXT INDEX code_text IF NOT EXISTS FOR (c:CodeBlock) ON (c.code)",
    "CREATE FULLTEXT INDEX skillSearch IF NOT EXISTS FOR (s:Skill) ON EACH [s.name, s.description]",
    "CREATE FULLTEXT INDEX contentSearch IF NOT EXISTS FOR (s:Section) ON EACH [s.heading, s.content]"
)

foreach ($constraint in $constraints) {
    Invoke-CypherQuery -Query $constraint
}

foreach ($index in $indexes) {
    Invoke-CypherQuery -Query $index
}

Write-Host "✅ Constraints and indexes created" -ForegroundColor Green

# Step 2: Find all SKILL.md files

Write-Host "`n🔍 Finding SKILL.md files..." -ForegroundColor Yellow
$skillFiles = Get-ChildItem -Path $SkillsPath -Recurse -Filter "SKILL.md" | Where-Object { $_.DirectoryName -notmatch '\\(node_modules|\.git|History)\\' }
Write-Host "Found $($skillFiles.Count) skills" -ForegroundColor Green

# Step 3: Import each skill

$skillCount = 0
foreach ($file in $skillFiles) {
    $skillCount++
    $skillName = $file.Directory.Name

    Write-Host "`n[$skillCount/$($skillFiles.Count)] Processing skill: $skillName" -ForegroundColor Cyan

    try {
        # Read file content
        $content = Get-Content $file.FullName -Raw -ErrorAction Stop

        # Parse frontmatter
        $frontmatter = Parse-Frontmatter -Content $content

        # Extract metadata
        $name = if ($frontmatter.name) { $frontmatter.name } else { $skillName }
        $description = if ($frontmatter.description) { $frontmatter.description } else { "" }
        $version = if ($description -match '^(V[\d.]+)') { $Matches[1] } else { "V1.0" }
        $license = $frontmatter.license
        $compatibility = $frontmatter.compatibility

        # Create Skill node
        $skillQuery = @"
MERGE (s:Skill {name: `$name})
ON CREATE SET
    s.description =`$description,
    s.version = `$version,
    s.path = `$path,
    s.created = datetime(),
    s.modified = datetime()
ON MATCH SET
    s.description =`$description,
    s.version = `$version,
    s.modified = datetime()
"@
        if ($license) { $skillQuery += "`nSET s.license =`$license" }
        if ($compatibility) { $skillQuery += "`nSET s.compatibility = `$compatibility" }

        $params = @{
            name = $name
            description = $description
            version = $version
            path = $file.FullName
            license = $license
            compatibility = $compatibility
        }

        Invoke-CypherQuery -Query $skillQuery -Parameters $params | Out-Null
        Write-Host "  ✅ Created Skill node" -ForegroundColor Green

        # Create MarkdownFile node
        $fileQuery = @"
MERGE (f:MarkdownFile {path: `$path})
ON CREATE SET
    f.filename =`$filename,
    f.type = 'SKILL',
    f.created = datetime(),
    f.modified = datetime(),
    f.size = `$size,
    f.lineCount = `$lineCount
ON MATCH SET
    f.modified = datetime(),
    f.size =`$size,
    f.lineCount = `$lineCount
"@

        $fileParams = @{
            path = $file.FullName
            filename = $file.Name
            size = $file.Length
            lineCount = (Get-Content $file.FullName | Measure-Object -Line).Lines
        }

        Invoke-CypherQuery -Query $fileQuery -Parameters $fileParams | Out-Null

        # Link Skill to File
        $linkQuery = @"
MATCH (s:Skill {name: `$name})
MATCH (f:MarkdownFile {path:`$path})
MERGE (s)-[:HAS_FILE]->(f)
"@

        Invoke-CypherQuery -Query $linkQuery -Parameters @{name = $name; path = $file.FullName} | Out-Null
        Write-Host "  ✅ Created MarkdownFile node and relationship" -ForegroundColor Green

        # Parse and create sections
        $sections = Parse-Sections -Content $content
        Write-Host "  📄 Found $($sections.Count) sections" -ForegroundColor Gray

        foreach ($section in $sections) {
            $sectionQuery = @"
MATCH (f:MarkdownFile {path: `$filePath})
CREATE (s:Section {
    heading:`$heading,
    level: `$level,
    content: `$content,
    order:`$order
})
CREATE (f)-[:HAS_SECTION]->(s)
"@

            $sectionParams = @{
                filePath = $file.FullName
                heading = $section.heading
                level = $section.level
                content = $section.content.Substring(0, [Math]::Min(5000, $section.content.Length))
                order = $section.order
            }

            Invoke-CypherQuery -Query $sectionQuery -Parameters $sectionParams | Out-Null
        }

        # Parse and create code blocks
        $codeBlocks = Parse-CodeBlocks -Content $content
        Write-Host "  💻 Found $($codeBlocks.Count) code blocks" -ForegroundColor Gray

        foreach ($codeBlock in $codeBlocks) {
            $codeQuery = @"
MATCH (f:MarkdownFile {path: `$filePath})
CREATE (c:CodeBlock {
    language:`$language,
    code: `$code,
    order: `$order
})
CREATE (f)-[:HAS_CODE]->(c)
"@

            $codeParams = @{
                filePath = $file.FullName
                language = $codeBlock.language
                code = $codeBlock.code.Substring(0, [Math]::Min(10000, $codeBlock.code.Length))
                order = $codeBlock.order
            }

            Invoke-CypherQuery -Query $codeQuery -Parameters $codeParams | Out-Null
        }

        # Extract and link keywords
        $keywords = Extract-Keywords -Content $content -Description $description
        Write-Host "  🏷️  Found $($keywords.Count) keywords" -ForegroundColor Gray

        foreach ($keyword in $keywords) {
            $keywordQuery = @"
MERGE (k:Keyword {term: `$term})
ON CREATE SET k.category =`$category
WITH k
MATCH (s:Skill {name: `$skillName})
MERGE (s)-[:MENTIONS]->(k)
"@

            $keywordParams = @{
                term = $keyword.term
                category = $keyword.category
                skillName = $name
            }

            Invoke-CypherQuery -Query $keywordQuery -Parameters $keywordParams | Out-Null
        }

        Write-Host "  ✅ Skill '$name' imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "❌ Failed to import skill '$skillName': $_"
        Write-Warning "   File: $($file.FullName)"
        if ($_.Exception.Message) {
            Write-Warning "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        # Continue with next skill instead of failing completely
    }
}

Write-Host "`n🎉 Import complete! Imported $skillCount skills" -ForegroundColor Green
Write-Host "`n🌐 Open Neo4j Browser: <http://localhost:7474>" -ForegroundColor Cyan
Write-Host "   Username: neo4j" -ForegroundColor Gray
Write-Host "   Password: password" -ForegroundColor Gray
