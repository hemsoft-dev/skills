# Dune House Data Guide

## Purpose

`houses.json` is the canonical local database for Landsraad house-representative lookup and reward-route planning.
It contains all 25 houses active in game version 1.4.10.4.

## Source priority

| Priority | Source | Use |
| --- | --- | --- |
| 1 | Funcom patch notes | Live version and current Landsraad mechanics |
| 2 | The Hidden Gaming Lair interactive map | Exact representative coordinate triples |
| 3 | Method representative guide | Representative names and landmark directions |
| 4 | Dune: Awakening Community Wiki | Blocs, specializations, and cross-checks |
| 5 | Dune Gaming Tools | Versioned house, mission, reward, and item cross-checks |

## Coordinate contract

The `point` object preserves the source's three-value in-game coordinate array as `x`, `y`, and `z`. Route length is
calculated only between points on the same map and is reported as relative map units.

Do not convert these values to meters. Do not compare a distance on Hagga Basin with one on Arrakeen, Harko Village,
or the Deep Desert because the map coordinate systems and travel transitions differ.

## Route model

1. Resolve canonical names and aliases.
2. Group requested houses by map.
3. Optimize an open path inside each map using nearest-neighbor candidates and two-opt improvement.
4. Anchor the first map and first leg when `StartHouse` is supplied.
5. Use the documented map order for transitions because measured cross-map travel times are not yet available.

The resulting itinerary is a defensible geographic route, not a guarantee of minimum elapsed time. Add measured,
directed travel-time edges only after repeatable in-game timings exist.

## Maintenance checks

### Step 1: Verify sources

Confirm the current version and check whether all 25 representative markers remain present. Recheck Deep Desert
markers after changes to the Coriolis cycle or map generation.

### Step 2: Update records

Keep canonical names aligned with current in-game labels. Add common OCR or community spellings to `aliases` instead
of changing the canonical name.

### Step 3: Validate

Run:

```powershell
./dune/scripts/Test-HouseData.ps1
./dune/scripts/Plan-HouseRewardRoute.ps1 -Houses Hurata,Torveld,Spinette
./dune/scripts/Plan-HouseRewardRoute.ps1 -Houses Alexin,Mutelli,Wayku -OutputFormat Json
```

The validator enforces 25 unique houses, five houses per specialization, required map counts, unique aliases,
coordinates, HTTPS sources, and Deep Desert recheck flags.
