---
name: fleet
description: "V1.5 - Commands: Connect, Run, Send, Retrieve. Operate the private five-computer Tailscale fleet across laptop, home, air, mini, and amd, including amd's local-inference stack."
disable-model-invocation: true
---

# Fleet

Use the SSH aliases `laptop`, `home`, `air`, `mini`, and `amd`. They route over the
private Tailscale network. Verify an alias from its source machine before
declaring that direction ready.

## Default behavior

When the user invokes this skill without specifying a command, identify the
current machine, report the five fleet aliases and their live Tailscale status,
then ask which machine and operation to use. Do not start interactive SSH or
transfer files without a specific destination and action.

## Machine map

| Alias | Platform | SSH account | Tailscale hostname | Tailscale IPv4 | User home |
| --- | --- | --- | --- | --- | --- |
| `laptop` | Windows | `User` | `desktop-7es73q4` | `100.117.202.124` | `C:\Users\User` |
| `home` | Windows | `User` | `desktop-phubt5b` | `100.101.122.39` | `C:\Users\User` |
| `air` | macOS | `home` | `franzs-macbook-air` | `100.69.182.27` | `/Users/home` |
| `mini` | Ubuntu 26.04 | `franz` | `mini` | `100.97.164.73` | `/home/franz` |
| `amd` | AMD Ryzen AI Developer Platform 1 | `franz` | `amd` | `100.113.233.103` | `/home/franz` |

Prefer aliases over IP addresses. Treat IP addresses and underlying hostnames
as diagnostics and fallbacks, not user-facing names.

## `amd` local-inference host

`amd` is the RAH-001 AMD Ryzen AI Halo Developer Platform: Ryzen AI Max+ 395,
Radeon 8060S (`gfx1151`), XDNA 2 NPU, 128 GB unified memory, and a 2 TB NVMe
drive. It runs AMD Ryzen AI Developer Platform 1 (`rex`), a Debian-derived,
AMD-curated Linux image. AMD's Developer Center is the live authority for the
installed Best Known Configuration. See
[references/amd-ryzen-ai-developer-platform.md](references/amd-ryzen-ai-developer-platform.md)
for the researched platform design, supported serving paths, and primary-source
links.

Do not equate platform support, an installed launcher, a cached container image,
or a downloaded model with an active server. For inventory-only requests, do not
install software, download models, load models, or start or stop inference
services unless the user explicitly asks.

Live baseline verified on 2026-08-16:

| Component | Installed state | Serving state |
| --- | --- | --- |
| AMD Ryzen AI Developer Center | `halo-lp` 1.2.0 | Active on loopback port `10000` |
| Lemonade Server | 10.5.1 | Active on HTTP port `13305`; the five fleet machines are allowed over Tailscale; auto-loads one text model at a time |
| vLLM | AMD-managed `ryai-vllm:latest` image, reported as v0.21.0, plus `vllm-launch` | Container stopped; no listener; launcher default is loopback port `8001` |
| ComfyUI | AMD-managed `ryai-comfyui:latest` image, reported as v0.21.1 | Container stopped; socket activation listens on loopback port `8188` |
| llama.cpp | Build 9413 with HIP/ROCm support | `llama-server.service` disabled and inactive |
| Ollama | 0.32.14 with the AMD ROCm package | Active on port `11434`; nftables currently permits localhost and `home` only |
| OpenCode | 1.18.18 in `/home/franz/.opencode/bin` | Configured for AMD Ollama, AMD Lemonade, OpenCode Go, and OpenCode Zen |
| PyTorch / ROCm | `therock-gfx1151` 7.13.0 and ROCm-enabled PyTorch 2.10.0 | Libraries installed; not a standalone model server |

Lemonade reports these downloaded models:

- `Qwen3-Coder-30B-A3B-Instruct-Q4_K_M`
- `gpt-oss-120b-Q4_K_M`

They are custom GGUF imports. Use the API model IDs
`extra.Qwen3-Coder-30B-A3B-Instruct-Q4_K_M` and
`extra.gpt-oss-120b-Q4_K_M`; the unprefixed IDs returned by `/v1/models` make
Lemonade 10.5.1 attempt a failing Hugging Face lookup. Their saved context
sizes are 262,144 and 131,072 tokens, respectively.

The shared `/var/cache/models` also contains the AMD-provided GPT-OSS 20B,
Qwen3-Coder 30B, GPT-OSS 120B, and Z Image Turbo assets. vLLM and ComfyUI images
are preloaded in Podman's shared image store. Podman is the container runtime;
the `docker` command is Podman compatibility, not a Docker daemon.

### Lemonade service on `amd`

Lemonade exposes its OpenAI-compatible API to the five-machine fleet at:

```text
http://100.113.233.103:13305/api/v1
```

Use `extra.gpt-oss-120b-Q4_K_M` or
`extra.Qwen3-Coder-30B-A3B-Instruct-Q4_K_M` as the request model ID. Lemonade
advertises the same names without `extra.`, but the prefix is required for these
custom imports on Lemonade 10.5.1. The configured API-key placeholder is
`lemonade` for clients that require a non-empty OpenAI key.

`lemond` binds IPv4 port `13305` on all interfaces so localhost and Tailscale
clients both work. Access is still restricted by
`/etc/nftables.d/lemonade-tailnet.nft`, which explicitly allows `laptop`,
`home`, `air`, and `mini` through `tailscale0`, allows local access on `amd`,
then drops every other source. The WebSocket listener on port `9000` is limited
to local access by the same policy. Do not remove or broaden the final drop
rules.

The persistent firewall unit is
`/etc/systemd/system/lemonade-tailnet-firewall.service`. The Lemonade bind
override is `/etc/systemd/system/lemond.service.d/network.conf`. Both the
firewall unit and `lemond.service` are enabled, and `lemond.service` requires
the firewall unit so the API does not start without its allowlist.

Before admitting another machine, confirm its live Tailscale IPv4, add one
explicit `tailscale0` source rule above the final drop rule, reload
`lemonade-tailnet-firewall.service`, and prove `/api/v1/models` plus one
inference request from that machine.

### Ollama service on `amd`

Ollama serves `qwen3.8:27b` from `amd` through the Radeon 8060S ROCm backend.
The model is 17 GB and reports vision, tools, thinking, and completion
capabilities. The service configuration is:

- Native API: `http://100.113.233.103:11434/api`
- OpenAI-compatible base URL: `http://100.113.233.103:11434/v1`
- Context window: `OLLAMA_CONTEXT_LENGTH=262144`, the model's advertised maximum
- Processor after loading: `100% GPU`
- Cloud models disabled with `OLLAMA_NO_CLOUD=true`
- One Ollama model loaded at a time with `OLLAMA_MAX_LOADED_MODELS=1`

Initial rollout scope is `home` only. `/etc/nftables.d/ollama-tailnet.nft`
allows loopback and Home's Tailscale IPv4 `100.101.122.39`, then drops every
other connection to TCP port `11434`. The persistent
`ollama-tailnet-firewall.service` starts before and is bound to
`ollama.service`; do not remove or bypass it. The Ollama override lives at
`/etc/systemd/system/ollama.service.d/network.conf`.

From `home`, use the remote server for one PowerShell session without changing
the normal local Ollama default:

```powershell
$previousOllamaHost = $env:OLLAMA_HOST
try {
    $env:OLLAMA_HOST = 'http://100.113.233.103:11434'
    ollama list
    ollama run qwen3.8:27b
} finally {
    if ($null -eq $previousOllamaHost) {
        Remove-Item Env:OLLAMA_HOST -ErrorAction SilentlyContinue
    } else {
        $env:OLLAMA_HOST = $previousOllamaHost
    }
}
```

Before admitting another fleet machine, confirm its live Tailscale IPv4, add
one explicit source-address accept rule above the final drop rule, reload
`ollama-tailnet-firewall.service`, and prove `/v1/models` plus one inference
request from that machine. Never replace the source allowlist with a public or
LAN-wide bind rule.

### OpenCode on `amd`

OpenCode 1.18.18 is installed for `franz`; the installer added
`/home/franz/.opencode/bin` to `.bashrc`. Its global model configuration is
`/home/franz/.config/opencode/opencode.json`, and its credential store is
`/home/franz/.local/share/opencode/auth.json`. Both files are mode `600`.

The default is `amd-ollama/qwen3.8:27b`. The configured local choices are:

- `amd-ollama/qwen3.8:27b`: 262,144 context, 16,384 output
- `amd-lemonade/extra.Qwen3-Coder-30B-A3B-Instruct-Q4_K_M`: 262,144 context, 16,384 output
- `amd-lemonade/extra.gpt-oss-120b-Q4_K_M`: 131,072 context, 16,384 output

The credential store contains only OpenCode Go and OpenCode Zen credentials.
Zen was validated with `opencode/deepseek-v4-flash-free`. Go authentication is
valid, but its workspace currently rejects inference at the $50 monthly
spending limit; re-check that live state before treating Go as usable.

OpenCode 1.18.18 has a non-interactive stdin bug. Over SSH or from automation,
close stdin even when the prompt is supplied as an argument:

```bash
ssh amd 'opencode run --model amd-ollama/qwen3.8:27b "Reply OK" < /dev/null'
```

Without `< /dev/null`, `opencode run` can remain at `message=init` without
creating a session or contacting the model. Interactive `opencode` TUI use is
not affected.

Use these read-only checks before reporting current state because AMD updates can
change the baseline:

```bash
ssh amd "lemonade status"
ssh amd "lemonade list"
ssh amd "systemctl is-active lemond halo-lp llama-server"
ssh amd "systemctl is-enabled lemond halo-lp llama-server"
ssh amd "ss -lntp"
ssh amd "curl -fsS http://127.0.0.1:10000/api/container-status"
ssh amd "curl -fsS http://127.0.0.1:10000/api/package-info"
```

Use root only when the unprivileged checks cannot expose system-wide state. To
inspect Franz's rootless containers without starting them:

```bash
ssh root@amd "cd /home/franz && runuser -u franz -- env HOME=/home/franz XDG_RUNTIME_DIR=/run/user/1001 podman ps -a"
```

The documented AMD vLLM route is GPU inference through ROCm, launched with
`vllm-launch` and exposed as an OpenAI-compatible API. Ollama is compatible with
the hardware but optional and separately installed. Lemonade provides another
OpenAI-compatible local API and can manage llama.cpp, vLLM, image, speech, and
other recipe backends; a backend marked `installable` is not installed.

## Connect and run commands

- Connect interactively with `ssh laptop`, `ssh home`, `ssh air`, `ssh mini`, or `ssh amd`.
- Test noninteractively with `ssh -o BatchMode=yes -o ConnectTimeout=10 <alias> "echo connected"`.
- Invoke PowerShell explicitly for nontrivial commands on `laptop` or `home`.
- Use the normal remote shell on `air`, `mini`, or `amd`.
- `mini` and `amd` use Tailscale SSH. The tailnet's self-device SSH rule uses
  `accept`, so automation should not require an additional web check.
- Never disable SSH host-key checking. If a host-key mismatch appears, stop and report it.
- Use SSH for shells and remote commands only. Do not use FTP, SCP, or SFTP for file sharing.

## Tailscale CLI

Use Tailscale's native Taildrop commands for files. Resolve the CLI in this
order:

- Run `tailscale` if it is on `PATH`.
- On Windows, fall back to `C:\Program Files\Tailscale\tailscale.exe`.
- On air, fall back to `/Applications/Tailscale.app/Contents/MacOS/Tailscale`.

Taildrop target names differ from the friendly aliases:

| Friendly alias | Taildrop target |
| --- | --- |
| `laptop` | `desktop-7es73q4` |
| `home` | `desktop-phubt5b` |
| `air` | `franzs-macbook-air` |
| `mini` | `mini` |
| `amd` | `amd` |

Confirm the current target list with `tailscale file cp --targets` when
diagnosing a delivery problem.

## Shared transfer convention

Every machine has the same tree beneath its user home:

```text
TailscaleShare/
├── Inbox/
│   ├── from-laptop/
│   ├── from-home/
│   ├── from-air/
│   ├── from-mini/
│   └── from-amd/
└── Outbox/
    ├── to-laptop/
    ├── to-home/
    ├── to-air/
    ├── to-mini/
    └── to-amd/
```

Use these meanings consistently:

- `Inbox/from-<sender>/` is the delivery point on the receiving machine.
- `Outbox/to-<recipient>/` is the pickup point on the sending machine.
- Stage outbound files in `Outbox/to-<recipient>/` when practical, then send them with Taildrop.
- Prefix the Taildrop filename with `from-<sender>--` so the recipient can route it to the matching Inbox subfolder.
- The installed Windows and macOS desktop clients automatically receive Taildrop files in the user's `Downloads` directory.
- After receiving, move each `from-<sender>--<name>` file into `Inbox/from-<sender>/<name>`.

## Send and retrieve files

Determine the current machine and use its alias as `<sender>`. Convert the
recipient alias to its Taildrop target with the table above.

Send one file:

```text
tailscale file cp --name "from-<sender>--<filename>" "<local-file>" <recipient-taildrop-target>:
```

Desktop pickup locations:

```text
laptop: C:\Users\User\Downloads
home:   C:\Users\User\Downloads
air:    /Users/home/Downloads
mini:   /home/franz/Downloads
amd:    /home/franz/Downloads
```

On `mini` or `amd`, receive its CLI Taildrop inbox with
`tailscale file get --conflict=rename /home/franz/Downloads`. Do not run
`tailscale file get` routinely on the desktop clients.

`mini` and `amd` are configured with Tailscale operator `franz`. After rebuilding
a Linux host, restore non-root Taildrop access once with:

```bash
sudo tailscale set --operator=$USER
```

Taildrop sends files, not directory trees. Archive a directory first, send the
archive, and keep or remove that archive according to the user's request.

## Transfer procedure

1. Resolve the source machine, destination machine, and exact source path.
2. Confirm the recipient appears in `tailscale file cp --targets`.
3. Stage the file in `Outbox/to-<recipient>/` when useful.
4. Send it with `tailscale file cp`, using the `from-<sender>--` filename prefix.
5. On the recipient, wait for the completed Taildrop file to appear in `Downloads`; the send command can return before the desktop client finishes placing it.
6. Move it to `Inbox/from-<sender>/`, removing only the routing prefix. Do not silently overwrite.
7. Verify the destination exists and compare byte size; use SHA-256 for important files.
8. Report the destination alias and native absolute path. Keep the source unless the user explicitly asks to move or delete it.

Use these native pickup paths when reporting completion:

- laptop: `C:\Users\User\TailscaleShare\Inbox\from-<sender>\`
- home: `C:\Users\User\TailscaleShare\Inbox\from-<sender>\`
- air: `/Users/home/TailscaleShare/Inbox/from-<sender>/`
- mini: `/home/franz/TailscaleShare/Inbox/from-<sender>/`
- amd: `/home/franz/TailscaleShare/Inbox/from-<sender>/`

Taildrop is the file-sharing transport. Do not substitute FTP, SCP, SFTP,
public links, or email attachments unless the user explicitly asks. Do not
expose SSH beyond Tailscale or copy private SSH keys between machines.
