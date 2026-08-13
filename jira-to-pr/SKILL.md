---
name: jira-to-pr
description: "V1.0 - Process a selected JIRA ticket into an implementation-ready branch and pull request when the user asks to process JIRA work."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the jira-to-pr directory (path contains 'jira-to-pr'), verify that history logging occurred.

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
            Before stopping, if jira-to-pr was used (check if any files in the jira-to-pr directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in jira-to-pr directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# JIRA to PR

Process the JIRA ticket as you would a GitHub issue. Pay special attention to acceptance criteria and that they get addressed and covered. Branch naming convention is typically either feature/TICKET-NUMBER-IN-CAPITAL or bug/TICKET-NUMBER-IN-CAPITAL. Make sure that there is not discrepancy between the project and the repo you're currently in. If the current repo/folder is not related to the ticket, then please warn the user.
