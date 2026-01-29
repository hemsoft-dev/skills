---
name: ai-chapter
description: V1.4 - Manages administrative tasks for AI Chapter meetings with Geo Rufino. Two-track meeting structure (AI Engineering Chapter on Confluence, AI Foundation Chapter on SharePoint) with weekly alternation. Generates welcome messages for new members.
---

# AI Chapter

Manage administrative tasks, resources, and agendas for AI Chapter meetings hosted with Geo Rufino.

## Meeting Structure: Two Tracks

AI Chapter has **two separate tracks** that alternate weekly:

### Track 1: AI Engineering Chapter

- **Agenda Location**: Confluence (AIPE space)
- **Title Format**: `AI Chapter 2026 -- Meeting notes {MM/DD/YY}`
- **Space**: AI Initiatives (Productivity Engineering)
- **Management**: Use Atlassian skill for Confluence operations
- **Recording Storage**: SharePoint (AI Engineering Chapter folder)

### Track 2: AI Foundation Chapter

- **Agenda Location**: SharePoint Word documents
- **Path**: `Shared Documents/AI Foundation Chapter/Agendas/`
- **File Format**: `{YYYY-MM-DD}-Meeting-Notes.docx`
- **Management**: Use SharePoint skill for document access
- **Recording Storage**: SharePoint (AI Foundation Chapter folder)

### Current Week Schedule

**Week of 2026-01-20**: AI Foundation Chapter

- Next alternation: Week of 2026-01-27 (AI Engineering Chapter)

When asked about "the meeting" or "Wednesday's meeting", determine which track based on the current week's schedule.

## CRITICAL: Always Provide Links

**When referencing any resource, page, or file, ALWAYS include the direct link:**

- **Confluence pages**: Include full Confluence URL (e.g., `https://relias.atlassian.net/wiki/spaces/AIPE/pages/...`)
- **Meeting notes files**: Include relative file path (e.g., `History/2026-01-21-meeting-notes.md`)
- **Resources**: Include URL from `resources.md` if available
- **Previous meetings**: Link to both Confluence page (if exists) and local meeting notes file

**Format**: Use markdown link syntax: `[Display Text](URL or path)`

**Example output:**

```
Found agenda: [AI Chapter - 2026-01-21](https://relias.atlassian.net/wiki/spaces/AIPE/pages/...)
Previous meeting notes: [2026-01-14 Meeting Notes](History/2026-01-14-meeting-notes.md)
```

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## ALWAYS: Retrospective Check

Before completing, reflect on this interaction:

1. Were new patterns or edge cases discovered?
2. Could instructions be clearer?
3. Do scripts need improvements or bug fixes?
4. Should new capabilities be added?

If improvements identified:

- Present proposed changes with clear rationale
- Wait for user approval before applying
- Keep skill concise (remove/condense when adding if possible)
- Version bump SKILL.md if changes applied

## Core Functions

### 1. Welcome Messages for New Members

When asked to generate a welcome message for someone joining the AI Chapter, use this template:

**Template:**

```
Hey {user} and welcome to Relias! We're excited to have you join the AI Chapter. 

We have two different tracks:
- **AI Foundation Chapter**: Beginner-friendly and accessible to all skill levels
- **AI Engineering Chapter**: More technical discussions, but nothing too crazy 😊

You're welcome to join both or just one—it's completely up to you! They each occur biweekly without overlap, which means there's an AI Chapter meeting every week that alternates between the two tracks.

Just let me know which one(s) you're interested in, and I'll make sure you get added to the right meetings!
```

**Customization:**

- Replace `{user}` with the person's name or @mention
- Adjust tone if needed (more formal/casual)
- Add specific details if the person has expressed interest in a particular track

**Resource Links to Include:**

When welcoming new members, you can reference these resources:

- **AI Engineering Chapter Agenda**: [Confluence Page](https://relias.atlassian.net/wiki/spaces/AIPE/pages/5830213651/AI+Engineering+Chapter+Meeting+Notes+--+2026)
- **AI Engineering Chapter Recordings**: [SharePoint Folder](https://reliaslearning.sharepoint.com/:f:/r/sites/ProductivityEngineering/Shared%20Documents/AI%20Engineering%20Chapter/Recordings?csf=1&web=1&e=RE3hax)
- **AI Foundation Chapter Agenda**: [SharePoint Folder](https://reliaslearning.sharepoint.com/:f:/r/sites/ProductivityEngineering/Shared%20Documents/AI%20Foundation%20Chapter/Agendas?csf=1&web=1&e=wDmeoV)
- **AI Foundation Chapter Recordings**: [SharePoint Folder](https://reliaslearning.sharepoint.com/:f:/r/sites/ProductivityEngineering/Shared%20Documents/AI%20Foundation%20Chapter/Recordings?csf=1&web=1&e=eAaC39)

### 2. Meeting Agenda Management

**AI Engineering Chapter (Confluence):**

Use the `atlassian` skill to manage agendas in Confluence:

- **Main Agenda Page**: [AI Engineering Chapter Meeting Notes -- 2026](https://relias.atlassian.net/wiki/spaces/AIPE/pages/5830213651/AI+Engineering+Chapter+Meeting+Notes+--+2026)
- **Search for Agendas**: `Search-Confluence.ps1 -Query "AI Chapter" -Title "AI Chapter"`
- **Space**: AI Initiatives (Productivity Engineering) - `AIPE`
- **Title Format**: `AI Chapter 2026 -- Meeting notes {MM/DD/YY}`
- **ALWAYS provide direct links** to Confluence pages: `[Page Title](Full Confluence URL)`

**AI Foundation Chapter (SharePoint):**

Use the `sharepoint` skill to access agendas on SharePoint:

- **Agenda Folder**: [AI Foundation Chapter Agendas](https://reliaslearning.sharepoint.com/:f:/r/sites/ProductivityEngineering/Shared%20Documents/AI%20Foundation%20Chapter/Agendas?csf=1&web=1&e=wDmeoV)
- **Location**: `https://reliaslearning.sharepoint.com/sites/ProductivityEngineering`
- **Path**: `Shared Documents/AI Foundation Chapter/Agendas/`
- **File Format**: `{YYYY-MM-DD}-Meeting-Notes.docx`
- **Access**: Use SharePoint Web UI or `Get-PnPFile` to download documents
- **ALWAYS provide direct SharePoint links** when referencing agendas

### 3. Resource Tracking

Maintain `resources.md` file with all available resources:

**Resource Categories:**

- Documentation (papers, articles, guides)
- Tools & Platforms (AI tools, frameworks, services)
- Learning Materials (courses, tutorials, videos)
- Community Resources (forums, Discord servers, communities)
- Internal Resources (company-specific docs, Confluence pages)

**Resource Entry Format:**

```markdown
## {Category Name}

### {Resource Title}
- **Type**: {Documentation/Tool/Learning/Community/Internal}
- **URL**: {link}
- **Description**: {brief description}
- **Added**: {YYYY-MM-DD}
- **Tags**: {tag1, tag2, tag3}
- **Notes**: {any additional context}
```

**Operations:**

- Add new resources to `resources.md`
- Search resources by category, tag, or keyword
- Update resource status (active, archived, deprecated)
- Generate resource summaries for meetings
- **ALWAYS include resource URLs** when referencing resources in output

### 4. Meeting Notes & Administration

**Create Meeting Notes:**

- Format: `History/{YYYY-MM-DD}-meeting-notes.md`
- Include:
  - Meeting date and attendees
  - Key discussion points
  - Decisions made
  - Action items (with owners and due dates)
  - Resources shared or discussed
  - Follow-up items

**Meeting Preparation:**

- Review previous meeting notes
- Check pending action items
- Prepare agenda items based on ongoing discussions
- Gather relevant resources for discussion topics
- **ALWAYS link to previous meeting notes** when referencing them: `[YYYY-MM-DD Meeting Notes](History/YYYY-MM-DD-meeting-notes.md)`
- **ALWAYS link to Confluence agendas** when referencing them: `[Agenda Title](Confluence URL)`

**Action Item Tracking:**

- Maintain action items from meetings
- Track completion status
- Follow up on overdue items
- Generate action item summaries

### 5. SharePoint Document Access

**When to Use SharePoint Integration:**

- Accessing AI Chapter documents stored in Productivity Engineering SharePoint site
- Listing meeting notes, recordings, or agendas from SharePoint folders
- Retrieving files from AI Engineering Chapter or AI Foundation Chapter folders

**Recommended Approach:**
Use the SharePoint skill's `Get-AIChapterDocuments.ps1` script for streamlined document access:

```powershell
# List all documents from both chapters
.\sharepoint\scripts\Get-AIChapterDocuments.ps1

# List only Engineering Chapter documents
.\sharepoint\scripts\Get-AIChapterDocuments.ps1 -Chapter Engineering

# List only Foundation Chapter documents
.\sharepoint\scripts\Get-AIChapterDocuments.ps1 -Chapter Foundation
```

**SharePoint Location:**

- Site: <https://reliaslearning.sharepoint.com/sites/ProductivityEngineering>
- Folders: AI Engineering Chapter, AI Foundation Chapter, AI Quick Tutorials
- Document library: Shared Documents

**Direct Links to Recordings:**

- **AI Engineering Chapter Recordings**: [SharePoint Folder](https://reliaslearning.sharepoint.com/:f:/r/sites/ProductivityEngineering/Shared%20Documents/AI%20Engineering%20Chapter/Recordings?csf=1&web=1&e=RE3hax)
- **AI Foundation Chapter Recordings**: [SharePoint Folder](https://reliaslearning.sharepoint.com/:f:/r/sites/ProductivityEngineering/Shared%20Documents/AI%20Foundation%20Chapter/Recordings?csf=1&web=1&e=eAaC39)

**Note:** The SharePoint skill handles authentication and connection management. Use it rather than duplicating SharePoint functionality in this skill.

### 6. Integration with Atlassian Skill

**When to Use Atlassian Integration:**

- Creating/updating Confluence agendas
- Searching for past meeting agendas
- Retrieving Confluence pages related to AI Chapter
- Managing Confluence content structure

**Required Environment Variables:**

- `ATLASSIAN_EMAIL`: Your Atlassian email
- `ATLASSIAN_API_TOKEN`: API token from Atlassian account

**Common Confluence Operations:**

- List all AI Chapter pages: `Search-Confluence.ps1 -Query "AI Chapter" -Title "AI Chapter"`
- Get specific agenda: `Get-ConfluencePage.ps1 -PageId {id} -IncludeBody`
- Create new agenda: Use `New-ConfluencePage.ps1` with proper space key

## File Structure

```
ai-chapter/
├── SKILL.md
├── resources.md          # Tracked resources
└── History/
    ├── {YYYY-MM-DD}-meeting-notes.md
    └── {YYYY-MM-DD}.md   # Interaction logs
```

## Best Practices

1. **ALWAYS provide links** - Every reference to a Confluence page, SharePoint document, meeting notes file, or resource MUST include a clickable link
2. **Understand the track** - Determine if the meeting is AI Engineering Chapter (Confluence) or AI Foundation Chapter (SharePoint)
3. **Link meeting notes** - When referencing previous meetings, link to both Confluence page/SharePoint doc and local meeting notes file
4. **Link resources** - When mentioning resources, include the URL from `resources.md`
5. **Keep resources updated** - Add new resources immediately after meetings
6. **Track action items** - Ensure follow-up items are documented with owners
7. **Maintain continuity** - Reference previous meetings and ongoing discussions with links
8. **Know the schedule** - Track which week alternates between Engineering and Foundation
9. **Archive old resources** - Move deprecated resources to archived section

## Common Workflows

### Preparing for a Meeting

1. **Determine which track** (Engineering on Confluence or Foundation on SharePoint)
2. Review last meeting notes for that track
3. Check pending action items
4. Locate agenda:
   - **Engineering**: Search Confluence for latest agenda
   - **Foundation**: Check SharePoint `AI Foundation Chapter/Agendas/` folder
5. Gather relevant resources for discussion

### During/After a Meeting

1. Take meeting notes in `History/{YYYY-MM-DD}-meeting-notes.md`
2. Update agenda location:
   - **Engineering**: Update Confluence page
   - **Foundation**: Update SharePoint Word document (via web UI)
3. Add new resources to `resources.md`
4. Document action items with owners and due dates
5. Log interaction in `History/{YYYY-MM-DD}.md`

### Checking Agenda Status

When asked about "the meeting" or "Wednesday's meeting":

1. Check current week to determine track (Engineering vs Foundation)
2. Search appropriate location:
   - **Engineering**: Use `Search-Confluence.ps1`
   - **Foundation**: Provide SharePoint link to Agendas folder
3. Report agenda status with direct links

### Resource Management

1. Add new resources with proper categorization
2. Tag resources for easy searching
3. Update resource status as needed
4. Generate resource summaries for sharing
