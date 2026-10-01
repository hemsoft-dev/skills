# Browser access maintenance

Verified 2026-09-30. The endpoint and session map is in the main fleet skill.

## Routing and credentials

All four domain names have DNS-only A records pointing to Mini's Tailscale IP.
Caddy listens on Mini's Tailscale addresses, HTTPS port 443. No public tunnel or
Funnel. Tailnet ACLs control access; this is not a separate per-user web login.
Mini must stay online even for Home and Air terminals.

Mini's system service is `herdr-gateway.service`. Its configuration and
zone-scoped Cloudflare DNS credential are under
`~/.config/herdr-gateway/`; keep the credential file private, mode 0600.
Caddy renews domain certificates through DNS-01. Never copy the token into
skills, logs, or transfer packages.

The gateway proxies the dashboard to Mini port 8788, Mini's ttyd to localhost
7681, and Home/Air through user SSH tunnel services `herdr-home-tunnel` and
`herdr-air-tunnel`, on localhost 7682/7683. Each remote ttyd binds localhost
7681. The gateway supplies ttyd's required auth header. Preserve origin checks,
loopback binding, and Home's unrelated Tailscale Serve routes. The original
[Mini Tailscale URL](https://mini.tail3280fc.ts.net/) remains an alias.

## Terminal services

| Host | Browser frontend | Persistent Herdr session |
| --- | --- | --- |
| Mini | User systemd `herdr-web.service` | `herdr-browser.service`, session `browser` |
| Home | Scheduled task `herdr-web`, launcher `~/herdr-web/run-herdr-web.vbs` | Existing `default` server |
| Air | LaunchAgent `com.hemsoft.herdr-web` | Existing `default` server |

All use ttyd `--writable --check-origin --auth-header Tailscale-User-Login
--max-clients 8`. The former limit of one rejected second tabs/devices with a
reconnect prompt. Restart only the affected browser frontend after changes;
verify the persistent Herdr server PID remains unchanged. Never stop Herdr or
working agents to fix a browser connection.

## Verification and deployment

- Check DNS, certificate validation, HTTP, then the actual WebSocket and terminal
  rendering. HTTP 200 alone is insufficient. Test simultaneous desktop and
  tablet-sized clients without sending input to working agents. Terminal
  WebSocket probes need subprotocol `tty` and the matching HTTPS Origin;
  mismatched origins must fail.
- For 502 errors, inspect the gateway, SSH tunnel, and frontend logs. A reconnect
  prompt can mean the browser-client limit is full or the attached client exited.
- The dashboard reads Herdr snapshots without input/focus changes. Its live
  counts exclude tmux; existing session history and usage remain separate.
- Dashboard feature source is currently the `feat/herdr-fleet` worktree at
  `D:\github\HemSoft\hs-pi-dashboard.worktrees\herdr-fleet`. Preserve its pending
  changes. Use its `deploy/build_fleet.py` for explicit OS/architecture builds.
  Validate Linux x86_64 ELF, Windows x86_64 PE, or macOS ARM64 Mach-O before
  deployment. A Windows executable mislabeled as Linux caused an actual outage.
  Verify the public HTTPS endpoint after the service finishes starting, not just
  a successful restart command.
