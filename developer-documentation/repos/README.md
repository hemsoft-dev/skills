# Developer Documentation Repository

This folder contains a local copy of the Relias Engineering developer documentation for offline reference and easy updates.

## Repository Info

**Source**: [relias-engineering/developer-documentation](https://github.com/relias-engineering/developer-documentation)  
**Last Updated**: 2026-01-09  
**Access**: GitHub CLI (fhemmerrelias account)

## Pulling Updates

To update the documentation from the source repository:

```powershell
# Using Git (if cloned)
cd C:\Users\User\.claude\skills\developer-documentation\repos\developer-documentation
git pull origin main

# Or using GitHub CLI to fetch specific files
gh api repos/relias-engineering/developer-documentation/contents/docs \
  --jq '.[] | .download_url' | xargs -I {} curl -O {}
```

## Directory Structure

```
developer-documentation/
├── docs/
│   ├── onboarding/              # Getting started and environment setup
│   ├── engineering-process/     # Development workflows and standards
│   ├── how-to/                  # Step-by-step guides for common tasks
│   ├── test-automation/         # Testing strategies (Cypress, Integration)
│   ├── troubleshooting/         # Error resolution guides
│   ├── accessibility/           # WCAG standards and best practices
│   └── helpful-commands/        # Useful CLI commands and scripts
├── README.md                    # Main documentation index
├── CONTRIBUTING.md              # Contribution guidelines
└── CODEOWNERS                   # Code ownership rules
```

## Key Documentation Files

- **README.md** - Master index of all documentation
- **docs/onboarding/** - Workstation setup, tool recommendations
- **docs/test-automation/** - Cypress E2E, integration testing, test pyramid
- **docs/how-to/** - GitHub setup, Docker config, service scaffolding
- **docs/engineering-process/** - SDLC, code review, release procedures
- **docs/troubleshooting/** - Common error solutions

## Quick Reference

### Fetch a specific document via GitHub API
```powershell
gh api repos/relias-engineering/developer-documentation/contents/docs/onboarding/developer-workstation-setup.md \
  --jq '.content' | [System.Convert]::FromBase64String($_) | [System.Text.Encoding]::UTF8.GetString()
```

### List all documentation files
```bash
gh api repos/relias-engineering/developer-documentation/contents/docs --jq '.[].name'
```

## Notes

- Documentation is kept lean in SKILL.md for quick reference
- Full documentation is available in the local `docs/` folder
- Pull updates regularly to stay in sync with main repository
- Check Contributing Guidelines before making local modifications
