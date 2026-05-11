---
name: html
description: V1.0 - Expert in producing consistent standalone HTML files with a shared visual system and approved layout variants. Use when markdown should become polished HTML you can open locally.
compatibility: Requires a local HTML handler, browser, or lightweight viewer for generated .html files.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the html directory (path contains 'html'), verify that history logging occurred.
            
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
            Before stopping, if html was used (check if any files in html directory were modified), verify that the interaction was logged:
            
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
    :root {
      --clay: #D97757;
      --olive: #788C5D;
      --sky: #6A8CAF;
      --oat: #E3DACC;
      --slate: #141413;
      --g500: #9A9891;
      --g300: #D1CBC0;
      --white: #FFFFFF;
      --space-1: 4px;
      --space-2: 8px;
      --space-3: 12px;
      --space-4: 16px;
      --space-5: 24px;
      --space-6: 32px;
      --space-7: 48px;
      --radius-lg: 32px;
      --radius-md: 20px;
      --shadow-soft: 0 24px 80px rgba(0, 0, 0, 0.18);
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      background: #080808;
      color: var(--slate);
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
      background: #F5F1E8;
      border: 1px solid rgba(20, 20, 19, 0.08);
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow-soft);
    }
  </style>
</head>
<body>
  <main class="page-shell">
    <article class="window">
      {CONTENT}
    </article>
  </main>
</body>
</html>
```

## Handoff Style

After writing the file, respond briefly with:

- the output file path
- the chosen variant
- whether any script-driven interactions were included
