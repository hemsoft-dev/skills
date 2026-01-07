---
name: token-encoder
description: V1.1 - When you, the LLM, need to transfer information in an optimized way, use Token-Oriented Object Notation (TOON) to reduce token usage by 30-60% compared to JSON.
---

# Token Encoder (TOON)

Token-Oriented Object Notation (TOON) is a compact, human-readable encoding of the JSON data model designed specifically for one-way token optimization in LLM prompts. It combines YAML-like indentation for objects with CSV-style tabular layouts for uniform arrays to achieve maximum density.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Usage

Use this skill when you need to transfer large datasets or complex objects to an LLM while minimizing token consumption. This is a one-way encoding process; the format is optimized for model comprehension, not for programmatic round-trips.

### Encoding Data

To encode a PowerShell object or JSON string to TOON:

```powershell
# From a PowerShell object
$data | pwsh -File tasks/encode.ps1

# From a JSON string
pwsh -File tasks/encode.ps1 -Json '{"key": "value"}'

# With tab delimiters (most efficient for many tokenizers)
$data | pwsh -File tasks/encode.ps1 -Delimiter tab
```

### Format Overview

- **Objects**: `key: value` with indentation.
- **Arrays**: `name[count]: val1,val2,val3`
- **Tabular Arrays**: 
  ```toon
  users[2]{id,name,role}:
    1,Alice,admin
    2,Bob,user
  ```

## Best Practices

1. **Tab Delimiters**: Use `-Delimiter tab` for maximum token savings, as many tokenizers (like GPT-4/o1) handle tabs more efficiently than commas.
2. **Key Folding**: Use `-KeyFolding safe` to collapse deeply nested single-key objects (e.g., `a.b.c: value`).
3. **Code Blocks**: Always wrap TOON output in ` ```toon ` code blocks.
4. **Headers**: When asking a model to generate TOON, provide the header template (e.g., `users[N]{id,name}`) to ensure consistency.
