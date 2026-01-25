---
name: generate-image
description: V1.5 - Generates images from text prompts using OpenRouter API with dedicated scripts for each model (Seedream, Nano Banana, Nano Banana Pro). Includes automatic credit balance tracking.
---

# Generate Image

Generate images from text descriptions using OpenRouter's image generation models.

## Quick Start - Use Dedicated Scripts

Each model has its own dedicated script in `~/.claude/skills/generate-image/scripts/`:

| Model | Script | Cost | Best For |
|-------|--------|------|----------|
| **Seedream 4.5** | `generate-seedream.ps1` | ~$0.04/image | Fast, good quality, best value |
| **Nano Banana** | `generate-nanobanana.ps1` | ~$0.10-0.15/image | Contextual edits, multi-turn |
| **Nano Banana Pro** | `generate-nananapro.ps1` | ~$0.50-1.00/image | Best quality, text rendering |

### Usage

```powershell
# Seedream 4.5 (fast, cheap)
& ~/.claude/skills/generate-image/scripts/generate-seedream.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png"

# Nano Banana (Google Gemini 2.5 Flash)
& ~/.claude/skills/generate-image/scripts/generate-nanobanana.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png"

# Nano Banana Pro (Google Gemini 3 Pro - highest quality)
& ~/.claude/skills/generate-image/scripts/generate-nananapro.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png"

# With Directory Opus preview (add -Preview to any script)
& ~/.claude/skills/generate-image/scripts/generate-seedream.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png" -Preview
```

### Parameters (All Scripts)

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

- Use for: Infographics, presentations, social media headers
- Alternative ratios only when specifically requested (1:1 for square posts, 9:16 for vertical/mobile)

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

## CRITICAL: Model Selection

**If the user does not specify a model, you MUST:**

1. Ask which model they prefer OR present the comparison table
2. Default to **Seedream** if they say "whatever" or "cheapest"
3. Use **Nano Banana Pro** only if they explicitly want highest quality

## Model Comparison

| Feature | Seedream 4.5 | Nano Banana | Nano Banana Pro |
|---------|--------------|-------------|-----------------|
| Model ID | `bytedance-seed/seedream-4.5` | `google/gemini-2.5-flash-image` | `google/gemini-3-pro-image-preview` |
| Speed | ⚡ Fastest | 🏃 Fast | 🐢 Slower |
| Quality | ⭐⭐⭐ Good | ⭐⭐⭐⭐ Very Good | ⭐⭐⭐⭐⭐ Best |
| Text Rendering | ⭐⭐ Basic | ⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent |
| Cost | ~$0.04 | ~$0.10-0.15 | ~$0.50-1.00 |
| Resolution | 1024x1024 | 1024x1024 | Up to 4K |

## Credit Balance Tracking

After each image generation, the system automatically displays your OpenRouter credit balance:

```
💰 OpenRouter Credit Balance
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total:     $70
Used:      $41.64 (59.49%)
Remaining: $28.36
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Manual Balance Check:**

```powershell
& ~/.claude/skills/generate-image/scripts/Get-OpenRouterBalance.ps1
```

This helps track spending and avoid unexpected charges. The balance check uses OpenRouter's `/api/v1/credits` endpoint.

## Legacy Script (Still Works)

The unified `generate-image.ps1` script still works with model shortcuts:

```powershell
.\generate-image.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png" -Model seedream
.\generate-image.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png" -Model banana
.\generate-image.ps1 -Prompt "Your prompt" -OutputPath "D:\image.png" -Model pro
```

## Technical Notes

### Response Formats (Important for Debugging)

Each model returns images differently:

- **Seedream**: `choices[0].message.images[0].image_url` = base64 data URL
- **Nano Banana/Pro**: `choices[0].message.content` contains inline base64 data URL, OR `message.images[]` array

The dedicated scripts handle these differences automatically.

### API Structure

All models use OpenRouter's chat completions endpoint:

- URL: `https://openrouter.ai/api/v1/chat/completions`
- Method: POST
- Body: `{ "model": "<model-id>", "messages": [{ "role": "user", "content": "Generate an image: <prompt>" }] }`

## History

| Version | Date | Changes |
|---------|------|---------|
| 1.5 | 2026-01-06 | Added OpenRouter credit balance tracking after each generation |
| 1.4 | 2026-01-06 | Added dedicated per-model scripts for reliability |
| 1.3 | 2026-01-06 | Added model shortcuts and CRITICAL model selection requirement |
| 1.2 | Previous | Added Nano Banana models |
| 1.0 | Initial | Basic Seedream support |
