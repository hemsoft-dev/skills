---
name: skills-hub
description: "V1.0 - Commands: setup, list, find, install, uninstall, installed, update, status. Package manager for AI agent skills with junction-based installation."
---

# SkillsHub

When user activates this skill without specifying an action, show the help output (command list).

## What It Does

SkillsHub is a CLI package manager that lets users browse, install, and manage AI agent skills from a shared
repository. Skills are installed as Windows junction links so they stay up-to-date automatically.

## Quick Start (For New Users)

### One-Liner Install

```powershell
irm https://raw.githubusercontent.com/HemSoft/skills/main/skills-hub/scripts/Install-SkillsHub.ps1 | iex
```

### If You Already Have the Repo Cloned

```powershell
.\skills-hub\scripts\Install-SkillsHub.ps1 -UseExisting "C:\path\to\skills-repo"
```

### Then in a New Terminal

```powershell
skills-hub list                  # Browse all skills
skills-hub find "testing"        # Search by keyword
skills-hub install copilot       # Install a skill
skills-hub update                # Pull latest changes
```

## Commands

| Command | Action | Example |
| --- | --- | --- |
| `setup` | First-time clone and configure | `skills-hub setup` |
| `list` | Browse all skills (● installed, ○ available) | `skills-hub list` |
| `find <query>` | Search by name or description keyword | `skills-hub find react` |
| `install <name>` | Create junction link for skill(s) | `skills-hub install copilot slack` |
| `uninstall <name>` | Remove junction link(s) | `skills-hub uninstall copilot` |
| `installed` | Show currently installed skills | `skills-hub installed` |
| `update` | Git pull the skills repo | `skills-hub update` |
| `status` | Overview: counts, repo freshness | `skills-hub status` |

## How It Works

1. **Setup** clones the skills repo to `~/.skills-hub/repo/` (or points at an existing clone)
2. **Install** creates a Windows junction from `~/.agents/skills/<name>` → the repo's `<name>/` folder
3. **Update** runs `git pull` on the repo — all linked skills update instantly
4. No files are copied. Junctions are transparent pointers. Every tool sees real files.

## Architecture

```text
~/.skills-hub/
├── config.json           # Repo URL, paths
├── SkillsHub.psm1        # PowerShell module (copied from repo)
└── repo/                 # Cloned skills repository
    ├── copilot/
    ├── slack/
    └── ...

~/.agents/skills/
├── copilot → ~/.skills-hub/repo/copilot     (junction)
├── slack   → ~/.skills-hub/repo/slack       (junction)
└── ...
```

## Decision Table

| Situation | Action |
| --- | --- |
| New user, no repo clone | `skills-hub setup` |
| User already has the skills repo | `Install-SkillsHub.ps1 -UseExisting <path>` |
| Want to browse what's available | `skills-hub list` |
| Know the skill name | `skills-hub install <name>` |
| Looking for something specific | `skills-hub find <keyword>` |
| Want latest changes | `skills-hub update` |
| Remove a skill (keeps repo copy) | `skills-hub uninstall <name>` |

## File Structure

```text
skills-hub/
├── SKILL.md                          # This file
└── scripts/
    ├── SkillsHub.psm1                # PowerShell module with all commands
    └── Install-SkillsHub.ps1         # Bootstrap installer
```

## Distribution Options

### Option A: One-Liner (Recommended)

Share this with your team:

```powershell
irm https://raw.githubusercontent.com/HemSoft/skills/main/skills-hub/scripts/Install-SkillsHub.ps1 | iex
```

### Option B: Manual Setup

```powershell
git clone https://github.com/HemSoft/skills.git C:\path\to\skills
cd C:\path\to\skills
.\skills-hub\scripts\Install-SkillsHub.ps1 -UseExisting .
```

### Option C: Private/Enterprise Repo

```powershell
.\skills-hub\scripts\Install-SkillsHub.ps1 -RepoUrl "git@github.com:YourOrg/ai-skills.git"
```
