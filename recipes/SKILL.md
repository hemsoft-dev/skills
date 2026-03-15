---
name: recipes
description: V1.1 - Expert in recipes and recipe management. Stores and manages personal recipe collection with detailed metadata, beautiful markdown formatting, and image support. Use when the user wants to add, view, search, or manage recipes.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the recipes directory (path contains 'recipes'), verify that history logging occurred.
            
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
            Before stopping, if recipes was used (check if any files in recipes directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in recipes directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Recipes

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert in recipes and recipe management. Manages a personal recipe collection with comprehensive metadata, beautiful
markdown formatting, and image support.

## Recipe Structure

Each recipe is stored in its own folder under `collection/` with the following structure:

```text
collection/
└── {recipe-slug}/          # Folder name: kebab-case slug, max 96 characters
    ├── RECIPE.md           # Always named RECIPE.md
    ├── recipe-image.jpg    # Main recipe image (optional)
    ├── step-1.jpg          # Step images (optional)
    ├── step-2.jpg
    └── video.mp4           # Videos or other resources (optional)
```

The `RECIPE.md` file follows this structure:

```markdown
# {Recipe Name}

{Description}

![{Recipe Name}](recipe-image.jpg)

## Metadata

- **Author**: {author}
- **Source**: {source.name} {source.url if available}
- **Cuisine**: {recipeCuisine}
- **Category**: {recipeCategory}
- **Difficulty**: {difficulty}
- **Servings**: {recipeYield}
- **Prep Time**: {prepTime}
- **Cook Time**: {cookTime}
- **Total Time**: {totalTime}
- **Status**: {status}
- **Ratings**: {ratings array - show latest rating or average if multiple}
- **Tags**: {tags.join(', ')}
- **Dietary**: {suitableForDiet.join(', ')}
- **Date Added**: {dateAdded}
- **Date Modified**: {dateModified}

## Ingredients

{Formatted ingredient list with quantities}

## Instructions

{Numbered step-by-step instructions with optional step images}

## Nutrition

{If available: calories, protein, fat, carbs, etc.}

## Notes

{Personal notes, variations, modifications}

## Variations

{If available: documented variations}
```

## Recipe Schema

All recipes follow the schema defined in `recipe.json` at the root of the skill. The schema includes:

- **Core**: name, description, image(s), author, source
- **Timing**: prepTime, cookTime, totalTime (ISO 8601 format: PT15M, PT1H30M)
- **Ingredients**: recipeIngredient array (strings or structured objects)
- **Instructions**: recipeInstructions array (strings or HowToStep objects with images)
- **Classification**: recipeCuisine, recipeCategory, tags, difficulty
- **Dietary**: suitableForDiet array
- **Nutrition**: nutrition object with calories, macros, etc.
- **Personal**: ratings (array of date/time + rating 1-5), status (want-to-try/made/liked/favorite), dates, notes, variations

## Best Practices

1. **Folder Structure**: Each recipe gets its own folder under `collection/` with a kebab-case slug name (max 96 characters)
2. **File Naming**: The recipe markdown file is always named `RECIPE.md` (uppercase) within each recipe folder
3. **Images & Resources**: Store images, videos, and other resources directly in the recipe folder and reference them
   relative to `RECIPE.md` (e.g., `recipe-image.jpg`, `step-1.jpg`, `video.mp4`)
4. **Metadata**: Always include name, ingredients, and instructions (required fields)
5. **Formatting**: Use consistent markdown formatting for readability
6. **Status**: Track recipe status (want-to-try, made, liked, favorite)
7. **Ratings**: Track each time the recipe is made with date/time and rating (1-5 stars: 1=bad, 5=great)
8. **Variations**: Document successful modifications in variations section
9. **ISO 8601 Durations**: Use format like `PT15M` (15 minutes), `PT1H30M` (1 hour 30 minutes)

## Folder Naming

Recipe folders should use kebab-case slugs derived from the recipe name, truncated to a maximum of 96 characters. Examples:

- `chocolate-chip-cookies`
- `grandmas-famous-meatloaf`
- `quick-weeknight-pasta-with-tomato-and-basil`

## Preferences

When suggesting recipes or adding new ones to the collection, consider these preferences:

### Rebecca

**Likes:**

- Mediterranean food
- Vinegar
- Apples
- Mexican cuisine
- Italian cuisine
- Pizza (especially good calzones)
- Warm breakfast with eggs over medium and ham and potato scramble

**Dislikes:**

- Seafood in general
- Olives

### Franz

**Likes:**

- Filet Mignon
- Mexican cuisine
- Italian cuisine
- Yellow curry dishes
- Danish cuisine
- Fresh bread
- Danish pancakes/crepes

**Dislikes:**

- Limited seafood (prefers minimal seafood)
- Olives

**Note:** When searching for or recommending recipes, prioritize options that align with these preferences. Both enjoy
Mexican and Italian cuisines, making those excellent choices for shared meals. Both dislike olives, so recipes
containing olives should be modified to substitute with alternatives like black beans, capers, or simply omitted.

## When to Use

- Add a new recipe to the collection
- View or search recipes
- Update recipe metadata or notes
- Rate or update recipe status
- Create recipe variations
- Generate recipe summaries or lists
- Search for recipes matching personal preferences
