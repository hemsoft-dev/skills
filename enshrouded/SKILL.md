---
name: enshrouded
description: V1.0 - Expert in Enshrouded game mechanics, gameplay, progression, crafting systems, and community modding support.
---

# Enshrouded

Expert knowledge of the Enshrouded survival crafting game, including base building, combat, exploration, progression systems, and community mods.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Core Knowledge Areas

- **Gameplay Mechanics** - Combat, stamina, hunger/thirst systems, health, survival mechanics
- **Progression** - Leveling, skill trees, unlocking new recipes and crafting
- **Crafting & Building** - Workbenches, construction materials, furniture, decorative items, optimization
- **Exploration** - Map locations, dungeons, loot, fast travel via flame altars
- **NPCs & Quests** - NPC recruitment, trade, quest progression, relationship systems
- **Combat** - Weapons, armor, enchantments, enemy types, boss mechanics
- **Community Mods** - Asset packs, quality-of-life improvements, cosmetics despite lack of official modding support
- **Performance Optimization** - Settings, render distance, common issues and workarounds

## When to Use This Skill

- Player questions about game mechanics and strategies
- Building and base layout optimization
- Crafting recipes and progression paths
- Exploration guides and location recommendations
- Mod recommendations and installation guidance
- Troubleshooting common gameplay issues
- Survival mode tips and advanced strategies

## Installing Enshrouded Mods (EML Method)

### Prerequisites

- GitHub account (free at github.com)
- Enshrouded installed (Steam or standalone)

### Step 1: Install Enshrouded Mod Loader (EML)

**Method A: Using GitHub CLI (Recommended)**

1. Install GitHub CLI from https://cli.github.com/ if not already installed
2. Open PowerShell and run:
   ```powershell
   gh auth login
   gh run download 20083688075 --repo Brabb3l/kfc-parser
   ```
3. Files will be downloaded to subdirectories - extract the actual files:
   - `dbghelp.dll` (10.60 MB)
   - `dinput8.dll` (10.46 MB)
   - `emm.exe` (10.69 MB)
   - `kfc-parser.exe` (2.05 MB)

**Method B: Manual Download from GitHub**

1. **Create a free GitHub account** at https://github.com (required to download artifacts)
2. **Log into GitHub**
3. Navigate to: https://github.com/Brabb3l/kfc-parser/actions/workflows/build_release.yml
4. Click on the **topmost successful run** (green checkmark icon)
5. Scroll to the **bottom** of the run page to find the "Artifacts" section
6. Click each artifact name to download
7. Each artifact downloads into its own folder - extract the actual DLL/EXE file from each

**Install to Enshrouded:**

7. Find your Enshrouded installation folder:
   - **Steam**: Usually `C:\Program Files (x86)\Steam\steamapps\common\Enshrouded\`
   - Right-click game in Steam → Manage → Browse local files
8. **IMPORTANT**: Backup `enshrouded.kfc` (copy it somewhere safe)
   - If using Steam, you can skip this (Steam will verify files if needed)
9. Copy all 4 downloaded files directly into the Enshrouded root folder (where `enshrouded.exe` is located)
10. Verify files are in the right place:
    ```
    Enshrouded/
    ├── enshrouded.exe
    ├── dbghelp.dll      ← NEW
    ├── dinput8.dll      ← NEW
    ├── emm.exe          ← NEW
    └── kfc-parser.exe   ← NEW
    ```

### Step 2: Install Mods

**Example: Immersive Embervale Mod**

1. Download the mod from Nexus Mods
2. Create a `mods` folder in your Enshrouded directory if it doesn't exist
3. Extract the mod's contents into `Enshrouded/mods/`
4. Each mod should have its own subfolder with this structure:
   ```
   Enshrouded/mods/
   └── buildZonePlus/
       ├── mod.json
       └── src/
           └── mod.lua
   ```
5. Repeat for each module you want to install (the Immersive Embervale mod has multiple modules like `craftingPlus`, `inventoryPlus`, etc.)

### Step 3: Launch and Verify

1. Launch Enshrouded normally (through Steam or executable)
2. EML will load automatically via the DLL proxy
3. Check for any error messages on game startup
4. Test mod features in-game to confirm installation

### Troubleshooting

- **Game won't launch**: Ensure you downloaded **release** binaries, not debug versions
- **Mods not working**: Verify folder structure exactly matches `mods/<modname>/mod.json`
- **Crashes on startup**: Remove recently added mods one at a time to identify conflicts
- **Steam validation issues**: Restore your backed-up `enshrouded.kfc` or verify game files through Steam
