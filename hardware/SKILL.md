---
name: hardware
description: V1.0 - Commands: list, add, remove, info. Tracks personal hardware inventory with product details, manuals, and maintenance info. Use when the user asks about their hardware, devices, appliances, or equipment.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the hardware directory (path contains 'hardware'), verify that history logging occurred.
            
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
            Before stopping, if hardware was used (check if any files in hardware directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in hardware directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Hardware Inventory

Track personal hardware, devices, appliances, and equipment.

## Default Behavior

When user activates this skill without specifying an action, run **list** to show all tracked hardware.

## Commands

| Command | Description |
|---------|-------------|
| `list` | Show all tracked hardware items |
| `add` | Add a new hardware item to inventory |
| `remove` | Remove a hardware item from inventory |
| `info` | Show detailed info for a specific item |

## Inventory File

All hardware items are stored in `inventory/hardware-inventory.md`.

Each item follows this format:

```markdown
## {Product Name}

| Field | Value |
|-------|-------|
| Category | {category} |
| Location | {where it is} |
| Brand | {manufacturer} |
| Model | {model number} |
| Purchase Date | {date or "Unknown"} |
| Manual | {link to manual} |
| Product Page | {link to product page} |
| Notes | {any additional notes} |
```

## Adding Items

When adding a new item, ask for any missing required fields:

- Product Name (required)
- Category (required — e.g., Air Purifier, Monitor, Keyboard, etc.)
- Location (required — e.g., Office, Living Room, Kitchen)
- Brand, Model, Manual link, Product Page — include if provided

## File Structure

```text
hardware/
├── SKILL.md
├── inventory/
│   └── hardware-inventory.md
└── History/
    └── {YYYY-MM-DD}.md
```
