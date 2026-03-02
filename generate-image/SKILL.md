---
name: generate-image
description: V2.0 - Generates images from text prompts using Nano Banana 2 (Gemini 3.1 Flash Image) via OpenRouter API. Pro-level quality at Flash speed. Includes automatic credit balance tracking.
---

# Generate Image

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Generate images from text descriptions using **Nano Banana 2** (Gemini 3.1 Flash Image Preview) — Pro-level visual quality at Flash speed and cost (~$0.08-0.12/image).

## Usage

```powershell
# Basic
& $env:USERPROFILE\.agents\skills\generate-image\scripts\generate-image.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png"

# With Directory Opus preview
& $env:USERPROFILE\.agents\skills\generate-image\scripts\generate-image.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png" -Preview
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Prompt` | Yes | The text prompt describing the image to generate |
| `-OutputPath` | Yes | Absolute path where the image will be saved |
| `-Preview` | No | Opens the generated image in Directory Opus viewer after saving |

## Requirements

- `OPENROUTER_API_KEY` environment variable must be set (User or Process scope)
- Get a key at: <https://openrouter.ai/keys>

## CRITICAL: Prompt Quality

**Image generation costs money. Make every generation count.**

When crafting prompts, you MUST be **verbose and specific**. A sparse prompt wastes money and produces generic results.

### Bad Prompt (DO NOT DO THIS)

```
"Dashboard infographic with logos"
```

### Good Prompt (DO THIS)

```
"A professional, modern infographic poster for HemSoft Dashboard, a developer analytics platform. 
Dark theme with deep navy (#0a0a1a) background and subtle gradient overlays. 
Feature a central holographic dashboard visualization showing real-time metrics and charts.
Include floating 3D tech stack icons: Next.js (white N logo), TypeScript (blue TS badge), 
Tailwind CSS (teal wind symbol), Supabase (green database icon), Bun (peach bun logo), 
Vercel (black triangle). Add glowing neon accent lines in purple (#8b5cf6) and cyan (#06b6d4).
Include subtle grid patterns and data visualization elements like line graphs and pie charts.
Professional tech startup aesthetic, clean typography, high contrast, 4K quality."
```

### Prompt Checklist

- [ ] **Subject**: What is being shown? (product, concept, scene)
- [ ] **Style**: Art style, aesthetic (modern, minimalist, cyberpunk, professional)
- [ ] **Colors**: Specific hex codes or color palette description
- [ ] **Composition**: Layout, focal points, visual hierarchy
- [ ] **Aspect Ratio**: Default to 16:9 unless specified otherwise
- [ ] **Details**: Specific elements, logos, icons, text to include
- [ ] **Quality**: Resolution, lighting, atmosphere
- [ ] **Context**: Brand identity, target audience, use case

## Default Settings

**Aspect Ratio**: 16:9 (widescreen format, ideal for presentations and displays)

## Infographic Templates

### Professional Infographic Style (Preferred)

For business reports, executive summaries, and data visualizations, use this signature style:

**Color Palette:**

- Background: Black (#000000)
- Primary Text: White (#FFFFFF)
- Accent 1: Vibrant Yellow (#FFD700)
- Accent 2: Luxurious Gold (#FFA500)
- Accent 3: Orange (#FF8C00)

**Design Elements:**

- Slick black background with subtle geometric patterns
- High contrast white text for readability
- Yellow/gold/orange highlights for emphasis
- Futuristic, modern aesthetic
- Clean typography
- Professional layout with clear sections divided by gold lines
- **16:9 aspect ratio** (widescreen format)
- 4K resolution for presentations

**Example Prompt Structure:**

```
"Professional [TYPE] infographic in 16:9 aspect ratio. Black background (#000000) with elegant white text, 
vibrant yellow (#FFD700) highlights, and luxurious gold (#FFA500) accents.

Title at top: '[TITLE]' in bold white with gold underline.

Layout in sections with gold divider lines:
[SECTION CONTENT WITH SPECIFIC NUMBERS/ICONS]

Footer text in white: '[TAGLINE]'

Modern, clean corporate design. High contrast. Professional typography. 
Subtle geometric patterns. Futuristic style. 16:9 widescreen format. 4K resolution. Executive presentation quality."
```

## Credit Balance Tracking

After each image generation, the system automatically displays your OpenRouter credit balance.

**Manual Balance Check:**

```powershell
& $env:USERPROFILE\.agents\skills\generate-image\scripts\Get-OpenRouterBalance.ps1
```

## Model Info

| Property | Value |
|----------|-------|
| Model ID | `google/gemini-3.1-flash-image-preview` |
| Nickname | Nano Banana 2 |
| Quality | Pro-level |
| Speed | Flash (fast) |
| Cost | ~$0.08-0.12/image |
| Released | Feb 26, 2026 |
| Features | Contextual understanding, image editing, multi-turn, aspect ratio control |

## Technical Notes

### Response Format

Nano Banana 2 returns images via `choices[0].message.images[]` array with base64 data URLs, or inline base64 in `message.content`. The script handles both formats automatically.

### API Structure

- URL: `https://openrouter.ai/api/v1/chat/completions`
- Method: POST
- Body: `{ "model": "google/gemini-3.1-flash-image-preview", "messages": [{ "role": "user", "content": "Generate an image: <prompt>" }] }`

## History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | 2026-03-01 | Hardwired to Nano Banana 2 (Gemini 3.1 Flash Image). Removed multi-model scripts. Single script simplicity. |
| 1.6 | 2026-02-28 | Added Nano Banana Pro script |
| 1.5 | 2026-01-06 | Added OpenRouter credit balance tracking after each generation |
| 1.4 | 2026-01-06 | Added dedicated per-model scripts for reliability |
| 1.3 | 2026-01-06 | Added model shortcuts and CRITICAL model selection requirement |
| 1.2 | Previous | Added Nano Banana models |
| 1.0 | Initial | Basic Seedream support |
