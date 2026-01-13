---
name: dopus
description: V1.0 - Expert in Directory Opus file manager for Windows, covering configuration, scripting, button customization, toolbars, and advanced file operations.
---

# Directory Opus

Expert in Directory Opus (DOpus), the advanced file manager for Windows.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Core Expertise

- **Buttons & Toolbars**: Creating custom buttons, context menus, and toolbar layouts
- **Scripting**: JScript/VBScript for advanced automation and custom commands
- **File Operations**: Batch rename, copy/move filters, file collections, and folder formats
- **Configuration**: Preferences, layouts, styles, and folder options
- **Integration**: External tools, viewers, and system integration
- **Hotkeys**: Keyboard shortcuts and hotkey assignments

## Directory Opus Installation Location

Default installation path: `C:\Program Files\GPSoftware\Directory Opus\`

Configuration files location: `C:\Users\{USERNAME}\AppData\Roaming\GPSoftware\Directory Opus\`

## Common Commands

### Button Commands

DOpus uses its own command language for buttons and hotkeys:

- `Go`: Navigate to locations
- `Copy`: Copy files with filters
- `CreateFolder`: Create new folders
- `Select`: Select files by pattern
- `SetAttr`: Change file attributes
- `Show`: Display various panels and features
- `Prefs`: Open preferences
- `CLI`: Execute command line tools

### Example Button Definitions

**Open PowerShell Here**:

```
@runmode hide
PowerShell.exe -NoExit -Command "Set-Location '{sourcepath}'"
```

**Copy Full Path to Clipboard**:

```
Clipboard COPYNAMES=path
```

**Batch Rename**:

```
Rename PRESET="MyPreset"
```

## Scripting

DOpus supports script add-ins (JScript/VBScript) for advanced customization.

Script location: `C:\Users\{USERNAME}\AppData\Roaming\GPSoftware\Directory Opus\Script AddIns\`

### Basic Script Structure

```javascript
function OnInit(initData) {
    initData.name = "ScriptName";
    initData.desc = "Description";
    initData.version = "1.0";
    initData.default_enable = true;
}

function OnClick(clickData) {
    var cmd = clickData.func.command;
    var tab = clickData.func.sourcetab;
    // Script logic here
}
```

## Folder Formats

Folder formats control how folders are displayed (columns, view mode, sorting).

Access: `Settings > Preferences > Folders > Folder Formats`

Formats can be saved and applied automatically based on:

- Path matching
- Content type detection
- Folder type

## File Collections

Virtual folders that can contain files from multiple locations.

Create: `File > New > File Collection`

Useful for:

- Organizing files across different folders
- Building temporary working sets
- Search result management

## Filters

DOpus filters control which files are affected by operations:

- **Copy Filters**: Control what gets copied during file operations
- **Find Filters**: Advanced file search criteria
- **Display Filters**: Hide/show files in listers

Syntax supports:

- Wildcards: `*.txt`, `photo*.jpg`
- Regular expressions (when enabled)
- Size/date/attribute criteria

## Layouts

Layouts save entire lister configurations (open tabs, positions, toolbars).

Save: `Settings > Lister Layouts > Save Layout`
Load: `Settings > Lister Layouts > {LayoutName}`

Can be triggered via:

- Startup options
- Button commands
- Hotkeys

## Viewer

Built-in file viewer with plugin support.

Command: `Show VIEWERCMD=find` (opens viewer)

Supported formats:

- Images (all common formats)
- Text files
- Office documents (with plugins)
- Media files (with plugins)

## Troubleshooting

### Common Issues

1. **Buttons not working**: Check command syntax and quotation marks
2. **Scripts not loading**: Verify script location and enable in Preferences
3. **Performance issues**: Check folder format complexity and thumbnail settings
4. **Integration problems**: Verify DOpus is set as default file manager

### Configuration Backup

Backup location: `Settings > Backup & Restore`

Recommended: Regular backups before major configuration changes

## Resources

- Official documentation: `C:\Program Files\GPSoftware\Directory Opus\Help\DirectoryOpus.chm`
- Resource Centre: <https://resource.dopus.com/>
- Forums: <https://resource.dopus.com/c/help-support>

## When to Use This Skill

Invoke this skill when:

- Creating or modifying DOpus buttons and toolbars
- Writing DOpus scripts or automation
- Configuring folder formats and layouts
- Troubleshooting DOpus issues
- Setting up file operations and filters
- Integrating external tools with DOpus
