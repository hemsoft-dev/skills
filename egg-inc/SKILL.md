---
name: egg-inc
description: V1.3 - Expert in Egg Inc mobile game mechanics, player tracking, spaceship missions, Truth Eggs/Path of Virtue, and progress calculations for King Friday, King Saturday, King Sunday, and King Monday accounts.
---

# Egg Inc Expert

Expert assistant for the mobile game Egg Inc by Auxbrain. Specializes in player tracking, progress calculations, prestige strategies, and game mechanics.

## Community Resources

### Majeggstics
The largest organized co-op group in Egg Inc Discord. Motto: "No Farmer is Left Behind!"

| Resource | URL |
|----------|-----|
| Website | https://majeggstics.com |
| Guide | https://majeggstics.com/guide |
| Boost Calculator | https://majeggstics.com/contract-boost-calculator |
| Discord | https://discord.gg/egginc (then DM recruiters) |

**Key Channels** (Discord):
- `#mj-announcements` - Contract registration, minimums
- `#mj-contracts` - Co-op threads
- `#the_majeggstics` - General discussion
- `#wonky-spam` - Bot commands

**Wonky Bot** - Manages co-op assignments, player tracking, leaderboards

### wasmegg Tools (by @mk2)
Community tools at https://wasmegg.netlify.app/

| Tool | URL | Purpose |
|------|-----|---------|
| CoopTracker | https://eicoop.netlify.app/ | Live co-op tracking |
| Rockets Tracker | https://wasmegg.netlify.app/rockets-tracker/ | Mission tracking, artifact collection |
| Smart Assistant | https://wasmegg.netlify.app/smart-assistant/ | Artifact loadout optimizer |
| Enlightenment Companion | https://wasmegg.netlify.app/enlightenment/ | Diamond trophy guide |
| Artifact Explorer | https://wasmegg.netlify.app/artifact-explorer/ | Artifact database |
| Inventory Visualizer | https://wasmegg.netlify.app/inventory-visualizer/ | Share artifact inventory |

### Other Tools
| Tool | URL | Purpose |
|------|-----|---------|
| Gompaniyon | https://docs.google.com/spreadsheets/d/1hudIh0FG5HZro7mGHrnSYqd7afdFU3s1uPFSDxjLbKU/ | Boost calculator spreadsheet |
| Legendary Study | https://legendary-study.netlify.app/ | Legendary artifact stats |
| Ad-hoc Tools | https://eiadhoc.netlify.app/ | Crafting cost, shipping time calculators |

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:
```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Quick Actions

| Request | Action |
|---------|--------|
| Refresh all account data | Run: `& "c:\Users\User\.claude\skills\egg-inc\scripts\FetchAllAccounts.ps1"` |
| Show Truth Eggs / TE for all accounts | Run: `& "c:\Users\User\.claude\skills\egg-inc\scripts\TruthEggsStatusAll.ps1"` |
| Show spaceship missions for all accounts | Run: `& "c:\Users\User\.claude\skills\egg-inc\scripts\MissionStatusAll.ps1"` |
| Show Virtue missions for all accounts | Run: `& "c:\Users\User\.claude\skills\egg-inc\scripts\VirtueMissionsAll.ps1"` |

## Cached Data

Account data is cached locally in JSON files for quick querying without API calls:

| Account | Data File |
|---------|-----------|
| King Friday! | `c:\Users\User\.claude\skills\egg-inc\data\king-friday.json` |
| King Saturday! | `c:\Users\User\.claude\skills\egg-inc\data\king-saturday.json` |
| King Sunday! | `c:\Users\User\.claude\skills\egg-inc\data\king-sunday.json` |
| King Monday! | `c:\Users\User\.claude\skills\egg-inc\data\king-monday.json` |

**Usage**: Read JSON files directly to answer questions. Run `FetchAllAccounts.ps1` to refresh data.

## Tracked Accounts

| Account | EID | API Endpoint |
|---------|-----|--------------|
| King Friday! | EI6335140328505344 | `https://ei_worker.tylertms.workers.dev/backup?EID={EID}` |
| King Saturday! | EI5435770400276480 | Same pattern |
| King Sunday! | EI6306349753958400 | Same pattern |
| King Monday! | EI6725967592947712 | Same pattern |

## API Endpoints

### Player Info
```
https://eggincdatacollection.azurewebsites.net/api/formulae/all?eid={EID}
https://ei_worker.tylertms.workers.dev/backup?EID={EID}
```

### Events & Contracts
```
https://ei_worker.tylertms.workers.dev/periodicals?EID={EID}
```

### Player Contracts Archive
```
https://ei_worker.tylertms.workers.dev/archive?EID={EID}
```

### Contract Details
```
https://ei_worker.tylertms.workers.dev/contract?EID={EID}&contract={contractId}&coop={coopId}
```

### MAJ Rankings (Google Sheets)
```
https://sheets.googleapis.com/v4/spreadsheets/17juaBpcUiw1Rw3sMnVRbRkY_rxW-AdTCD-WyIO8YPs8/values/SE!P1:Y1000?key={API_KEY}
```

## Core Currencies

### Soul Eggs (SE)
- Earned via prestige, contracts, trophies, daily calendar
- Each SE provides +10% earnings (base), up to +150% with max Soul Food
- Displayed in Egg Inc format: **123.330s** (sextillion)

### Prophecy Eggs (PE)
- Multiply SE effectiveness by 5-10% each (compounding)
- Earned from contracts, trophies, daily calendar, seasons
- Integer count: **231** PE

### Truth Eggs (EoV) - NEW!
- Also called "Eggs of Virtue" 
- Earned from the Virtue system (5 enlightenment paths)
- API Location: `response.virtue`
  - `eovEarnedList[5]` - EoV earned per path (sum for total earned)
  - `eggsDeliveredList[5]` - Progress per path (calculate pending from thresholds)
  - `shiftCount` - Total shifts (milestones) completed, NOT pending
  - `resets` - Number of Virtue resets completed

**Path order**: [Curiosity, Integrity, Humility, Resilience, Kindness]

## Core Calculations

### Earnings Bonus (EB)
```
Base EB = SoulEggs × 150 × (1.1 ^ ProphecyEggs) × (1.035 ^ TruthEggs)
```
- Base Soul Egg bonus: 150% (with max Soul Food Epic Research)
- Prophecy Egg multiplier: 1.1x per PE (with max Prophecy Bonus)
- Truth Egg multiplier: ~1.035x per EoV (compounding)

**Note**: The Truth Egg multiplier is approximate. In-game EB may vary due to artifacts and other bonuses.

### Title Progression (by EB%)

| EB Threshold | Title |
|--------------|-------|
| 1,000 | Farmer |
| 10,000 | Farmer II |
| 100,000 | Farmer III |
| 1M | Kilofarmer |
| 10M | Kilofarmer II |
| 100M | Kilofarmer III |
| 1B | Megafarmer |
| 10B | Megafarmer II |
| 100B | Megafarmer III |
| 1T | Gigafarmer |
| 10T | Gigafarmer II |
| 100T | Gigafarmer III |
| 1q | Terafarmer |
| 10q | Terafarmer II |
| 100q | Terafarmer III |
| 1Q | Petafarmer |
| 10Q | Petafarmer II |
| 100Q | Petafarmer III |
| 1s | Exafarmer |
| 10s | Exafarmer II |
| 100s | Exafarmer III |
| 1S | Zettafarmer |
| 10S | Zettafarmer II |
| 100S | Zettafarmer III |
| 1o | Yottafarmer |
| 10o | Yottafarmer II |
| 100o | Yottafarmer III |
| 1N | Xennafarmer |
| 10N | Xennafarmer II |
| 100N | Xennafarmer III |
| 1d | Weccafarmer |
| 10d | Weccafarmer II |
| 100d | Weccafarmer III ← **King Friday is here** |
| 1U | Vendafarmer |

**Example**: King Friday has **103.440d%** EB = **Vendafarmer** (between 100d and 1U)

### Number Suffixes (Case Sensitive!)
| Suffix | Value | Example |
|--------|-------|---------|
| K | 10³ | 1.234K = 1,234 |
| M | 10⁶ | 1.234M = 1,234,000 |
| B | 10⁹ | 1.234B = 1.234 billion |
| T | 10¹² | 1.234T = 1.234 trillion |
| q | 10¹⁵ | 1.234q = 1.234 quadrillion |
| Q | 10¹⁸ | 1.234Q = 1.234 quintillion |
| **s** | 10²¹ | **123.330s** = 123.330 sextillion |
| S | 10²⁴ | 1.234S = 1.234 septillion |
| o | 10²⁷ | 1.234o = 1.234 octillion |
| N | 10³⁰ | 1.234N = 1.234 nonillion |
| **d** | 10³³ | **103.440d** = 103.440 decillion |
| U | 10³⁶ | 1.234U = 1.234 undecillion |

**CRITICAL**: Use lowercase `s` and `d` - these are case-sensitive!

## Egg Types

| ID | Egg | Value Tier |
|----|-----|------------|
| 1 | Edible | Starter |
| 2 | Superfood | Low |
| 3 | Medical | Low |
| 4 | Rocket Fuel | Mid |
| 5 | Supermaterial | Mid |
| 6 | Fusion | Mid |
| 7 | Quantum | Mid |
| 8 | Immortality | High |
| 9 | Tachyon | High |
| 10 | Graviton | High |
| 11 | Dilithium | High |
| 12 | Prodigy | Elite |
| 13 | Terraform | Elite |
| 14 | Antimatter | Elite |
| 15 | Dark Matter | Elite |
| 16 | AI | Elite |
| 17 | Nebula | Elite |
| 18 | Universe | Top |
| 19 | Enlightenment | Special |

## Key Game Mechanics

### Prestige
Resets farm progress but grants Soul Eggs based on lifetime earnings. Soul Eggs permanently boost earnings on all future farms.

### Soul Eggs (SE)
- Earned via prestige, contracts, trophies, daily calendar
- Each SE provides +10% earnings (base), up to +150% with max Soul Food

### Prophecy Eggs (PE)
- Multiply SE effectiveness by 5-10% each (compounding)
- Earned from contracts, trophies, daily calendar, seasons
- Current max available: ~231 PE

### Artifacts & Stones
- Collected from spaceship missions
- Provide passive bonuses when equipped
- Key artifacts: Phoenix Feather (SE gain), Book of Basan (PE bonus), Lunar Totem (away earnings)

### Contracts
- Multiplayer co-op goals
- Reward SE, PE, Golden Eggs, artifacts
- Leggacy contracts available Fridays

### Events
Types: Double Prestige, Generous Drones, Longer Boosts, etc.

## Spaceship Missions

Spaceships are sent on missions to collect Artifacts, Stones, and Ingredients. Each account can have **3 active missions** at a time, plus 1 fueling.

### Ship Types (by ID)
| ID | Ship Name | Max Stars |
|----|-----------|-----------|
| 0 | Chicken One | 2 |
| 1 | Chicken Nine | 2 |
| 2 | Chicken Heavy | 3 |
| 3 | BCR | 4 |
| 4 | Quintillion Chicken | 4 |
| 5 | Cornish-Hen Corvette | 4 |
| 6 | Galeggtica | 5 |
| 7 | Defihent | 5 |
| 8 | Voyegger | 6 |
| 9 | Henerprise | 8 |
| 10 | Atreggies Henliner | 8 |

### Duration Types
| ID | Type | Description |
|----|------|-------------|
| 0 | Short | Fastest, lowest quality |
| 1 | Standard | Balanced |
| 2 | Extended | Slowest, highest quality |

### Mission Types
| ID | Type | Description |
|----|------|-------------|
| 0 | Normal | Standard artifact missions |
| 1 | Virtue | Enlightenment/Virtue path missions |

### Mission Status Codes
| ID | Status |
|----|--------|
| 0 | Fueling |
| 5 | Prepared |
| 10 | In-Flight |
| 15 | Returned |
| 20 | Analyzing |
| 25 | Complete |

### API Structure (`response.artifactsDb`)
| Field | Description |
|-------|-------------|
| `missionInfosList` | Array of active/returned missions |
| `fuelingMission` | Currently fueling mission (if any) |

**Mission object fields:**
- `ship` - Ship ID (0-10)
- `status` - Mission status code
- `durationType` - Duration type (0-2)
- `type` - Mission type (0=Normal, 1=Virtue)
- `level` - Star level (0-8)
- `capacity` - Number of items mission will return
- `durationSeconds` - Total mission duration
- `secondsRemaining` - Time until return (negative = ready)
- `missionLog` - Fun flavor text
- `fuelList` - Array of {egg, amount} for fuel requirements

## Virtue System (Truth Eggs)

The Virtue system is the endgame enlightenment prestige mechanic that awards **Truth Eggs (Eggs of Virtue / EoV)**. Introduced ~September 2025.

### Community EoT Tracking
- **Majeggstics Leaderboard**: Tracked via Discord/Wonky bot (old spreadsheet deprecated)
- **Top Players** (as of late 2025): 100-150+ EoT
- **Leading Pack**: 85-130 EoT typical for active players
- **Average First Run**: 25-55 EoT in 7-8 shifts

### The 5 Virtue Paths
| Index | Path | Focus | Threshold per EoV |
|-------|------|-------|-------------------|
| 0 | Curiosity | Research | ~10q eggs |
| 1 | Integrity | Housing | ~10q eggs |
| 2 | Humility | Artifacts | ~10q eggs |
| 3 | Resilience | Silos | ~10T eggs |
| 4 | Kindness | Vehicles | ~10q eggs |

### How It Works
1. **Enlightenment Farms**: Deliver enlightenment eggs to progress each path
2. **Pending EoV**: Calculated when hitting thresholds on each path
3. **Virtue Reset**: Reset to collect all pending EoV and start over
4. **Shifts**: Total milestone completions across all paths (`shiftCount`)

### API Structure (`response.virtue`)
| Field | Type | Description |
|-------|------|-------------|
| `shiftCount` | int | Total shifts completed (NOT pending - purpose unclear) |
| `eovEarnedList` | int[5] | EoV earned per path (order: Curiosity, Integrity, Humility, Resilience, Kindness) |
| `eggsDeliveredList` | double[5] | Progress per path in eggs delivered (same order) |
| `resets` | int | Number of Virtue resets completed |

### Calculating Pending EoV

**Pending = Completed Tiers - Earned** for each path.

**Standard Paths** (Curiosity, Integrity, Humility, Kindness) use 1-2-5 progression:
```
500B, 1T, 2T, 5T, 10T, 20T, 50T, 100T, 200T, 500T, 1q, 2q, 5q, 10q, 20q, 50q, 100q, ...
```

**Resilience Path** uses linear then 1-2-5 progression:
```
1T, 2T, 3T, 4T, 5T, 6T, 7T, 20T, 50T, 100T, 200T, 500T, 1q, ...
```

Algorithm: Count how many thresholds the `eggsDeliveredList[path]` value exceeds, subtract `eovEarnedList[path]`.

### Truth Egg Bonus
- Each Truth Egg provides a **multiplier to Earnings Bonus**
- Stacks multiplicatively with SE and PE
- Exact multiplier per EoV: ~3.5% compounding (estimated)
- Formula: `EB = SE × 150 × (1.1^PE) × (1.035^EoV)` (approximate)

### King Monday's Virtue Stats (Example)
```
Path            | Earned | Pending | Progress
----------------|--------|---------|------------------
Humility        | 10     | 6       | 53.519q / 100.000q
Curiosity       | 10     | 3       | 5.912q / 10.000q
Integrity       | 8      | 5       | 5.439q / 10.000q
Resilience      | 7      | 0       | 7.099T / 20.000T
Kindness        | 10     | 3       | 5.047q / 10.000q
----------------|--------|---------|
Total           | 45     | 17      |
```

### Virtue Strategy
1. **Early Virtue**: Focus on completing enlightenment diamond trophy first
2. **Path Focus**: Prioritize paths closest to next threshold
3. **Reset Timing**: Reset when pending EoV is high enough to justify losing progress
4. **Artifacts**: Use Book of Basan and clarifying stones for enlightenment runs

## Prestige Strategies

### Single Prestige (Early-Mid Game)
1. Max Universe egg
2. Use boosts: Soul Beacon + Bird Feed + Boost Beacon
3. Run chickens, prestige when boosts expire

### Multistige (Late Game, 100Q%+ EB)
1. Use dilithium stones to extend boosts
2. Multiple prestiges per boost set
3. Optimal legs ≈ 0.58 × (T + τ) / τ

### Lunarstige (Lazy Strategy)
1. Equip Lunar Totem + Lunar Stones
2. Go offline during boost duration
3. Prestige when returning

## Reference Project

The Egg-Inc-Tracker project at `F:\github\HemSoft\Egg-Inc-Tracker` contains:
- `sources/HemSoft.EggIncTracker.Domain/PlayerManager.cs` - EB calculations, title progression
- `sources/HemSoft.EggIncTracker.Domain/Api.cs` - API call implementations
- `sources/HemSoft.EggIncTracker.Data/Dtos/PlayerDto.cs` - Player data model
- `sources/HemSoft.EggIncTracker.Data/Utils.cs` - Number formatting utilities
- `sources/HemSoft.EggIncTracker.Functions/` - Azure Functions for automated tracking

## Scripts

All scripts are located in `c:\Users\User\.claude\skills\egg-inc\scripts\`

### FetchAllAccounts.ps1
Fetches backup data for all tracked accounts and saves to JSON files in the `data` folder.
```powershell
& "c:\Users\User\.claude\skills\egg-inc\scripts\FetchAllAccounts.ps1"
```

### TruthEggsStatusAll.ps1
Returns Truth Eggs status for all tracked accounts with both earned AND pending:
```powershell
& "c:\Users\User\.claude\skills\egg-inc\scripts\TruthEggsStatusAll.ps1"
```

Output columns: Account, Earned, Pending, Total, Curiosity (earned+pending), Integrity, Humility, Resilience, Kindness, Resets

### MissionStatusAll.ps1
Returns active spaceship missions for all tracked accounts:
```powershell
& "c:\Users\User\.claude\skills\egg-inc\scripts\MissionStatusAll.ps1"
```

Output columns: Account, Ship, Duration, Type, Stars, Capacity, Status, TimeLeft

### VirtueMissionsAll.ps1
Returns Virtue (enlightenment path) missions for all tracked accounts with arrival times:
```powershell
& "c:\Users\User\.claude\skills\egg-inc\scripts\VirtueMissionsAll.ps1"
```

Output columns: Account, Ship, Duration, Stars, Capacity, Arrival (local time)

## Usage Examples

### Fetch Player Status
```powershell
$EID = "EI6335140328505344"  # King Friday
$r = Invoke-RestMethod "https://ei_worker.tylertms.workers.dev/backup?EID=$EID"

# Key stats
$SE = $r.game.soulEggsD          # 1.23329828791588E+23 → 123.330s
$PE = $r.game.eggsOfProphecy     # 231
$EoV_earned = ($r.virtue.eovEarnedList | Measure-Object -Sum).Sum  # 43
# Pending: run TruthEggsStatusAll.ps1 for full calculation
```

### Example Output Format
```
King Friday!
────────────────────
Truth Eggs: 43 (pending requires in-game check)
PE: 231
SE: 123.330s
EB: 103.440d%
Title: Vendafarmer
```

### Calculate EB (with Truth Eggs)
```csharp
// Full EB calculation including Truth Eggs
var baseEB = soulEggs * 150 * Math.Pow(1.1, prophecyEggs);
var fullEB = baseEB * Math.Pow(1.035, truthEggs);
```

```powershell
# PowerShell EB calculation
$SE = $r.game.soulEggsD
$PE = $r.game.eggsOfProphecy
$EoV = ($r.virtue.eovEarnedList | Measure-Object -Sum).Sum
$EB = $SE * 150 * [Math]::Pow(1.1, $PE) * [Math]::Pow(1.035, $EoV)
```

### Format Large Numbers
```csharp
Utils.FormatBigInteger(bigNumber.ToString()) // Returns "1.234Q"
```

## Discord Webhook

Progress updates sent to: Discord webhook configured in project settings.
