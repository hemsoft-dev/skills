# Goal

Help the user create a new skill by using the skill-creator skill to create the skill the user wants to create.

## Variables

- `{skill-name}` - The name of the skill to create (e.g., "my-new-skill"). This will be used as the directory name and skill identifier.

## Parameters

When invoking this command, you can specify:

- **skill-name**: The name for the new skill (required). Use kebab-case (e.g., "my-new-skill").

## Codebase Structure

Insert the skill at the user level: ~/.claude/skills/{skill-name} unless the user asks to have the skill created in their repo.

## Instructions

Follow the guidance in the skill-creator skill.

## Report

Concisely report back where the skill was created and recommendations for improvements if you have any.
