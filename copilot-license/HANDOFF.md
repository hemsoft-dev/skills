# Copilot License — Premium Request Investigation Handoff

## Context

The `Get-InactiveCopilotUsers.ps1 -Enterprise bertelsmann` script found **11 users with zero premium
requests** out of 212 active Copilot seats. The org metrics report (from **relias-engineering/org-metrics**)
shows significantly more users with zero premium requests in the "Bottom 50 Least Active Users" table.

## Bug Found: `relias-engineering/org-metrics` → `scripts/Get-CopilotMetrics.ps1`

### The Bug (line 253)

```powershell
# CURRENT (buggy) — only queries users who appear in usage-metrics user-day reports
$activeLogins = @($userUsageTotals.Keys | Sort-Object)
```

`$userUsageTotals` is populated from **Copilot usage-metrics API user-day report rows** (lines 219–227).
Users who have a seat but zero usage-metrics activity are NOT in this hash table, so they **never get
queried** for premium requests via the enterprise billing API.

At line 425, unqueried users default to `0`:

```powershell
$premium = if ($userPremiumReqs.ContainsKey($s.Login)) { $userPremiumReqs[$s.Login] } else { 0 }
```

This means the "Bottom 50" table shows `0` premium requests for users who may actually have usage — they
just weren't in the usage-metrics report, so they never got checked.

### The Fix (line 253)

```powershell
# FIXED — query ALL seat holders, not just those in usage reports
$activeLogins = @($seatList | ForEach-Object { $_.Login } | Sort-Object -Unique)
```

`$seatList` is built from the Copilot billing/seats API at line 384–396 and contains every assigned seat.
This ensures every seat holder gets queried for premium requests via the enterprise billing endpoint.

### Impact

- All ~231 seat holders will be queried (vs only those with usage-metrics activity)
- The "Bottom 50 Least Active Users" table will show accurate premium request counts
- Users with true zero premium requests will be distinguishable from unqueried users
- API call count increases (queries all seats instead of just active ones), but this is the correct behavior

## Verification Data

Spot-checked 7 users the report showed as "0 premium requests" against the live enterprise billing API:

| User | Report Shows | Enterprise Billing API (`grossQuantity`) |
|---|---|---|
| hscheibner-relias | 0 | **207** |
| cyeung-relias | 0 | **49** |
| ShilpaAmbardekar | 0 | **37** |
| hbheemavarapu | 0 | **9** |
| JackCornblum | 0 | **8** |
| gdecherney-relias | 0 | **5** |
| khushboo-raghani | 0 | **0** (truly zero) |

6 of 7 actually DO have premium request usage. Only `khushboo-raghani` is truly zero.

## Key Facts

- Repo: `relias-engineering/org-metrics`
- Bug file: `scripts/Get-CopilotMetrics.ps1` (708 lines), line 253
- Workflow: `.github/workflows/copilot-metrics.yml` — passes `-Enterprise "bertelsmann"` correctly
- Enterprise slug: `bertelsmann`
- Billing API: `GET /enterprises/bertelsmann/settings/billing/premium_request/usage`
- Correct quantity field: `grossQuantity` (NOT `netQuantity`)
- `$seatList` is populated at lines 384–396 from Copilot billing/seats API
