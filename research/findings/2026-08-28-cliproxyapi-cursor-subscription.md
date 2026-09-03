# Cursor subscriptions behind CLIProxyAPI

Research date: 2026-08-28

## Executive answer

The earlier conclusion that Cursor cannot feed models into CLIProxyAPI was too broad.

The official CLIProxyAPI 7.2.145 binary on Mini does not have a native Cursor login or provider. It can still route a Cursor subscription today through a second local service:

```text
Pi or another client
  -> CLIProxyAPI on Mini
  -> OpenAI-compatible Cursor sidecar on 127.0.0.1
  -> official Cursor CLI or ACP
  -> Cursor subscription models
```

The strongest current sidecar candidate is [`cursor-api-proxy`](https://github.com/anyrobert/cursor-api-proxy). Version 1.4.0 exposes `/v1/models`, `/v1/chat/completions`, `/v1/responses`, and `/v1/messages`, then invokes Cursor's official `agent` CLI or its official ACP mode. CLIProxyAPI's existing `openai-compatibility` provider can point at that loopback endpoint.

This is not a native provider and it is not a raw model API. Cursor's agent harness still sits in the request path. Expect added latency, context translation, and some compatibility work around tools and reasoning levels.

I would test this as a small, reversible pilot. I would not install an unmerged CLIProxyAPI branch that calls Cursor's private Connect-RPC endpoints.

## What ships in CLIProxyAPI 7.2.145

The exact `v7.2.145` source used on Mini defines login flags for Codex, Claude, Antigravity, Kimi, and xAI, but not Cursor. See [`cmd/server/main.go`](https://github.com/router-for-me/CLIProxyAPI/blob/v7.2.145/cmd/server/main.go#L95-L102).

Its supported configuration already includes generic OpenAI-compatible upstreams with a provider name, prefix, base URL, API keys, and explicit model aliases. See [`config.example.yaml`](https://github.com/router-for-me/CLIProxyAPI/blob/v7.2.145/config.example.yaml#L610-L649).

The 7.2.145 OpenAI-compatible executor translates normal inbound requests to OpenAI Chat Completions and sends them to `<base-url>/chat/completions`. That makes an OpenAI-compatible Cursor sidecar a valid architectural fit. See [`openai_compat_executor.go`](https://github.com/router-for-me/CLIProxyAPI/blob/v7.2.145/internal/runtime/executor/openai_compat_executor.go#L88-L145) and its [streaming path](https://github.com/router-for-me/CLIProxyAPI/blob/v7.2.145/internal/runtime/executor/openai_compat_executor.go#L307-L385).

CLIProxyAPI also has an in-process provider plugin ABI, but its [current official plugin registry](https://raw.githubusercontent.com/router-for-me/CLIProxyAPI-Plugins-Store/main/registry.json) contains no Cursor plugin. A plugin could implement this, but there is no supported artifact we can install from the official store today.

## Native Cursor work in the CLIProxyAPI repository

Several GitHub threads matter, and they do not all describe the same direction.

| Work | Current state | What it means |
| --- | --- | --- |
| [PR #5252](https://github.com/router-for-me/CLIProxyAPI/pull/5252) | Open, review required, build checks pass | Adds `-cursor-login`, Cursor models, and a Cursor executor. It directly implements Cursor's private login and `api2.cursor.sh` Connect-RPC protocol, including client fingerprints and checksums. It is not in 7.2.145 or `main`. |
| [PR #3651](https://github.com/router-for-me/CLIProxyAPI/pull/3651) and [PR #4055](https://github.com/router-for-me/CLIProxyAPI/pull/4055) | Open, review required | Add a Composer provider with an optional SDK bridge and a private-protocol fallback. Their own test plans still leave live chat-completion verification unchecked. |
| [PR #935](https://github.com/router-for-me/CLIProxyAPI/pull/935) | Closed without merge | Proposed spawning Cursor Agent CLI. A maintainer rejected it at the time because the project did not accept third-party reseller providers. |
| [Issue #4609](https://github.com/router-for-me/CLIProxyAPI/issues/4609) | Closed | The reporter was already using an external local wrapper through `openai-compatibility` and requested native support. This confirms the sidecar pattern predates the new native PR. |
| [Issue #2696](https://github.com/router-for-me/CLIProxyAPI/issues/2696) | Closed as not planned | Requested Cursor subscription support and was pointed to a separate community bridge. |

The open native PR is evidence that native support is technically possible. It is not evidence that the project supports it in a released build. Its direct use of private endpoints also creates a policy problem.

## Cursor's supported paths and policy boundary

Cursor officially supports:

- Browser or API-key authentication for its CLI. See [Cursor CLI authentication](https://docs.cursor.com/en/cli/reference/authentication).
- Non-interactive CLI runs with structured JSON or NDJSON. See [output formats](https://docs.cursor.com/en/cli/reference/output-format).
- ACP over `stdio` for custom clients and integrations. See [Cursor's ACP documentation](https://prod.cursor.com/docs/cli/acp).
- First-party TypeScript and Python SDKs plus the local [SDK Bridge](https://prod.cursor.com/docs/sdk/bridge).

Cursor does not publish a raw OpenAI-compatible inference endpoint. A Cursor forum administrator, Dean Rie, states that the supported external paths are the Cursor CLI, Agent SDK or headless mode, and the Cloud Agents API. He also states that all of them run the Cursor agent harness. The same response says that third-party clients calling private, non-public endpoints violate Cursor's use restrictions and can trigger account enforcement. See the [forum response](https://forum.cursor.com/t/does-using-oh-my-pi-s-cursor-provider-or-an-openai-compatible-proxy-to-the-same-endpoints-violate-cursor-s-tos/167778/5) and [Cursor's current terms, section 1.5](https://cursor.com/terms-of-service#1-access-and-use).

That distinction matters:

- A wrapper that spawns the official Cursor CLI or communicates through official ACP is built on a supported integration path.
- A provider that reconstructs Cursor's private `api2.cursor.sh` client protocol is not. PR #5252 and Oh My Pi's direct Cursor provider fall into this second category.

This is a product-risk reading, not legal advice. The official CLI or SDK path is clearly the safer choice.

## The practical sidecar

[`cursor-api-proxy`](https://github.com/anyrobert/cursor-api-proxy) is a community OpenAI-compatible adapter for the official Cursor CLI. Its current npm release is `1.4.0`, requires Node 18 or newer, and has no install-time script in its package manifest. It can use normal `agent login` state or `CURSOR_API_KEY`.

The bridge dynamically reads `agent --list-models`. Cursor's own current model catalog includes GPT-5.6 Sol, Luna, and Terra, and the community bridge has live reports using `gpt-5.6-sol-high`. See [Cursor's model catalog](https://cursor.com/docs) and [`cursor-api-proxy` issue #39](https://github.com/anyrobert/cursor-api-proxy/issues/39).

The bridge's tool support has moved quickly. An August report showed ACP tools were not forwarded, but [PR #38](https://github.com/anyrobert/cursor-api-proxy/pull/38) added stateful ACP tool passthrough and merged into 1.4.0. This deserves a real Pi tool-loop test before relying on it.

Known limits remain:

- Reasoning controls are not fully normalized. [Issue #39](https://github.com/anyrobert/cursor-api-proxy/issues/39) tracks mapping OpenAI `reasoning_effort` to Cursor's model IDs such as `gpt-5.6-sol-high`.
- One open report measured more than a minute per request. The maintainer added a benchmark to separate CLI startup, inference, ACP, and proxy overhead. See [issue #37](https://github.com/anyrobert/cursor-api-proxy/issues/37).
- The model is behind Cursor's agent harness, not a raw completion endpoint. System instructions and behavior may differ from the same underlying GPT model through Codex or OpenAI.
- The sidecar's token counts are estimates and are not Cursor billing meters.
- The project is community-maintained. Pin the npm version and audit upgrades.

Reddit posts are consistent with the repository evidence, but they are secondary sources. The [LocalLLM launch thread](https://www.reddit.com/r/LocalLLM/comments/1rdye8q/i_built_an_openaicompatible_local_proxy_to_expose/) describes the official-CLI wrapper. A later [Cursor policy thread](https://www.reddit.com/r/cursor/comments/1vkk4yw/does_using_oh_my_pis_cursor_provider_or_an/) distinguishes that approach from direct use of private Cursor endpoints and links to the Cursor forum response above.

## Recommended Mini pilot

1. Install Cursor's official `agent` CLI on Mini under a dedicated service account.
2. Authenticate that service account through `agent login`, or use a Cursor Dashboard API key stored as a systemd credential. Do not copy a desktop database or private access token.
3. Install and pin `cursor-api-proxy@1.4.0` as a separate systemd service.
4. Bind the sidecar to `127.0.0.1` only. Require a separate random bridge API key even on loopback.
5. Start with `CURSOR_BRIDGE_USE_ACP=true`, `CURSOR_BRIDGE_CHAT_ONLY_WORKSPACE=true`, `CURSOR_BRIDGE_VERBOSE=false`, and an explicit `CURSOR_AGENT_BIN` path.
6. Add an `openai-compatibility` entry to CLIProxyAPI with `name: cursor`, `prefix: cursor`, and `base-url: http://127.0.0.1:8765/v1`.
7. Populate only the models returned by Mini's live `agent --list-models`. Do not assume every Cursor plan exposes every model or reasoning variant.
8. Validate in this order: direct sidecar text, direct sidecar tool call, CLIProxyAPI Chat Completions, CLIProxyAPI Responses translation, then a real Pi tool round trip.
9. Measure first-token and total latency against the existing `mini-openai` route before deciding whether to keep it.

A representative CLIProxyAPI entry would look like this after the live model list is known:

```yaml
openai-compatibility:
  - name: "cursor"
    prefix: "cursor"
    base-url: "http://127.0.0.1:8765/v1"
    api-key-entries:
      - api-key: "<separate-loopback-secret>"
    models:
      - name: "gpt-5.6-sol"
        alias: "gpt-5.6-sol"
        display-name: "GPT 5.6 Sol via Cursor"
        max-context-length: 272000
        input-modalities: [text, image]
        output-modalities: [text]
```

The exact model ID and context value must come from Mini's authenticated Cursor catalog. Cursor's public page currently lists GPT-5.6 Sol with a 272K default context and a 1M maximum, but the CLI can expose separate normal, reasoning, fast, and max variants.

## Pi naming caveat

Adding Cursor to the same CLIProxyAPI instance does not by itself produce both `[mini-openai]` and `[mini-cursor]` in Pi.

The Pi CLIProxyAPI extension has one global `providerId`. It maps each CLIProxyAPI catalog `slug` to a Pi model ID. With the current `CLIPROXYAPI_PROVIDER_ID=mini-openai`, a Cursor-prefixed model would appear as:

```text
cursor/gpt-5.6-sol [mini-openai]
```

See the extension's [provider configuration and catalog mapping](https://github.com/router-for-me/pi-cliproxyapi-provider#non-interactive-configuration).

To get the exact bracket labels the user requested:

```text
gpt-5.6-sol [mini-openai]
gpt-5.6-sol [mini-cursor]
```

Pi needs two provider registrations, each filtered to one route, or two explicit static providers that point to the corresponding prefixed model IDs. A cleaner single-provider alternative is to rename the global provider to `[mini-proxy]` and keep the origin in the model ID:

```text
personal-pro/gpt-5.6-sol [mini-proxy]
cursor/gpt-5.6-sol       [mini-proxy]
```

This naming decision is separate from making the Cursor upstream work.

## Bottom line

Yes, a paid Cursor subscription can be placed behind CLIProxyAPI on Mini. The released CLIProxyAPI build cannot do it natively, and a YAML-only Cursor credential is not enough. The sensible route today is a loopback sidecar that uses Cursor's official CLI or ACP, then a normal CLIProxyAPI `openai-compatibility` entry.

That setup should remain a pilot until a real Pi tool loop and latency test pass. Native private-endpoint branches may be faster, but Cursor has explicitly warned against that access pattern.
