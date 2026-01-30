---
name: support
description: V1.1 - Tracks support incidents with read-only discovery and troubleshooting documentation.
---

# Support Incident Tracker

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Track and document support incidents with structured markdown files.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## ⛔ CRITICAL RULE: READ-ONLY DISCOVERY

**THIS IS NON-NEGOTIABLE:**

- ALL discovery and troubleshooting MUST be **READ-ONLY**
- NEVER execute commands that modify data, state, or configurations
- NEVER trigger pipelines, deployments, or processes
- NEVER make code changes or file modifications (except incident documentation)
- **ALWAYS ASK THE USER** before taking ANY action that could alter data or kick off processes

If in doubt, **ASK FIRST**.

## Incident File Structure

Location: `incidents/{YYYY-MM-DD}-{incident-slug}.md`

### Template

```markdown
# {Incident Title}

## Metadata

| Field | Value |
|-------|-------|
| **Date/Time** | {YYYY-MM-DD HH:MM} |
| **Reported By** | {Name or Team} |
| **Status** | {Open / Investigating / Resolved / Closed} |

## Links

- {Link to Slack thread, JIRA ticket, or other relevant resources}

## Issue Description

{Clear description of the reported problem}

## Troubleshooting Notes

{Chronological notes of discovery, findings, and investigation steps}

## Resolution

{What fixed the issue, or current state if unresolved}

## Lessons Learned

{Key takeaways for future reference}
```

## Workflow

1. **Create Incident** - Generate new incident file with slug from title
2. **Document Discovery** - Add findings to Troubleshooting Notes (read-only investigation only!)
3. **Update Status** - Track progress in Metadata
4. **Record Resolution** - Document what fixed the issue
5. **Capture Lessons** - Note takeaways for future incidents

## Naming Convention

```
incidents/2026-01-09-sonarcloud-scanner-failure.md
incidents/2026-01-10-database-connection-timeout.md
```

Use lowercase, hyphen-separated slugs describing the incident.
