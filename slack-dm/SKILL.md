---
name: slack-dm
description: V1.5 - Send concise, structured Slack direct-message updates with an outcome, project, summary, category emoji, optional detail table, and available runtime metrics. Issue and pull-request updates must lead with the artifact ID and exact title. Use when an agent or scheduled automation needs to notify the owner through Slack.
disable-model-invocation: true
---

# Slack DM

Use this skill to send a Slack direct-message update. When the user does not
specify a format, always use the structured project, outcome, and summary
format below.

## Safety rules

- Treat DMs to Franz Hemmer (`U2XMZDPJ7`) as preauthorized when requested
  directly or included in a user-invoked workflow or scheduled automation.
  Send the workflow's one completion DM autonomously after its required gates.
  Do not ask for another recipient, payload, or send confirmation.
- Franz's 2026-09-05 instruction explicitly authorizes routine completion
  metadata for the processed repository, including a private repository:
  project name, artifact number/title/URL, outcome, merge SHA/method,
  validation/review results, cleanup, retained-work summary, and available
  metrics. Exclude credentials, raw private files, unrelated data, and other
  recipients. This authorization covers the final values discovered during
  the work; a separate message preview is not required for Franz.
- Supply that user authorization and exact destination as context when a tool
  requires it. Runtime restrictions still apply. Do not bypass a rejection or
  retry an unchanged rejected send; report the execution block and its stated
  reason. Do not claim that this workflow lacks user consent when it is already
  recorded.
- For every other recipient, show the exact recipient and exact message
  preview. Wait for clear approval before sending.
- Run the send command once only. Do not retry because output is blank or
  surprising.
- If the DM does not arrive, inspect the error and ask before trying again.
- Keep SSH and Slack tokens private. Never print `SLACK_TOKEN`.

## Message contract

Every message must begin with these three items in this order:

| Position | Content | Example |
| --- | --- | --- |
| 1 | Short outcome, on one line | `✅ PR #102 — Add saved-reset selection — merged` |
| 2 | Project, on one line | `📦 codexbar-ios` |
| 3 | One- or two-line summary | `The squash merge passed review and CI gates.` |

Follow these rules:

1. For every message about an issue or pull request, resolve the exact artifact
   ID and current title before composing the DM. Never send the message when
   either value is unknown.
2. Begin `--task` with the artifact ID and exact title, then state the result:
   `PR #<ID> — <exact title> — <result>` or
   `Issue #<ID> — <exact title> — <result>`. This is the first fallback line
   and the first visible Block Kit content. A titleless outcome such as
   `PR117 merged`, `PR #117 merged`, or `Issue #72 blocked` is prohibited.
3. For messages not about an issue or pull request, keep the outcome to a few
   words, such as `Release deployed`.
4. Keep the summary to one or two short sentences. Do not repeat the project
   or outcome.
5. Put multi-part implementation results in `--detail` rows. Do not turn the
   summary into a list.
6. Put links in `--url`. Do not insert a long raw URL into the first three
   lines.
7. Never pass a free-form blob. The helper intentionally requires structured
   arguments.
8. Put available runtime metrics in ordinary detail rows. Do not add them to
   the summary or send a follow-up message just to report a late metric.

Slack uses the same three-line hierarchy for the top-level fallback text.
This keeps notifications, History results, and screen-reader output
scannable. The opened message uses Block Kit and renders detail rows as a
table.

## Runtime metric detail rows

The caller owns measurement; the Slack helpers only render supplied values.
For agent or automation work:

- Add `Duration=<human-readable elapsed time>` when the caller measured the
  run, such as `Duration=42s`, `Duration=8m 17s`, or `Duration=1h 4m`.
- Add `Tokens=<exact cumulative count>` only when the runtime exposes an exact
  value before the message is sent, such as `Tokens=18,742`.
- Never estimate tokens from characters, transcript size, or elapsed time.
- Omit unavailable metrics instead of displaying guessed values or `unknown`.
- Send once only; do not send a second DM if a final token count appears after
  the approved notification.

These remain `--detail "Area=Result"` / `-Detail "Area=Result"` values so every
caller gets the existing detail table and accessible fallback behavior without
a new command interface. Slack documents
[table blocks](https://docs.slack.dev/reference/block-kit/blocks/table-block)
as the structured-data component for messages and recommends meaningful
[top-level fallback text](https://docs.slack.dev/block-kit/) for screen-reader
access.

## Category emoji

Choose exactly one category:

| Category | Emoji | Use for |
| --- | --- | --- |
| `merged` | ✅ | A pull request merged |
| `completed` | 🎯 | An issue or task completed |
| `review` | 🔍 | Review or audit results |
| `blocked` | 🚧 | Work that needs intervention |
| `failed` | 🚨 | Failed validation or execution |
| `deployed` | 🚀 | A release or deployment |
| `tests` | 🧪 | Test-focused results |
| `maintenance` | 🛠️ | Cleanup, dependency, or upkeep work |
| `info` | ℹ️ | Neutral information |

## Command path

Use the command for the active runtime:

| Runtime | Command prefix |
| --- | --- |
| Windows agent | `& "$HOME\.agents\skills\slack-dm\scripts\Send-SlackDm.ps1"` |
| macOS agent | `python3 "$HOME/.agents/skills/slack-dm/scripts/slack_dm.py"` |
| macOS Hermes | `python3 "$HOME/.hermes/skills/slack-dm/scripts/slack_dm.py"` |

## Step 1: Compose the update

Provide:

- `--project`: repository, product, or workstream name
- `--category`: one value from the category table
- `--task`: the short outcome
- `--summary`: one or two short sentences
- `--detail "Area=Result"`: optional; repeat for multi-part work
- `--url`: optional primary link

Example content:

```text
--project "codexbar-ios"
--category merged
--task "PR #102 — Add saved-reset selection — merged"
--summary "The squash merge passed review and CI gates."
--detail "Inventory=Added saved-reset selection flow"
--detail "Reliability=Added retry-safe redemption state"
--detail "Quality=Added accessibility coverage and tests"
--detail "Duration=8m 17s"
--detail "Tokens=18,742"
--url "https://github.com/HemSoft/codexbar-ios/pull/102"
```

## Step 2: Preview when required

Dry-run is the default and does not contact Slack. Use it for a non-owner
recipient or whenever a preview is useful:

```bash
python3 "$HOME/.agents/skills/slack-dm/scripts/slack_dm.py" \
  --user-id U2XMZDPJ7 \
  --project "codexbar-ios" \
  --category merged \
  --task "PR #102 — Add saved-reset selection — merged" \
  --summary "The squash merge passed review and CI gates." \
  --detail "Inventory=Added saved-reset selection flow" \
  --detail "Reliability=Added retry-safe redemption state" \
  --url "https://github.com/HemSoft/codexbar-ios/pull/102"
```

The preview prints the exact fallback text and Block Kit payload.

Windows agents use the same arguments with PowerShell parameter names:

```powershell
& "$HOME\.agents\skills\slack-dm\scripts\Send-SlackDm.ps1" `
  -UserId U2XMZDPJ7 `
  -Project "codexbar-ios" `
  -Category merged `
  -Task "PR #102 — Add saved-reset selection — merged" `
  -Summary "The squash merge passed review and CI gates." `
  -Detail "Inventory=Added saved-reset selection flow", `
          "Reliability=Added retry-safe redemption state" `
  -Url "https://github.com/HemSoft/codexbar-ios/pull/102"
```

## Step 3: Send once

Add `--confirm-send` to the approved command. DMs to the owner are already
authorized; other recipients require approval first.

```bash
python3 "$HOME/.agents/skills/slack-dm/scripts/slack_dm.py" \
  --user-id U2XMZDPJ7 \
  --project "codexbar-ios" \
  --category merged \
  --task "PR #102 — Add saved-reset selection — merged" \
  --summary "The squash merge passed review and CI gates." \
  --detail "Inventory=Added saved-reset selection flow" \
  --detail "Reliability=Added retry-safe redemption state" \
  --url "https://github.com/HemSoft/codexbar-ios/pull/102" \
  --confirm-send
```

On Windows, add `-ConfirmSend` to the preview command.

## Environment

The bot token must be available as `SLACK_TOKEN`, start with `xoxb-`, and
include:

- `im:write`
- `chat:write`
- `users:read.email` only when using `--email`

Check token presence without printing it:

```bash
test -n "$SLACK_TOKEN" && echo "SLACK_TOKEN is set" || echo "SLACK_TOKEN is missing"
```

Verify token identity without sending a message:

```bash
python3 "$HOME/.agents/skills/slack-dm/scripts/slack_dm.py" --auth-test
```

On Windows:

```powershell
& "$HOME\.agents\skills\slack-dm\scripts\Send-SlackDm.ps1" -AuthTest
```

## History

After using this skill, append an entry to `History/{YYYY-MM-DD}.md` in this
skill folder: `## HH:MM - {Action Taken}` plus a one-line summary naming the
recipient and category. Take the timestamp from the shell
(`Get-Date -Format "HH:mm"` on Windows, `date +%H:%M` elsewhere), never an
estimate.

## Troubleshooting

- `Permission denied: ...virtual_file.log`: the helper removes inherited
  `SSLKEYLOGFILE` settings before opening Slack HTTPS connections.
- `SLACK_TOKEN is not set`: add the bot token to the agent environment.
- `missing_scope`: the Slack app token lacks a required scope.
- `channel_not_found` or `not_allowed_token_type`: use a bot token (`xoxb-`)
  with DM scopes, not a user token.
- `user_not_found`: verify the Slack user ID or email.
- Argument errors about summary lines or lengths: shorten the message instead
  of bypassing the structured format.
