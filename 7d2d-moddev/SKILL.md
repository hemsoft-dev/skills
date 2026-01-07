---
name: 7d2d-moddev
description: V1.2 - 7 Days to Die V2.5 mod development, compatibility, and best practices for XML, DLL, and Harmony mods.
---

# 7 Days to Die V2.5 Mod Development

Use this skill for creating, updating, or troubleshooting mods for 7 Days to Die version 2.5 (PC/Steam).

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

## Reference Mods
- **SphereII.Mods (SCore)**: https://github.com/SphereII/SphereII.Mods - extensive Harmony examples
- **Nexus Mods**: https://www.nexusmods.com/7daystodie/mods - community mods

## HemSoft Mods
- **HemSoft QoL v1.2.0** (`D:\github\hemsoft\7d2d-mods\HemSoft_QoL`): Inventory hotkeys (Q/Alt+X/Alt+R/S), HUD info panel (Level, Gamestage, Lootstage, Day, Blood Moon, Kills, Nearest Enemy, Enemy Count), `hs` console command

---

## History Tracking
All uses of this skill should be logged to `History/{YYYY-MM-DD}.md` with a one-line summary.
