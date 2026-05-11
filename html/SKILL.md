---
name: html
description: V2.0 - Expert in producing consistent standalone HTML files with a shared visual system, approved layout variants, and theme toggle (Paper/Obsidian/Twilight/Carbon). Use when markdown should become polished HTML you can open locally.
compatibility: Requires a local HTML handler, browser, or lightweight viewer for generated .html files.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the html skill directory (path contains `.agents/skills/html/` or `.agents\skills\html\`), verify that history logging occurred.
            
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
            Before stopping, if html was used (check if any files in `.agents/skills/html/` were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in html directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# HTML

Create standalone `.html` files instead of dumping raw HTML into chat.

## Core Rules

1. Default to writing a complete `.html` file in the working directory unless the user gives a different path.
2. Return a short handoff in chat with the file path, chosen variant, and any interaction notes.
3. Use inline CSS in a single `<style>` block. Avoid external frameworks, CDNs, and downloaded fonts unless explicitly requested.
4. Keep JavaScript optional and minimal. Add it only for requested interactions.
5. Prefer semantic HTML, accessible contrast, and reusable sections over one-off styling.
6. Reuse the same tokens, spacing scale, component vocabulary, and page shell every time.

## Visual System

- Outer canvas: deep near-black background with generous margins
- Primary surface: warm paper card or window with soft corners and subtle border and shadow
- Palette:
  - `--clay: #D97757`
  - `--olive: #788C5D`
  - `--sky: #6A8CAF`
  - `--oat: #E3DACC`
  - `--slate: #141413`
  - `--g500: #9A9891`
  - `--g300: #D1CBC0`
  - `--white: #FFFFFF`
- Typography:
  - Display and headings: serif
  - Body and UI: clean sans-serif
  - Code and meta labels: ui-monospace
- Spacing scale: `4, 8, 12, 16, 24, 32, 48`
- Tone: editorial, product-design, calm, premium, minimal

## Themes

All generated HTML files include a **theme toggle** (⋮ kebab menu, top-right) that lets users switch between themes. Selection persists via `localStorage`.

### Theme Definitions

| Token | Paper (default) | Obsidian | Twilight | Carbon |
|-------|----------------|----------|----------|--------|
| Name | Paper | Obsidian | Twilight | Carbon |
| `--bg-canvas` | `#080808` | `#0d1117` | `#16162a` | `#111111` |
| `--bg-surface` | `#F5F1E8` | `#161b22` | `#1e1e3f` | `#1a1a1a` |
| `--bg-card` | `#FFFFFF` | `#21262d` | `#2a2a4a` | `#222222` |
| `--text-primary` | `#141413` | `#c9d1d9` | `#e0def4` | `#ececec` |
| `--text-secondary` | `#9A9891` | `#8b949e` | `#908caa` | `#888888` |
| `--text-muted` | `#9A9891` | `#6e7681` | `#6c6c89` | `#666666` |
| `--accent-primary` | `#D97757` | `#58a6ff` | `#7c5cbf` | `#D97757` |
| `--accent-secondary` | `#788C5D` | `#3fb950` | `#c4a7e7` | `#788C5D` |
| `--accent-tertiary` | `#6A8CAF` | `#d2a8ff` | `#f7c59f` | `#6A8CAF` |
| `--border-subtle` | `rgba(20,20,19,0.08)` | `rgba(240,246,252,0.1)` | `rgba(200,180,240,0.12)` | `rgba(255,255,255,0.08)` |
| `--link-color` | `#6A8CAF` | `#58a6ff` | `#7c5cbf` | `#D97757` |
| `--shadow-soft` | standard | `0 24px 80px rgba(0,0,0,0.4)` | `0 24px 80px rgba(0,0,0,0.5)` | `0 24px 80px rgba(0,0,0,0.5)` |
| Inspiration | Editorial warm paper | GitHub Dark | Vim/Twilight | Linear/Notion Dark |

### Theme Toggle Component

Every generated HTML file MUST include this toggle in the top-right corner:

```html
<div class="theme-toggle" aria-label="Theme selector">
  <button class="theme-toggle-btn" onclick="toggleThemeMenu()" aria-haspopup="true" aria-expanded="false">⋮</button>
  <div class="theme-menu" id="themeMenu">
    <button onclick="setTheme('paper')">📰 Paper</button>
    <button onclick="setTheme('obsidian')">🖤 Obsidian</button>
    <button onclick="setTheme('twilight')">🌆 Twilight</button>
    <button onclick="setTheme('carbon')">🔲 Carbon</button>
  </div>
</div>
```

### Theme JavaScript

Every generated HTML file MUST include this inline `<script>` before `</body>`:

```js
function setTheme(t){document.documentElement.setAttribute('data-theme',t);localStorage.setItem('html-theme',t);closeThemeMenu()}
function toggleThemeMenu(){const m=document.getElementById('themeMenu');const b=document.querySelector('.theme-toggle-btn');const open=m.classList.toggle('open');b.setAttribute('aria-expanded',open)}
function closeThemeMenu(){document.getElementById('themeMenu').classList.remove('open');document.querySelector('.theme-toggle-btn').setAttribute('aria-expanded','false')}
document.addEventListener('click',e=>{if(!e.target.closest('.theme-toggle'))closeThemeMenu()});
(function(){const t=localStorage.getItem('html-theme')||'paper';document.documentElement.setAttribute('data-theme',t)})()
```

### Theme CSS

Every generated HTML file MUST include these theme rules in its `<style>` block, BEFORE the component styles:

```css
/* Theme: Paper (default) — light editorial */
[data-theme="paper"], :root {
  --bg-canvas: #080808; --bg-surface: #F5F1E8; --bg-card: #FFFFFF;
  --text-primary: #141413; --text-secondary: #9A9891; --text-muted: #9A9891;
  --accent-primary: #D97757; --accent-secondary: #788C5D; --accent-tertiary: #6A8CAF;
  --border-subtle: rgba(20,20,19,0.08); --link-color: #6A8CAF;
  --accent-tag-bg: rgba(217,119,87,0.12); --accent-tag-text: #D97757;
  --sky-tag-bg: rgba(106,140,175,0.12); --sky-tag-text: #6A8CAF;
  --olive-tag-bg: rgba(120,140,93,0.12); --olive-tag-text: #788C5D;
  --slate-tag-bg: rgba(20,20,19,0.08); --slate-tag-text: #9A9891;
  --warn-bg: #D97757; --warn-text: #FFFFFF;
  --shadow-soft: 0 24px 80px rgba(0,0,0,0.18);
  --table-header-bg: rgba(20,20,19,0.04); --table-border: rgba(20,20,19,0.06);
  --stat-positive: #788C5D; --stat-negative: #D97757;
}

/* Theme: Obsidian — GitHub Dark inspired */
[data-theme="obsidian"] {
  --bg-canvas: #0d1117; --bg-surface: #161b22; --bg-card: #21262d;
  --text-primary: #c9d1d9; --text-secondary: #8b949e; --text-muted: #6e7681;
  --accent-primary: #58a6ff; --accent-secondary: #3fb950; --accent-tertiary: #d2a8ff;
  --border-subtle: rgba(240,246,252,0.1); --link-color: #58a6ff;
  --accent-tag-bg: rgba(88,166,255,0.12); --accent-tag-text: #58a6ff;
  --sky-tag-bg: rgba(210,168,255,0.12); --sky-tag-text: #d2a8ff;
  --olive-tag-bg: rgba(63,185,80,0.12); --olive-tag-text: #3fb950;
  --slate-tag-bg: rgba(139,148,158,0.12); --slate-tag-text: #8b949e;
  --warn-bg: #f85149; --warn-text: #FFFFFF;
  --shadow-soft: 0 24px 80px rgba(0,0,0,0.4);
  --table-header-bg: rgba(240,246,252,0.06); --table-border: rgba(240,246,252,0.08);
  --stat-positive: #3fb950; --stat-negative: #f85149;
}

/* Theme: Twilight — Vim/Twilight inspired */
[data-theme="twilight"] {
  --bg-canvas: #16162a; --bg-surface: #1e1e3f; --bg-card: #2a2a4a;
  --text-primary: #e0def4; --text-secondary: #908caa; --text-muted: #6c6c89;
  --accent-primary: #7c5cbf; --accent-secondary: #c4a7e7; --accent-tertiary: #f7c59f;
  --border-subtle: rgba(200,180,240,0.12); --link-color: #7c5cbf;
  --accent-tag-bg: rgba(124,92,191,0.15); --accent-tag-text: #7c5cbf;
  --sky-tag-bg: rgba(247,197,159,0.15); --sky-tag-text: #f7c59f;
  --olive-tag-bg: rgba(196,167,231,0.15); --olive-tag-text: #c4a7e7;
  --slate-tag-bg: rgba(144,140,170,0.12); --slate-tag-text: #908caa;
  --warn-bg: #7c5cbf; --warn-text: #FFFFFF;
  --shadow-soft: 0 24px 80px rgba(0,0,0,0.5);
  --table-header-bg: rgba(200,180,240,0.08); --table-border: rgba(200,180,240,0.1);
  --stat-positive: #c4a7e7; --stat-negative: #f7c59f;
}

/* Theme: Carbon — Linear/Notion Dark inspired */
[data-theme="carbon"] {
  --bg-canvas: #111111; --bg-surface: #1a1a1a; --bg-card: #222222;
  --text-primary: #ececec; --text-secondary: #888888; --text-muted: #666666;
  --accent-primary: #D97757; --accent-secondary: #788C5D; --accent-tertiary: #6A8CAF;
  --border-subtle: rgba(255,255,255,0.08); --link-color: #D97757;
  --accent-tag-bg: rgba(217,119,87,0.15); --accent-tag-text: #D97757;
  --sky-tag-bg: rgba(106,140,175,0.15); --sky-tag-text: #6A8CAF;
  --olive-tag-bg: rgba(120,140,93,0.15); --olive-tag-text: #788C5D;
  --slate-tag-bg: rgba(255,255,255,0.08); --slate-tag-text: #888888;
  --warn-bg: #D97757; --warn-text: #FFFFFF;
  --shadow-soft: 0 24px 80px rgba(0,0,0,0.5);
  --table-header-bg: rgba(255,255,255,0.04); --table-border: rgba(255,255,255,0.06);
  --stat-positive: #788C5D; --stat-negative: #D97757;
}
```

### Theme Toggler CSS

Every generated HTML file MUST include these toggle styles:

```css
.theme-toggle{position:fixed;top:var(--space-4);right:var(--space-4);z-index:100;font-family:ui-monospace,"Cascadia Code","Fira Code",monospace;font-size:0.75rem}
.theme-toggle-btn{background:var(--bg-card);color:var(--text-secondary);border:1px solid var(--border-subtle);border-radius:6px;padding:6px 10px;cursor:pointer;font-size:1.2rem;line-height:1;transition:background .2s,color .2s}
.theme-toggle-btn:hover{background:var(--accent-primary);color:var(--bg-canvas)}
.theme-menu{display:none;position:absolute;top:100%;right:0;margin-top:4px;background:var(--bg-card);border:1px solid var(--border-subtle);border-radius:8px;box-shadow:var(--shadow-soft);overflow:hidden;min-width:140px}
.theme-menu.open{display:block}
.theme-menu button{display:block;width:100%;text-align:left;background:none;color:var(--text-primary);border:none;padding:10px 16px;cursor:pointer;font-family:inherit;font-size:0.8rem;transition:background .15s}
.theme-menu button:hover{background:var(--accent-primary);color:var(--bg-canvas)}
```

## Using Themes in Component Styles

When writing component CSS, **always use theme variables** instead of hardcoded colors. Replace:
- `color: var(--slate)` → `color: var(--text-primary)`
- `background: #F5F1E8` → `background: var(--bg-surface)`
- `background: #FFFFFF` on cards → `background: var(--bg-card)`
- `color: var(--g500)` for secondary text → `color: var(--text-secondary)`
- `color: var(--g500)` for muted text → `color: var(--text-muted)`
- `border: 1px solid rgba(20,20,19,0.06)` → `border: 1px solid var(--border-subtle)`
- `color: var(--sky)` for links → `color: var(--link-color)`
- Tag backgrounds: use `--accent-tag-bg` / `--sky-tag-bg` / `--olive-tag-bg` / `--slate-tag-bg` with corresponding `--*-tag-text`
- Positive/negative deltas: use `--stat-positive` / `--stat-negative`
- Warning badges: use `--warn-bg` / `--warn-text`
- Table headers/borders: use `--table-header-bg` / `--table-border`

The **spacing, typography, and layout tokens** remain constant across themes — only color variables change.

## Approved Variants

- `article` - narrative explanation and long-form content
- `note` - compact summary, memo, or reference
- `showcase` - visually led presentation or concept board
- `dashboard` - grouped facts, stats, status, or comparison

All variants share the same tokens, type ramp, shell, and components.

## Preferred Component Vocabulary

Use these building blocks consistently:

- `.page-shell`
- `.window`
- `.hero`
- `.section`
- `.section-title`
- `.card`
- `.grid`
- `.eyebrow`
- `.actions`
- `.button`
- `.mono`
- `.muted`

## Output Process

1. Pick the smallest approved variant that fits the request.
2. Create a full HTML document with `<!DOCTYPE html>`, `<head>`, `<meta charset>`, `<meta name="viewport">`, `<title>`, and one `<style>` block.
3. Put the main content inside a framed `.window` surface on a dark `.page-shell`.
4. If the user asks for interactions, keep them self-contained with a small inline `<script>`.
5. If the request starts from markdown-like content, translate it into structured sections and cards rather than preserving markdown syntax.
6. Do not return markdown tables or lists as the primary deliverable when the user asked for HTML.

## Default Skeleton

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{TITLE}</title>
  <style>
    /* === Theme Definitions === */
    [data-theme="paper"], :root {
      --bg-canvas: #080808; --bg-surface: #F5F1E8; --bg-card: #FFFFFF;
      --text-primary: #141413; --text-secondary: #9A9891; --text-muted: #9A9891;
      --accent-primary: #D97757; --accent-secondary: #788C5D; --accent-tertiary: #6A8CAF;
      --border-subtle: rgba(20,20,19,0.08); --link-color: #6A8CAF;
      --accent-tag-bg: rgba(217,119,87,0.12); --accent-tag-text: #D97757;
      --sky-tag-bg: rgba(106,140,175,0.12); --sky-tag-text: #6A8CAF;
      --olive-tag-bg: rgba(120,140,93,0.12); --olive-tag-text: #788C5D;
      --slate-tag-bg: rgba(20,20,19,0.08); --slate-tag-text: #9A9891;
      --warn-bg: #D97757; --warn-text: #FFFFFF;
      --shadow-soft: 0 24px 80px rgba(0,0,0,0.18);
      --table-header-bg: rgba(20,20,19,0.04); --table-border: rgba(20,20,19,0.06);
      --stat-positive: #788C5D; --stat-negative: #D97757;
    }
    [data-theme="obsidian"] {
      --bg-canvas: #0d1117; --bg-surface: #161b22; --bg-card: #21262d;
      --text-primary: #c9d1d9; --text-secondary: #8b949e; --text-muted: #6e7681;
      --accent-primary: #58a6ff; --accent-secondary: #3fb950; --accent-tertiary: #d2a8ff;
      --border-subtle: rgba(240,246,252,0.1); --link-color: #58a6ff;
      --accent-tag-bg: rgba(88,166,255,0.12); --accent-tag-text: #58a6ff;
      --sky-tag-bg: rgba(210,168,255,0.12); --sky-tag-text: #d2a8ff;
      --olive-tag-bg: rgba(63,185,80,0.12); --olive-tag-text: #3fb950;
      --slate-tag-bg: rgba(139,148,158,0.12); --slate-tag-text: #8b949e;
      --warn-bg: #f85149; --warn-text: #FFFFFF;
      --shadow-soft: 0 24px 80px rgba(0,0,0,0.4);
      --table-header-bg: rgba(240,246,252,0.06); --table-border: rgba(240,246,252,0.08);
      --stat-positive: #3fb950; --stat-negative: #f85149;
    }
    [data-theme="twilight"] {
      --bg-canvas: #16162a; --bg-surface: #1e1e3f; --bg-card: #2a2a4a;
      --text-primary: #e0def4; --text-secondary: #908caa; --text-muted: #6c6c89;
      --accent-primary: #7c5cbf; --accent-secondary: #c4a7e7; --accent-tertiary: #f7c59f;
      --border-subtle: rgba(200,180,240,0.12); --link-color: #7c5cbf;
      --accent-tag-bg: rgba(124,92,191,0.15); --accent-tag-text: #7c5cbf;
      --sky-tag-bg: rgba(247,197,159,0.15); --sky-tag-text: #f7c59f;
      --olive-tag-bg: rgba(196,167,231,0.15); --olive-tag-text: #c4a7e7;
      --slate-tag-bg: rgba(144,140,170,0.12); --slate-tag-text: #908caa;
      --warn-bg: #7c5cbf; --warn-text: #FFFFFF;
      --shadow-soft: 0 24px 80px rgba(0,0,0,0.5);
      --table-header-bg: rgba(200,180,240,0.08); --table-border: rgba(200,180,240,0.1);
      --stat-positive: #c4a7e7; --stat-negative: #f7c59f;
    }
    [data-theme="carbon"] {
      --bg-canvas: #111111; --bg-surface: #1a1a1a; --bg-card: #222222;
      --text-primary: #ececec; --text-secondary: #888888; --text-muted: #666666;
      --accent-primary: #D97757; --accent-secondary: #788C5D; --accent-tertiary: #6A8CAF;
      --border-subtle: rgba(255,255,255,0.08); --link-color: #D97757;
      --accent-tag-bg: rgba(217,119,87,0.15); --accent-tag-text: #D97757;
      --sky-tag-bg: rgba(106,140,175,0.15); --sky-tag-text: #6A8CAF;
      --olive-tag-bg: rgba(120,140,93,0.15); --olive-tag-text: #788C5D;
      --slate-tag-bg: rgba(255,255,255,0.08); --slate-tag-text: #888888;
      --warn-bg: #D97757; --warn-text: #FFFFFF;
      --shadow-soft: 0 24px 80px rgba(0,0,0,0.5);
      --table-header-bg: rgba(255,255,255,0.04); --table-border: rgba(255,255,255,0.06);
      --stat-positive: #788C5D; --stat-negative: #D97757;
    }

    /* === Theme Toggle === */
    .theme-toggle{position:fixed;top:16px;right:16px;z-index:100;font-family:ui-monospace,"Cascadia Code","Fira Code",monospace;font-size:0.75rem}
    .theme-toggle-btn{background:var(--bg-card);color:var(--text-secondary);border:1px solid var(--border-subtle);border-radius:6px;padding:6px 10px;cursor:pointer;font-size:1.2rem;line-height:1;transition:background .2s,color .2s}
    .theme-toggle-btn:hover{background:var(--accent-primary);color:var(--bg-canvas)}
    .theme-menu{display:none;position:absolute;top:100%;right:0;margin-top:4px;background:var(--bg-card);border:1px solid var(--border-subtle);border-radius:8px;box-shadow:var(--shadow-soft);overflow:hidden;min-width:140px}
    .theme-menu.open{display:block}
    .theme-menu button{display:block;width:100%;text-align:left;background:none;color:var(--text-primary);border:none;padding:10px 16px;cursor:pointer;font-family:inherit;font-size:0.8rem;transition:background .15s}
    .theme-menu button:hover{background:var(--accent-primary);color:var(--bg-canvas)}

    /* === Layout & Spacing === */
    :root {
      --space-1: 4px; --space-2: 8px; --space-3: 12px; --space-4: 16px;
      --space-5: 24px; --space-6: 32px; --space-7: 48px;
      --radius-lg: 32px; --radius-md: 20px; --radius-sm: 12px;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      background: var(--bg-canvas);
      color: var(--text-primary);
      font: 400 16px/1.6 Inter, "Segoe UI", Arial, sans-serif;
    }

    .page-shell {
      min-height: 100vh;
      padding: var(--space-7) var(--space-5);
    }

    .window {
      max-width: 1100px;
      margin: 0 auto;
      padding: var(--space-6);
      background: var(--bg-surface);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow-soft);
    }
  </style>
</head>
<body>
  <div class="theme-toggle" aria-label="Theme selector">
    <button class="theme-toggle-btn" onclick="toggleThemeMenu()" aria-haspopup="true" aria-expanded="false">⋮</button>
    <div class="theme-menu" id="themeMenu">
      <button onclick="setTheme('paper')">📰 Paper</button>
      <button onclick="setTheme('obsidian')">🖤 Obsidian</button>
      <button onclick="setTheme('twilight')">🌆 Twilight</button>
      <button onclick="setTheme('carbon')">🔲 Carbon</button>
    </div>
  </div>
  <main class="page-shell">
    <article class="window">
      {CONTENT}
    </article>
  </main>
  <script>
  function setTheme(t){document.documentElement.setAttribute('data-theme',t);localStorage.setItem('html-theme',t);closeThemeMenu()}
  function toggleThemeMenu(){const m=document.getElementById('themeMenu');const b=document.querySelector('.theme-toggle-btn');const open=m.classList.toggle('open');b.setAttribute('aria-expanded',open)}
  function closeThemeMenu(){document.getElementById('themeMenu').classList.remove('open');document.querySelector('.theme-toggle-btn').setAttribute('aria-expanded','false')}
  document.addEventListener('click',e=>{if(!e.target.closest('.theme-toggle'))closeThemeMenu()});
  (function(){const t=localStorage.getItem('html-theme')||'paper';document.documentElement.setAttribute('data-theme',t)})()
  </script>
</body>
</html>
```

## Handoff Style

After writing the file, respond briefly with:

- the output file path
- the chosen variant
- whether any script-driven interactions were included
