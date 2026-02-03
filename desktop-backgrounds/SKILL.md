---
name: desktop-backgrounds
description: V1.0 - Curates and manages a personal collection of high-quality desktop backgrounds from vetted free sources. Integrates with the Generate Image skill to create custom backgrounds on demand. Library includes tech-related, Microsoft-related, and engineering software themes.
---

# Desktop Backgrounds Skill

## Default Behavior

When activated without specifying an action, display the current background collection summary and offer interactive options:

- **View current collection** - list categories and background counts
- **Add a background** - import from file or URL
- **Generate new** - use Generate Image skill
- **Browse sources** - discover from trusted free sources
- **Apply background** - set as Windows wallpaper

## Folder Structure

```
desktop-backgrounds/
├── SKILL.md                 # Main skill documentation
├── RESOURCES.md             # Curated sources and Windows-compatible background recommendations
├── History/
│   └── YYYY-MM-DD.md (interaction logs)
├── assets/
│   ├── Favorites/           # Top-tier personal collection
│   ├── Tech-Engineering/    # Development, coding, software engineering themes
│   ├── Microsoft-Windows/   # Microsoft branding, Windows-themed backgrounds
│   ├── Generated/           # Custom wallpapers from Generate Image skill
│   ├── Minimalist/          # Clean, simple, minimal designs
│   ├── Dark/                # Dark mode backgrounds
│   ├── Colorful/            # Vibrant, multi-color designs
│   └── Abstract/            # Geometric, abstract, artistic backgrounds
└── scripts/
    └── Set-Wallpaper.ps1    # PowerShell script for applying wallpapers
```

## Default Workflow

**First interaction**: User says "I want to manage my desktop backgrounds" or similar.

**Agent response**:

1. Check if assets folder exists and list current backgrounds
2. Display categories and counts
3. Offer menu of available actions

## Use Cases and Workflows

### Use Case 1: View Current Background Collection

**Trigger**: "List my backgrounds" or "Show my background collection"

**Workflow**:

1. List all categories in assets/
2. For each category, count background files
3. Format as table with category name and background count
4. Show total backgrounds available
5. Offer action options (add new, generate, browse sources, apply)

**Expected Output**:

```
📁 Background Collection Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Category              Backgrounds    Notes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Favorites            X
Tech-Engineering     X
Microsoft-Windows    X
Generated            X
Minimalist           X
Dark                 X
Colorful             X
Abstract             X
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: X backgrounds across 8 categories
```

### Use Case 2: Add a Background Manually

**Trigger**: "Add a background" or "Add background from file" or filename provided (e.g., "Add sunset.png")

**Workflow**:

1. If file path/URL provided, copy to appropriate category folder
   - Ask user to specify category if not obvious
   - Validate image format (.png, .jpg, .jpeg, .webp, etc.)
2. If no file provided, ask user to:
   - Provide file path or URL
   - Select destination category
3. Confirm addition with filename and location
4. Log to History/YYYY-MM-DD.md with timestamp and source

**Parameters**:

| Parameter | Type | Required | Notes |
|-----------|------|----------|-------|
| file | string | Yes if not in context | Path, URL, or filename in active directory |
| category | string | No | Target folder; defaults to Favorites if unspecified |
| source | string | No | Website or origin (e.g., "Unsplash", "custom") |

### Use Case 3: Generate Custom Background

**Trigger**: "Generate a background" or "Create a background" or prompt description (e.g., "Generate a minimalist dark blue background")

**Workflow**:

1. Take or ask for aesthetic/theme description
2. Map to Generate Image skill with parameters:
   - Prompt: enhanced description for visual generation
   - Model: suggest Seedream or Nano Banana Pro for high quality
   - Save path: `assets/Generated/[timestamp-description].png`
3. Execute Generate Image command
4. Confirm generation with preview/path
5. Log to History with timestamp, prompt, and model used

**Expected Prompt Mapping**:

- "minimalist dark background" → full prompt for clean aesthetic
- "tech code editor theme" → prompt with monitors, code syntax
- "Microsoft Windows modern" → prompt with Windows design language

### Use Case 4: Browse Recommended Sources

**Trigger**: "Find backgrounds" or "Browse sources" or "Show sources"

**Workflow**:

1. Direct user to [RESOURCES.md](RESOURCES.md) for comprehensive, curated background recommendations
2. RESOURCES.md includes:
   - Direct search/collection links for each source
   - Category-specific recommendations (Tech, Minimalist, Dark, etc.)
   - Windows-compatible resolutions
   - GitHub repository cloning instructions for batch collections
   - Bulk download tips and best practices
3. User can:
   - Browse curated links directly
   - Search specific categories
   - Clone GitHub repos for entire themed collections
   - Download individual images from stock sites

**Quick Reference - Trusted Sources**:

| Source | Type | Best For | Direct Link |
|--------|------|----------|-------------|
| **Unsplash** | Stock Photos | Professional photography, diverse themes | [https://unsplash.com/t/wallpapers](https://unsplash.com/t/wallpapers) |
| **Pexels** | Stock Photos | Free commercial use, high-quality | [https://www.pexels.com/search/wallpaper/](https://www.pexels.com/search/wallpaper/) |
| **Pixabay** | Photos + Illustrations | Variety including vectors and drawings | [https://pixabay.com/images/search/wallpaper/](https://pixabay.com/images/search/wallpaper/) |
| **Wallhaven** | Community Curated | Aesthetic/gaming wallpapers, best filtering | [https://wallhaven.cc](https://wallhaven.cc) |
| **D3Ext GitHub** | Open-Source | 500+ minimalist aesthetic wallpapers | [https://github.com/D3Ext/aesthetic-wallpapers](https://github.com/D3Ext/aesthetic-wallpapers) |
| **nordic-wallpapers** | Open-Source | Nordic colorscheme, minimalist tech | [https://github.com/linuxdotexe/nordic-wallpapers](https://github.com/linuxdotexe/nordic-wallpapers) |
| **gruvbox-wallpapers** | Open-Source | Retro warm aesthetic, developer-friendly | [https://github.com/AngelJumbo/gruvbox-wallpapers](https://github.com/AngelJumbo/gruvbox-wallpapers) |

**See [RESOURCES.md](RESOURCES.md) for detailed collection links, search terms, and bulk download instructions.**

### Use Case 5: Apply Background to Windows

**Trigger**: "Apply background" or "Set wallpaper" or "Change wallpaper to [filename]"

**Workflow**:

1. List available backgrounds in assets/ (with preview thumbnails if possible)
2. Ask user to select background and target monitor(s):
   - All monitors (default)
   - Primary monitor only
   - Specific monitor (if multi-monitor setup)
3. Execute Set-Wallpaper.ps1 script
4. Confirm application with visual feedback
5. Log to History with timestamp, background name, and monitor(s)

**Script Reference**: scripts/Set-Wallpaper.ps1

- Sets Windows wallpaper via registry
- Supports single and multi-monitor setups
- Supports tile, center, stretch, fit, fill options

## Integration Points

### Generate Image Skill

- **When to use**: User requests custom backgrounds
- **Parameters passed**:
  - `prompt`: Enhanced aesthetic description
  - `model`: Seedream or Nano Banana Pro (high quality)
  - `output_path`: `assets/Generated/[description-timestamp].png`
- **Expected output**: Generated image file in assets/Generated/

### Windows PowerShell

- **When to use**: Applying backgrounds to desktop(s)
- **Script**: scripts/Set-Wallpaper.ps1
- **Capabilities**:
  - Get current wallpaper
  - Set wallpaper for all monitors
  - Set wallpaper for specific monitor
  - Support multiple fill styles (stretch, fit, center, tile, fill)

### File Management

- **Assets folder**: Central repository for background organization
- **History folder**: Persistent interaction logging
- **Metadata**: Optional JSON metadata for each background (source, artist, category tags)

## ALWAYS: Log This Interaction

Every meaningful background management action must be logged to `History/YYYY-MM-DD.md`:

**Log Format**:

```markdown
## HH:MM - Action Taken
Brief 1-2 sentence description of what was done

**Details**:
- Background: [filename or description]
- Category: [folder name]
- Source: [URL, "Generated", or "Manual"]
- Action: [Added/Generated/Applied/Discovered]
```

**Example Entries**:

```markdown
## 14:32 - Added Tech Engineering Background
Added "code-editor-minimal.png" to Tech-Engineering folder from Unsplash

**Details**:
- Background: code-editor-minimal.png
- Category: Tech-Engineering
- Source: https://unsplash.com/photos/...
- Action: Added

## 09:15 - Generated Custom Minimalist Background
Created custom minimalist dark blue background using Generate Image skill (Seedream model)

**Details**:
- Background: generated-2026-02-02-minimalist-blue.png
- Category: Generated
- Source: Generated (Seedream)
- Action: Generated
- Prompt: "Minimalist dark blue background with subtle geometric shapes, clean aesthetic"

## 16:45 - Applied Background to All Monitors
Set "Tech-Engineering/code-editor-minimal.png" as wallpaper for all monitors (2-monitor setup)

**Details**:
- Background: code-editor-minimal.png
- Category: Tech-Engineering
- Source: Unsplash
- Action: Applied
- Target: All monitors (primary + secondary)
```

**When to Log**:

- ✅ Added new background from file or URL
- ✅ Generated custom background
- ✅ Applied background to monitor(s)
- ✅ Discovered new source or collection
- ❌ Simple viewing/listing (not necessary)
- ❌ Navigation or questions without action

## Asset Categories Reference

### Favorites

Top-tier, go-to backgrounds used frequently. Manual curation.

### Tech-Engineering

Development environments, code editors, coding aesthetics, hackathon vibes, developer tools, software engineering themes.

### Microsoft-Windows

Windows 11 official wallpapers, Microsoft design language, Fluent Design System, modern UI, Office aesthetics.

### Generated

Custom backgrounds created via Generate Image skill. Auto-organize by date.

### Minimalist

Clean, simple designs. Minimal colors, geometric, whitespace-focused.

### Dark

Dark mode optimized. Black backgrounds, dark grays, night themes. Good for OLED displays.

### Colorful

Vibrant, multi-color designs. Sunsets, gradients, neon, rainbow aesthetics.

### Abstract

Geometric, artistic, abstract designs. Digital art, mathematical patterns, creative interpretations.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Wallpaper won't apply | Run Set-Wallpaper.ps1 with admin privileges; verify image path is correct |
| Image format not supported | Convert to .png, .jpg, or .webp using Image Magick skill |
| Can't find source website | Check provided URLs are accessible and current; perform web search for alternatives |
| Multi-monitor setup issues | Manually select monitor in script or use Windows Display Settings directly |

## Version History

- **V1.0** (2026-02-02) - Initial skill creation with core background management and integration
