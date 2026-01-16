# Neo4j Quick Reference

Quick reference for common Neo4j operations with the Skills knowledge graph.

## Basic Queries

### View All Skills

```cypher
MATCH (s:Skill)
RETURN s.name, s.version, s.description
ORDER BY s.name;
```

### Count Nodes by Type

```cypher
MATCH (n)
RETURN labels(n) AS type, count(*) AS count
ORDER BY count DESC;
```

### View Skill Details

```cypher
MATCH (s:Skill {name: 'neo4j'})
OPTIONAL MATCH (s)-[:HAS_FILE]->(f:MarkdownFile)
OPTIONAL MATCH (f)-[:HAS_SECTION]->(sec:Section)
OPTIONAL MATCH (s)-[:MENTIONS]->(k:Keyword)
RETURN s, collect(DISTINCT sec.heading) AS sections, collect(DISTINCT k.term) AS keywords;
```

## Search Operations

### Full-Text Search Skills

```cypher
CALL db.index.fulltext.queryNodes('skillSearch', 'docker graph')
YIELD node, score
RETURN node.name AS skill, node.description, score
ORDER BY score DESC
LIMIT 10;
```

### Full-Text Search Content

```cypher
CALL db.index.fulltext.queryNodes('contentSearch', 'import data')
YIELD node, score
MATCH (node)<-[:HAS_SECTION]-(f:MarkdownFile)<-[:HAS_FILE]-(s:Skill)
RETURN s.name AS skill, node.heading AS section, score
ORDER BY score DESC
LIMIT 10;
```

### Find Skills by Keyword

```cypher
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword {term: 'Docker'})
RETURN s.name, s.description;
```

### Find All Keywords

```cypher
MATCH (k:Keyword)
RETURN k.term, k.category
ORDER BY k.term;
```

## Code Block Queries

### Find PowerShell Code

```cypher
MATCH (c:CodeBlock {language: 'powershell'})
MATCH (c)<-[:HAS_CODE]-(f:MarkdownFile)<-[:HAS_FILE]-(s:Skill)
RETURN s.name AS skill, c.code
LIMIT 5;
```

### Find Code Using Docker

```cypher
MATCH (c:CodeBlock)
WHERE c.code CONTAINS 'docker'
MATCH (c)<-[:HAS_CODE]-(f:MarkdownFile)<-[:HAS_FILE]-(s:Skill)
RETURN s.name AS skill, c.language, c.code
LIMIT 10;
```

### Count Code Blocks by Language

```cypher
MATCH (c:CodeBlock)
RETURN c.language, count(*) AS count
ORDER BY count DESC;
```

## Relationship Queries

### Find Most Referenced Keywords

```cypher
MATCH (k:Keyword)<-[:MENTIONS]-(s:Skill)
RETURN k.term, k.category, count(s) AS skill_count
ORDER BY skill_count DESC
LIMIT 10;
```

### Skills with Most Code Examples

```cypher
MATCH (s:Skill)-[:HAS_FILE]->()-[:HAS_CODE]->(c:CodeBlock)
RETURN s.name, count(c) AS code_count
ORDER BY code_count DESC;
```

### Find Skills with Similar Keywords

```cypher
MATCH (s1:Skill {name: 'neo4j'})-[:MENTIONS]->(k:Keyword)<-[:MENTIONS]-(s2:Skill)
WHERE s1 <> s2
RETURN s2.name AS related_skill, collect(k.term) AS common_keywords;
```

## Graph Visualization

### Skill and Its Immediate Neighbors

```cypher
MATCH (s:Skill {name: 'neo4j'})-[r]-(n)
RETURN s, r, n
LIMIT 25;
```

### Subgraph of a Skill

```cypher
MATCH path = (s:Skill {name: 'neo4j'})-[:HAS_FILE]->()-[:HAS_SECTION|HAS_CODE]->(n)
RETURN path
LIMIT 50;
```

### Keywords Network

```cypher
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword)
WHERE k.term IN ['Docker', 'PowerShell', 'Python', 'Neo4j']
RETURN s, k
LIMIT 50;
```

## Aggregation Queries

### Skills by Version

```cypher
MATCH (s:Skill)
RETURN s.version, count(*) AS skill_count
ORDER BY s.version DESC;
```

### Average Sections per Skill

```cypher
MATCH (s:Skill)-[:HAS_FILE]->()-[:HAS_SECTION]->(sec:Section)
RETURN s.name, count(sec) AS section_count
ORDER BY section_count DESC;
```

### Skills by Keyword Category

```cypher
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword)
RETURN k.category, count(DISTINCT s) AS skill_count
ORDER BY skill_count DESC;
```

## Pattern Matching

### Find Skill Dependencies (if modeled)

```cypher
MATCH (s:Skill {name: 'neo4j'})-[:REFERENCES]->(dep:Skill)
RETURN dep.name AS dependency;
```

### Find Circular References

```cypher
MATCH (s1:Skill)-[:REFERENCES]->(s2:Skill)-[:REFERENCES]->(s1)
RETURN s1.name, s2.name;
```

### Find Skill Clusters

```cypher
MATCH (s1:Skill)-[:MENTIONS]->(k:Keyword)<-[:MENTIONS]-(s2:Skill)
WHERE s1 <> s2
WITH k.term AS keyword, collect(DISTINCT s1.name) AS skills
WHERE size(skills) > 2
RETURN keyword, skills
ORDER BY size(skills) DESC;
```

## Data Management

### Delete All Skills Data

**⚠️ WARNING: This deletes all data!**

```cypher
MATCH (n)
DETACH DELETE n;
```

### Delete Specific Skill

```cypher
MATCH (s:Skill {name: 'old-skill'})-[r]-()
DELETE s, r;
```

### Update Skill Property

```cypher
MATCH (s:Skill {name: 'neo4j'})
SET s.version = 'V1.2', s.modified = datetime();
```

### Add New Keyword

```cypher
MERGE (k:Keyword {term: 'PostgreSQL'})
ON CREATE SET k.category = 'Tool';
```

## Index Management

### List All Indexes

```cypher
SHOW INDEXES;
```

### List All Constraints

```cypher
SHOW CONSTRAINTS;
```

### Check Index Status

```cypher
SHOW INDEXES
YIELD name, type, state, populationPercent;
```

## Performance

### Profile Query Performance

```cypher
PROFILE
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword {term: 'Docker'})
RETURN s.name;
```

### Explain Query Plan

```cypher
EXPLAIN
MATCH (s:Skill)-[:MENTIONS]->(k:Keyword)
RETURN s.name, k.term;
```

## Export Data

### Export Skills as JSON

Requires APOC plugin:

```cypher
CALL apoc.export.json.query(
  "MATCH (s:Skill) RETURN s",
  "skills-export.json",
  {}
);
```

### Export Skills as CSV

```cypher
CALL apoc.export.csv.query(
  "MATCH (s:Skill) RETURN s.name, s.version, s.description",
  "skills.csv",
  {}
);
```

## Tips and Best Practices

1. **Use Parameters**: For better performance and security

   ```cypher
   :param skillName => 'neo4j'
   MATCH (s:Skill {name: $skillName}) RETURN s;
   ```

2. **Limit Large Results**: Always use LIMIT for exploratory queries

   ```cypher
   MATCH (n) RETURN n LIMIT 100;
   ```

3. **Use PROFILE for Optimization**: Identify slow queries

   ```cypher
   PROFILE MATCH (s:Skill) WHERE s.name CONTAINS 'docker' RETURN s;
   ```

4. **Leverage Indexes**: Full-text search is faster than CONTAINS

   ```cypher
   // Slower
   MATCH (s:Skill) WHERE s.description CONTAINS 'docker' RETURN s;
   
   // Faster
   CALL db.index.fulltext.queryNodes('skillSearch', 'docker') YIELD node RETURN node;
   ```

5. **Use MERGE for Idempotence**: Prevents duplicates

   ```cypher
   MERGE (s:Skill {name: 'example'})
   ON CREATE SET s.created = datetime()
   ON MATCH SET s.modified = datetime();
   ```
