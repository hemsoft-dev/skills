---
name: wezterm
description: V1.0 - Expert in WezTerm terminal configuration, theme management, and settings. Use when modifying WezTerm config, changing themes, or adjusting terminal settings.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the wezterm directory (path contains 'wezterm'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if wezterm was used (check if any files in wezterm directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in wezterm directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
              - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
              - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# WezTerm Configuration Manager

Expert in managing WezTerm terminal emulator configuration, specializing in theme cycling and settings management.

## Configuration Location

**Primary Config File**: `~\.wezterm.lua` (Windows: `C:\Users\User\.wezterm.lua`)

The configuration file is automatically reloaded by WezTerm when saved - changes are visible immediately.

## Available Themes

The configuration contains 21 commented-out themes that can be tested:

1. Bamboo
2. Fahrenheit
3. Galaxy
4. GJM (terminal.sexy)
5. Hacktober
6. N0tch2k
7. Obsidian
8. Palenight (Gogh)
9. Qualia (base16)
10. Railscasts (base16)
11. s3r0 modified (terminal.sexy) - **CURRENT**
12. Tango (base16)
13. Ubuntu
14. Vacuous 2 (terminal.sexy)
15. Warm Neon (Gogh)
16. X::DotShare (terminal.sexy)
17. Yousai (terminal.sexy)
18. zenbones
19. zenbones_dark
20. Zenburn
21. Zenburn (base16)
22. Zenburn (Gogh)
23. zenburned

## Theme Cycling Workflow

When user requests theme cycling:

1. **Uncomment next theme** in sequence
2. **Comment out current active theme**
3. **Save the file** (WezTerm auto-reloads)
4. **Ask user**: "Is this the theme you want? (Current: {theme-name})"
5. **If no**: Move to next theme and repeat
6. **If yes**: Confirm selection and stop

## Theme Change Pattern

To activate a theme, modify the color scheme section:

**Before**:

```lua
-- config.color_scheme = 'Next Theme'
config.color_scheme = 'Current Theme'
-- config.color_scheme = 'Another Theme'
```

**After**:

```lua
config.color_scheme = 'Next Theme'
-- config.color_scheme = 'Current Theme'
-- config.color_scheme = 'Another Theme'
```

## Other Configuration Tasks

### Change Font

```lua
config.font = wezterm.font('Font Name', { weight = 'Medium' })
```

### Adjust Font Size

```lua
config.font_size = 14.0
```

### Window Settings

```lua
config.initial_cols = 140  -- Width
config.initial_rows = 40   -- Height
config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
```

### Opacity/Transparency

```lua
config.window_background_opacity = 0.95
```

### Default Shell & Directory

```lua
config.default_prog = { 'pwsh.exe' }
config.default_cwd = 'D:\\'
```

## Important Notes

- **Immediate Feedback**: WezTerm reloads config automatically on save
- **Theme Names**: Must match exactly (case-sensitive)
- **Commented Sections**: Use `--` prefix in Lua
- **Split Panes**: Configuration includes automatic side-by-side panes on startup
