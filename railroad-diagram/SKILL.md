---
name: railroad-diagram
description: >-
  V1.0 - Commands: generate, generate-all, from-ebnf, explain.
  Generates SVG railroad syntax diagrams from JSON grammar definitions or EBNF notation.
  Uses tabatkins/railroad-diagrams (MIT). Includes pre-built grammars for VS Code
  agentic workflow frontmatter (.agent.md, .prompt.md, .instructions.md, SKILL.md).
  Use when visualizing syntax, grammars, or configuration schemas.
---

# Railroad Diagram Generator

## Default Behavior

When activated without a specific command, generate all pre-built grammars:

```powershell
cd c:\Users\User\.agents\skills\railroad-diagram
.\.venv\Scripts\Activate.ps1
python scripts/generate.py grammars/ --all
```

Then open the output folder for the user.

## Commands

| Command | What It Does |
|---------|-------------|
| `generate <file>` | Render a single `.grammar.json` file to HTML with SVG diagrams |
| `generate-all` | Render all grammars in `grammars/` folder |
| `from-ebnf <file>` | Convert EBNF notation to `.grammar.json`, then render |
| `explain <spec>` | Agent reads a spec/schema, writes a `.grammar.json`, then renders |

## File Structure

```text
railroad-diagram/
├── SKILL.md                    # This file
├── History/                    # Interaction logs
├── grammars/                   # JSON grammar definitions
│   ├── agent-md.grammar.json   # VS Code .agent.md frontmatter
│   ├── prompt-md.grammar.json  # VS Code .prompt.md frontmatter
│   ├── instructions-md.grammar.json  # VS Code .instructions.md frontmatter
│   └── skill-md.grammar.json  # SKILL.md frontmatter (agentskills.io)
├── output/                     # Generated HTML files with SVG diagrams
├── scripts/
│   ├── generate.py             # Main generator: JSON grammar → HTML+SVG
│   └── ebnf_to_grammar.py     # EBNF → JSON grammar converter
└── .venv/                      # Isolated Python virtual environment
```

## Grammar JSON Format

Grammar files use `.grammar.json` extension. Structure:

```json
{
  "meta": {
    "title": "Grammar Name",
    "description": "What this grammar describes",
    "source": "https://...",
    "version": "2026-04"
  },
  "rules": {
    "Rule Name": {
      "description": "Optional rule description",
      "definition": { ... }
    }
  }
}
```

### Node Types

| Type | Properties | Description |
|------|-----------|-------------|
| `Terminal` | `label` | Literal token (rounded box) |
| `NonTerminal` | `label` | Reference to another rule (rectangular box) |
| `Sequence` | `items[]` | Items in order, left to right |
| `Choice` | `items[]`, `default` | Alternative paths (vertical branches) |
| `Optional` | `items[]`, `skip` | Can be skipped (bypass path) |
| `OneOrMore` | `items[]` (body, separator) | Repeat 1+ times |
| `ZeroOrMore` | `items[]` (body, separator) | Repeat 0+ times |
| `Stack` | `items[]` | Vertical stacking for wide diagrams |
| `Group` | `items[]`, `label` | Named grouping box |
| `Comment` | `label` | Annotation text |
| `HorizontalChoice` | `items[]` | Side-by-side alternatives |
| `Skip` | — | Empty path |

Shorthand: a bare `"string"` becomes a Terminal; a bare `[array]` becomes a Sequence.

## Pre-Built Grammars

### VS Code Agentic Workflow Frontmatter

These grammars document the YAML frontmatter schemas for GitHub Copilot's
customization files:

| Grammar | Covers |
|---------|--------|
| `agent-md` | `.agent.md` — custom agents with tools, model, handoffs, visibility |
| `prompt-md` | `.prompt.md` — prompt files with agent target, tools |
| `instructions-md` | `.instructions.md` — path-scoped instructions with applyTo, excludeAgent |
| `skill-md` | `SKILL.md` — agent skills with dependencies, compatibility, hooks |

### Generating

```powershell
# All grammars
python scripts/generate.py grammars/ --all

# Single grammar
python scripts/generate.py grammars/agent-md.grammar.json

# Custom output path
python scripts/generate.py grammars/agent-md.grammar.json --output ~/Desktop/agent-md.html
```

## Explain Command (Agent Workflow)

When the user says "explain" with a spec or schema:

### Step 1: Read the specification

Read the provided URL, file, or pasted text.

### Step 2: Create the grammar JSON

Analyze the spec and create a `.grammar.json` file in `grammars/`. Use the
node type reference above to model the syntax accurately.

### Step 3: Generate the diagram

```powershell
cd c:\Users\User\.agents\skills\railroad-diagram
.\.venv\Scripts\Activate.ps1
python scripts/generate.py grammars/<name>.grammar.json
```

### Step 4: Show the result

Open the generated HTML file for the user.

## ALWAYS: Accuracy Audit After Generation

After generating or updating any grammar diagram, perform a **cross-reference audit** to verify the grammar matches the live specification:

### Audit Steps

1. **Fetch the live spec pages** referenced in `meta.source` (and related sub-pages).
2. **Read the full grammar JSON** that was just generated/updated.
3. **Cross-reference every rule** — for each field or option in the spec:
   - Is it present in the grammar? (missing = gap)
   - Is its value range correct? (e.g., `approved` only vs `none|low|medium|high|approved`)
   - Are all variants/choices included? (e.g., `bi-weekly`, `tri-weekly`)
4. **Check the user's actual workflow files** (if in workspace) against the grammar to catch real-world fields the grammar doesn't cover.
5. **Report findings as a table** with: Field, Grammar Status, Fix Needed.
6. **Fix all gaps immediately** — don't just report them.

### What to Look For

- **Missing fields**: Spec documents a field that grammar doesn't include
- **Wrong value ranges**: Grammar hardcodes one value but spec allows multiple
- **Missing choices**: Grammar has some options but not all (e.g., trigger types, schedule frequencies)
- **Missing trigger shorthands**: Natural-language triggers the spec documents but grammar omits
- **Missing safe output types**: New output types added to spec
- **Missing tool types**: New tools in the tools reference

### When to Audit

- Every time `generate` or `explain` produces output for a spec-backed grammar
- When user reports a discrepancy
- When fetching updated spec pages

## EBNF Conversion

For grammars written in EBNF notation:

```powershell
cd c:\Users\User\.agents\skills\railroad-diagram
.\.venv\Scripts\Activate.ps1

# Convert EBNF to grammar JSON
python scripts/ebnf_to_grammar.py input.ebnf --title "My Grammar" --output grammars/my.grammar.json

# Then render
python scripts/generate.py grammars/my.grammar.json
```

### Supported EBNF Syntax

| Notation | Meaning |
|----------|---------|
| `rule = expr ;` | Rule definition |
| `"text"` or `'text'` | Terminal |
| `Identifier` | NonTerminal |
| `a , b` | Sequence |
| `a \| b` | Choice/alternation |
| `[ expr ]` | Optional |
| `{ expr }` | Zero or more |
| `( expr )` | Grouping |
| `(* ... *)` | Comment (ignored) |

## Python Environment

The skill uses an isolated virtual environment at `.venv/`. To set up:

```powershell
$pythonExe = "C:\Users\User\AppData\Local\Programs\Python\Python312\python.exe"
cd c:\Users\User\.agents\skills\railroad-diagram
& $pythonExe -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install railroad-diagrams
```

## ALWAYS: Log This Interaction

Append to `History/YYYY-MM-DD.md`:

```markdown
## HH:MM - Action
One-line summary
```
