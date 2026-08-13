---
name: skill-archive
description: "V1.1 - Commands: Archive, Scan. Archives local agent skills by moving named skill folders to ~/.agents/skills-archived, or scans History entries to find long-unused archive candidates when no skill is provided."
disable-model-invocation: true
---

# Skill Archive

Archive skills that should no longer be active in `~/.agents/skills`.

## Default Behavior

When activated without a skill name, scan for archive candidates and report the oldest skills by latest `History/*.md`
entry. Do not archive anything until the user names a skill.

## Workflow

| User request | Action |
| --- | --- |
| Archive a named skill | Run `scripts/Invoke-SkillArchive.ps1 -SkillName {skill-name}` |
| Find unused skills | Run `scripts/Invoke-SkillArchive.ps1` |
| Use a custom inactivity window | Add `-InactiveDays {days}` |
| Preview an archive operation | Add `-WhatIf` to the named-skill command |

## Steps

1. Identify the skill name from the user request.
2. If a skill name is provided, run the archive command.
3. If no skill name is provided, run the scan command and show candidates.
4. Report the source path, archive path, and whether any files moved.

## Script

Use the bundled script for all archive and scan operations:

```powershell
.\skill-archive\scripts\Invoke-SkillArchive.ps1 -SkillName "old-skill"
.\skill-archive\scripts\Invoke-SkillArchive.ps1
```

## Archive Rules

| Rule | Behavior |
| --- | --- |
| Source root | Defaults to `~/.agents/skills` |
| Archive root | Defaults to `~/.agents/skills-archived` |
| Existing destination | Stop with an error; do not overwrite |
| Missing skill | Stop with an error |
| `skill-archive` itself | Stop unless `-Force` is supplied |
| No `History` folder | Include as a scan candidate with no last-used date |

## Candidate Scan

The scan reads each skill's `History` folder and uses the newest dated history filename as the last-used date. If dated
filenames are missing, it falls back to the newest history file write time. Skills with no history are listed first.
