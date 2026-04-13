---
name: screenshot
description: Import screenshots from SnagIt into skill image libraries with AI description and OCR text extraction.
---

# Screenshot

Import screenshots from SnagIt into skill image libraries.

## Default Behavior

When user activates this skill without specifying an action:

1. Look for latest .snagx file in `D:\OneDrive\Snagit`
2. **If none found**: Report "No SnagIt captures found" and stop (do not search other locations)
3. **If found**: Process it with Script 1

## Scripts (Execute in Order)

| # | Script | Purpose | When to Use |
|---|--------|---------|-------------|
| 1 | `1-Extract-SnagX.ps1` | Extract PNG from .snagx, detect app/window, call script 2 | **Always start here** for .snagx files |
| 2 | `2-Process-Image.ps1` | Compress to WebP, generate AI description, extract OCR text, save metadata | Called automatically by script 1 |
| 3 | `3-Search-Library.ps1` | Search existing screenshots by skill, tags, or text | Only for searching |

## Workflow: Import Latest Screenshot

Execute these steps in order:

### Step 1: Find Latest .snagx File

```powershell
$latestSnagx = Get-ChildItem "D:\OneDrive\Snagit" -Filter "*.snagx" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1
Write-Host "Found: $($latestSnagx.Name) - Captured: $($latestSnagx.LastWriteTime)"
```

### Step 2: Run Script 1-Extract-SnagX.ps1

```powershell
& ~/.claude/skills/screenshot/scripts/1-Extract-SnagX.ps1 `
    -SnagItFileName $latestSnagx.Name `
    -DestinationSkill "screenshot" `
    -Tags @()
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-SnagItFileName` | Yes | - | Filename from SnagIt library |
| `-DestinationSkill` | Yes | - | Target skill name |
| `-Tags` | No | `@()` | Array of tags |
| `-AutoDescription` | No | `$true` | Generate AI description |
| `-CustomDescription` | No | `""` | Skip AI, use this description |

### Step 3: Verify Output

Check `{skill}/images/library/{date}/` for:

- `{filename}.webp` - Compressed image
- `{filename}.webp.meta.json` - Description + OCR text + metadata

## Workflow: Search Existing Screenshots

```powershell
# All screenshots
& ~/.claude/skills/screenshot/scripts/3-Search-Library.ps1

# Filter by skill
& ~/.claude/skills/screenshot/scripts/3-Search-Library.ps1 -Skill "architect"

# Search by text
& ~/.claude/skills/screenshot/scripts/3-Search-Library.ps1 -SearchText "workflow"
```

## Filename Conventions

Script 1 auto-detects source and prefixes filenames:

| Source | Detection | Prefix | Example |
|--------|-----------|--------|---------|
| Slack | AppName="Slack" or window contains "\|" | `slack-` | `slack-dm-bryan.webp` |
| Twitter/X | Short window title + browser app | `tweet-` | `tweet-timeline.webp` |
| Other | - | None | `vscode-editor.webp` |

## Output Structure

```
{skill}/
└── images/
    └── library/
        └── 2026-02-02/
            ├── slack-channel-name.webp
            └── slack-channel-name.webp.meta.json
```

## Metadata Format

```json
{
  "filename": "slack-channel-name.webp",
  "source": "SnagIt",
  "imported_date": "2026-02-02",
  "description": "AI-generated description of image content",
  "text_content": "Full OCR text extraction",
  "tags": ["tag1", "tag2"],
  "skill": "screenshot"
}
```

## Dependencies

- **FFmpeg** - WebP compression
- **text-read-image skill** - AI description and OCR

## ALWAYS: Log This Interaction

After completing work, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary}
```

```
