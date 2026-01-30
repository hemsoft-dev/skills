---
name: badge-manager
description: V1.2 - Expert in GitHub badges for README files, specializing in Next.js, React, Supabase, and .NET stacks.
---

# Badge Manager

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert guidance for selecting, styling, and implementing high-quality GitHub README badges to enhance project visibility and professionalism.

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Core Principles

1. **Visual Consistency**: Stick to a single style (e.g., `flat`, `flat-square`, or `for-the-badge`) within a row.
2. **Information Hierarchy**: Group badges logically (Status, Tech Stack, Community).
3. **Brand Accuracy**: Use official brand colors and logos (via Simple Icons).
4. **Performance**: Prefer static badges for tech stacks and dynamic badges for live metrics.

## Badge Styles (Shields.io)

- `flat`: Default, clean, professional. Best for metrics.
- `flat-square`: Sharp corners, modern. Good for versioning.
- `for-the-badge`: Large, bold, high-impact. Best for tech stack callouts.
- `social`: GitHub-native look for stars and forks.

## Curated Badge Templates

### Tech Stack (for-the-badge)

- **Next.js**: `https://img.shields.io/badge/Next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white`
- **React**: `https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB`
- **Supabase**: `https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white`
- **.NET**: `https://img.shields.io/badge/.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white`
- **Tailwind CSS**: `https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white`
- **TypeScript**: `https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white`
- **Vercel**: `https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white`
- **Bun**: `https://img.shields.io/badge/Bun-000000?style=for-the-badge&logo=bun&logoColor=white`

### Project Metrics (flat/flat-square)

- **NuGet Version**: `https://img.shields.io/nuget/v/{PACKAGE}?style=flat-square&color=004880`
- **Build Status**: `https://img.shields.io/github/actions/workflow/status/{USER}/{REPO}/{WORKFLOW}.yml?branch=main`
- **Vercel Deployment (via GitHub API)**: `https://img.shields.io/github/deployments/{USER}/{REPO}/production?label=vercel&logo=vercel&logoColor=white` (Uses GitHub's deployment status API - most accurate for Vercel)
- **Vercel Deployment (via Vercel API)**: `https://img.shields.io/vercel/deployments/{USER}/{REPO}?logo=vercel&style=flat-square` (Requires Vercel project ID, less common)
- **License**: `https://img.shields.io/github/license/{USER}/{REPO}?color=blue`
- **Test Coverage**: `https://img.shields.io/badge/coverage-90%25-brightgreen` (Static or dynamic via Vitest/Codecov)

### Community (social)

- **GitHub Stars**: `https://img.shields.io/github/stars/{USER}/{REPO}?style=social`
- **GitHub Forks**: `https://img.shields.io/github/forks/{USER}/{REPO}?style=social`

### Specialty Badges

- **Vercel Deploy Button**: `[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url={REPO_URL})`

## Implementation Best Practices

- **Grouping**: Use a single paragraph for a row of badges to ensure they wrap correctly.
- **Alt Text**: Always provide descriptive alt text for accessibility (e.g., `![Next.js](...)`).
- **Links**: Wrap badges in links to the relevant resource (e.g., the NuGet package page or the GitHub Actions tab).
- **Logo Color**: Use `logoColor=white` or `logoColor=black` for consistent contrast.

## Example Layout

```markdown
# Project Name

<p align="left">
  <img src="https://img.shields.io/github/actions/workflow/status/USER/REPO/ci.yml?branch=main" alt="Build Status" />
  <img src="https://img.shields.io/vercel/deployments/USER/REPO?logo=vercel&style=flat-square" alt="Vercel Deployment" />
  <img src="https://img.shields.io/github/license/USER/REPO" alt="License" />
  <img src="https://img.shields.io/github/stars/USER/REPO?style=social" alt="Stars" />
</p>

---

### Built With

![Next.js](https://img.shields.io/badge/Next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)

---

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/USER/REPO)
```
