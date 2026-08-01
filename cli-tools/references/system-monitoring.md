# System Monitoring

Read this file only for tools in the System monitoring category.

## btop - btop4win

| Field | Value |
|---|---|
| Author | aristocratos |
| Current version | 1.0.5, verified 2026-01-20 |
| Purpose | Monitor CPU, memory, disks, network, processes, and services in a terminal UI. |
| Requirements | Windows 10 version 1607 or newer; Windows Terminal recommended. |

```powershell
# Basic installation
scoop install btop

# Hardware-monitoring variant with LibreHardwareMonitor
scoop install btop-lhm

# Update and verify
scoop update btop
btop --version
scoop info btop

# Start
btop
```

- GitHub: <https://github.com/aristocratos/btop4win>
- Scoop search: <https://scoop.sh/#/apps?q=btop>

The `btop-lhm` variant requires administrator rights for GPU and temperature sensors. The basic package does not,
although elevated access can expose more process information.
