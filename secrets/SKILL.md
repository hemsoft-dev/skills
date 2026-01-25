---
name: secrets
description: V1.0 - Stores and retrieves sensitive environment variables and API keys from SECRETS.md for quick reference.
---

# Secrets Manager

Centralized storage for environment variables, API keys, and sensitive credentials.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Usage

All secrets are stored in `SECRETS.md` in this directory. Reference this file when:

- Looking up API keys or tokens
- Checking environment variable values
- Verifying credentials for services
- Adding new secrets to the repository

## Adding New Secrets

To add a new secret:

1. Read `SECRETS.md`
2. Add the new entry in the appropriate category
3. Use the format: `SECRET_NAME = value`
4. Update the file

## Security Note

This skill is designed for private repositories only. Never commit secrets to public repositories.
