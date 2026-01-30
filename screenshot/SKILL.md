---
name: screenshot
description: V2.0 - SnagIt screenshot library management. Import .snagx files with automatic WebP compression, AI-generated descriptions, smart filenames from window metadata, and superior OCR text extraction. Defaults to processing latest SnagIt capture when no action specified.
---

# Screenshot

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Import and manage screenshots from your SnagIt library with automatic processing, AI descriptions, and OCR text extraction.

## Default Behavior

**When user activates this skill without specifying an action:**

Automatically process the latest screenshot from SnagIt library (equivalent to "grab latest screenshot"):

1. Find most recent .snagx file in `D:\OneDrive\Snagit`
2. Import to screenshot skill's own `images/library/{date}/` folder
3. Generate AI description and extract OCR text
4. Save with smart filename from window metadata

**User must explicitly request otherwise to:**

- Import to a different skill: "import to [skillname]"
- Add specific tags: "with tags [tag1, tag2]"
- Search existing screenshots: "search screenshots"
- List screenshots: "show screenshots"

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Grab Latest Screenshot

**Triggered by:**

- "grab the latest screenshot" or "get the latest screenshot"
- **Using screenshot skill without specifying an action** (default behavior)
- "process latest screenshot"

Find the most recent .snagx file in the SnagIt library and import it to the screenshot skill's own image library:

**Default behavior:**

- **Destination:** `screenshot` skill (this skill's own `images/library/` folder)
- **Tags:** Empty by default
- **Auto-description:** Enabled (AI generates description + OCR)

```powershell
# Find and import latest screenshot
$latestSnagx = Get-ChildItem "D:\OneDrive\Snagit" -Filter "*.snagx" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if ($latestSnagx) {
    Write-Host "Latest screenshot: $($latestSnagx.Name)" -ForegroundColor Cyan
    Write-Host "Captured: $($latestSnagx.LastWriteTime)" -ForegroundColor Gray
    
    # Import to screenshot skill's library by default
    & ~/.claude/skills/screenshot/scripts/Import-SnagItScreenshot-Auto.ps1 `
        -SnagItFileName $latestSnagx.Name `
        -DestinationSkill "screenshot" `
        -Tags @()
} else {
    Write-Host "No .snagx files found in SnagIt library" -ForegroundColor Red
}
```

**To import to a different skill, user must specify:**

- "grab the latest screenshot and import to [skillname]"
- "get the latest screenshot for the [skillname] skill"

## SnagIt Integration

Import important screenshots from your SnagIt library into skills with automatic compression, AI-generated descriptions, and metadata tracking.

### Quick Start

```powershell
# Import screenshot with AI auto-description
& ~/.claude/skills/screenshot/scripts/Import-SnagItScreenshot-Auto.ps1 `
    -SnagItFileName "2026-01-30_09-56-49.snagx" `
    -DestinationSkill "myskill" `
    -Tags @("architecture")
```

### SnagIt Library Location

**Path:** `D:\OneDrive\Snagit`
**Total files:** ~2,823 screenshots (.snagx format)

### Import Workflow

**Automated Method (Recommended)**

Import directly from SnagIt library - no manual export needed:

```powershell
# Basic import with auto-description
& ~/.claude/skills/screenshot/scripts/Import-SnagItScreenshot-Auto.ps1 `
    -SnagItFileName "2026-01-30_09-56-49.snagx" `
    -DestinationSkill "myskill" `
    -Tags @("architecture", "critical")

# With custom description (skip AI)
& ~/.claude/skills/screenshot/scripts/Import-SnagItScreenshot-Auto.ps1 `
    -SnagItFileName "workflow-diagram.snagx" `
    -DestinationSkill "protocols" `
    -Tags @("workflow") `
    -CustomDescription "OAuth integration flow" `
    -AutoDescription:$false
```

**What this does:**

- Finds `.snagx` file in your SnagIt library (`D:\OneDrive\Snagit`)
- Automatically extracts the PNG from the .snagx container
- **Generates descriptive filename** from window name (e.g., `slack-dm-bryan-halterman.webp`)
- Compresses to WebP (1024px wide, Q85)
- Generates AI description using vision model (default: enabled)
- **Extracts ALL visible text (OCR)** - better than SnagIt's runtime-only OCR
- Creates `.meta.json` sidecar file with description + OCR text
- Cleans up temporary files
- Stores in `skill-name/images/library/YYYY-MM-DD/`

**Manual Method (If Already Exported)**

If you've already exported a PNG from SnagIt:

```powershell
& ~/.claude/skills/screenshot/scripts/Import-SnagItScreenshot.ps1 `
    -ImagePath "C:\Temp\my-screenshot.png" `
    -DestinationSkill "myskill" `
    -Tags @("architecture") `
    -AutoDescription
```

### Parameters

**Import-SnagItScreenshot-Auto.ps1** (Automated from .snagx)

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-SnagItFileName` | Yes | - | Filename from SnagIt library (e.g., `2026-01-30_09-56-49.snagx`) |
| `-DestinationSkill` | Yes | - | Skill name (folder name in skills directory) |
| `-Tags` | No | `@()` | Array of tags for categorization |
| `-AutoDescription` | No | `$true` | Generate AI description using vision model |
| `-CustomDescription` | No | `""` | Provide custom description (sets `-AutoDescription:$false`) |

**Import-SnagItScreenshot.ps1** (Manual from exported PNG)

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-ImagePath` | Yes | - | Path to exported PNG/JPG file |
| `-DestinationSkill` | Yes | - | Skill name (folder name in skills directory) |
| `-Tags` | No | `@()` | Array of tags for categorization |
| `-AutoDescription` | No | `$false` | Generate AI description using vision model |
| `-CustomDescription` | No | `""` | Provide your own description instead |

### How .snagx Extraction Works

SnagIt's `.snagx` files are ZIP containers with this structure:

```
2026-01-30_09-56-49.snagx
├── {GUID}.png          ← Main captured image (we extract this)
├── {GUID}.json         ← Edit history
├── metadata.json       ← Capture metadata
├── index.json          ← File index
└── thumbnail.png       ← Preview thumbnail
```

The automated script extracts the main PNG, processes it, then cleans up temporary files.

### Folder Structure

```
myskill/
├── SKILL.md
├── images/
│   └── library/
│       ├── 2026-01-30/
│       │   ├── architecture-diagram.webp
│       │   ├── architecture-diagram.webp.meta.json
│       │   ├── workflow.webp
│       │   └── workflow.webp.meta.json
│       └── 2026-01-29/
│           └── ...
```

### Metadata Format

Each imported image gets a `.meta.json` sidecar file:

```json
{
  "filename": "bryan-halterman-dm-relias-engineering-slack.webp",
  "source": "SnagIt",
  "snagit_library": "D:\\OneDrive\\Snagit",
  "imported_date": "2026-01-30",
  "imported_time": "14:32:15",
  "description": "Discord conversation about console-output skill with GitHub CLI screenshot showing Pull Requests...",
  "text_content": "Bryan Halterman 9:32 AM\\nToday\\nso I tried to make a console-output skill...\\n[Full OCR text of conversation and GitHub CLI table]",
  "tags": ["architecture", "critical"],
  "skill": "architect",
  "size_webp": "1024x1036",
  "size_original": "681x689",
  "original_filename": "{DD100B78-3DB4-42E5-947C-2D82F87B2629}.png",
  "original_path": "C:\\Temp\\extract\\{DD100B78-3DB4-42E5-947C-2D82F87B2629}.png"
}
```

**Key fields:**

- `description` - AI-generated summary of image content
- `text_content` - Full OCR text extraction (all visible text)

### Search Imported Screenshots

List and search all imported screenshots across skills:

```powershell
# List all imported screenshots
& ~/.claude/skills/screenshot/scripts/Get-ImportedScreenshots.ps1

# Filter by skill
& ~/.claude/skills/screenshot/scripts/Get-ImportedScreenshots.ps1 -Skill "architect"

# Filter by tags
& ~/.claude/skills/screenshot/scripts/Get-ImportedScreenshots.ps1 -Tags @("architecture", "critical")

# Search by text in description/filename
& ~/.claude/skills/screenshot/scripts/Get-ImportedScreenshots.ps1 -SearchText "workflow"

# Show full file paths
& ~/.claude/skills/screenshot/scripts/Get-ImportedScreenshots.ps1 -ShowPaths
```

### Referencing in SKILL.md

After importing, add to your skill's SKILL.md:

```markdown
## Architecture Diagram

![Architecture Overview](./images/library/2026-01-30/architecture-diagram.webp)

**Description:** Three-tier system architecture showing frontend, API gateway, and database layers.
```

### Features

✓ **Smart filenames** - Uses window name from SnagIt metadata (not GUIDs)  
✓ **Deduplication** - Warns if filename already exists  
✓ **Auto-compression** - Reduces to WebP Q85 @ 1024px (82% smaller)  
✓ **AI descriptions** - Vision model analyzes and describes content  
✓ **OCR text extraction** - Extracts ALL visible text (superior to SnagIt's runtime-only OCR)  
✓ **Metadata tracking** - Full provenance from SnagIt library  
✓ **Tag-based organization** - Categorize and search easily  
✓ **Skill-based storage** - Images live with the skills they document  

### OCR vs SnagIt Text Recognition

| Feature | SnagIt OCR | Our Vision Model |
|---------|------------|------------------|
| Stored in `.snagx` | ❌ No (runtime only) | ✅ Yes (`.meta.json`) |
| Table extraction | ⚠️ Limited | ✅ Excellent |
| Context understanding | ❌ No | ✅ Generates description |
| Searchable after import | ❌ No | ✅ Yes (`Get-ImportedScreenshots`) |
| Requires manual extraction | ✅ Yes | ❌ Automatic |

Our vision model extracts text automatically on import and stores it permanently in searchable metadata.  

### Cost Optimization

- **Vision API calls:** Only when using `-AutoDescription`
- **Default model:** `google/gemini-2.0-flash-001` (~$0.0001 per image)
- **Descriptions cached** in metadata JSON (one-time cost)
- **Search is free** - Queries local JSON files only

## Dependencies

- **PowerShell** - For SnagIt file management and import workflows
- **FFmpeg** - For WebP compression (available system-wide)
- **OpenRouter API** - For AI vision descriptions and OCR text extraction

## How Screenshots Are Taken

All screenshots are captured using **SnagIt** software:

- Press `PrtScn` to capture full screen, region, or window
- SnagIt saves to `D:\OneDrive\Snagit` as `.snagx` files
- Use this skill to import and process captures into skill libraries

**SnagIt replaces all manual capture methods** - no python-mss, no PowerShell screen capture needed.
