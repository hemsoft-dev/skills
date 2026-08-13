---
name: developer-documentation
description: V1.3 - Expert in all software engineering standards, processes, and best practices at Relias, including onboarding, testing, CI/CD, security, and developer tooling.
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the developer-documentation directory (path contains 'developer-documentation'), verify that history logging occurred.

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
            Before stopping, if developer-documentation was used (check if any files in developer-documentation directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in developer-documentation directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            4. Verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Developer Documentation

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert guide to Relias software engineering practices. Full documentation sourced from the
[relias-engineering/developer-documentation](https://github.com/relias-engineering/developer-documentation) repo.

## Documentation Locations

- **Full Docs**: `D:\github\HemSoft\developer-documentation\docs\`
- **Main Index**: `D:\github\HemSoft\developer-documentation\README.md`
- **Update Docs**: `cd D:\github\HemSoft\developer-documentation && git pull origin main`

### Pulling Latest Documentation

Keep documentation in sync with the source repository:

```powershell
# Quick update
cd D:\github\HemSoft\developer-documentation
git pull origin main

# Or from any location
git -C "D:\github\HemSoft\developer-documentation" pull origin main
```

## Key Areas

| Topic                  | Purpose                                                   |
|------------------------|-----------------------------------------------------------|
| **Onboarding**         | Workstation setup, tool recommendations, test automation  |
| **Engineering Process**| SDLC, code review, branching, release procedures          |
| **How-To Guides**      | GitHub, Docker, local dev, Cortex scaffolding             |
| **Test Automation**    | Cypress E2E, integration testing, test pyramid            |
| **Troubleshooting**    | Common error solutions (.NET, EF, storage, auth)          |
| **Accessibility**      | WCAG standards, inclusive design, keyboard/screen reader  |
| **Helpful Commands**   | Dotnet, Git, port management utilities                    |

## Technology Stack

**Backend**: .NET, C#, ASP.NET Core, EF Core, SQL Server  
**Frontend**: React, TypeScript, Cypress, LaunchDarkly  
**DevOps**: GitHub Actions, Docker, Kubernetes (AKS), Azure  
**Standards**: Security scanning, linting, code coverage, accessibility

## Quick Reference

### Development Workflow

1. Branch from main → code → test (unit/integration/E2E)
2. Create PR with security checks
3. Code review & approval → merge → auto-deploy
4. Validation testing with LaunchDarkly feature flags
**Pull updates regularly** before consulting docs to ensure accuracy

- Repository requires GitHub CLI authentication (`gh auth setup-git`)
- All Relias software must meet WCAG accessibility standards
- Refer to full docs for comprehensive guides on any topic

## Available Documentation Files

The repository contains 50+ documentation files covering:

- **Onboarding**: Workstation setup, test automation, tool recommendations
- **Engineering Process**: SDLC, code review standards, release procedures
- **How-To Guides**: GitHub, Docker, Cortex scaffolding, security rulesets, code quality
- **Test Automation**: Cypress E2E, integration testing, test pyramid
- **Troubleshooting**: .NET EF errors, auth issues, storage emulator, service index
- **Accessibility**: WCAG standards and implementation
- **Helpful Commands**: Dotnet, Git, port management
- **AI Agents**: C# Quality Expert agent for automated code quality setup
- ⏱️ Some: Integration tests (cross-service)
- 📊 Few: E2E tests (full user workflows)

### Essential Processes

- **Service Creation**: Use Cortex for scaffolding
- **Local Dev**: Docker + custom subdomains + local SQL Server
- **Testing**: Cypress for E2E, Testcontainers for integration
- **Release**: Platform release instructions + flag management

## Best Practices

✅ **Always**: Follow coding standards, test locally, check docs first, use Cortex for services, document discoveries  
❌ **Never**: Skip tests, bypass security checks, commit to main directly, ignore accessibility, keep knowledge siloed

## Notes

- Documentation lives in `D:\github\HemSoft\developer-documentation`
- Pull updates regularly: `git -C "D:\github\HemSoft\developer-documentation" pull`
- All Relias software must meet WCAG accessibility standards
- Refer to full docs for comprehensive guides on any topic
