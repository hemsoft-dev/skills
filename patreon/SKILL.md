---
name: patreon
description: V1.1 - Manage HemSoft Developments Patreon page, generate posts, track patrons/tiers, and interact with the Patreon API.
---

# Patreon

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Manage the HemSoft Developments Patreon creator account.

## Account Info

| Field | Value |
|-------|-------|
| Creator Name | HemSoft Developments |
| Email | <fphemmer@gmail.com> |
| URL | <https://www.patreon.com/c/HemSoft> |
| Dashboard | <https://www.patreon.com/dashboard> |

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Capabilities

### Content Creation

Generate Patreon posts with:

- Engaging titles and descriptions
- Appropriate tier visibility settings
- Tags and categories
- Embedded media suggestions

**Post Template:**

```markdown
# {Title}

{Hook - 1-2 sentences to grab attention}

{Main content}

{Call-to-action}

---
Tier: {Public | Patron-only | Tier Name}
Tags: {comma-separated}
```

### Tier Management

Track and suggest membership tiers:

| Tier | Price | Benefits |
|------|-------|----------|
| Free | $0 | Public posts, community access |
| Supporter | $3-5 | Early access, patron-only posts |
| Premium | $10+ | All above + exclusive content, direct support |

### Patreon API

**Base URL:** `https://www.patreon.com/api/oauth2/v2`

**Key Endpoints:**

- `GET /identity` - Current user info
- `GET /campaigns` - Creator's campaigns
- `GET /campaigns/{id}/members` - Patron list
- `GET /campaigns/{id}/posts` - Published posts

**Authentication:** OAuth2 with Creator Access Token

**Example - Get Campaign Stats:**

```bash
curl -H "Authorization: Bearer {ACCESS_TOKEN}" \
  "https://www.patreon.com/api/oauth2/v2/campaigns/{CAMPAIGN_ID}?fields[campaign]=patron_count,creation_name,pledge_sum"
```

### Analytics & Reporting

Track key metrics:

- Patron count and growth
- Monthly revenue (pledge_sum)
- Post engagement
- Tier distribution

## Quick Actions

| Action | Command |
|--------|---------|
| Draft a post | "Write a Patreon post about {topic}" |
| Check stats | "Get my Patreon stats" (requires API token) |
| Suggest content | "What should I post on Patreon?" |
| Review tiers | "Help me optimize my Patreon tiers" |

## Resources

- [Creator Dashboard](https://www.patreon.com/dashboard)
- [Patreon API Docs](https://docs.patreon.com/)
- [Creator Best Practices](https://www.patreon.com/creator-toolkit)
