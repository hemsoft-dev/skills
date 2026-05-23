---
name: github-metrics
description: "V1.2 - Commands: CopilotUsage, PremiumRequests, LegacyMetrics. Reference for GitHub Copilot organization and enterprise usage, billing, and report APIs when you need to find the right metrics endpoint quickly."
compatibility: Requires GitHub Cloud, network access, and org or enterprise owner or billing-manager access for most enterprise metrics endpoints.
metadata:
  author: skills-agent
  version: "1.2"
---

# GitHub Metrics

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Default Behavior

When user activates this skill without specifying an action, first classify the request as one of these:

| Need | Use |
| --- | --- |
| Copilot adoption or feature usage | `CopilotUsage` |
| Premium request cost or billing analytics | `PremiumRequests` |
| Older aggregated active and engaged user metrics | `LegacyMetrics` |

Then return the matching documented endpoint, required scope, and a `gh api` or `curl` example.

## Findings Summary

| Finding | What it means |
| --- | --- |
| The enterprise Premium request analytics page is backed by a documented billing API | Use the billing usage endpoint for spend, SKU, model, user, org, and cost-center filtering |
| Copilot usage reports are exposed through dedicated Copilot usage metrics APIs | Use these for downloadable org and enterprise report files, including user-level reports |
| The older Copilot metrics APIs are legacy | They are still documented, but GitHub says to migrate to usage-metrics endpoints before April 2, 2026 |
| Usage telemetry and billing are separate surfaces | Do not treat Copilot usage report APIs as a replacement for premium request billing totals |
| Organization admins on enterprise-owned orgs cannot always filter premium billing by `user` at org scope | `GET /orgs/{org}/settings/billing/premium_request/usage?...&user=...` can return `403`, even when the org aggregate endpoint works |
| Current-cycle top-consumer ranking only needs two direct API surfaces | Query Copilot seat assignments once, then issue one per-user premium billing query per seat holder and sort by `grossQuantity` |
| CI may have stronger credentials than a local CLI session | That changes which direct API calls will succeed, but it does not change the correct solution: query billing directly instead of scraping workflow output |

## Decision Table

| If the user asks for | Recommended API surface | Typical output |
| --- | --- | --- |
| "Show Copilot usage for the org or enterprise" | `CopilotUsage` | Signed report download links |
| "Show usage by user" | `CopilotUsage` users reports | Signed report download links for user-level usage |
| "Show usage by team" | `CopilotUsage` user-teams + users reports | Join user-teams-1-day with users-1-day, aggregate by team_id |
| "Show premium request spend or overages" | `PremiumRequests` | JSON usage items with quantities and amounts |
| "Show model-level premium request consumption" | `PremiumRequests` | Billing rows filterable by `model` |
| "Show active and engaged users by editor or language" | `LegacyMetrics` | Aggregated daily metrics JSON |

## Commands

### CopilotUsage

Use when the request is about Copilot adoption, feature usage, downloadable usage reports, or user-level usage reports.

| Scope | Endpoint | Returns |
| --- | --- | --- |
| Enterprise, latest 28-day aggregate | `GET /enterprises/{enterprise}/copilot/metrics/reports/enterprise-28-day/latest` | Signed `download_links` plus report date range |
| Enterprise, latest 28-day users | `GET /enterprises/{enterprise}/copilot/metrics/reports/users-28-day/latest` | Signed `download_links` for user-level usage report files |
| Enterprise, specific day aggregate | `GET /enterprises/{enterprise}/copilot/metrics/reports/enterprise-1-day?day={YYYY-MM-DD}` | Signed `download_links` for that day |
| Enterprise, specific day users | `GET /enterprises/{enterprise}/copilot/metrics/reports/users-1-day?day={YYYY-MM-DD}` | Signed `download_links` for that day |
| Enterprise, user-teams daily | `GET /enterprises/{enterprise}/copilot/metrics/reports/user-teams-1-day?day={YYYY-MM-DD}` | Signed `download_links` mapping users to enterprise/business teams |
| Organization, latest 28-day aggregate | `GET /orgs/{org}/copilot/metrics/reports/organization-28-day/latest` | Signed `download_links` plus report date range |
| Organization, latest 28-day users | `GET /orgs/{org}/copilot/metrics/reports/users-28-day/latest` | Signed `download_links` for org user-level usage |
| Organization, specific day aggregate | `GET /orgs/{org}/copilot/metrics/reports/organization-1-day?day={YYYY-MM-DD}` | Signed `download_links` for that day |
| Organization, specific day users | `GET /orgs/{org}/copilot/metrics/reports/users-1-day?day={YYYY-MM-DD}` | Signed `download_links` for that day |
| Organization, user-teams daily | `GET /orgs/{org}/copilot/metrics/reports/user-teams-1-day?day={YYYY-MM-DD}` | Signed `download_links` mapping users to organization teams |

**Important**

1. These endpoints return download links, not the report payload inline.
2. Enterprise reports are available starting from October 10, 2025, with up to one year of history.
3. Enterprise endpoints usually require `manage_billing:copilot` or `read:enterprise` on classic tokens.
4. Organization endpoints usually require `read:org` on classic tokens or `Organization Copilot metrics` read permission on fine-grained tokens.
5. The `user-teams-1-day` report maps users to teams; join with `users-1-day` on `(user_id, day)` then aggregate by `team_id` to produce team-level metrics.
6. Teams with fewer than 5 Copilot-seated users are excluded from user-teams reports (privacy threshold).
7. Users on multiple teams appear in multiple rows — one per `(user, team)` pair. Team totals are not additive.
8. Do NOT join the 28-day user reports with daily user-teams — always join daily-to-daily, then aggregate the window.

**Examples**

```powershell
$enterprise = "hemsoft-corp"
gh api \
  -H "Accept: application/vnd.github+json" \
  "/enterprises/$enterprise/copilot/metrics/reports/enterprise-28-day/latest"

gh api \
  -H "Accept: application/vnd.github+json" \
  "/enterprises/$enterprise/copilot/metrics/reports/users-28-day/latest"
```

```powershell
$org = "fhemmer"
gh api \
  -H "Accept: application/vnd.github+json" \
  "/orgs/$org/copilot/metrics/reports/organization-28-day/latest"

gh api \
  -H "Accept: application/vnd.github+json" \
  "/orgs/$org/copilot/metrics/reports/users-28-day/latest"
```

### PremiumRequests

Use when the request is about premium request cost, quantities, overages, model-level consumption, org-level or user-level billing filters, or cost-center reporting.

| Scope | Endpoint | Filters |
| --- | --- | --- |
| Enterprise premium request billing report | `GET /enterprises/{enterprise}/settings/billing/premium_request/usage` | `year`, `month`, `day`, `organization`, `user`, `model`, `product`, `cost_center_id` |

**Response shape**

| Field | Meaning |
| --- | --- |
| `product` | Product name such as Copilot |
| `sku` | Billing SKU such as Copilot Premium Request |
| `model` | Model name such as GPT-5 |
| `grossQuantity` | Raw measured quantity |
| `discountQuantity` | Included or discounted quantity |
| `netQuantity` | Billable quantity after discounts |
| `grossAmount` | Pre-discount amount |
| `netAmount` | Billed amount after discounts |

**Important**

1. This is the closest documented API match for the enterprise Premium request analytics view.
2. This endpoint is for billing usage, not general Copilot adoption telemetry.
3. Only data from the past 24 months is available.
4. For enterprise scope, you must be an enterprise administrator or billing manager.
5. For enterprise-owned organizations, org-level aggregate calls can succeed while org-level `user=` filtering still returns `403`.
6. The minimum direct ranking strategy is: enumerate current seat holders, query billing once per seat holder, sum `grossQuantity`, then sort descending.

**Example**

```powershell
$enterprise = "hemsoft-corp"
gh api \
  -H "Accept: application/vnd.github+json" \
  "/enterprises/$enterprise/settings/billing/premium_request/usage?year=2026&month=3&product=Copilot&model=GPT-5"
```

```powershell
$enterprise = "hemsoft-corp"
$params = "year=2026&month=3&organization=fhemmer&user=octocat"
gh api \
  -H "Accept: application/vnd.github+json" \
  "/enterprises/$enterprise/settings/billing/premium_request/usage?$params"
```

**Direct script example**

```powershell
.\Scripts\Get-CopilotPremiumTopConsumers.ps1 `
  -Org "relias-engineering" `
  -Enterprise "bertelsmann" `
  -ReportMonth "2026-05" `
  -BillingToken $env:ENTERPRISE_BILLING_TOKEN
```

### LegacyMetrics

Use only when the user explicitly wants the older aggregated active and engaged usage metrics broken down by editor, language, chat, or pull request summary usage.

| Scope | Endpoint |
| --- | --- |
| Enterprise | `GET /enterprises/{enterprise}/copilot/metrics` |
| Enterprise team | `GET /enterprises/{enterprise}/team/{team_slug}/copilot/metrics` |
| Organization | `GET /orgs/{org}/copilot/metrics` |
| Team | `GET /orgs/{org}/team/{team_slug}/copilot/metrics` |

**Important**

1. GitHub says these legacy metrics APIs are closing down on April 2, 2026.
2. Prefer `CopilotUsage` unless the user specifically needs this old response shape.
3. These responses include aggregated daily metrics like active users, engaged users, IDE chat, dotcom chat, and pull request summary activity.

## Access Notes

| Role or token situation | Caveat |
| --- | --- |
| Organization owners | Can use org-level Copilot usage metrics reports, but user-level premium request analytics access is more limited than enterprise owners and billing managers |
| Organization admins on enterprise-owned orgs | Can often read org aggregate premium-request totals, but may get `403` on org-level `user=` filters; exact per-user ranking usually still needs enterprise admin or billing-manager scope |
| Enterprise owners and billing managers | Can access enterprise-level premium request and Copilot usage report APIs |
| Fine-grained PATs | Supported for org usage-metrics endpoints, but not for some enterprise billing endpoints |
| Legacy metrics endpoints | May return `422` if the Copilot metrics API policy is disabled |

## Direct Top-Consumer Query

For "who are the top Copilot premium request consumers right now?", use this direct pattern:

1. Enumerate current seat holders with `GET /orgs/{org}/copilot/billing/seats`
2. Query premium request billing once per seat holder with either:
   - `GET /orgs/{org}/settings/billing/premium_request/usage?...&user={login}` when org-level user filtering is allowed
   - `GET /enterprises/{enterprise}/settings/billing/premium_request/usage?...&user={login}` when enterprise scope is required
3. Sum `grossQuantity` for each user
4. Sort descending and return the top N users

Use `Scripts\Get-CopilotPremiumTopConsumers.ps1` in this skill for that flow. It does not depend on workflow dispatch, committed reports, or HTML parsing.

## Working Rules

1. Always distinguish billing data from usage telemetry before choosing an endpoint.
2. If the user starts from a Premium request analytics page, prefer `PremiumRequests` first.
3. If the user starts from a Copilot adoption or engagement question, prefer `CopilotUsage` first.
4. When the API returns signed `download_links`, tell the user that the second step is downloading the report artifact.
5. When a user asks whether "the same data" is available by API, answer precisely: sometimes yes, but it may be exposed through a different documented surface than the UI page they started from.
6. For current-cycle premium-consumer ranking, prefer the direct billing script over workflow artifacts.

## Sources

1. [REST API endpoints for Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics)
2. [REST API endpoints for Copilot metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics)
3. [Billing usage REST API](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage)
4. [Managing your company's spending on GitHub Copilot](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/manage-and-track-spending/manage-company-spending)
5. [Viewing your usage of metered products and licenses](https://docs.github.com/en/enterprise-cloud@latest/billing/how-tos/products/view-productlicense-use)
6. [GitHub Copilot premium requests](https://docs.github.com/en/enterprise-cloud@latest/billing/concepts/product-billing/github-copilot-premium-requests)
