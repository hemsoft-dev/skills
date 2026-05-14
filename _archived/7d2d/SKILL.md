---
name: 7d2d
description: V1.6 - 7 Days to Die V2.5 mod development, compatibility, and best practices for XML, DLL, and Harmony mods.
---

# 7 Days to Die V2.5 Mod Development

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Use this skill for creating, updating, or troubleshooting mods for 7 Days to Die version 2.5 (PC/Steam).

## Key Paths

| Path | Description |
|------|-------------|
| `C:\Program Files (x86)\Steam\steamapps\common\7 Days To Die` | Game install directory |
| `{GameDir}\Mods\` | Installed mods folder |
| `{GameDir}\Data\Config\` | Vanilla XML configs (items.xml, blocks.xml, etc.) |
| `%LOCALAPPDATA%\Temp\The Fun Pimps\7 Days To Die\Player.log` | **Game log file** - check for mod errors/warnings |
| `%APPDATA%\7DaysToDie\Saves\` | Save games and world data |

## Mod Load Order

Mods load **alphabetically by folder name**. This is critical for compatibility:

- `0_TFP_Harmony` loads before `HemSoft_QoL` which loads before `RW_SimpleUI`
- Use folder name prefixes to control load order: `0_`, `00_`, `S_`, `z_`
- Check log for `[MODS]` entries to verify actual load order
- **If your mod patches XML created by another mod, your folder must sort AFTER that mod**

### Load Order Example

| Folder Name | Load Order | Notes |
|-------------|------------|-------|
| `0_TFP_Harmony` | 1st | Core Harmony framework |
| `0-Quartz` | 2nd | UI framework mod |
| `00000-Gears` | 3rd | Settings mod |
| `ProxiCraft` | 4th | |
| `RW_SimpleUI` | 5th | Creates `RWSUI_LeftHUD` window |
| `S_HemSoft_QoL` | 6th | Appends to RWSUI_LeftHUD (must load after) |
| `z100K-itemstack` | Last | Prefix z_ for "load last" |

## Mod Types

- **XML Modlets**: Tweak game data (items, blocks, loot, recipes, etc.) via Config/ XML files. Place in `Mods/{ModName}/Config/`.
- **DLL Mods (Harmony)**: Inject C# code using Harmony patches. Place DLL and `ModInfo.xml` in `Mods/{ModName}/`.
- **Hybrid**: Combine XML and DLL for advanced features.

## DLL Mod Structure

```
Mods/{ModName}/
├── ModInfo.xml              # Required metadata
├── {ModName}.dll            # Compiled Harmony assembly
├── {ModName}.csproj         # Build configuration (optional, for source)
├── README.md
├── Config/
│   └── {ConfigName}.xml     # User-editable settings
└── Harmony/
    ├── {ModName}.cs         # IModApi entry point + config loader
    └── *Patches.cs          # Harmony patch classes
```

## ModInfo.xml Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xml>
  <Name value="ModName" />
  <DisplayName value="Mod Display Name" />
  <Description value="Description here" />
  <Author value="Author Name" />
  <Version value="1.0.0" />
  <Website value="https://github.com/..." />
</xml>
```

## IModApi Entry Point

```csharp
public class MyMod : IModApi
{
    public void InitMod(Mod _modInstance)
    {
        var modPath = _modInstance.Path;
        var harmony = new Harmony("com.author.modname");
        harmony.PatchAll(Assembly.GetExecutingAssembly());
    }
}
```

## Key Game Classes for UI/Inventory Mods

| Class | Purpose |
|-------|---------|
| `XUiC_BackpackWindow` | Player backpack UI - patch `Update` for hotkey input |
| `XUiC_LootWindow` | Container loot window |
| `XUiC_ItemStack` | Individual item slot in UI |
| `TileEntityLootContainer` | Container storage (world containers) |
| `XUiM_PlayerInventory` | Player inventory model |
| `TEFeatureStorage` | Storage tile entity features |

## Harmony Patch Example (Hotkeys)

```csharp
[HarmonyPatch(typeof(XUiC_BackpackWindow))]
[HarmonyPatch("Update")]
public class MyHotkeyPatch
{
    public static void Postfix(XUiC_BackpackWindow __instance)
    {
        if (!XUi.IsGameRunning()) return;
        if (__instance.xui?.lootContainer == null) return;
        
        if (Input.GetKey(KeyCode.LeftAlt) && Input.GetKeyDown(KeyCode.Q))
        {
            // Do something when Alt+Q pressed with container open
        }
    }
}
```

## XML Config for User Settings

```xml
<?xml version="1.0" encoding="UTF-8"?>
<MyModConfig>
  <Hotkeys>
    <SomeAction enabled="true" modifier="LeftAlt" key="Q" />
  </Hotkeys>
</MyModConfig>
```

Load with `XmlDocument` in `InitMod()`. Parse `KeyCode` via `Enum.TryParse<KeyCode>()`.

## .csproj Setup (net48)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net48</TargetFramework>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
  <PropertyGroup>
    <GamePath>C:\...\7 Days To Die</GamePath>
    <ManagedPath>$(GamePath)\7DaysToDie_Data\Managed</ManagedPath>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="UnityEngine"><HintPath>$(ManagedPath)\UnityEngine.dll</HintPath><Private>false</Private></Reference>
    <Reference Include="UnityEngine.CoreModule"><HintPath>$(ManagedPath)\UnityEngine.CoreModule.dll</HintPath><Private>false</Private></Reference>
    <Reference Include="Assembly-CSharp"><HintPath>$(ManagedPath)\Assembly-CSharp.dll</HintPath><Private>false</Private></Reference>
    <Reference Include="0Harmony"><HintPath>$(ManagedPath)\0Harmony.dll</HintPath><Private>false</Private></Reference>
  </ItemGroup>
</Project>
```

## V2.5-Specific Guidance

- Always test on a clean V2.5 install; vanilla XML structure and APIs may change between versions.
- Check for new/renamed/removed XML nodes and attributes (see Data/Config/).
- For DLL mods, target net48 and use the Harmony version bundled with the game (0Harmony.dll).
- Review patch notes for breaking changes (e.g., new water, smell, vehicle, and temperature systems in 2.5).
- Use `ModInfo.xml` for metadata; keep version and author fields up to date.
- For multiplayer mods, ensure all clients and server use the same mod version.

## Console Commands

See [console-commands.md](console-commands.md) for a complete reference of all available console commands in 7D2D V2.5.

**Quick examples:**

- `giveself resourceBeeswax 100` - Give yourself beeswax
- `cm` - Enable creative mode/cheat mode
- Press **U** - Open creative menu (easier than console commands)
- Press **F1** - Open console

## Popups & Notifications

7D2D has several built-in systems for showing information popups:

### 1. GameMessage.ShowGameMessage() - Toast Style (Recommended)

Non-intrusive, top-center notification with optional icon and sound:

```csharp
GameMessage.ShowGameMessage("Lootstage increased to: " + lootstage, "ui_misc", "smIconPerkCompleteQuestTier2");
```

**Parameters:**

- First: message text
- Second: sound effect category (optional)
- Third: icon name from game's icon library (optional)

**Example - Lootstage Change Notification:**

```csharp
private int lastKnownLootstage = -1;

public void Update() 
{
    var player = GameManager.Instance.World.GetPrimaryPlayer();
    if (player == null) return;
    
    int currentLootstage = (int)EffectManager.GetValue(
        PassiveEffects.LootGamestage, null, 0, player);
    
    if (lastKnownLootstage != -1 && currentLootstage != lastKnownLootstage)
    {
        GameMessage.ShowGameMessage(
            $"Lootstage: {lastKnownLootstage} → {currentLootstage}", 
            "ui_notification", 
            "ui_game_symbol_trophy"
        );
    }
    
    lastKnownLootstage = currentLootstage;
}
```

### 2. GameManager.ShowTooltip() - Center Screen Tip

More prominent center-screen notification:

```csharp
GameManager.ShowTooltip(player, "Lootstage Changed!\n\nNew Lootstage: " + lootstage);
```

### 3. Custom XUi Popup Window

For advanced control, create custom XML popup windows:

```xml
<window name="CustomPopup" panel="none" anchor="center" pivot="center" 
        pos="0,0" width="400" height="200" 
        controller="XUiC_CustomPopup">
  <panel style="border_thick" disableautoposition="true">
    <label text="Important Information" style="header.label" />
    <label name="popupMessage" text="" style="normal.label" />
  </panel>
</window>
```

### 4. Buff Notification

Create a silent buff to trigger native buff notification UI:

```xml
<buff name="notificationBuff" name_key="Title" 
      description_key="Description here" 
      icon="ui_game_symbol_trophy" 
      duration="5">
</buff>
```

Apply when event occurs to show notification.

## Best Practices

- Keep mods modular: avoid overwriting core files, use xpath for XML edits.
- **EAC must be disabled** for DLL mods.
- Use in-game console (`F1`) for mod diagnostics and commands.
- Document config options in README; use XML config for user-editable settings.
- Log with `Debug.Log("[ModName] message")` for troubleshooting.
- Reference SphereII/SCore on GitHub for advanced patterns (NPCs, containers, UI).

## Common Pitfalls

### ModInfo.xml Validation

- **Name field must match regex** `^[0-9a-zA-Z_\-]+$` - NO SPACES allowed
- Use underscores: `HemSoft_QoL` not `HemSoft QoL`

### XUi Controller Classes

- **Must be outside any namespace** for `Type.GetType()` to find them
- Bad: `namespace HemSoft.QoL { public class XUiC_MyPanel : XUiController }`
- Good: `public class XUiC_MyPanel : XUiController` (no namespace)
- Reference in XML: `controller="XUiC_MyPanel, AssemblyName"`

### XUi XML Attributes

- Attribute values are **case-sensitive enum values**
- Invalid: `anchor="TopCenter"`, `pivot="topcenter"`
- Valid: `anchor="center"`, `pivot="top"`, `pivot="center"`
- Check game's XUi XML files for valid enum values

### XUi Click Handling

- Panels with `on_press="true"` intercept all clicks within their bounds
- Keep window structures flat - avoid complex nested overlay patterns
- Place interactive elements (buttons, toggles) as direct window children

### XPath OR Conditions for Multi-Mod Compatibility

Target multiple possible window names when other mods may rename elements:

```xml
<append xpath="/windows/window[@name='HUDLeftStatBars' or @name='RWSUI_LeftHUD']">
```

### RW_SimpleUI Compatibility

RW_SimpleUI is a popular HUD mod that **replaces** vanilla windows rather than modifying them:

- Creates **new window** `RWSUI_LeftHUD` instead of modifying `HUDLeftStatBars`
- The original `HUDLeftStatBars` name becomes an inner rect, not a window
- **Your mod must load AFTER RW_SimpleUI** to append to `RWSUI_LeftHUD`
- Prefix folder with `S_` or later letter to ensure correct load order
- Uses `<include filename="...">` for modular HUD variants (Horizontal, Vertical, Round, etc.)

### V2.5 Removed Items

These items were removed in V2.5 - xpath patches targeting them will fail:

- `medicalBloodDrawKit` - removed from items.xml

## Reference Mods

- **SphereII.Mods (SCore)**: <https://github.com/SphereII/SphereII.Mods> - extensive Harmony examples
- **Nexus Mods**: <https://www.nexusmods.com/7daystodie/mods> - community mods

## V2.5 Tested & Working Mods

- **Bigger Backpack Larger Storage And Quality Of Life**: <https://www.nexusmods.com/7daystodie/mods/7741> - 136 slot backpack, expanded storage, QoL features. Confirmed working great in V2.5.

## HemSoft Mods

- **HemSoft QoL v1.2.0** (`D:\github\hemsoft\7d2d-mods\S_HemSoft_QoL`): Inventory hotkeys (Q/Alt+X/Alt+R/S), HUD info panel (Level, Gamestage, Lootstage, Day, Blood Moon, Kills, Nearest Enemy, Enemy Count), `hs` console command
- **Folder name**: `S_HemSoft_QoL` - prefixed with `S_` to load after RW_SimpleUI

---

## History Tracking

All uses of this skill should be logged to `History/{YYYY-MM-DD}.md` with a one-line summary.
