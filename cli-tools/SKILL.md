---
name: cli-tools
description: "V1.10 - Commands: Install, Update, VersionCheck, Usage. Route CLI-tool requests to concise category references and verify results."
metadata:
  author: HemSoft Developments
  version: "1.10"
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the cli-tools directory (path contains 'cli-tools'), verify that history logging occurred.

            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained with Get-Date -Format "HH:mm", never guessed)

            If history is missing or incomplete, provide specific feedback on what needs to be added.
            If history exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if cli-tools was used, verify the interaction was logged:

            1. Check whether History/{YYYY-MM-DD}.md exists in the cli-tools directory.
            2. Verify it contains "## HH:MM - {Action Taken}" using a timestamp obtained from Get-Date.
            3. Ensure the entry includes a one-line summary.
            4. Verify the retrospective check was performed.

            If history is missing, return a blocking decision requesting the required entry.
            If history exists, return an approving decision with a concise status message.
---

# CLI Tools

Reference guide for installing, updating, checking, and using command-line tools.

Before proceeding, check the `protocols` skill for an applicable procedure.

## Default Behavior

When activated without an action:

1. Show the tool index below.
2. Ask which tool the user wants to install, update, inspect, or use.
3. Read only the category reference containing that tool.

## Tool Index

| Category | Tool | Purpose | Reference |
|---|---|---|---|
| Development | `prs` | Check GitHub and Bitbucket pull requests | [Development tools](references/development-tools.md) |
| Text editors | `edit` | Microsoft terminal text editor | [Text editors](references/text-editors.md) |
| Text editors | `glow` | Render Markdown in the terminal | [Text editors](references/text-editors.md) |
| Text editors | `nano` | Edit text in the terminal | [Text editors](references/text-editors.md) |
| AI | `gemini` | Google Gemini coding agent | [AI tools](references/ai-tools.md) |
| AI | `claude` | Anthropic Claude Code agent | [AI tools](references/ai-tools.md) |
| AI | `copilot` | GitHub Copilot coding agent | [AI tools](references/ai-tools.md) |
| AI | `codex` | OpenAI Codex coding agent | [AI tools](references/ai-tools.md) |
| AI review | `greptile` | Review local branch changes | [AI tools](references/ai-tools.md) |
| AI | `goose` | Multi-provider coding agent | [AI tools](references/ai-tools.md) |
| System monitoring | `btop` | Monitor system resources | [System monitoring](references/system-monitoring.md) |

## Command Routing

| User action | Required workflow |
|---|---|
| Install | Read the tool entry, check prerequisites, run its installation command, then verify the executable and version. |
| Update | Follow the update workflow below. |
| VersionCheck | Run the installed-version and latest-version commands from the tool entry. |
| Usage | Read the tool entry and provide only the commands relevant to the requested task. |

## Update Workflow

1. Read the tool's category reference.
2. Record the installed version.
3. Run the documented update command.
4. Verify the new version.
5. Fetch release notes from the documented official source.
6. Report the old version, new version, important changes, breaking changes, and a clickable release-notes link.

Use the package registry for package-manager tools and the official release page for other tools.

## Adding a Tool

1. Select the existing category reference or create one under `references/`.
2. Add the tool to the index in this file.
3. Add one reference entry containing every required field below.
4. Verify the installation and version commands on the target operating system.
5. Increment the skill version and add the dated history entry.

| Required field | Content |
|---|---|
| Category | Tool classification |
| Description | Purpose and primary capabilities |
| Author | Maintainer or organization |
| Current version | Version and verification date |
| Requirements | Runtime, operating system, or authentication prerequisites |
| Installation | Complete command |
| Update | Built-in or package-manager command |
| Version check | Installed and latest-version commands |
| Links | Official documentation, repository, package registry, and releases |
| Usage | Minimal common commands |
| Notes | Authentication, pricing, platform, or safety details |
