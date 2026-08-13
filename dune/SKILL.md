---
name: dune
description: "V1.1 - Expert guidance for Dune: Awakening, especially Landsraad Great Houses, representatives, reward screenshots, locations, and efficient reward-collection routes. Use when identifying houses such as Hurata or Thorvald, locating representatives, reading Landsraad rewards from screenshots, planning a multi-house redemption route, or maintaining current Dune location data."
disable-model-invocation: true
---

# Dune: Awakening Expert

## Default behavior

When activated without an action, ask for the Landsraad reward screenshot or screenshots. Extract every house with
an unclaimed reward, normalize its name, and produce a zone-aware collection route.

## Choose the workflow

| Request | Action |
| --- | --- |
| Reward screenshot or route | Follow the reward route workflow |
| House, representative, or location question | Query `references/houses.json` |
| List all houses | Run `scripts/Plan-HouseRewardRoute.ps1 -ListHouses` |
| Change or add location data | Follow the data maintenance workflow |
| Other Dune: Awakening question | Research current sources and answer with version/date caveats |

## Reward route workflow

### Step 1: Read the screenshots

1. Inspect every supplied screenshot at full useful resolution.
2. Record only houses showing a reward the user intends to claim.
3. Normalize OCR and spelling variants with `aliases` in `references/houses.json`.
4. Ask for confirmation only when a house remains ambiguous. Do not block on clear variants such as
   `Torveld` or `Torvald`, which resolve to `Thorvald`.

### Step 2: Establish route constraints

Use any starting house, ending house, excluded map, or travel preference provided by the user. If none is supplied,
use the planner's default zone order and state that inter-map order is a heuristic.

### Step 3: Plan the route

Run:

```powershell
./dune/scripts/Plan-HouseRewardRoute.ps1 -Houses Hurata,Thorvald,Mutelli
```

Add `-StartHouse <name>` when the user gives a known starting representative. Use `-OutputFormat Json` when another
tool needs structured output.

The planner optimizes within each map from the sourced coordinate data. It does not claim that straight-line map
units equal meters or travel time. Cliffs, caves, vehicle access, loading screens, and terrain change real cost.

### Step 4: Present the itinerary

1. Lead with the ordered stops.
2. Group stops by Hagga Basin, Harko Village, Arrakeen, and the Deep Desert.
3. Include each representative, region, landmark directions, and current caveat.
4. Warn that Deep Desert terrain changes with the Coriolis cycle and recheck Wayku or Maros before departure.
5. Include clickable source links when current web research was used.

## House lookup workflow

Read `references/houses.json` for the canonical name, aliases, representative, Landsraad bloc, specialization,
map, region, landmark directions, exact source coordinate, and verification state. Give the shortest practical
answer first, followed by useful alternatives or caveats.

Treat reward rotations, prices, recipes, missions, and patch behavior as time-sensitive. Verify them against current
official notes and a current data source before presenting them as current.

## Data maintenance workflow

Read `references/data-guide.md`, then:

1. Verify the current live game version from Funcom patch notes.
2. Cross-check representative points against the interactive map and directions against a second source.
3. Preserve source coordinates exactly; never invent or visually estimate missing values.
4. Update `verifiedOn`, `gameVersion`, source metadata, aliases, and caveats.
5. Run `scripts/Test-HouseData.ps1`.
6. Run at least one single-map and one multi-map route smoke test.
7. Record the interaction in `History/YYYY-MM-DD.md` with a timestamp from `Get-Date -Format "HH:mm"`.

## Reliability rules

- Distinguish a sourced coordinate from an approximate route cost.
- Do not silently drop an unrecognized screenshot name.
- Do not claim a globally fastest route without measured travel-time edges and a known start.
- Prefer current official patch notes for mechanics and current interactive-map data for coordinates.
- Attach the game version and verification date to time-sensitive answers.
