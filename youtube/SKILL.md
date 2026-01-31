---
name: youtube
description: V1.0 - Catalogs YouTube videos watched (partially or fully) with metadata for searchability. Use when adding, searching, or reviewing YouTube video watch history.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the youtube directory (path contains 'youtube'), verify that history logging occurred.
            
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
            Before stopping, if youtube was used (check if any files in youtube directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in youtube directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# YouTube Catalog

Maintains a catalog of YouTube videos watched (partially or fully) with metadata for later discovery and reference. Supports both **quick cataloging** for simple tracking and **deep processing** with AI-generated summaries and transcripts via integration with the **youtube-processor** skill.

## When to Use Each Workflow

**Quick Add**:

- Just want to track that you watched a video
- Need basic metadata (title, channel, duration, speakers)
- Quick reference for later
- No need for full transcript or AI summary

**Deep Processing**:

- Technical/educational content worth detailed analysis
- Want searchable transcript
- Need AI-generated summary with chapter breakdown
- Plan to reference specific timestamps or quotes

## Catalog Structure

Videos are cataloged in daily markdown files:

```
youtube/
├── catalog/
│   └── {YYYY-MM-DD}.md
├── thumbnails/
│   └── {video-id}.webp
├── processed/              # Optional: Full youtube-processor output
│   └── {YYYY-MM-DD - title}/
│       ├── {base_filename}.en.vtt
│       ├── {base_filename}-summary.md
│       └── {base_filename}-metadata.json
├── History/
└── SKILL.md
```

## Daily Catalog Format

Each day's catalog file (`catalog/{YYYY-MM-DD}.md`) contains:

```markdown
# YouTube Videos - {Month DD, YYYY}

## {HH:MM} - {Video Title}

- **URL**: {youtube-url}
- **Channel**: {channel-name}
- **Featuring**: {host/speaker names} (optional)
- **Duration**: {duration}
- **Thumbnail**: thumbnails/{video-id}.webp
- **Processed**: processed/{YYYY-MM-DD - title}/ (if using youtube-processor)
- **Watch Status**: {Fully Watched|Partially Watched (HH:MM:SS)}
- **Category**: {category} (e.g., Tutorial, Entertainment, Tech Review, Gaming, Music, etc.)
- **Tags**: {tag1}, {tag2}, {tag3}
- **Notes**: {optional notes about the video}
- **Key Takeaways**: {optional bullet points of key information}
- **AI Summary**: Link to processed/{YYYY-MM-DD - title}/{base_filename}-summary.md (if processed)

---
```

## Workflows

### Quick Add (Basic Cataloging)

For quickly cataloging a video you watched:

1. Get current timestamp: `Get-Date -Format "HH:mm"`
2. Get current date: `Get-Date -Format "yyyy-MM-dd"`
3. Download thumbnail: `ytd --write-thumbnail --skip-download --output "thumbnails/%(id)s.%(ext)s" {video-url}`
4. Extract basic metadata: `ytd --dump-json --no-download {video-url}`
5. Create or append to `catalog/{YYYY-MM-DD}.md`
6. Add video entry with metadata from ytd output

### Deep Processing (Full Analysis)

For detailed analysis with transcript and summary:

1. Use the **youtube-processor** skill to process the video
2. Output directory: `processed/{YYYY-MM-DD - title}/`
3. The processor will create:
   - Metadata JSON
   - Transcript (.vtt)
   - AI-generated summary (.md)
4. Download thumbnail to `thumbnails/`
5. Create catalog entry in `catalog/{YYYY-MM-DD}.md` referencing the processed folder

**To invoke youtube-processor**:

```powershell
$outputDir = "c:\Users\User\.claude\skills\youtube\processed\{folder-name}"
$url = "{video-url}"

# Run all processing steps
& "c:\Users\User\.claude\skills\youtube-processor\scripts\Get-YouTubeMetadata.ps1" -Url $url -OutputDir $outputDir
$metadata = Get-Content "$outputDir/*-metadata.json" | ConvertFrom-Json

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Download-YouTubeVideo.ps1" -Url $url -OutputDir $outputDir -BaseFilename $metadata.base_filename

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Get-YouTubeTranscript.ps1" -Url $url -OutputDir $outputDir -BaseFilename $metadata.base_filename -VideoPath "$outputDir/$($metadata.base_filename).webm"

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Create-YouTubeSummary.ps1" -TranscriptPath "$outputDir/$($metadata.base_filename).en.vtt" -OutputDir $outputDir -BaseFilename $metadata.base_filename

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Create-YouTubeSummaryAudio.ps1" -SummaryPath "$outputDir/$($metadata.base_filename)-summary.md" -OutputDir $outputDir -BaseFilename $metadata.base_filename
```

### Searching for Videos

Search across all catalog files by:

- Video title
- Channel name
- Featuring/speakers
- Category
- Tags
- Date range
- Watch status
- Keywords in notes or takeaways
- AI summary content (if processed)
- Transcript content (if processed)

### Required Information

When cataloging a video, collect:

- Video URL (required)
- Video title (required)
- Channel name (required)
- Duration (required)
- Thumbnail image (auto-downloaded)
- Watch status (required)
- Featuring/Hosts/Speakers (extracted from description)
- Category (optional but recommended)
- Tags (optional but recommended)
- Notes (optional)
- Key takeaways (optional)
- Processed folder path (if using youtube-processor)
- AI summary link (if processed)
- HTML report link (if processed)

## Example Entry

### Quick Add

```markdown
## 15:23 - How to Build a REST API with Node.js

- **URL**: https://www.youtube.com/watch?v=fgTGADljAeg
- **Channel**: Programming with Mosh
- **Featuring**: Mosh Hamedani
- **Duration**: 1:03:22
- **Thumbnail**: thumbnails/fgTGADljAeg.webp
- **Watch Status**: Fully Watched
- **Category**: Tutorial
- **Tags**: node.js, rest-api, express, backend, api-development
- **Notes**: Comprehensive tutorial covering Express setup, routing, middleware, and error handling.
- **Key Takeaways**:
  - Use express.json() for parsing JSON request bodies
  - Implement proper error handling middleware
  - Use environment variables for configuration
  - Follow RESTful naming conventions

---
```

### Deep Processing

```markdown
## 15:23 - How to Build a REST API with Node.js

- **URL**: https://www.youtube.com/watch?v=fgTGADljAeg
- **Channel**: Programming with Mosh
- **Featuring**: Mosh Hamedani
- **Duration**: 1:03:22
- **Thumbnail**: thumbnails/fgTGADljAeg.webp
- **Processed**: processed/2026-01-31 - how-to-build-a-rest-api-with-nodejs/
- **Watch Status**: Fully Watched
- **Category**: Tutorial
- **Tags**: node.js, rest-api, express, backend, api-development
- **Notes**: Comprehensive tutorial covering Express setup, routing, middleware, and error handling.
- **AI Summary**: [View Summary](processed/2026-01-31 - how-to-build-a-rest-api-with-nodejs/2026-01-31 - how-to-build-a-rest-api-with-nodejs-summary.md)
- **Key Takeaways**: See AI Summary for detailed chapter-by-chapter breakdown

---
```

## Search Strategies

- **By topic**: Search tags and categories
- **By creator**: Search channel names
- **By date**: Check specific catalog files
- **By completion**: Search "Fully Watched" or "Partially Watched"
- **By content**: Search notes and key takeaways
