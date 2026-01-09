---
name: branding
description: V1.1 - HemSoft Developments branding guidelines, design system, and shadcn/ui component library.
---

# Branding

Expert in HemSoft Developments branding, visual identity, and front-end design standards.

## Core Brand Identity

**Color Scheme: GOLD ON BLACK**

| Element | Color | Usage |
|---------|-------|-------|
| Primary | Gold / Metallic Gold | Logos, accents, highlights |
| Background | Pure Black (#000000) | Primary background |
| Text | Gold or White | On dark backgrounds |

This is the signature HemSoft look - luxurious, refined, premium tech aesthetic.

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Assets

### HemSoft Developments

| Asset | Path | Format |
|-------|------|--------|
| Logo (JPG) | `assets/hemsoft-developments-logo.jpg` | JPEG |
| Logo (PNG) | `assets/hemsoft-developments-logo.png` | PNG (transparent) |
| Dashboard Icon | `assets/hemsoft-developments-dashboard-icon.png` | PNG |

### HemSoft Corp (Enterprise)

| Asset | Path | Format |
|-------|------|--------|
| Logo (Symbol) | `assets/hemsoft-corp-logo.png` | PNG |
| Logo (With Text) | `assets/hemsoft-corp-logo-with-text.png` | PNG |

## Branding Guide

- [HemSoft Developments Front-End Branding Guide](guide/HemSoft%20Developments%20Front-End%20Branding%20Guide.pdf)

## Design System: shadcn/ui

**Primary Component Library**: <https://ui.shadcn.com/>

shadcn/ui is a set of beautifully-designed, accessible components and a code distribution platform. It's **not** a traditional component library—you own the code.

### Why shadcn/ui

| Principle | Benefit |
|-----------|---------|
| **Open Code** | Full transparency—modify components directly |
| **Composition** | Consistent, predictable API across all components |
| **AI-Ready** | LLMs can read, understand, and generate components |
| **Beautiful Defaults** | Clean, minimal look out-of-the-box |

### Quick Start

```bash
# Initialize in a Next.js project
npx shadcn@latest init

# Add components as needed
npx shadcn@latest add button card dialog
```

### Key Resources

- **Docs**: <https://ui.shadcn.com/docs>
- **Components**: <https://ui.shadcn.com/docs/components>
- **Themes**: <https://ui.shadcn.com/themes>
- **Examples**: <https://ui.shadcn.com/examples>
- **GitHub**: <https://github.com/shadcn-ui/ui>

## Usage Checklist

When building HemSoft front-end applications:

- [ ] Follow the branding guide for colors, typography, and visual identity
- [ ] Use shadcn/ui components (`npx shadcn@latest add <component>`)
- [ ] Reference logo assets from `assets/` folder
- [ ] Customize shadcn/ui theme to match HemSoft brand colors
- [ ] Ensure accessibility standards are maintained
