# AI Chapter Foundation: Skills from Scratch

## Meeting Details

- **Title**: Building Your First AI Skills: From Zero to Hero
- **Date & Time**: Wednesday, February 5, 2026 at 3:00 PM EST
- **Host**: Franz Hemmer
- **Audience**: AI Foundation Chapter members - beginner-friendly, all skill levels welcome
- **Skill Level**: 100 (Introductory) - Assumes little or no expertise with AI skills

## Observations

This session aims to showcase the transformative power of AI skills by starting completely fresh with a clean Visual Studio Code installation. The goal is to inspire participants by demonstrating practical, real-world use cases that solve actual problems they face daily.

## Presentation Flow

1. **Clean slate demonstration** - Start with fresh VS Code
2. **Skill Creator** - The gateway skill that enables everything else
3. **Meeting Prep** - Practical example everyone can relate to
4. **Advanced Skills** - Show what's possible with more complex integrations

## Preparation Tasks

| Task | Status | Resources | Notes |
|------|--------|-----------|-------|
| Set up clean VS Code environment | ✗ | [VS Code Download](https://code.visualstudio.com/) | Fresh install to demonstrate "from scratch" experience |
| Prepare skill-creator demonstration | ✗ | [Agent Skills Spec](https://agentskills.io/specification) | Show how to create first skill, explain frontmatter and structure |
| Create meeting-prep skill live demo | ✗ | [Microsoft Skill Levels](https://learn.microsoft.com/en-us/archive/blogs/ieitpro/microsofts-standard-level-definitions-100-to-400) | Walk through creating the meeting-preparation skill as live example |
| Prepare Slack search skill showcase | ✗ | [Slack Web API](https://api.slack.com/web) | Demonstrate searching channels, DMs, retrieving messages with context |
| Prepare GitHub PR creation demo | ✗ | [GitHub REST API](https://docs.github.com/en/rest) | Show creating issues, pull requests, managing repos programmatically |
| Prepare Confluence search showcase | ✗ | [Confluence REST API](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/) | Demonstrate searching spaces, retrieving pages, accessing documentation |
| Test all demo flows end-to-end | ✗ | [VS Code Skills Extension](https://marketplace.visualstudio.com/items?itemName=AnthropicPBC.claude-skills) | Ensure smooth transitions between demonstrations |
| Prepare inspiring use case stories | ✗ | - | Real examples: meeting prep saves 30min per meeting, Slack search finds lost context, GitHub automation eliminates repetitive tasks |

## Key Messages to Convey

### Why Skills Matter

Skills transform AI assistants from general helpers into domain experts. They enable AI tools such as VSCode & GitHub Copilot to understand your specific workflows, tools, and context without repeated explanations.

### The Power of Starting Simple

- **Skill Creator**: Meta-skill that teaches GitHub Copilot how to create more skills
- **Meeting Prep**: Immediate value - everyone attends meetings and needs preparation
- **Progressive Complexity**: Start simple, build confidence, then tackle advanced integrations

### Advanced Capabilities Preview

- **Slack Integration**: Never lose track of important conversations again
- **GitHub Automation**: Reduce repetitive PR/issue creation tasks
- **Confluence Search**: Find documentation faster than manual browsing
- **Composable Skills**: Skills can call other skills for powerful workflows

## Demo Script Outline

### Part 1: The Foundation (8 minutes)

1. Show clean VS Code installation
2. Create `.claude/skills/` directory structure
3. Introduce SKILL.md format and frontmatter

### Part 2: Skill Creator (12 minutes)

1. Create `skill-creator` skill live
2. Explain version prefixes, descriptions
3. Show history tracking with hooks
4. Demonstrate using skill-creator to make another skill

### Part 3: Meeting Prep (10 minutes)

1. Use skill-creator to build meeting-preparation skill
2. Show meeting.json template
3. Create a sample meeting prep (meta: prep for this meeting!)
4. Demonstrate checklist, resource gathering, readiness assessment

### Part 4: Advanced Skills Showcase (10 minutes)

1. **Slack Search**: Search for past conversations, retrieve thread context
2. **GitHub**: Create issue, generate PR with proper formatting
3. **Confluence**: Search documentation, retrieve page content
4. Show how these save hours of manual work

### Part 5: Q&A and Inspiration (5 minutes)

- What problems could skills solve for you?
- What workflows could be automated?
- What domain knowledge could be captured?

## Success Metrics

- Participants understand what skills are and why they matter
- At least 3 participants express interest in creating their own skills
- Clear takeaway: "I could use this for [specific use case]"
- Excitement about the technology, not fear or confusion

## Follow-up Resources

Prepare these for sharing after the meeting:

- Link to Agent Skills specification: <https://agentskills.io>
- Your personal skills repository (if public/shareable)
- Getting started guide document
- Slack channel for continued discussion
- Office hours schedule for skill creation help
