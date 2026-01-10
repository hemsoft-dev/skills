---
name: developer-documentation
description: V1.0 - Expert in all software engineering standards, processes, and best practices at Relias, including onboarding, testing, CI/CD, security, and developer tooling.
---

# Developer Documentation

Expert guide to Relias software engineering practices. Full documentation sourced from [relias-engineering/developer-documentation](https://github.com/relias-engineering/developer-documentation) GitHub repository.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Documentation Locations

- **Full Docs**: `./repos/developer-documentation/docs/`
- **Main Index**: `./repos/developer-documentation/README.md`
- **Update Docs**: `cd ./repos/developer-documentation && git pull origin main`

### Pulling Latest Documentation

Keep documentation in sync with the source repository:

```powershell
# Quick update
cd C:\Users\User\.claude\skills\developer-documentation\repos\developer-documentation
git pull origin main

# Or from any location
git -C "C:\Users\User\.claude\skills\developer-documentation\repos\developer-documentation" pull origin main
```

**First-time setup**: If the repo folder is empty, clone it:

```powershell
cd C:\Users\User\.claude\skills\developer-documentation\repos
gh auth setup-git  # Configure GitHub CLI authentication
git clone https://github.com/relias-engineering/developer-documentation.git
```

## Key Areas

| Topic | Purpose |
|-------|---------|
| **Onboarding** | Workstation setup, tool recommendations, test automation |
| **Engineering Process** | SDLC, code review, branching, release procedures |
| **How-To Guides** | GitHub, Docker, local dev, Cortex scaffolding |
| **Test Automation** | Cypress E2E, integration testing, test pyramid |
| **Troubleshooting** | Common error solutions (.NET, EF, storage, auth) |
| **Accessibility** | WCAG standards, inclusive design, keyboard/screen reader support |
| **Helpful Commands** | Dotnet, Git, port management utilities |

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

- Documentation is kept in `./repos/developer-documentation` for easy offline access
- Pull updates regularly: `git -C ./repos/developer-documentation pull`
- All Relias software must meet WCAG accessibility standards
- Refer to full docs for comprehensive guides on any topic
