---
name: text-read-image
description: V1.1 - Extracts text from images using OpenRouter vision models. Use when you need to read text from screenshots, documents, or any image.
---

# Text Read Image

Extract visible text from images using OpenRouter's vision-capable models.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Quick Start

```powershell
# Extract text from an image
& ~/.claude/skills/text-read-image/scripts/read-text.ps1 -ImagePath "D:\screenshot.png"

# With custom prompt for specific extraction
& ~/.claude/skills/text-read-image/scripts/read-text.ps1 -ImagePath "D:\receipt.jpg" -Prompt "Extract the total amount and date"

# Save output to file
& ~/.claude/skills/text-read-image/scripts/read-text.ps1 -ImagePath "D:\document.png" -OutputPath "D:\extracted.txt"
```

## Parameters

| Parameter     | Required | Description                                                    |
|---------------|----------|----------------------------------------------------------------|
| `-ImagePath`  | Yes      | Absolute path to the image file (PNG, JPG, JPEG, GIF, WEBP)    |
| `-Prompt`     | No       | Custom extraction prompt (default: extract all visible text)   |
| `-OutputPath` | No       | Save extracted text to file instead of console output          |
| `-Model`      | No       | OpenRouter model ID (default: `google/gemini-2.0-flash-001`)   |

## Supported Image Formats

- PNG
- JPG / JPEG
- GIF
- WEBP

## Requirements

- `OPENROUTER_API_KEY` environment variable must be set
- Get a key at: <https://openrouter.ai/keys>

## Use Cases

| Scenario         | Example Prompt                                    |
|------------------|---------------------------------------------------|
| Screenshot OCR   | (default) Extract all visible text                |
| Receipt scanning | "Extract merchant name, date, items, and total"   |
| Document parsing | "Extract the title and all headings"              |
| Code from image  | "Extract the code, preserve formatting"           |
| Form data        | "Extract all field labels and their values"       |

## Model Selection

The default `google/gemini-2.0-flash-001` is fast and cost-effective. For specific needs:

```powershell
# Use GPT-4o for complex documents
& ~/.claude/skills/text-read-image/scripts/read-text.ps1 -ImagePath "D:\doc.png" -Model "openai/gpt-4o"

# Use Claude for detailed analysis
& ~/.claude/skills/text-read-image/scripts/read-text.ps1 -ImagePath "D:\doc.png" -Model "anthropic/claude-sonnet-4"
```

## Output

- Returns extracted text to stdout (or saves to file with `-OutputPath`)
- Preserves line breaks from the original image
- Plain text format for easy processing

## Lessons Learned

| Issue                                              | Solution                                                       |
|----------------------------------------------------|----------------------------------------------------------------|
| `openrouter/auto` can route to quota-limited APIs  | Default to `google/gemini-2.0-flash-001` (reliable, cheap)     |
