```skill
---
name: beautiful-mermaid
description: V1.0 - Expert in Beautiful Mermaid library for rendering Mermaid diagrams as beautiful SVGs or ASCII art. Use for installing, configuring, and working with beautiful-mermaid in Node.js/TypeScript projects.
license: MIT
compatibility: Requires Node.js/Bun, npm/pnpm/bun package manager
metadata:
  author: Luki Labs (Craft)
  repository: https://github.com/lukilabs/beautiful-mermaid
  version: "1.0"
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the beautiful-mermaid directory (path contains 'beautiful-mermaid'), verify that history logging occurred.
            
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
            Before stopping, if beautiful-mermaid was used (check if any files in beautiful-mermaid directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in beautiful-mermaid directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Beautiful Mermaid

Expert in Beautiful Mermaid - a library for rendering Mermaid diagrams as beautiful SVGs or ASCII art. Built by Craft for the AI era.

## What is Beautiful Mermaid?

Beautiful Mermaid is an open-source TypeScript library that renders Mermaid diagram text to:

- **SVG** - Styled, production-ready vector graphics
- **ASCII/Unicode** - Terminal-friendly box-drawing characters

**Key Features**:

- Ultra-fast (100+ diagrams in <500ms)
- Zero DOM dependencies (works in Node.js, Bun, Deno, browsers)
- 15 built-in themes + full Shiki compatibility
- 5 diagram types: Flowcharts, State, Sequence, Class, ER
- Live theme switching via CSS custom properties
- Mono mode (beautiful diagrams from just 2 colors)

## Installation

### NPM/Bun/PNPM

```bash
npm install beautiful-mermaid
# or
bun add beautiful-mermaid
# or
pnpm add beautiful-mermaid
```

### Browser (CDN)

```html
<script src="https://unpkg.com/beautiful-mermaid/dist/beautiful-mermaid.browser.global.js"></script>
<script>
  const { renderMermaid, THEMES } = beautifulMermaid;
</script>
```

## Usage

### SVG Output (Async)

```typescript
import { renderMermaid } from 'beautiful-mermaid'

// Minimal (default theme)
const svg = await renderMermaid(`
  graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Action]
    B -->|No| D[End]
`)

// With custom colors
const svg = await renderMermaid(diagram, {
  bg: '#1a1b26',    // Background
  fg: '#a9b1d6',    // Foreground
})

// With enriched theme
const svg = await renderMermaid(diagram, {
  bg: '#1a1b26',
  fg: '#a9b1d6',
  line: '#3d59a1',      // Edge/connector color
  accent: '#7aa2f7',    // Arrow heads, highlights
  muted: '#565f89',     // Secondary text, labels
  surface: '#292e42',   // Node fill tint
  border: '#3d59a1',    // Node stroke
  font: 'Inter',        // Font family
  transparent: false,   // Transparent background
})

// Using built-in themes
import { THEMES } from 'beautiful-mermaid'
const svg = await renderMermaid(diagram, THEMES['tokyo-night'])
```

### ASCII/Unicode Output (Sync)

```typescript
import { renderMermaidAscii } from 'beautiful-mermaid'

// Unicode mode (default) - prettier box drawing
const unicode = renderMermaidAscii(`graph LR; A --> B --> C`)

// ASCII mode - maximum compatibility
const ascii = renderMermaidAscii(`graph LR; A --> B`, {
  useAscii: true,
  paddingX: 5,
  paddingY: 5,
  boxBorderPadding: 1,
})
```

**Unicode output**:

```
┌───┐     ┌───┐     ┌───┐
│   │     │   │     │   │
│ A │────►│ B │────►│ C │
│   │     │   │     │   │
└───┘     └───┘     └───┘
```

**ASCII output**:

```
+---+     +---+     +---+
|   |     |   |     |   |
| A |---->| B |---->| C |
|   |     |   |     |   |
+---+     +---+     +---+
```

## Supported Diagrams

### 1. Flowcharts

All directions: `TD` (top-down), `LR` (left-right), `BT` (bottom-top), `RL` (right-left)

```
graph TD
  A[Start] --> B{Decision}
  B -->|Yes| C[Process]
  B -->|No| D[End]
  C --> D
```

### 2. State Diagrams

```
stateDiagram-v2
  [*] --> Idle
  Idle --> Processing: start
  Processing --> Complete: done
  Complete --> [*]
```

### 3. Sequence Diagrams

```
sequenceDiagram
  Alice->>Bob: Hello Bob!
  Bob-->>Alice: Hi Alice!
  Alice->>Bob: How are you?
  Bob-->>Alice: Great, thanks!
```

### 4. Class Diagrams

```
classDiagram
  Animal <|-- Duck
  Animal <|-- Fish
  Animal: +int age
  Animal: +String gender
  Animal: +isMammal() bool
  Duck: +String beakColor
  Duck: +swim()
  Duck: +quack()
```

### 5. ER Diagrams

```
erDiagram
  CUSTOMER ||--o{ ORDER : places
  ORDER ||--|{ LINE_ITEM : contains
  PRODUCT ||--o{ LINE_ITEM : "is in"
```

## Theming

### Two-Color Foundation (Mono Mode)

Every diagram needs just **2 colors**: `bg` and `fg`. The system auto-derives all other colors using `color-mix()`:

| Element | Derivation |
|---------|------------|
| Text | `--fg` at 100% |
| Secondary text | `--fg` at 60% into `--bg` |
| Edge labels | `--fg` at 40% into `--bg` |
| Connectors | `--fg` at 30% into `--bg` |
| Arrow heads | `--fg` at 50% into `--bg` |
| Node fill | `--fg` at 3% into `--bg` |
| Node stroke | `--fg` at 20% into `--bg` |

```typescript
const svg = await renderMermaid(diagram, {
  bg: '#1a1b26',
  fg: '#a9b1d6',
})
```

### Enriched Mode (Optional)

Override specific derivations with enrichment colors:

```typescript
const svg = await renderMermaid(diagram, {
  bg: '#1a1b26',
  fg: '#a9b1d6',
  line: '#3d59a1',    // Edge/connector color (overrides derived)
  accent: '#7aa2f7',  // Arrow heads, highlights
  muted: '#565f89',   // Secondary text, labels
  surface: '#292e42', // Node fill tint
  border: '#3d59a1',  // Node stroke
})
```

### Built-in Themes

15 themes available via `THEMES` object:

| Theme | Type | Background | Accent |
|-------|------|------------|--------|
| `zinc-light` | Light | `#FFFFFF` | Derived |
| `zinc-dark` | Dark | `#18181B` | Derived |
| `tokyo-night` | Dark | `#1a1b26` | `#7aa2f7` |
| `tokyo-night-storm` | Dark | `#24283b` | `#7aa2f7` |
| `tokyo-night-light` | Light | `#d5d6db` | `#34548a` |
| `catppuccin-mocha` | Dark | `#1e1e2e` | `#cba6f7` |
| `catppuccin-latte` | Light | `#eff1f5` | `#8839ef` |
| `nord` | Dark | `#2e3440` | `#88c0d0` |
| `nord-light` | Light | `#eceff4` | `#5e81ac` |
| `dracula` | Dark | `#282a36` | `#bd93f9` |
| `github-light` | Light | `#ffffff` | `#0969da` |
| `github-dark` | Dark | `#0d1117` | `#4493f8` |
| `solarized-light` | Light | `#fdf6e3` | `#268bd2` |
| `solarized-dark` | Dark | `#002b36` | `#268bd2` |
| `one-dark` | Dark | `#282c34` | `#c678dd` |

```typescript
import { THEMES } from 'beautiful-mermaid'
const svg = await renderMermaid(diagram, THEMES['tokyo-night'])
```

### Shiki Integration

Use any VS Code theme via Shiki:

```typescript
import { getSingletonHighlighter } from 'shiki'
import { renderMermaid, fromShikiTheme } from 'beautiful-mermaid'

const highlighter = await getSingletonHighlighter({
  themes: ['vitesse-dark', 'rose-pine', 'material-theme-darker']
})

const colors = fromShikiTheme(highlighter.getTheme('vitesse-dark'))
const svg = await renderMermaid(diagram, colors)
```

### Live Theme Switching

All colors are CSS custom properties - switch themes instantly without re-rendering:

```javascript
svg.style.setProperty('--bg', '#282a36')
svg.style.setProperty('--fg', '#f8f8f2')
// Entire diagram updates immediately
```

## API Reference

### `renderMermaid(text, options?): Promise<string>`

Render Mermaid diagram to SVG. Auto-detects diagram type.

**Parameters**:

- `text` - Mermaid source code (string)
- `options` - Optional `RenderOptions` object

**RenderOptions**:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `bg` | `string` | `#FFFFFF` | Background color |
| `fg` | `string` | `#27272A` | Foreground color |
| `line` | `string?` | — | Edge/connector color (optional) |
| `accent` | `string?` | — | Arrow heads, highlights (optional) |
| `muted` | `string?` | — | Secondary text, labels (optional) |
| `surface` | `string?` | — | Node fill tint (optional) |
| `border` | `string?` | — | Node stroke color (optional) |
| `font` | `string` | `Inter` | Font family |
| `padding` | `number` | `32` | SVG padding in pixels |
| `transparent` | `boolean` | `false` | Render with transparent background |

**Returns**: `Promise<string>` - Self-contained SVG string

### `renderMermaidAscii(text, options?): string`

Render Mermaid diagram to ASCII/Unicode text. Synchronous.

**Parameters**:

- `text` - Mermaid source code (string)
- `options` - Optional `AsciiRenderOptions` object

**AsciiRenderOptions**:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `useAscii` | `boolean` | `false` | Use ASCII instead of Unicode |
| `paddingX` | `number` | `5` | Horizontal node spacing |
| `paddingY` | `number` | `5` | Vertical node spacing |
| `boxBorderPadding` | `number` | `1` | Inner box padding |

**Returns**: `string` - Multi-line ASCII/Unicode text

### `fromShikiTheme(theme): DiagramColors`

Extract diagram colors from a Shiki theme object.

**Parameters**:

- `theme` - Shiki theme object

**Returns**: `DiagramColors` object with `bg`, `fg`, and optional enrichment colors

### `THEMES: Record<string, DiagramColors>`

Object containing all 15 built-in themes.

### `DEFAULTS: { bg: string, fg: string }`

Default colors: `{ bg: '#FFFFFF', fg: '#27272A' }`

## When to Use This Skill

Use this skill when:

- Installing beautiful-mermaid in a project
- Rendering Mermaid diagrams to SVG or ASCII
- Configuring themes or custom colors
- Working with flowcharts, state, sequence, class, or ER diagrams
- Integrating Mermaid rendering into Node.js/TypeScript applications
- Need terminal-friendly diagram output
- Troubleshooting beautiful-mermaid issues

## Common Tasks

### Add to Existing Project

```bash
cd {project-directory}
npm install beautiful-mermaid
# or
bun add beautiful-mermaid
```

### Create Simple SVG Renderer

```typescript
import { renderMermaid } from 'beautiful-mermaid'
import fs from 'fs/promises'

const diagram = `
graph TD
  A[Start] --> B{Decision}
  B -->|Yes| C[Action]
  B -->|No| D[End]
`

const svg = await renderMermaid(diagram, {
  bg: '#1a1b26',
  fg: '#a9b1d6',
})

await fs.writeFile('output.svg', svg)
```

### Create CLI ASCII Renderer

```typescript
import { renderMermaidAscii } from 'beautiful-mermaid'

const diagram = `graph LR; A --> B --> C`
const ascii = renderMermaidAscii(diagram, { useAscii: true })

console.log(ascii)
```

### Use with Express/Next.js API Route

```typescript
// Express example
import { renderMermaid } from 'beautiful-mermaid'

app.post('/render', async (req, res) => {
  const { diagram, theme } = req.body
  const svg = await renderMermaid(diagram, theme || {})
  res.setHeader('Content-Type', 'image/svg+xml')
  res.send(svg)
})
```

## Repository Information

- **GitHub**: <https://github.com/lukilabs/beautiful-mermaid>
- **NPM**: <https://www.npmjs.com/package/beautiful-mermaid>
- **Live Demo**: <https://agents.craft.do/mermaid>
- **Built by**: Luki Labs (Craft) - <https://craft.do>
- **License**: MIT
- **Attribution**: ASCII engine based on mermaid-ascii by Alexander Grooff

## Troubleshooting

### Issue: Module not found

**Solution**: Ensure `beautiful-mermaid` is installed:

```bash
npm install beautiful-mermaid
```

### Issue: Fonts not rendering correctly

**Solution**: Specify font explicitly in options:

```typescript
const svg = await renderMermaid(diagram, {
  font: 'Arial, sans-serif'
})
```

### Issue: SVG too small/large

**Solution**: Adjust `padding` option:

```typescript
const svg = await renderMermaid(diagram, {
  padding: 64  // Default is 32
})
```

### Issue: Need transparent background

**Solution**: Set `transparent: true`:

```typescript
const svg = await renderMermaid(diagram, {
  transparent: true
})
```

### Issue: ASCII output looks wrong in terminal

**Solution**: Use `useAscii: true` for pure ASCII:

```typescript
const ascii = renderMermaidAscii(diagram, { useAscii: true })
```

```
