---
name: copilot-cost
description: "V1.5 - Commands: daily, weekly, monthly, ytd, team. Track GitHub Copilot usage-based billing costs (AI Credits) for Bertelsmann enterprise and Relias-Engineering organization. Reports per-day, per-user, per-team, and per-org spending with budget tracking. June 2026: AI Credits billing is LIVE — billing API now returns native credit data (SKU: 'Copilot AI Credits', unitType: 'ai-credits', pricePerUnit: $0.01). Multiplier estimates only needed for pre-June historical data."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the copilot-cost directory (path contains 'copilot-cost'), verify that history logging occurred.

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
            Before stopping, if copilot-cost was used (check if any files in copilot-cost directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in copilot-cost directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Copilot Cost Tracker

Track GitHub Copilot usage-based billing costs for the **bertelsmann** enterprise, scoped to the **Relias-Engineering** organization.

## Context: Billing Structure

The enterprise billing page (<https://github.com/enterprises/bertelsmann/billing>) shows:

### Cost Components

1. **Copilot Usage** (seat licenses) — $39/seat/month for Enterprise plan (271 seats = ~$10,569/month base)
2. **Copilot Premium Requests** (overage) — $0.04/request ONLY for usage beyond the included allotment
3. **Included allotment** — 1,000 premium requests/user/month (271 × 1,000 = 271,000/month)

### How to Read the Numbers

#### Pre-June 2026 (PRU era — historical data)

- `grossAmount` from API = total premium requests consumed × $0.04 (what it WOULD cost)
- `discountAmount` = amount covered by included allotment (same as gross when within budget)
- `netAmount` = actual overage charge ($0 if within allotment)
- SKU: `Copilot Premium Request`, unitType: `requests`, pricePerUnit: `0.04`

#### June 2026+ (AI Credits era — LIVE)

- `grossAmount` = total AI credits consumed × $0.01
- `discountAmount` = credits covered by included pool
- `netAmount` = overage cost ($0 if within pool)
- **New response fields (verified June 1, 2026):**
  - `sku`: **`Copilot AI Credits`** (was `Copilot Premium Request`)
  - `unitType`: **`ai-credits`** (was `requests`)
  - `pricePerUnit`: **`0.01`** (was `0.04`)
  - `model` field: still present with model-level breakdown
- Enterprise `usage/summary` endpoint also works with: `sku: copilot_ai_unit`, `unitType: ai-units`

### Transition: Token-Based Billing (LIVE as of June 1, 2026)

GitHub Copilot has transitioned from premium request-based billing to **usage-based billing with AI Credits**:

- **1 AI Credit = $0.01 USD**
- Credits are consumed based on token usage (input, output, cached) × model rate
- Code completions and Next Edit Suggestions remain **free** (no credit charge)
- Credits are **pooled** at the billing entity level — light users offset heavy users
- **Enterprise pool confirmed:** 5,369,400 AI Credits (Bertelsmann, Jun 2026)
- Adding licenses mid-cycle increases pool immediately; removing doesn't shrink until next cycle

### Monthly Credit Allotments (Post June 1)

| Plan | Credits/User/Month | Cost/User/Month |
|------|-------------------|-----------------|
| Copilot Business | 1,900 | $19 |
| Copilot Enterprise | 3,900 | $39 |
| **Promotional (Jun–Aug 2026)** | Business: 3,000 / Enterprise: 7,000 | Same |

### What Consumes Credits (Premium Requests today)

- Copilot Chat (IDE, web, mobile)
- Copilot CLI
- Code review agents
- Workspace/Spaces
- Cloud Agent (coding agent)
- Third-party extensions using Copilot API

### What Does NOT Consume Credits

- Code completions (tab suggestions)
- Next Edit Suggestions
- Copilot in pull request summaries (free tier)

### Token Economy Projection Methodology

> **Note (June 2026):** For June+ data, the billing API now returns **actual AI Credit quantities** natively. Multiplier-based estimates are only needed for interpreting pre-June historical data (≤ May 2026).

The script provides a **side-by-side comparison** of current PRU billing vs projected AI Credits billing. For pre-June data where the billing API reported PRUs, the projection uses GitHub's own **model multiplier changes** as the conversion factor:

**Formula:**

```
actual_requests = grossQuantity / current_multiplier
ai_credits = actual_requests × new_multiplier
ai_credit_cost = ai_credits × $0.01
```

**Rationale:** GitHub set the new multipliers (effective June 1, 2026) based on their internal data about average token consumption per model. The new multiplier directly represents the expected AI Credit cost per interaction. This makes the projection authoritative — it's GitHub's own estimate.

**Key Model Multiplier Changes (Current → June 1):**

| Model | Current Mult | New Mult | Impact |
|-------|-------------|----------|--------|
| Claude Opus 4.6 | 3× | 27× | 9× more expensive |
| Claude Opus 4.7 | 15× | 27× | 1.8× more expensive |
| Claude Sonnet 4.6 | 1× | 9× | 9× more expensive |
| Claude Sonnet 4.5 | 1× | 6× | 6× more expensive |
| GPT-5.3-Codex | 1× | 6× | 6× more expensive |
| GPT-5.4 | 1× | 6× | 6× more expensive |
| GPT-5.5 | 1× | 15× | 15× more expensive |
| Claude Haiku 4.5 | 0.33× | 0.33× | No change |
| Gemini 2.5 Pro | 1× | 1× | No change |

**Auto model selection:** Gets 10% discount on multipliers (e.g., Claude Sonnet 4.6 Auto = 8.1× instead of 9×).

**Budget comparison:**

- Current: 271 seats × 1,000 PRUs = **271,000 PRU/month** allotment
- Token economy: 271 seats × 3,900 credits = **1,056,900 AI Credits/month** allotment
- Promotional (Jun–Aug): 271 seats × 7,000 = **1,897,000 AI Credits/month**

### Per-Token Pricing Reference (per 1M tokens)

**IMPORTANT: Cached input tokens are a SUBSET of total input tokens, not additive.**
The correct cost formula is: `(totalInput - cached) × inputRate + cached × cachedRate + output × outputRate`.
Anthropic models also incur a separate **cache write** cost when new context is written to cache.

| Model | Input | Cached Input | Cache Write | Output | Category |
|-------|-------|--------------|-------------|--------|----------|
| GPT-4.1 | $2.00 | $0.50 | — | $8.00 | Versatile |
| GPT-5 mini | $0.25 | $0.025 | — | $2.00 | Lightweight |
| GPT-5.2 / 5.2-Codex / 5.3-Codex | $1.75 | $0.175 | — | $14.00 | Powerful |
| GPT-5.4 | $2.50 | $0.25 | — | $15.00 | Versatile |
| GPT-5.4 mini | $0.75 | $0.075 | — | $4.50 | Lightweight |
| GPT-5.4 nano | $0.20 | $0.02 | — | $1.25 | Lightweight |
| GPT-5.5 | $5.00 | $0.50 | — | $30.00 | Powerful |
| Claude Haiku 4.5 | $1.00 | $0.10 | $1.25 | $5.00 | Versatile |
| Claude Sonnet 4/4.5/4.6 | $3.00 | $0.30 | $3.75 | $15.00 | Versatile |
| Claude Opus 4.5/4.6/4.7 | $5.00 | $0.50 | $6.25 | $25.00 | Powerful |
| Gemini 2.5 Pro | $1.25 | $0.125 | — | $10.00 | Powerful |
| Gemini 3 Flash | $0.50 | $0.05 | — | $3.00 | Lightweight |
| Gemini 3.1 Pro | $2.00 | $0.20 | — | $12.00 | Powerful |
| Grok Code Fast 1 | $0.20 | $0.02 | — | $1.50 | Lightweight |

*Source: <https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing>*

## Default Behavior

When activated without specifying a command, run **daily** for the current date scoped to `Relias-Engineering`.

## Prerequisites

- Authenticated via `gh auth login` with an account that has **org owner** or **billing manager** permissions
- Organization: `Relias-Engineering` (within bertelsmann enterprise)
- Enterprise: `bertelsmann`
- Required token scopes for org-level: `admin:org`, `copilot`
- Optional for per-user: `admin:enterprise` (used by org-metrics repo via separate EnterpriseBillingToken)

## Commands

### daily

Report today's Copilot credit consumption for Relias-Engineering.

```powershell
# Today (default)
.\scripts\Get-CopilotCost.ps1 -Period Daily

# Specific date
.\scripts\Get-CopilotCost.ps1 -Period Daily -Date "2026-05-01"

# Previous day
.\scripts\Get-CopilotCost.ps1 -Period Daily -Previous
```

### weekly

Report the last 7 days of Copilot credit consumption.

```powershell
# Current week (last 7 days from today)
.\scripts\Get-CopilotCost.ps1 -Period Weekly

# Previous week
.\scripts\Get-CopilotCost.ps1 -Period Weekly -Previous
```

### monthly

Report the current month's Copilot credit consumption.

```powershell
# Current month (default)
.\scripts\Get-CopilotCost.ps1 -Period Monthly

# Previous month
.\scripts\Get-CopilotCost.ps1 -Period Monthly -Previous

# Specific month
.\scripts\Get-CopilotCost.ps1 -Period Monthly -Year 2026 -Month 5
```

### ytd

Report year-to-date Copilot credit consumption.

```powershell
# Current year-to-date
.\scripts\Get-CopilotCost.ps1 -Period YTD

# Specific year
.\scripts\Get-CopilotCost.ps1 -Period YTD -Year 2026
```

### team

Report Copilot usage metrics broken down by team. Joins the `user-teams-1-day` NDJSON report with `users-1-day` to produce per-team aggregates.

```powershell
# Yesterday (default — latest available data)
.\scripts\Get-CopilotTeamMetrics.ps1

# Specific day
.\scripts\Get-CopilotTeamMetrics.ps1 -Day "2026-05-20"

# 7-day rolling window
.\scripts\Get-CopilotTeamMetrics.ps1 -Window 7

# 28-day rolling window, filter to one team
.\scripts\Get-CopilotTeamMetrics.ps1 -Window 28 -Team "platform-engineering"

# Raw JSON output for downstream processing
.\scripts\Get-CopilotTeamMetrics.ps1 -Window 7 -Raw
```

**Output includes per team:**

| Metric | Description |
|--------|-------------|
| Active Users | Distinct users with any Copilot usage in the period |
| Chat Users | Distinct users who used Copilot Chat |
| Agent Users | Distinct users who used Copilot Agent |
| CLI Users | Distinct users who used Copilot CLI |
| Interactions | Total user-initiated interactions |
| Code Generations | Code generation activity count |
| Accept Rate | Code acceptance / code generation percentage |
| LOC Added | Lines of code added from Copilot suggestions |

**Important notes:**

- Users on multiple teams are counted in EACH team — team totals are NOT additive
- Teams with fewer than 5 Copilot-seated users are excluded by the API (privacy threshold)
- For multi-day windows, distinct-user counts are deduplicated across the full window
- Data is typically available after midnight UTC for the previous day

## API Reference

### Working Endpoints (Verified)

| Endpoint | Purpose | Era |
|----------|---------|-----|
| `GET /orgs/Relias-Engineering/settings/billing/premium_request/usage?year={Y}&month={M}` | Monthly usage by model (PRU for ≤May, AI Credits for Jun+) | Both |
| `GET /orgs/Relias-Engineering/settings/billing/premium_request/usage?year={Y}&month={M}&day={D}` | Daily usage by model | Both |
| `GET /enterprises/bertelsmann/settings/billing/premium_request/usage?year={Y}&month={M}&day={D}` | Enterprise-level daily usage by model (also supports `&organization=` and `&user=` filters) | Both |
| `GET /enterprises/bertelsmann/settings/billing/usage/summary?year={Y}&month={M}&product=Copilot` | Enterprise AI Credit usage summary (aggregate, no model breakdown) | Jun+ |
| `GET /enterprises/bertelsmann/settings/billing/usage/summary?year={Y}&month={M}&product=Copilot&organization=Relias-Engineering` | Org-scoped AI Credit usage summary via enterprise endpoint | Jun+ |
| `GET /orgs/Relias-Engineering/settings/billing/usage` | ALL billing (Actions, Copilot, LFS, Packages) | Both |
| `GET /orgs/Relias-Engineering/copilot/billing` | Seat breakdown (total, active, inactive) | Both |
| `GET /orgs/Relias-Engineering/copilot/billing/seats` | Per-user seat assignments + last activity | Both |

### NDJSON Metrics Endpoints (Verified — API Version 2026-03-10)

These return `download_links` to Azure-hosted NDJSON files with rich per-user/org metrics.

| Endpoint | Purpose |
|----------|---------|
| `GET /orgs/Relias-Engineering/copilot/metrics/reports/users-1-day?day={YYYY-MM-DD}` | Per-user daily metrics (120+ records) — includes CLI token counts |
| `GET /orgs/Relias-Engineering/copilot/metrics/reports/organization-1-day?day={YYYY-MM-DD}` | Org-level daily aggregate — includes CLI token totals |
| `GET /orgs/Relias-Engineering/copilot/metrics/reports/users-28-day/latest` | Per-user 28-day rolling window |
| `GET /orgs/Relias-Engineering/copilot/metrics/reports/user-teams-1-day?day={YYYY-MM-DD}` | User-to-team mapping for the day — join with users-1-day for team metrics |

**CRITICAL**: The URL pattern is `organization-1-day` NOT `org-1-day`.

**Token Data Availability:**

- **CLI users**: `totals_by_cli.token_usage` has `prompt_tokens_sum`, `output_tokens_sum`, `avg_tokens_per_request`
- **IDE/Chat/Agent**: `totals_by_model_feature` has model + feature + interaction counts — **NO token data**
- **No cached token counts** anywhere in the NDJSON API — cost estimates from NDJSON token data treat all prompt tokens at full input rate (slight overcount when caching is active)
- **June 2026+**: Billing API (`premium_request/usage`) now returns actual AI Credit quantities per model — use this instead of multiplier estimates

**NDJSON Model Name Mapping** (internal → display):

| Internal | Display |
|----------|---------|
| `claude-opus-4.6` | Claude Opus 4.6 |
| `claude-4.6-sonnet` | Claude Sonnet 4.6 |
| `claude-4.5-haiku` | Claude Haiku 4.5 |
| `auto` | Auto (10% discount) |

### Per-User (Requires Enterprise Token with admin:enterprise)

| Endpoint | Purpose |
|----------|---------|
| `GET /enterprises/bertelsmann/settings/billing/premium_request/usage?user={login}&year={Y}&month={M}` | Per-user premium request consumption |

**Note**: Per-user filtering via the org endpoint is explicitly blocked for enterprise-owned organizations. The org-metrics repo handles this with a dedicated `EnterpriseBillingToken`.

### Required Headers

```
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2026-03-10      # All endpoints (billing + NDJSON metrics)
```

**Note:** As of June 2026, the `2026-03-10` API version works for both billing and metrics endpoints. The older `2022-11-28` version still works for billing but is no longer required.

## Environment Defaults

```
ENTERPRISE = bertelsmann
ORGANIZATION = Relias-Engineering
API_VERSION = 2026-03-10
PRICE_PER_CREDIT = $0.01             # 1 AI Credit = $0.01 USD (June+ billing)
PRICE_PER_REQUEST = $0.04            # Legacy PRU rate (≤May 2026 data only)
```

**Important**: We are ONLY authorized to query the `Relias-Engineering` organization. Do not query other organizations within the bertelsmann enterprise.

## Output Format

Reports display:

1. **Summary header** — period, org, total PRU cost + multiplier-estimated AI Credits
2. **Model breakdown** — per-model PRU vs AI Credit comparison with multiplier changes
3. **Actual CLI token data** (Daily only) — real prompt/output token counts per CLI user from NDJSON
4. **Model × Feature interactions** (Daily only) — interaction counts per model per feature for all users
5. **Budget status** — credits consumed vs allotment, percentage used (both PRU and AI Credit)
6. **Projections** — estimated end-of-month spend at current rate

## Script Reference

| Script | Purpose |
|--------|---------|
| `Get-CopilotCost.ps1` | Main reporting script — handles all period queries with dual PRU/AI Credits comparison |
| `Get-CopilotTeamMetrics.ps1` | Team-level usage metrics — joins user-teams with per-user data, supports rolling windows |

## Important Notes

- Data availability: Reports are generated daily and available starting from October 10, 2025. Historical data up to 24 months.
- The billing usage API returns data in USD.
- Credits not consumed in a month do **not** roll over.
- Overage beyond the monthly allotment incurs additional charges at the same rate ($0.01/credit).
- The promotional period (Jun–Aug 2026) provides extra credits at no additional cost.
- **June+ billing data**: `grossQuantity` from API = actual AI Credits consumed. No multiplier conversion needed.
- **Pre-June billing data**: Still uses multiplier-based estimates (grossQuantity was PRU × old multiplier).
- **CLI token actuals**: Real `prompt_tokens_sum` and `output_tokens_sum` from NDJSON metrics for CLI users only (~7% of users but significant cost).
- **IDE/chat/agent**: Token counts NOT available in NDJSON — only interaction counts per model/feature.
- **10% auto-model discount**: Users selecting "auto" model get 10% off credit consumption rates.
- NDJSON report files are line-delimited JSON — each line is an independent record.
- NDJSON download links are Azure blob URLs that expire; they must be fetched fresh each time.
- **Enterprise pool total (Jun 2026)**: 5,369,400 AI Credits (all orgs combined, promotional rate).

## Token/Credit Data Availability (Updated June 1, 2026)

### The Current Reality (June 2026+)

| Source | What You Get | Full Credit Data? | Programmatic? |
|--------|-------------|-------------------|---------------|
| **Billing API** (`premium_request/usage`) | AI Credit quantities by model | ✅ Yes — `grossQuantity` = credits consumed | ✅ Yes |
| **Enterprise `usage/summary`** | AI Credit totals (aggregate) | ✅ Yes — aggregate credits | ✅ Yes |
| **NDJSON Metrics** (`users-1-day`) | Per-user metrics | ⚠️ CLI only (prompt + output tokens) | ✅ Yes |
| **CSV Download** (billing UI → "Get usage report") | Full usage report | ✅ Complete | ❌ Email delivery only |
| **AI Usage Dashboard** (enterprise web UI) | Pool gauge + model breakdown | ✅ Live visualization | ❌ Manual only |

### API Response Example (June 2026)

**`premium_request/usage` — model-level detail:**

```json
{
  "sku": "Copilot AI Credits",
  "model": "Claude Opus 4.6",
  "unitType": "ai-credits",
  "pricePerUnit": 0.01,
  "grossQuantity": 155.847275,
  "grossAmount": 1.55847275,
  "discountQuantity": 155.847275,
  "discountAmount": 1.55847275,
  "netQuantity": 0.0,
  "netAmount": 0.0
}
```

**`usage/summary` — aggregate view:**

```json
{
  "sku": "copilot_ai_unit",
  "unitType": "ai-units",
  "pricePerUnit": 0.01,
  "grossQuantity": 155.847275
}
```

### Key Differences: Pre-June vs Post-June API Responses

| Field | ≤ May 2026 (PRU) | June 2026+ (AI Credits) |
|-------|-------------------|-------------------------|
| `sku` | `Copilot Premium Request` | `Copilot AI Credits` |
| `unitType` | `requests` | `ai-credits` |
| `pricePerUnit` | `0.04` | `0.01` |
| `grossQuantity` | PRU count (multiplied) | AI Credit count (actual consumption) |
| `model` | ✅ Present | ✅ Present |
| Multiplier needed? | Yes (to estimate true cost) | No (values are native credits) |

### Important: Script Implications

- **June+ data**: `grossQuantity` from `premium_request/usage` IS the AI Credit count directly — no multiplier conversion needed
- **Pre-June data**: Still needs multiplier conversion (grossQuantity was PRU × old multiplier)
- The `usage/summary` endpoint provides enterprise-wide aggregate but NO model breakdown
- The `premium_request/usage` endpoint provides model-level breakdown — preferred for reporting

### Endpoints Confirmed NOT Working (Tested May 2, 2026 — may need retesting)

These returned 404 in May — status unknown post-June transition:

- `/orgs/{org}/settings/billing/ai-credits`
- `/orgs/{org}/settings/billing/credit/usage`
- `/orgs/{org}/settings/billing/premium_request/report`
- `/orgs/{org}/copilot/billing/usage`
- `/enterprises/{ent}/settings/billing/metered/reports`
