---
name: youtube
description: V1.1 - Catalogs YouTube videos watched (partially or fully) with metadata for searchability using one-video-one-folder structure. Use when adding, searching, or reviewing YouTube video watch history.
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

Maintains a catalog of YouTube videos watched (partially or fully) with metadata for later discovery and reference. Uses a **one-video-one-folder** structure where each video has its own dedicated folder containing all related files (README, transcript, summary, thumbnail, metadata). Supports both **quick cataloging** for simple tracking and **deep processing** with AI-generated summaries and transcripts via integration with the **youtube-processor** skill.

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

Each video gets its own folder with all related files:

```
youtube/
├── {YYYY-MM-DD - video-title}/
│   ├── README.md                    # Catalog entry with metadata
│   ├── thumbnail.webp               # Video thumbnail
│   ├── {base_filename}-metadata.json    # Raw metadata (if processed)
│   ├── {base_filename}-summary.md       # AI summary (if processed)
│   └── {base_filename}.en.vtt           # Transcript (if processed)
├── History/
└── SKILL.md
```

## Video Folder Format

Each video folder contains a `README.md` file with:

```markdown
# {Video Title}

**Cataloged**: {YYYY-MM-DD HH:MM}

## Video Information

- **URL**: {youtube-url}
- **Channel**: {channel-name}
- **Featuring**: {host/speaker names} (optional)
- **Duration**: {duration}
- **Watch Status**: {Fully Watched|Partially Watched (HH:MM:SS)}
- **Category**: {category} (e.g., Tutorial, Entertainment, Tech Review, Gaming, Music, etc.)
- **Tags**: {tag1}, {tag2}, {tag3}

## Description

{optional notes about the video}

## Files

- [AI Summary]({base_filename}-summary.md) - Detailed summary with chapters and key takeaways (if processed)
- [Transcript]({base_filename}.en.vtt) - Full transcript (if processed)
- [Metadata]({base_filename}-metadata.json) - Raw metadata (if processed)
- [Thumbnail](thumbnail.webp) - Video thumbnail

## Key Takeaways

{optional bullet points or link to AI summary}
```

## Workflows

### Quick Add (Basic Cataloging)

For quickly cataloging a video you watched:

1. Get current timestamp: `Get-Date -Format "yyyy-MM-dd HH:mm"`
2. Create folder: `{YYYY-MM-DD - video-title-slug}/`
3. Download thumbnail: `ytd --write-thumbnail --skip-download --convert-thumbnails webp --output "{folder}/thumbnail.%(ext)s" {video-url}`
4. Extract basic metadata: `ytd --dump-json --no-download {video-url}`
5. Create `README.md` in the video folder with metadata

### Deep Processing (Full Analysis)

For detailed analysis with transcript and summary:

1. Use the **youtube-processor** skill to process the video
2. Output directory: `{YYYY-MM-DD - video-title}/` (directly in youtube folder)
3. The processor will create:
   - Metadata JSON
   - Transcript (.vtt)
   - AI-generated summary (.md)
4. Download thumbnail to the video folder as `thumbnail.webp`
5. Create `README.md` in the video folder with catalog entry

**To invoke youtube-processor**:

```powershell
$outputDir = "c:\Users\User\.claude\skills\youtube\{YYYY-MM-DD - video-title}"
$url = "{video-url}"

# Run all processing steps
& "c:\Users\User\.claude\skills\youtube-processor\scripts\Get-YouTubeMetadata.ps1" -Url $url -OutputDir $outputDir
$metadata = Get-Content "$outputDir/*-metadata.json" | ConvertFrom-Json

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Download-YouTubeVideo.ps1" -Url $url -OutputDir $outputDir -BaseFilename $metadata.base_filename

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Get-YouTubeTranscript.ps1" -Url $url -OutputDir $outputDir -BaseFilename $metadata.base_filename -VideoPath "$outputDir/$($metadata.base_filename).webm"

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Create-YouTubeSummary.ps1" -TranscriptPath "$outputDir/$($metadata.base_filename).en.vtt" -OutputDir $outputDir -BaseFilename $metadata.base_filename

& "c:\Users\User\.claude\skills\youtube-processor\scripts\Create-YouTubeSummaryAudio.ps1" -SummaryPath "$outputDir/$($metadata.base_filename)-summary.md" -OutputDir $outputDir -BaseFilename $metadata.base_filename

# Download thumbnail
ytd --write-thumbnail --skip-download --convert-thumbnails webp --output "$outputDir/thumbnail.%(ext)s" $url
```

### Searching for Videos

Search across all video folders by:

- Video title (folder names and README.md)
- Channel name
- Featuring/speakers
- Category
- Tags
- Date range (folder name prefix)
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
- Thumbnail image (auto-downloaded as thumbnail.webp)
- Watch status (required)
- Cataloged timestamp (required)
- Featuring/Hosts/Speakers (extracted from description)
- Category (optional but recommended)
- Tags (optional but recommended)
- Description/Notes (optional)
- Key takeaways (optional)
- AI summary (if processed)
- Transcript (if processed)
- Metadata JSON (if processed)

## Example Entry

### Quick Add

Folder: `2026-01-31 - how-to-build-a-rest-api-with-nodejs/README.md`

```markdown
# How to Build a REST API with Node.js

**Cataloged**: 2026-01-31 15:23

## Video Information

- **URL**: <https://www.youtube.com/watch?v=fgTGADljAeg>
- **Channel**: Programming with Mosh
- **Featuring**: Mosh Hamedani
- **Duration**: 1:03:22
- **Watch Status**: Fully Watched
- **Category**: Tutorial
- **Tags**: node.js, rest-api, express, backend, api-development

## Description

Comprehensive tutorial covering Express setup, routing, middleware, and error handling.

## Files

- [Thumbnail](thumbnail.webp) - Video thumbnail

## Key Takeaways

- Use express.json() for parsing JSON request bodies
- Implement proper error handling middleware
- Use environment variables for configuration
- Follow RESTful naming conventions
```

### Deep Processing

Folder: `2026-01-31 - how-to-build-a-rest-api-with-nodejs/README.md`

```markdown
# How to Build a REST API with Node.js

**Cataloged**: 2026-01-31 15:23

## Video Information

- **URL**: <https://www.youtube.com/watch?v=fgTGADljAeg>
- **Channel**: Programming with Mosh
- **Featuring**: Mosh Hamedani
- **Duration**: 1:03:22
- **Watch Status**: Fully Watched
- **Category**: Tutorial
- **Tags**: node.js, rest-api, express, backend, api-development

## Description

Comprehensive tutorial covering Express setup, routing, middleware, and error handling.

## Files

- [AI Summary](2026-01-31%20-%20how-to-build-a-rest-api-with-nodejs-summary.md) - Detailed summary with chapters and key takeaways
- [Transcript](2026-01-31%20-%20how-to-build-a-rest-api-with-nodejs.en.vtt) - Full transcript
- [Metadata](2026-01-31%20-%20how-to-build-a-rest-api-with-nodejs-metadata.json) - Raw metadata
- [Thumbnail](thumbnail.webp) - Video thumbnail

## Key Takeaways

See [AI Summary](2026-01-31%20-%20how-to-build-a-rest-api-with-nodejs-summary.md) for detailed chapter-by-chapter breakdown.
```

## Search Strategies

- **By topic**: Search tags and categories in README.md files
- **By creator**: Search channel names in README.md files
- **By date**: Use folder name prefixes (YYYY-MM-DD)
- **By completion**: Search "Fully Watched" or "Partially Watched" in README.md
- **By content**: Search notes, key takeaways, summaries, and transcripts
