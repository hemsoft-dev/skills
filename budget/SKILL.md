---
name: budget
description: V1.2 - Extracts and reports on bank/credit account statements with confirmed tracking for Subscriptions and Utility Bills.
triggers:
  - subscriptions
  - subs
  - utilities
  - utility bills
  - recurring charges
  - monthly expenses
  - what am I paying for
  - budget
  - bank statements
---

# Budget Statement Analyzer

Extract transactions from bank statement PDFs, normalize with AI-assigned categories, and generate budget reports.

## Tracking Capabilities

This skill maintains **confirmed tracking** for two expense categories:

1. **Subscriptions** - Streaming services, software, memberships, etc.
2. **Utility Bills** - Electricity, water, gas, internet, phone, etc.

Both tracking files register only **confirmed entries** manually verified by the user.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Quick Commands

| User Says | Action |
|-----------|--------|
| "list my subs" / "subscriptions" / "what am I paying for" | Read `confirmed-subscriptions.md` and display active vs cancelled |
| "list my utilities" / "utility bills" | Read `confirmed-utilities.md` and display confirmed utility bills |
| "run subscription report" | Execute `subscriptions-report.ps1` |
| "extract statements" | Run `extract-usaa.py` for each account |
| "budget report" | Execute `statement-report.ps1` |

### List Subscriptions (Most Common)

**File**: `c:\Users\franz\.claude\skills\budget\tracking\confirmed-subscriptions.md`

Just read this file and present it. No scripts needed. Summarize:
- Active subscriptions with renewal dates
- Recently cancelled (still have access until expiry)
- Monthly/annual cost totals
- Any flagged items (⚠️)

### List Utility Bills

**File**: `c:\Users\franz\.claude\skills\budget\tracking\confirmed-utilities.md`

Read this file to show confirmed utility providers, account numbers, and typical billing amounts.

## 🚨 WATCHLIST - CHECK FIRST

**CRITICAL**: Before any budget analysis, search for these flagged vendors in new statements:

| Vendor Pattern | Reason | Action |
|----------------|--------|--------|
| `CONDENAST` | Unverified $11.99 charge (Feb 2025). Unknown source - possibly duplicate New Yorker subscription | Report ANY new charges immediately. Call 1-855-680-3077 to investigate. |
| `DOMINION ENERGY` | High, irregular ACH drafts (e.g., $764.26 on 12/09/2025). Possible legacy/second property auto-pay. | Alert immediately with date/amount/account; verify service address and cancel if legacy. |
| `DUKE ENERGY` | Multiple ACH payments for separate service address (e.g., $97.48 on 12/22/2025; acct #910185995089, 273 Rose St, Mooresville NC). | Alert immediately with date/amount/account; confirm active service vs. legacy and stop duplicate auto-pay. |

### Watchlist Check Command
```powershell
python "c:\Users\franz\.claude\skills\budget\scripts\search-pdfs.py" "CONDENAST"
```

If new CONDENAST charges found:
1. **Alert the user immediately** with date, amount, and description
2. Compare against confirmed subscriptions ($169/year New Yorker renewal expected ~Feb 2026)
3. Any charge other than the expected renewal is suspicious

---

## Capabilities

| Feature | Description |
|---------|-------------|
| **Extract** | Pull transactions from bank statement PDFs |
| **Normalize** | AI-categorize transactions in batches |
| **Report** | Generate combined budget report |
| **Subscriptions** | Deep-dive analysis of recurring expenses |

## Data Location

```
F:\OneDrive\Documents\Budget\Statements\
├── category-choices.txt      # 34 categories for AI
├── budget-report.md          # Combined report output
├── subscriptions-report.md   # Subscription analysis output
├── {AccountName}/
│   ├── 2025/
│   │   ├── *.pdf             # Source statements
│   │   └── all_transactions.csv  # Extracted transactions
│   └── YYYY-MM.csv           # Normalized monthly CSVs

Skill Location:
c:\Users\franz\.claude\skills\budget\
├── tracking/                        # Confirmed manual tracking
│   ├── confirmed-subscriptions.md   # Verified subscriptions
│   └── confirmed-utilities.md       # Verified utility bills
└── scripts/                         # Automation scripts
    ├── subscriptions-report.ps1
    ├── normalize-account.ps1
    ├── extract-usaa.py
    └── statement-report.ps1
```

## Scripts

| Script | Purpose |
|--------|---------|
| `extract-usaa.py` | Extract transactions from USAA PDFs using pdfplumber |
| `search-pdfs.py` | Search raw PDFs for merchant names not found in CSVs |
| `normalize-account.ps1` | Normalize with AI (batched - 1 call per account) |
| `statement-report.ps1` | Generate combined budget report |
| `subscriptions-report.ps1` | Generate subscription expense analysis |

## Workflow

### Step 1: Extract from PDFs (per account)
```powershell
cd "c:\Users\franz\.claude\skills\budget\scripts"
python extract-usaa.py "USAA Classic Checking"
```

### Step 2: Normalize with AI (1 premium request per account)
```powershell
& "c:\Users\franz\.claude\skills\budget\scripts\normalize-account.ps1" -AccountName "USAA Classic Checking"
```

### Step 3: Generate Reports
```powershell
& "c:\Users\franz\.claude\skills\budget\scripts\statement-report.ps1"
```

### Step 4: Subscription Analysis
```powershell
& "c:\Users\franz\.claude\skills\budget\scripts\subscriptions-report.ps1"
```

When prompted, choose where to save the report:
1. Budget Statements folder (default)
2. Current directory
3. Custom path

Or specify directly:
```powershell
& "c:\Users\franz\.claude\skills\budget\scripts\subscriptions-report.ps1" -OutputPath "C:\Reports\subscriptions-report.md"
```

## Subscription Analysis Features

The subscription report provides:

- **Summary Dashboard**: Total spend, estimated monthly/annual costs
- **Category Breakdown**: Developer Tools, Streaming, AI Tools, Gaming, etc.
- **Account Distribution**: Spend across Chase, USAA Classic, USAA Spending
- **Recurrence Detection**: Monthly, Annual, Quarterly, Irregular patterns
- **Recommendations**: High-cost alerts, irregular charges, new subscriptions
- **Cancellation Links**: Direct links to manage or cancel each subscription (24+ providers)

### Vendor-First Detection

**Architecture**: Script searches ALL transactions for known vendor patterns, then includes subscription-category transactions. This overcomes AI categorization gaps where subscriptions get classified as Entertainment, Technology, Shopping, etc.

**Deduplication**: Removes duplicate transactions that match both vendor patterns and category filters.

**Result**: Detects subscriptions regardless of how they're categorized, improving accuracy for miscategorized services.

### Subscription Categories Tracked

- Subscriptions
- Software & Subscriptions
- Streaming
- Membership
- Credit Report Monitoring
- Gaming

### Known Services Auto-Identified

Apple Services, Microsoft 365, YouTube Premium, ESPN+, SiriusXM, Prime Video, Cursor AI, Devin AI, GitKraken, Todoist, The Atlantic, The Economist, The New Yorker (CONDENAST), NordVPN, ChessBase, Google Play, Twitch Turbo, and 10+ more.

Each service includes a direct cancellation/management link:
- **Apple**: https://appleid.apple.com/account/subscriptions
- **Microsoft**: https://account.microsoft.com/subscriptions
- **Amazon Prime Video**: https://www.amazon.com/gp/video/settings/subscriptions
- **ESPN+**: https://www.espn.com/watch/espnplus
- **GitKraken**: https://www.gitkraken.com/account/subscriptions
- **Todoist**: https://todoist.com/app/settings/account
- **NordVPN**: https://account.nordvpn.com/billing
- (Plus 17+ more with one-click access in the report)

### Data Quality Notes

**YouTube Premium Missing**: Despite being in the known services list, YouTube Premium does not appear in current normalized CSV files. Possible causes:
1. Charged to a payment method not yet extracted (Apple Card, Google Wallet, etc.)
2. Bundled within Google One or other umbrella service
3. Not in the date range of extracted statements

Recommendation: Check Google account billing history and update extraction scripts if YouTube Premium found on different card.

## Normalized CSV Format

```csv
Date,Account,Category,Description,Amount
2025-01-15,Chase Credit Card,Groceries,HARRIS TEETER,-45.67
2025-01-16,Chase Credit Card,Credit Card Payment,PAYMENT RECEIVED,500.00
```

- **Date**: YYYY-MM-DD
- **Amount**: Negative = expense, Positive = income/credit

## Current Data Summary

| Account | Transactions | Months | Status |
|---------|-------------|--------|--------|
| Chase Credit Card | 599 | 17 | ✅ Complete |
| USAA Classic Checking | 284 | 13 | ✅ Complete |
| USAA Spending Checking | 311 | 12 | ✅ Complete |
| USAA Savings | 40 | 12 | ✅ Complete |
| **Total** | **1,236** | — | — |

### Subscription Analysis Results (Latest Run)

- **Active Subscriptions Found**: 28
- **Total Spend**: $3,472.83
- **Monthly Cost**: $826.46
- **Projected Annual Cost**: $9,917.52
- **High-Value (>$25/month)**: Apple Hardware/Services, GitKraken, Todoist, Augment Code AI

### Exclusion Patterns Filtered

The script filters out 208+ generic USAA entries:
- `RECURRING DEB CARD PURCH` (unidentifiable USAA codes — **FAULTY PARSING INDICATOR**)
- `DEBIT CARD PURCHASE|REFUND`
- `ACH WITHDRAWAL|PAYMENT|CREDIT`
- `POS DEBIT` (point-of-sale duplicates)
- `ONLINE BANKING TRANSFER`
- `WIRE TRANSFER`

**⚠️ PARSING WARNING**: If you see `RECURRING DEB CARD PURCH` in normalized CSVs without a merchant name, this indicates faulty PDF parsing. The merchant name was not properly captured during extraction. **Re-run `extract-usaa.py` for that account** to fix the issue.

## Cost Efficiency

Batching all transactions per account into ONE AI call reduced costs from ~50 premium requests to ~5.

## Troubleshooting

### Missing Transactions in CSVs

**Problem**: Known subscription not appearing in extracted CSVs but visible in PDF.

**Root Cause**: USAA statements use a two-line format where merchant name is on line 1 and transaction details (date/amount) are on line 2. Fixed December 2025.

**Solution**: 
1. Use `search-pdfs.py "merchant name"` to search raw PDFs
2. If found in PDF but not CSV, re-run `extract-usaa.py` for that account
3. The extraction script now handles two-line format:
   - Line 1: `CNP* NEWYORKER - DIGIT CONDENAST.COMNY`
   - Line 2: `02/28 RECURRING DEB CARD PURCH 022825 4899022825 $11.99 0 $1,428.66`

### Missing Subscriptions in Report

**Problem**: Known subscription not appearing in report.

**Root Cause**: Previous script only scanned subscription-category transactions. Now uses vendor-first detection.

**Solution**: 
1. Verify subscription is in `$KnownSubscriptions` hash table
2. Check the pattern matches actual transaction descriptions (use `-match [regex]::Escape($pattern)`)
3. Verify transaction exists in source CSV files for the date range
4. If found but categorized differently, add to category list or check exclusion patterns

**Example**: YouTube Premium search returned 0 results - indicates it's on a different payment method or account not yet extracted.

### Adding New Subscriptions

To add cancellation links for new services:

1. Update `$KnownSubscriptions` hash table with service pattern and CancelUrl:
```powershell
'SERVICE_PATTERN' = @{ 
    Name = 'Service Name'
    Type = 'Category'
    CancelUrl = 'https://service.com/account/subscriptions' 
}
```

2. Script automatically includes the link in High-Value Subscriptions table and Management Links section
3. Re-run report to see new subscription with clickable link

## Confirmed Subscriptions Tracking

**File**: `c:\Users\franz\.claude\skills\budget\tracking\confirmed-subscriptions.md`

Manual tracking of verified subscriptions with actual pricing and cancellation status. Used to cross-reference against automated report and maintain historical record.

### Format

| Service | Price | Frequency | Status | Notes |
|---------|-------|-----------|--------|-------|
| [The Economist](https://myaccount.economist.com/s/my-account) | $319.00 | Annual | Cancelled | Cancelled as of December 2025 |

Service names are linked to their management/cancellation pages when available.

### Purpose

- Track which subscriptions have been manually verified vs. auto-detected
- Record actual confirmed prices (sometimes auto-detection may overestimate)
- Maintain cancellation history
- Flag discrepancies between automated report and reality

### Workflow

1. Run `subscriptions-report.ps1` to see auto-detected subscriptions
2. Verify against confirmed list in `tracking/confirmed-subscriptions.md`
3. When you cancel a subscription, update status to "Cancelled" with date
4. Add any newly confirmed subscriptions to the table

## Confirmed Utilities Tracking

**File**: `c:\Users\franz\.claude\skills\budget\tracking\confirmed-utilities.md`

Manual tracking of verified utility bills with provider information, account numbers, and typical billing patterns.

### Purpose

- Track confirmed utility providers and account details
- Record typical billing amounts for budgeting
- Monitor for unexpected charges or rate increases
- Maintain service addresses and contact information

### Workflow

1. Extract utility payments from bank statements
2. Verify against confirmed list in `tracking/confirmed-utilities.md`
3. Update with new rates or account changes
4. Flag suspicious charges for investigation
