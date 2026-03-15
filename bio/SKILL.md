---
name: bio
description: V1.2 - Creates detailed biographies for any person using exhaustive research across multiple sources.
---

# Biography Expert

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Generate thorough, well-researched biographies using the template in this skill folder.

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Requirements

1. **Name**: The person's full name (required)
2. **Output Location**: Folder path where the biography will be saved (required - ask if not provided)
3. **Filename**: Defaults to `biography.md` if not specified

## Research Protocol

**CRITICAL**: A biography is only as good as the research behind it. You MUST exhaust all available avenues:

1. **Web Search First** - Use `fetch_webpage` to search for the person across multiple queries:
   - Full name + "biography"
   - Full name + "early life"
   - Full name + "career"
   - Full name + "interview"
   - Full name + "awards"
   - Full name + specific known affiliations (company, university, etc.)

2. **Image Capture** - **ALWAYS** locate and document the last known image of the person:
   - **Primary Source**: LinkedIn profile photo (use Playwright to screenshot if needed)
   - **Secondary Sources**: Company website, GitHub profile, Twitter/X, official website, news articles
   - **Image Requirements**:
     - Must be a professional/recent headshot or photo
     - Capture the URL source
     - Note the date the photo was last seen (when available)
     - Save URL or file path in the biography under "Image" section
   - **If LinkedIn is not accessible**: Use the next best professional source (company website, official bio page, etc.)

3. **Follow Every Lead** - When you find references to other sources, interviews, or articles, fetch those too.

4. **Multiple Source Types** - Search across:
   - Wikipedia and encyclopedias
   - News articles and interviews
   - Official websites and LinkedIn
   - Award databases
   - University/organization records
   - Social media profiles
   - Published works by/about them

5. **Cross-Reference** - Verify facts across multiple sources when possible.

6. **DO NOT GIVE UP** - If initial searches yield little, try:
   - Alternate name spellings or maiden names
   - Nicknames or stage names
   - Associated people (spouse, collaborator, mentor)
   - Organizations they're affiliated with
   - Events they participated in
   - Publications they authored or appeared in

**If a section has no verifiable information after exhaustive search, mark it as "Not publicly documented" rather than omitting it.**

## Workflow

1. Confirm you have the person's name and output location
2. Conduct exhaustive research using the protocol above
3. Fill out every section of `biography-template.md`
4. Save the completed biography to the specified location
5. List the sources used at the end

## Template

Use the `biography-template.md` file in this skill folder as the structure for all biographies.

## Output

- Format: Markdown (`.md`)
- Filename: User-specified or `biography.md`
- Location: User-specified (required)
