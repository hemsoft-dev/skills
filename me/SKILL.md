---
name: me
description: V1.0 - Tracks all kinds of information about the user including personal details, preferences, work info, and other user-specific data.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the me directory (path contains 'me'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if me was used (check if any files in me directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in me directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Me

Tracks comprehensive information about the user (Franz Hemmer) for quick reference and context.

## Information Categories

Store and retrieve user information across these categories:

### Personal

- Full name, preferred name, pronouns
- Contact information (email, phone, address)
- Birthday, timezone
- Family members, pets

### Professional

- Current employer, role, team
- Work email, Slack handle
- Manager, direct reports
- Skills, certifications
- Career goals, interests

### Preferences

- Favorite tools, IDEs, languages
- Coding style preferences
- Communication preferences
- Work hours, availability

### Technical

- GitHub username, SSH keys
- API keys, service accounts (reference only, not stored)
- Development environment setup
- Machine specifications

### Hobbies & Interests

- Games, sports, activities
- Learning goals
- Side projects

### Medical

- Healthcare provider information
- Doctor's website/patient portal
- Medications, allergies
- Medical history, conditions
- Insurance information

## Usage

When the user asks to:

- "Tell me about myself"
- "What's my work email?"
- "Update my {category}"
- "Add {information} to my profile"

Read or update the relevant information in this skill file or create supplementary markdown files in the `me/` directory for detailed categories.

## Structure

You can create additional files in `me/` directory for detailed information:

- `personal.md` - Personal details
- `professional.md` - Work information
- `preferences.md` - User preferences
- `technical.md` - Technical setup
- `hobbies.md` - Interests and hobbies
- `medical.md` - Medical information
- `gpt-export/` - Complete ChatGPT conversation export (read-only, for reference and neo4j indexing)
  - Contains `conversations.json`, `chat.html`, and binary attachments
  - Binary files are excluded from git via `.gitignore`
  - **Do not modify** - kept as historical reference

## User Information

### Basic Info

- Name: Franz Hemmer
- Location: Mooresville, NC (273 Rose St, 28117)
- Timezone: Eastern Time (ET)

### Professional

- Company: Relias
- Role: Developer Productivity Engineer
- GitHub: (to be added)
- Work Location: Remote

### Technical Setup

- OS: Windows 11 (Build 26200)
- Shell: PowerShell
- Primary IDE: Cursor
- Skills Directory: `C:\Users\User\.claude\skills`

### Medical

- Healthcare Provider: Novant Health
- Patient Portal: <https://www.novantmychart.org/MyChart/Home>
- Primary Care Physician: Stephanie Elkins, MD (Novant Health LKN Family Medicine)
- Cardiologist: Kobina Wilmot, MD (Novant Health Heart and Vascular Institute - Mooresville)

Add more details as needed during conversations.
