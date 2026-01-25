---
name: python
description: V1.1 - Expert in Python installation, virtual environments, package management, and troubleshooting on Windows. Skills must use isolated virtual environments - never install Python packages globally.
---

# Python Expert

Expert guidance for Python installation, virtual environments, and development on Windows.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Installation on Windows 11 (Clean Install)

### Best Practice: Minimal PATH Impact Strategy

The cleanest Python installation on Windows 11 follows these principles:

1. **Use Python Launcher (`py.exe`)** - Official Windows tool, no PATH pollution
2. **Never add Python to PATH** - Use `py` command instead
3. **Install to default user location** - Keeps system clean
4. **Use virtual environments for ALL projects** - Complete isolation
5. **Use pipx for CLI tools** - Isolated global tools

### Installation Steps

**Step 1: Install Python 3.12 via winget**

```powershell
# Install WITHOUT adding to PATH
winget install Python.Python.3.12 --custom "/quiet InstallAllUsers=0 PrependPath=0 Include_test=0"
```

**Important flags:**

- `InstallAllUsers=0` - User install (no admin rights needed)
- `PrependPath=0` - **Do NOT add to PATH** (key for minimal impact)
- `Include_test=0` - Skip test suite (saves space)

**Step 2: Verify Python Launcher**

```powershell
py --version          # Should show Python 3.12.x
py -0                 # List all installed Python versions
py -m pip --version   # Verify pip works
```

**Step 3: Upgrade pip**

```powershell
py -m pip install --upgrade pip
```

**Step 4: Install pipx for global CLI tools**

```powershell
py -m pip install --user pipx
py -m pipx ensurepath
```

**Step 5: Verify installation**

```powershell
# Check Python Launcher works
py --version

# Check pip works
py -m pip --version

# Verify PATH is clean (should only show py.exe, not python.exe)
Get-Command py
Get-Command python -ErrorAction SilentlyContinue  # Should not find it
```

### Post-Installation Configuration

**Enable script execution (if needed):**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Verify PATH is minimal:**

```powershell
$env:PATH -split ';' | Where-Object { $_ -like '*Python*' }
# Should show minimal entries (only Python Launcher, not Python itself)
```

### Why This Approach?

**PATH Pollution Problem:**

- Traditional installations add Python, Scripts, and pip to PATH
- Multiple Python versions create conflicts
- Hard to manage which Python is active

**Python Launcher Solution:**

- Single `py.exe` entry point for all Python versions
- Automatically finds and manages installed versions
- Clean, predictable behavior
- Microsoft-recommended approach for Windows

**Virtual Environments (venv) - ALWAYS USE:**

- Every project gets isolated dependencies
- No version conflicts between projects
- Clean uninstall (just delete folder)
- Reproducible environments

**pipx for CLI Tools:**

- Tools like `goose-ai`, `black`, `pytest` installed in isolation
- Each tool gets its own venv automatically
- Available globally without PATH pollution
- Easy updates and management

### Working with Python (No PATH needed)

**Run Python:**

```powershell
py                    # Interactive interpreter
py script.py          # Run script
py -3.12              # Specific version
py -m module          # Run module
```

**Use pip:**

```powershell
py -m pip install package      # Never use 'pip install'
py -m pip list
py -m pip freeze > requirements.txt
```

**Create project:**

```powershell
# Navigate to project folder
cd D:\projects\myapp

# Create virtual environment
py -m venv .venv

# Activate (PowerShell)
.\.venv\Scripts\Activate.ps1

# Now 'python' and 'pip' work directly (they're from venv)
python --version      # Shows Python from .venv
pip install requests  # Installs to .venv only

# When done
deactivate
```

**Install global CLI tool:**

```powershell
pipx install goose-ai       # Isolated install
pipx install black          # Another isolated install
pipx list                   # See all tools
goose --version             # Works globally
```

### Verification Checklist

After clean install, verify:

- [ ] `py --version` works (shows 3.12.x)
- [ ] `py -m pip --version` works
- [ ] `python --version` does NOT work (not in PATH)
- [ ] `pip --version` does NOT work (not in PATH)
- [ ] PATH variable is clean (minimal Python entries)
- [ ] Can create venv: `py -m venv test_venv`
- [ ] pipx is installed and working

### Installation on Windows

### Recommended: winget (Legacy - See Clean Install Above)

For a clean install, see "Installation on Windows 11 (Clean Install)" section above.

```powershell
winget install Python.Python.3.12
```

### Verify Installation

```powershell
python --version
# or
python3 --version
# or
py --version
```

### Fix PATH Issues

If Python is installed but not found, add to PATH:

**Option 1: Find Python location**

```powershell
# Common locations
C:\Users\{username}\AppData\Local\Programs\Python\Python312\
C:\Program Files\Python312\
C:\Python312\
```

**Option 2: Use Python Launcher**

```powershell
py --version          # Check version
py -m pip --version   # Check pip
```

**Option 3: Add to PATH manually**

```powershell
$env:Path += ";C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312;C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\Scripts"
```

For permanent PATH changes, use System Properties > Environment Variables.

## Virtual Environments

### ⚠️ CRITICAL: Skills Must Use Isolated Venvs

**NEVER install Python packages globally when working with skills. ALWAYS use isolated virtual environments in the skill folder.**

**For Skills:**

- Create venv in the skill folder: `{skill-name}/venv/` or `{skill-name}/.venv/`
- Install all dependencies in the skill's venv
- Scripts should check for venv, create if missing, and use it automatically
- This keeps skills isolated and prevents global Python pollution

**For Regular Projects:**

- Create venv in project root: `.venv/`
- Activate before working
- Install dependencies in venv only

### Create venv

```powershell
# Standard library venv
python -m venv .venv

# Or with python launcher
py -m venv .venv

# For skills - create in skill folder
py -m venv "$env:USERPROFILE\.claude\skills\{skill-name}\venv"
```

### Activate venv

```powershell
# PowerShell
.\.venv\Scripts\Activate.ps1

# CMD
.\.venv\Scripts\activate.bat

# For skills (from skill folder)
.\venv\Scripts\Activate.ps1
```

### Use venv Without Activation (Recommended for Scripts)

```powershell
# Run Python from venv directly (no activation needed)
.\venv\Scripts\python.exe script.py

# Run pip from venv directly
.\venv\Scripts\python.exe -m pip install package

# Check if venv exists
if (Test-Path "venv\Scripts\python.exe") { ... }
```

### Deactivate

```powershell
deactivate
```

### Check Active Environment

```powershell
Get-Command python | Select-Object Source
# Should show path inside .venv
```

### Skill Script Pattern

**PowerShell scripts in skills should use this pattern:**

```powershell
# Determine skill directory
$skillDir = Split-Path -Parent $PSScriptRoot

# Check/create venv
$venvPath = Join-Path $skillDir "venv"
if (-not (Test-Path "$venvPath\Scripts\python.exe")) {
    Write-Information "Creating virtual environment..."
    py -m venv $venvPath
}

# Use venv Python directly (no activation needed)
$pythonExe = Join-Path $venvPath "Scripts\python.exe"
& $pythonExe script.py

# Install packages in venv
& $pythonExe -m pip install package-name
```

## Package Management

### pip Basics

```powershell
# Install package
pip install {package-name}

# Install from requirements.txt
pip install -r requirements.txt

# Install in editable mode (development)
pip install -e .

# Upgrade package
pip install --upgrade {package-name}

# Uninstall
pip uninstall {package-name}

# List installed packages
pip list

# Show package details
pip show {package-name}

# Freeze requirements
pip freeze > requirements.txt
```

### pipx (for CLI tools)

```powershell
# Install pipx
python -m pip install --user pipx
python -m pipx ensurepath

# Install tool
pipx install {tool-name}

# List installed tools
pipx list

# Upgrade tool
pipx upgrade {tool-name}
```

## Common Issues

### "Python not found"

- Check if installed: `Get-Command python -ErrorAction SilentlyContinue`
- Try `python3` or `py` launcher
- Check PATH environment variable
- Reinstall with winget

### "Script execution disabled"

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### pip not found

```powershell
python -m ensurepip --upgrade
# or
py -m ensurepip --upgrade
```

### Multiple Python versions

```powershell
# Python Launcher can manage versions
py -3.12 --version    # Use Python 3.12
py -3.11 --version    # Use Python 3.11
py -0                 # List all installed versions
```

### Module not found (after install)

- Ensure venv is activated
- Check you're using correct Python: `Get-Command python`
- Reinstall package in active environment

## Best Practices

1. **Always use virtual environments** - Isolate project dependencies
2. **Skills MUST use isolated venvs** - Never install Python packages globally for skills
3. **Use requirements.txt** - Track dependencies
4. **Use pipx for CLI tools** - Keep global namespace clean (black, ruff, pytest, etc.)
5. **Pin versions in production** - Use exact versions in requirements.txt
6. **Keep pip updated** - `python -m pip install --upgrade pip`
7. **Research installation methods first** - Not all "Python" tools are Python packages
   - Check official docs for recommended installation (Scoop, winget, official installers)
   - Verify it's actually a Python package before using pip/pipx
   - Example: Goose (block/goose) is a Rust CLI tool, NOT a Python package despite similar names
8. **Scripts should auto-manage venvs** - Check for venv, create if missing, use it automatically

## Important Lessons

### When Installing CLI Tools

**ALWAYS** check these before using pip/pipx:

1. Is this tool written in Python? (Check GitHub language stats)
2. What does the official documentation recommend?
3. Is there a better package manager for this? (Scoop for dev tools, winget for apps)
4. Are there name conflicts? (e.g., `goose-ai` PyPI package vs Block's Goose CLI)

**Red Flags:**

- Tool has dedicated installers or package manager support → Use those instead
- Tool is written in Rust/Go/C++ → NOT a Python package
- PyPI package has different name than official tool → Likely wrong package
- Installation docs don't mention pip → Don't use pip

## Python Project Structure

```
project/
├── .venv/              # Virtual environment (gitignored)
├── src/                # Source code
│   └── __init__.py
├── tests/              # Tests
├── requirements.txt    # Production dependencies
├── requirements-dev.txt # Development dependencies
├── setup.py or pyproject.toml  # Package configuration
└── README.md
```

## Quick Commands Reference

| Task | Command |
|------|---------|
| Create venv | `python -m venv .venv` |
| Activate venv | `.\.venv\Scripts\Activate.ps1` |
| Install package | `pip install {package}` |
| Install from file | `pip install -r requirements.txt` |
| Save requirements | `pip freeze > requirements.txt` |
| Install CLI tool | `pipx install {tool}` |
| Check Python path | `Get-Command python \| Select Source` |
| List pip packages | `pip list` |
