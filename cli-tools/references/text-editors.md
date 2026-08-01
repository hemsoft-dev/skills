# Text Editors

Read this file only for tools in the Text editors category.

## edit - Microsoft Edit

| Field | Value |
|---|---|
| Author | Microsoft |
| Current version | 1.2.1, verified 2026-01-19 |
| Purpose | Lightweight modeless terminal editor with menus, mouse support, tabs, regex replacement, and word wrap. |
| Requirements | Windows 10 or newer; preinstalled on recent Windows 11 builds. |

### Commands

```powershell
# Install or update
winget install Microsoft.Edit
winget upgrade Microsoft.Edit

# Check version
edit --version
winget show Microsoft.Edit

# Open a file
edit README.md
```

### Links

- GitHub: <https://github.com/microsoft/edit>
- Documentation: <https://learn.microsoft.com/windows/edit/>

## glow - Markdown Viewer

| Field | Value |
|---|---|
| Author | Charm |
| Current version | 2.1.1, verified 2026-01-28 |
| Purpose | Render local and remote Markdown with terminal styling and syntax highlighting. |

### Commands

```powershell
# Install with Scoop or WinGet
scoop install glow
winget install charmbracelet.Glow

# Update with the selected package manager
scoop update glow
winget upgrade charmbracelet.Glow

# Check version and render Markdown
glow --version
glow README.md
glow github.com/charmbracelet/glow
```

### Links

- GitHub: <https://github.com/charmbracelet/glow>
- Releases: <https://github.com/charmbracelet/glow/releases>

## nano - GNU Nano

| Field | Value |
|---|---|
| Author | GNU Project |
| Current version | Check before use; last reviewed 2026-01-28 |
| Purpose | Simple terminal editor with visible keyboard shortcuts. |

### Commands

```powershell
# Install with WinGet or Chocolatey
winget install GNU.Nano
choco install nano --yes

# Update with the selected package manager
winget upgrade GNU.Nano
choco upgrade nano --yes

# Check version and edit a file
nano --version
nano README.md
```

### Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+O` | Save |
| `Ctrl+X` | Exit |
| `Ctrl+K` | Cut line |
| `Ctrl+U` | Paste |
| `Ctrl+W` | Search |
| `Ctrl+G` | Help |

### Links

- Official site: <https://www.nano-editor.org>
- Windows port: <https://github.com/lhmouse/nano-win>
