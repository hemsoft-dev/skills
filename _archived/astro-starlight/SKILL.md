---
name: astro-starlight
description: "V1.0 - Expert in Astro framework with Starlight documentation theme. Use for building landing pages + docs sites, content collections, Tailwind CSS integration, Vercel deployment, custom components, and cross-repo CI/CD content pipelines."
---

# Astro + Starlight

Expert skill for building sites with [Astro](https://astro.build/) and [Starlight](https://starlight.astro.build/) — the documentation framework for Astro.

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## When to Use

- Creating documentation sites with Astro Starlight
- Building landing pages + docs combos (landing at `/`, docs at `/docs`)
- Configuring Tailwind CSS with Starlight
- Deploying Astro sites to Vercel
- Setting up cross-repo CI/CD content pipelines (e.g., mother repo → site repo)
- Overriding or customizing Starlight components
- Working with Astro content collections and MDX

## Quick Start

### New Project with Tailwind

```bash
npm create astro@latest -- --template starlight/tailwind
```

### New Project (no Tailwind)

```bash
npm create astro@latest -- --template starlight
```

### Add Tailwind to Existing Project

```bash
npx astro add tailwind
```

## Project Structure

```text
/
├── public/                    # Static assets (favicon, images, fonts)
├── src/
│   ├── assets/                # Optimized images (processed by Astro)
│   ├── components/            # Reusable .astro components
│   ├── content/
│   │   └── docs/              # Starlight documentation pages (MD/MDX)
│   │       └── index.mdx      # Docs homepage
│   ├── layouts/               # Custom page layouts
│   ├── pages/
│   │   └── index.astro        # Custom landing page (full design control)
│   └── styles/
│       └── global.css         # Tailwind base styles
├── astro.config.mjs           # Astro + Starlight configuration
├── tailwind.config.mjs        # Tailwind configuration (if using Tailwind)
├── package.json
└── tsconfig.json
```

**Key insight**: `src/pages/index.astro` is your custom landing page with full design freedom. Starlight renders everything under `src/content/docs/` as documentation pages at the `/docs` path (configurable).

## Configuration

### astro.config.mjs with Starlight + Tailwind

```js
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  integrations: [
    starlight({
      title: 'My Project',
      social: {
        github: 'https://github.com/owner/repo',
      },
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'Introduction', slug: 'introduction' },
            { label: 'Installation', slug: 'installation' },
          ],
        },
        {
          label: 'Guides',
          autogenerate: { directory: 'guides' },
        },
      ],
      customCss: ['./src/styles/global.css'],
    }),
  ],
  vite: { plugins: [tailwindcss()] },
});
```

### Tailwind Base Styles (global.css)

```css
@import 'tailwindcss';
```

For Starlight-specific pages that need Tailwind, create a separate CSS file:

```css
/* src/styles/custom-pages-tailwind.css */
@import 'tailwindcss';
```

Then import it in custom page layouts:

```astro
---
// src/layouts/CustomPageLayout.astro
import '../styles/custom-pages-tailwind.css';
---
```

## Custom Landing Page

The landing page at `src/pages/index.astro` has **full design control** — it's a standard Astro page, not a Starlight doc page.

```astro
---
// src/pages/index.astro
import '../styles/custom-pages-tailwind.css';
---

<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>My Project</title>
  </head>
  <body>
    <main>
      <!-- Full design freedom here -->
      <h1>Welcome to My Project</h1>
      <a href="/docs">Read the Docs</a>
    </main>
  </body>
</html>
```

### Using StarlightPage for Consistent Styling

If you want a custom page that still looks like Starlight:

```astro
---
import StarlightPage from '@astrojs/starlight/components/StarlightPage.astro';
---

<StarlightPage frontmatter={{ title: 'My Custom Page' }}>
  <p>This page uses Starlight's layout and styling.</p>
</StarlightPage>
```

## Documentation Pages (Content Collections)

Docs live in `src/content/docs/` as Markdown or MDX files:

```markdown
---
# src/content/docs/introduction.mdx
title: Introduction
description: Get started with the project
sidebar:
  order: 1
  badge:
    text: New
    variant: tip
---

# Introduction

Your documentation content here.
```

### Sidebar Frontmatter Options

```markdown
---
title: My Page
sidebar:
  label: Custom Sidebar Label    # Override display name
  order: 2                       # Sort order (lower = higher)
  hidden: false                  # Hide from sidebar
  badge:
    text: Beta
    variant: caution             # note | tip | caution | danger
  attrs:
    style: 'font-weight: bold'
---
```

## Component Overrides

Override any Starlight built-in component:

```js
// astro.config.mjs
starlight({
  title: 'My Docs',
  components: {
    SocialIcons: './src/components/EmailLink.astro',
    Footer: './src/components/CustomFooter.astro',
  },
})
```

### Conditional Override (e.g., homepage-only footer)

```astro
---
// src/components/ConditionalFooter.astro
import Default from '@astrojs/starlight/components/Footer.astro';

const isHomepage = Astro.locals.starlightRoute.id === '';
---

{
  isHomepage ? (
    <footer>Built with Starlight</footer>
  ) : (
    <Default><slot /></Default>
  )
}
```

## Hero / Splash Pages

Use the `splash` template in frontmatter for hero-style pages:

```markdown
---
title: My Project
template: splash
hero:
  title: My Amazing Project
  tagline: A short description of what this project does.
  actions:
    - text: Get Started
      link: /docs/introduction
      icon: right-arrow
    - text: View on GitHub
      link: https://github.com/owner/repo
      variant: minimal
---
```

## Deployment to Vercel

### Option 1: Vercel Dashboard (recommended)

1. Push repo to GitHub
2. Import project in Vercel dashboard
3. Vercel auto-detects Astro — no config needed
4. Set custom domain in Vercel settings

### Option 2: Vercel CLI

```bash
npm install -g vercel
vercel
```

### Option 3: vercel.json (for custom config)

```json
{
  "framework": "astro"
}
```

### Custom Domain

In Vercel dashboard: Settings → Domains → Add `set-it-free-loop.org`

## Cross-Repo CI/CD Content Pipeline

For automatically pushing docs from a mother repo to a site repo:

### Mother Repo GitHub Action

```yaml
# .github/workflows/publish-docs.yml
name: Publish Docs to Site Repo
on:
  push:
    branches: [main]
    paths: ['docs/**']

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Push docs to site repo
        uses: cpina/github-action-push-to-another-repository@main
        env:
          SSH_DEPLOY_KEY: ${{ secrets.SITE_REPO_DEPLOY_KEY }}
        with:
          source-directory: 'docs'
          destination-github-username: 'HemSoft'
          destination-repository-name: 'set-it-free-loop-site'
          target-directory: 'src/content/docs/generated'
          target-branch: 'main'
```

### Site Repo: Auto-deploy

Vercel watches the `main` branch — when docs land via the action above, Vercel auto-rebuilds.

## Common Commands

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server (localhost:4321) |
| `npm run build` | Build production site to `./dist/` |
| `npm run preview` | Preview production build locally |
| `npx astro add {integration}` | Add an Astro integration |
| `npx astro check` | Type-check the project |

## Key References

- Astro docs: <https://docs.astro.build/>
- Starlight docs: <https://starlight.astro.build/>
- Starlight GitHub: <https://github.com/withastro/starlight>
- Astro + Vercel: <https://docs.astro.build/en/guides/deploy/vercel/>
- Tailwind + Starlight: <https://starlight.astro.build/guides/css-and-tailwind/>
