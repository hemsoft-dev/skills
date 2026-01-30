---
name: games
description: V1.4 - Tracks liked games and discovers new games matching user preferences by checking comprehensive gaming sources. Monitors news sites, discovery platforms, Reddit communities, and specialized sources for survival, crafting, RPG, and open-world games. ALWAYS includes clickable links and ratings (Metacritic, OpenCritic, Steam reviews) in game reports. Maintains a separate list of games to check out with comprehensive metadata.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the games directory (path contains 'games'), verify that history logging occurred.
            
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
            Before stopping, if games was used (check if any files in games directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in games directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Games Tracker

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Tracks your liked games and discovers new games matching your preferences by checking comprehensive gaming sources.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

**CRITICAL**: Get the current time using `Get-Date -Format "HH:mm"` command - never guess the timestamp.

## Data Files

- **GAMES.md** - Your liked games list and preferences
- **sources.json** - Comprehensive list of gaming sources to check
<!-- markdownlint-disable MD013 -->
- **game-to-check-out.json** - List of games you want to try out with comprehensive metadata (release date, ratings, description, when added, etc.)
<!-- markdownlint-enable MD013 -->

## Commands

<!-- markdownlint-disable MD060 -->
| Command | Description |
|---------|-------------|
| `add` | Add a new game to your liked list |
<!-- markdownlint-enable MD060 -->
| `list` | Show all liked games |
| `check` | **Check all sources for new games matching your preferences** |
| `update` | Update game details or preferences |
| `remove` | Remove a game from liked list |
| `add-to-checkout` | Add a game to the games-to-check-out list with metadata |
| `list-checkout` | Show all games in the games-to-check-out list |
| `remove-checkout` | Remove a game from the games-to-check-out list |

## Checking for New Games

**CRITICAL**: When asked to check for new games or discover potential matches, you MUST:

1. **Read sources.json** to get the complete list of sources
2. **Check ALL relevant sources** systematically:
   - News sites (daily check frequency)
   - Discovery platforms (Steam, Epic, GOG, itch.io)
   - Reddit communities (r/SurvivalGaming, r/BaseBuildingGames, r/gamingsuggestions, etc.)
   - Specialized sources (Metacritic new releases, SteamDB, etc.)
3. **Use web_search or mcp_web_fetch** to check each source
4. **Filter results** based on user preferences:
   - Survival games
   - Crafting mechanics
   - RPG elements
   - Open world exploration
   - Base building
   - Multiplayer support
5. **Compare against GAMES.md** to avoid duplicates
6. **Search for ratings** for each game found:
   - **Metacritic** scores (if available)
   - **OpenCritic** scores (if available)
   - **Steam** review scores (Positive/Very Positive/Overwhelmingly Positive, % positive, review count)
   - **User ratings** from gaming sites
   - Note if game is too new for ratings or in Early Access

7. **Present findings** with:
   - Game name
   - **ALWAYS include clickable links** (Steam store page, official website, or source URL)
   - **ALWAYS include ratings** (Metacritic, OpenCritic, Steam reviews, or note if unavailable)
   - Brief description
   - Why it matches preferences
   - Source where found
   - Release date/status (if available)
   - Platform availability

   <!-- markdownlint-disable MD013 -->
   **CRITICAL**: Every game mentioned MUST include at least one clickable link AND ratings information. Use markdown format: `[Game Name](URL)`. Prioritize Steam store links when available, otherwise use official websites or source URLs.
   <!-- markdownlint-enable MD013 -->

## Source Checking Protocol

When checking sources, prioritize by checkFrequency:

- **Daily sources**: Check first (news sites, Steam new releases, Reddit communities)
- **Weekly sources**: Check if doing comprehensive search (YouTube channels, Epic free games)
- **As-needed sources**: Check for specific game details (HowLongToBeat, OpenCritic)

<!-- markdownlint-disable MD013 -->
**Never skip sources** - the sources.json file exists to ensure comprehensive coverage. If a source is unavailable, note it but continue checking others.
<!-- markdownlint-enable MD013 -->

## Rating Requirements

**MANDATORY**: When reporting any game, you MUST search for and include ratings:

1. **Check Metacritic** - Search for "{Game Name} Metacritic" to find critic and user scores
2. **Check OpenCritic** - Search for "{Game Name} OpenCritic" for aggregated review scores
3. **Check Steam Reviews** - Extract from Steam store page:
   - Overall rating (Positive/Very Positive/Overwhelmingly Positive/Mixed/Negative)
   - Percentage of positive reviews
   - Total review count
4. **If ratings unavailable**: Note "Ratings: Not yet available" or "Ratings: Too new/Early Access" with explanation

**Format**: Include ratings in this format:

<!-- markdownlint-disable MD013 -->
- **Ratings**: Metacritic: {score}/100 (Critic), {score}/10 (User) | OpenCritic: {score}/100 | Steam: {rating} ({percentage}% positive, {count} reviews)
<!-- markdownlint-enable MD013 -->

**Never report a game without attempting to find ratings** - ratings help users assess game quality and community reception.

## User Preferences

Based on GAMES.md, user enjoys:

- Survival crafting games (Enshrouded, Valheim, 7D2D, Raft)
- Open world RPGs (Starfield, The Witcher 3, ESO, New World)
- Base building (Satisfactory, Valheim, Enshrouded)
- Exploration (No Man's Sky, Starfield)
- Multiplayer cooperative experiences

When discovering new games, prioritize games that match these characteristics.

## Games to Check Out List

<!-- markdownlint-disable MD013 -->
The skill maintains a separate list of games you want to try out in `game-to-check-out.json`. This file stores comprehensive metadata for each game:
<!-- markdownlint-enable MD013 -->

- **Game name** - Official title
- **Release date** - When the game was released (or Early Access date)
- **Status** - Released, Early Access, Upcoming, etc.
- **Ratings** - Metacritic (critic/user), OpenCritic, Steam reviews (rating, percentage, count)
- **Description** - Brief game description
- **Genres** - Array of genre tags
- **Platforms** - Available platforms (Steam, Epic, GOG, etc.)
- **Price** - Current price (if available)
- **Links** - Steam store page, official website, etc.
- **Developer/Publisher** - Developer and publisher information
- **Why interested** - Why this game matches your preferences
- **Source** - Where you discovered this game
- **Date added** - When you added it to the list (ISO format: YYYY-MM-DD)
- **Notes** - Any additional notes or observations

When adding a game to the checkout list, gather as much metadata as possible:

1. Search for release date, ratings (Metacritic, OpenCritic, Steam), and description
2. Extract genres, platforms, and pricing information
3. Include clickable links (Steam store page preferred)
4. Note why it matches user preferences
5. Record the date added (use current date in YYYY-MM-DD format)

## Workflow

1. Read `GAMES.md` to understand current liked games
2. Read `sources.json` to get source list
3. Check sources systematically based on request
4. Filter and match games to preferences
5. **For each game found, search for ratings** (Metacritic, OpenCritic, Steam reviews)
6. Update `GAMES.md` if adding new liked games
7. Update `game-to-check-out.json` if adding to checkout list (with comprehensive metadata)
8. **Report findings with clear reasoning, ALWAYS include clickable links, and ALWAYS include ratings**

## Link Requirements

**MANDATORY**: When reporting any game, you MUST include clickable links:

- **Steam games**: Use Steam store page URL (e.g., `https://store.steampowered.com/app/{appid}/`)
- **Epic Games Store**: Use Epic store page URL
- **GOG**: Use GOG store page URL
- **Official websites**: Use official game website if no store page available
- **Source URLs**: Include the source URL where the game was discovered

**Format**: Always use markdown links: `[Game Name](URL)`

<!-- markdownlint-disable MD013 -->
**Never report a game without at least one link** - links are essential for users to easily access more information or purchase the game.
<!-- markdownlint-enable MD013 -->

## Examples

- "Check for new survival crafting games" → Report with Steam/store links AND ratings for each game
- "What new games match my preferences?" → Include clickable links AND ratings for all matches
- "Add [Game Name] to my liked games" → Include link and ratings when adding
- "Show me all my liked games" → Include links and ratings for each game in GAMES.md
- "Check Steam for new releases this week" → Report with Steam store links AND ratings

**Remember**: Every game mention requires at least one clickable link AND ratings information (or note if unavailable).
