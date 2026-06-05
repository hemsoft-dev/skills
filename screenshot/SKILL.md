---
name: screenshot
description: Capture screenshots from the Windows clipboard or import SnagIt captures for AI description and OCR text extraction.
---

# Screenshot

Capture screenshots from the Windows clipboard, or import screenshots from SnagIt into skill image libraries.

## Default Behavior

When user activates this skill without specifying an action:

1. Try the Windows clipboard first with Script 0.
2. If the clipboard contains an image, save it only as a temporary PNG for agent inspection.
3. Inspect the temporary PNG with `view_image`.
4. Delete the temporary PNG immediately after it is understood or referenced in the reply.
5. If the clipboard has no image, fall back to the latest `.snagx` file in `D:\OneDrive\Snagit` and process it with Script 1.
6. If neither exists, report "No image found on clipboard and no SnagIt captures found" and stop.

Do not persist clipboard screenshots into `images/library` unless the user explicitly asks to import, save, archive, or add the screenshot to the library.

## Scripts

| # | Script | Purpose | When to Use |
|---|---|---|---|
| 0 | `0-Capture-Clipboard.ps1` | Save clipboard image to temp PNG; optionally import it | **Always start here by default** |
| 1 | `1-Extract-SnagX.ps1` | Extract PNG from `.snagx`, detect app/window, call script 2 | Use for SnagIt fallback or explicit `.snagx` import |
| 2 | `2-Process-Image.ps1` | Compress to WebP, generate AI description, extract OCR text, save metadata | Called by import workflows |
| 3 | `3-Search-Library.ps1` | Search existing screenshots by skill, tags, or text | Only for searching |

## Workflow: Inspect Current Clipboard Screenshot

Execute these steps in order:

### Step 1: Capture Clipboard Image

```powershell
& $env:USERPROFILE\.agents\skills\screenshot\scripts\0-Capture-Clipboard.ps1
```

If the script prints `CLIPBOARD_IMAGE_PATH=...`, inspect that file with `view_image`.

### Step 2: Clean Up Temporary Image

After inspection, delete the temporary file:

```powershell
Remove-Item -LiteralPath "<CLIPBOARD_IMAGE_PATH>" -Force
```

### Step 3: Fall Back to SnagIt When Clipboard Is Empty

If Script 0 reports no clipboard image, run:

```powershell
$latestSnagx = Get-ChildItem "D:\OneDrive\Snagit" -Filter "*.snagx" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestSnagx) {
    Write-Host "No image found on clipboard and no SnagIt captures found"
    return
}

& $env:USERPROFILE\.agents\skills\screenshot\scripts\1-Extract-SnagX.ps1 `
    -SnagItFileName $latestSnagx.Name `
    -DestinationSkill "screenshot" `
    -Tags @()
```

## Workflow: Import Clipboard Screenshot To Library

Only use this when the user explicitly asks to save/import/archive the clipboard screenshot.

```powershell
& $env:USERPROFILE\.agents\skills\screenshot\scripts\0-Capture-Clipboard.ps1 `
    -DestinationSkill "screenshot" `
    -Tags @() `
    -PersistToLibrary
```

Script 0 deletes its temporary PNG after importing it into the library.

## Workflow: Search Existing Screenshots

```powershell
# All screenshots
& $env:USERPROFILE\.agents\skills\screenshot\scripts\3-Search-Library.ps1

# Filter by skill
& $env:USERPROFILE\.agents\skills\screenshot\scripts\3-Search-Library.ps1 -Skill "architect"

# Search by text
& $env:USERPROFILE\.agents\skills\screenshot\scripts\3-Search-Library.ps1 -SearchText "workflow"
```

## Filename Conventions

Script 1 auto-detects source and prefixes filenames:

| Source | Detection | Prefix | Example |
|---|---|---|---|
| Slack | AppName="Slack" or window contains "\|" | `slack-` | `slack-dm-bryan.webp` |
| Twitter/X | Short window title + browser app | `tweet-` | `tweet-timeline.webp` |
| Other | - | None | `vscode-editor.webp` |

Clipboard imports use `clipboard-{timestamp}.webp` unless explicitly renamed later.

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
  "filename": "clipboard-20260601-203000.webp",
  "source": "Clipboard",
  "source_library": "Windows Clipboard",
  "imported_date": "2026-06-01",
  "description": "AI-generated description of image content",
  "text_content": "Full OCR text extraction",
  "tags": ["tag1", "tag2"],
  "skill": "screenshot"
}
```

## Dependencies

- **FFmpeg** - WebP compression for library imports
- **text-read-image skill** - AI description and OCR for library imports

## ALWAYS: Log This Interaction

After completing work, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary}
```
