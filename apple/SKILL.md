---
name: apple
description: V1.1 - Expert in all things Apple including macOS, iOS, iPadOS, watchOS, hardware (Mac, iPhone, iPad, Apple Watch, AirPods), software releases, and ecosystem integration. Tracks new releases, updates, and announcements similar to the games skill. ALWAYS includes clickable links and release dates in reports.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the apple directory (path contains 'apple'), verify that history logging occurred.
            
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
            Before stopping, if apple was used (check if any files in apple directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in apple directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Apple Expert

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

<!-- markdownlint-disable MD013 -->
Expert in all things Apple including macOS, iOS, iPadOS, watchOS, hardware (Mac, iPhone, iPad, Apple Watch, AirPods), software releases, and ecosystem integration. Tracks new releases, updates, and announcements.
<!-- markdownlint-enable MD013 -->

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

**CRITICAL**: Get the current time using `Get-Date -Format "HH:mm"` command - never guess the timestamp.

## Data Files

- **APPLE.md** - Your Apple products, interests, and preferences
- **sources.json** - Comprehensive list of Apple news sources to check
- **releases-to-check-out.json** - List of new releases, updates, or products you want to track with comprehensive metadata

## Commands

<!-- markdownlint-disable MD060 -->
| Command | Description |
|---------|-------------|
| `add` | Add a new Apple product or interest |
<!-- markdownlint-enable MD060 -->
| `list` | Show all tracked Apple products/interests |
| `check` | **Check all sources for new Apple releases, updates, and announcements** |
| `update` | Update product details or preferences |
| `remove` | Remove a product from tracked list |
| `add-to-checkout` | Add a release/product to the releases-to-check-out list with metadata |
| `list-checkout` | Show all items in the releases-to-check-out list |
| `remove-checkout` | Remove an item from the releases-to-check-out list |

## Checking for New Releases

**CRITICAL**: When asked to check for new releases, updates, or announcements, you MUST:

1. **Read sources.json** to get the complete list of sources
2. **Check ALL relevant sources** systematically:
   - Official Apple sources (Apple Newsroom, Apple Events, Developer pages)
   - News sites (daily check frequency)
   - Reddit communities (r/apple, r/macOS, r/iPhone, etc.)
   - Specialized sources (MacRumors, 9to5Mac, AppleInsider)
   - Developer sources (WWDC announcements, beta releases)
3. **Use web_search or mcp_web_fetch** to check each source
4. **Filter results** based on user interests:
   - macOS updates and features
   - iOS/iPadOS releases
   - Hardware announcements (Mac, iPhone, iPad, Apple Watch, AirPods)
   - Software updates and new features
   - Developer tools and frameworks
   - Ecosystem integration features
5. **Compare against APPLE.md** to avoid duplicates
6. **Gather comprehensive metadata** for each release found:
   - Release date/availability
   - Version numbers
   - Key features and improvements
   - Compatibility requirements
   - Pricing (if applicable)
   - Official announcement links

7. **Present findings** with:
   - Product/release name
   - **ALWAYS include clickable links** (Apple official pages, news articles, or source URLs)
   - **ALWAYS include release dates** and availability information
   - Brief description of what's new
   - Why it might be relevant
   - Source where found
   - Platform/device compatibility

   <!-- markdownlint-disable MD013 -->
   **CRITICAL**: Every release mentioned MUST include at least one clickable link AND release date information. Use markdown format: `[Product Name](URL)`. Prioritize Apple official pages when available, otherwise use news articles or source URLs.
   <!-- markdownlint-enable MD013 -->

## Source Checking Protocol

When checking sources, prioritize by checkFrequency:

- **Daily sources**: Check first (news sites, Apple Newsroom, MacRumors, Reddit communities)
- **Weekly sources**: Check if doing comprehensive search (YouTube channels, developer blogs)
- **As-needed sources**: Check for specific product details (Apple Support, technical specifications)

<!-- markdownlint-disable MD013 -->
**Never skip sources** - the sources.json file exists to ensure comprehensive coverage. If a source is unavailable, note it but continue checking others.
<!-- markdownlint-enable MD013 -->

## Release Requirements

**MANDATORY**: When reporting any Apple release, update, or announcement, you MUST include:

1. **Release Date** - When the product/update was released or announced
2. **Version Number** - Software version (e.g., macOS 15.1, iOS 18.2)
3. **Key Features** - Major new features or improvements
4. **Compatibility** - Which devices/models are supported
5. **Links** - Apple official pages, announcement pages, or news articles
6. **Availability** - Current availability status (Available now, Beta, Coming soon, etc.)

**Format**: Include release info in this format:

- **Release Date**: {date}
- **Version**: {version number}
- **Availability**: {status}
- **Compatibility**: {devices/models}
- **Links**: [Product Name](URL)

<!-- markdownlint-disable MD013 -->
**Never report a release without attempting to find release date and links** - this information helps users assess timing and access official resources.
<!-- markdownlint-enable MD013 -->

## User Preferences

<!-- markdownlint-disable MD013 -->
<!-- markdownlint-disable MD013 -->
Based on APPLE.md, track user's Apple products and interests. When discovering new releases, prioritize items that match these characteristics.
<!-- markdownlint-enable MD013 -->
<!-- markdownlint-enable MD013 -->

## Releases to Check Out List

<!-- markdownlint-disable MD013 -->
The skill maintains a separate list of releases/products you want to track in `releases-to-check-out.json`. This file stores comprehensive metadata for each item:
<!-- markdownlint-enable MD013 -->

- **Product/Release name** - Official name
- **Release date** - When it was released or announced
- **Status** - Available now, Beta, Coming soon, Rumored, etc.
- **Version** - Software version number (if applicable)
- **Description** - Brief description of what's new
- **Key Features** - Array of major features
- **Compatibility** - Supported devices/models
- **Pricing** - Current price (if applicable)
- **Links** - Apple official pages, announcement pages, news articles
- **Category** - Hardware, Software, macOS, iOS, iPadOS, watchOS, Services, etc.
- **Why interested** - Why this release matches your interests
- **Source** - Where you discovered this release
- **Date added** - When you added it to the list (ISO format: YYYY-MM-DD)
- **Notes** - Any additional notes or observations

When adding a release to the checkout list, gather as much metadata as possible:

1. Search for release date, version numbers, and description
2. Extract key features, compatibility, and pricing information
3. Include clickable links (Apple official pages preferred)
4. Note why it matches user interests
5. Record the date added (use current date in YYYY-MM-DD format)

## Workflow

1. Read `APPLE.md` to understand current products and interests
2. Read `sources.json` to get source list
3. Check sources systematically based on request
4. Filter and match releases to interests
5. **For each release found, gather comprehensive metadata** (release date, version, features, compatibility, links)
6. Update `APPLE.md` if adding new products/interests
7. Update `releases-to-check-out.json` if adding to checkout list (with comprehensive metadata)
8. **Report findings with clear reasoning, ALWAYS include clickable links, and ALWAYS include release dates**

## Link Requirements

**MANDATORY**: When reporting any Apple release, you MUST include clickable links:

<!-- markdownlint-disable MD013 -->
- **Official Apple pages**: Use Apple.com URLs (e.g., `https://www.apple.com/macos/`, `https://www.apple.com/newsroom/`)
<!-- markdownlint-enable MD013 -->
- **News articles**: Use news site URLs
- **Source URLs**: Include the source URL where the release was discovered

**Format**: Always use markdown links: `[Product Name](URL)`

<!-- markdownlint-disable MD013 -->
**Never report a release without at least one link** - links are essential for users to easily access more information or official resources.
<!-- markdownlint-enable MD013 -->

## Examples

- "Check for new macOS updates" → Report with Apple official links AND release dates for each update
- "What new Apple products were announced?" → Include clickable links AND release dates for all announcements
- "Add [Product Name] to my tracked products" → Include link and release info when adding
- "Show me all my tracked Apple products" → Include links and release info for each product in APPLE.md
- "Check Apple Newsroom for latest announcements" → Report with Apple official links AND release dates

**Remember**: Every release mention requires at least one clickable link AND release date information (or note if unavailable).
