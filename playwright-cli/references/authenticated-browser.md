# Authenticated browser and password-manager access

Use this workflow when browser work needs an existing login, SSO, MFA, or an
installed browser extension such as LastPass.

## Preferred architecture

Use the official Microsoft Playwright Extension to attach Playwright CLI to a
real Chrome profile. Extension mode reuses that profile's tabs, cookies,
sessions, and installed extensions. It avoids copying passwords into prompts or
launching a disposable browser that cannot see the password manager.

Official sources:

- [Playwright browser-extension connection](https://playwright.dev/mcp/configuration/browser-extension)
- [Microsoft Playwright Extension](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm)
- [Playwright Extension source and security token setup](https://github.com/microsoft/playwright/blob/main/packages/extension/README.md)
- [Chrome remote-debugging restrictions](https://developer.chrome.com/blog/remote-debugging-port)

Do not point Playwright at a person's normal Chrome data directory through
`open --profile`. A live profile can be locked or corrupted, and Chrome 136 and
later reject remote-debugging switches against the default data directory.
Extension attachment is the supported route for a normal signed-in profile.

## GitHub media attachments

Do not use a browser to upload screenshots or videos to GitHub when GitHub CLI
2.99.0 or newer can complete the task. Use the repeatable `--attach` flag on
`gh issue create`, `gh issue edit`, `gh issue comment`, `gh pr create`, `gh pr
edit`, or `gh pr comment`. Follow the shared UI evidence policy for local-path
rewriting, alt text, inline video placement, and verification.

If the active CLI is older, upgrade it through the approved package manager.
Use browser upload only when the target GitHub host or environment cannot use
the supported CLI attachment flow. If an attached browser identity cannot read
the target repository, stop. Never open a login form, add or switch browser
accounts, or invoke password-manager autofill solely to upload GitHub evidence.

## Preflight

On a skill host with Node.js, run the read-only health check first:

```bash
node scripts/browser-auth-preflight.mjs --profile=Default
```

The script checks Playwright CLI, the selected Chrome profile, LastPass, and the
Playwright Extension without reading either extension's storage. A nonzero exit
means authenticated attachment is not ready.

1. Run `playwright-cli --version` and require a version that supports
   `attach --extension`.
2. Run `playwright-cli list --all --json`. Confirm the intended channel reports
   `extensionInstalled: true`.
3. Confirm the password-manager extension is installed and enabled in the same
   Chrome profile. On Chrome, inspect the profile's extension settings rather
   than assuming that an extension installed in another profile is available.
4. Identify the exact browser profile and account context before acting. Do not
   guess from the last active tab.
5. Classify the task as public browsing, disposable test authentication, or
   access to a real authenticated account. Use extension mode only for the last
   category or when the page depends on an installed extension.

## Attach and detach

Use a named session so authenticated work cannot collide with disposable tests:

```bash
playwright-cli -s=authenticated attach --extension=chrome
playwright-cli -s=authenticated tab-list
```

The extension asks the browser user to approve a new connection by default.
Keep that approval step until the connection and tab isolation have been tested.
Several clients may connect at once, but each receives a separate browser tab
group. Run `tab-list` immediately after attachment. If the group contains an
unexpected existing tab, do not inspect or alter it. Detach and have the user
move only the intended tab into a clean group before retrying. An approved
connection does not make every visible tab in scope.

When finished, close only the task tabs created by the agent, then detach
instead of closing the user's browser:

```bash
playwright-cli -s=authenticated tab-close <task-tab-index>
playwright-cli -s=authenticated detach
```

Keep a tab ledger for the session. Record the connection tab and each task tab
created by the agent. Reuse the current task tab with `goto`; do not stack
`tab-new` retries. Never close a pre-existing user tab. If a site opens a window
outside the attached context, stop creating tabs and use the visual fallback
below.

## Unattended connection token

The Playwright Extension can issue a profile-specific connection token. The CLI
reads it from `PLAYWRIGHT_MCP_EXTENSION_TOKEN` and can then connect without the
approval dialog.

Treat this token as a credential because it authorizes browser attachment. A
permanent machine-scoped environment variable exposes it to more processes and
users than needed. Prefer an operating-system secret store or, when the official
environment-variable mechanism is required, a user-scoped value on a dedicated
agent account.

Never run raw `playwright-cli attach --extension` with the token in an
agent-visible terminal. Playwright's normal attach receipt includes the
connection URL and token, and it can write the URL to snapshot or console
artifacts. On Windows, use the suppressing wrapper and pass the authorized start
URL:

```powershell
./scripts/attach-authenticated.ps1 -Url https://example.com -Session authenticated
```

The wrapper reads the token without printing it, routes attach artifacts to a
temporary directory, suppresses the token-bearing receipt and existing tab
inventory, opens the authorized URL in one new task tab, and removes the
temporary artifacts.

The attach wrapper does not make later direct CLI commands safe. Normal output
from `eval`, `tab-list`, `snapshot`, `click`, and other commands can append an
`Open tabs` section containing the token-bearing connection URL. Run every
attached-session command through the safe command wrapper:

```powershell
./scripts/invoke-attached-safely.ps1 `
  -Session authenticated `
  -Command eval `
  -CommandArguments '({ origin: location.origin, title: document.title })'
```

The command wrapper forces `--raw`, uses a temporary artifact directory,
redacts the exact configured token and connection URLs, bounds returned text,
and deletes temporary output. For authenticated or private pages, make eval and
run-code return only the minimum booleans, origins, paths, counts, and status
needed for the next action. Do not return body text, account lists, messages, or
form values.

Never put the token in a repository, skill, shell profile, history file,
transcript, command-line argument, screenshot, or browser storage export. Never
print it while diagnosing a connection. If it appears in output or an artifact,
detach and delete the exact local artifact. Report the exposure once. Follow the
user's decision about rotation; do not turn the task into repeated token
rotation. Until the user rotates, avoid new unattended attachments when a safer
existing session or computer-use path can finish the work.

Enable unattended attachment only after a supervised test proves all of these:

- the selected profile is correct;
- client tab groups limit the agent to intended tabs;
- disconnect and revocation work;
- the agent cannot silently attach to another profile; and
- the user understands that an attached agent acts with the permissions of the
  signed-in browser session.

Browser attachment grants access, not authority. Existing workflow rules still
decide whether the agent may submit a form, change settings, make a purchase,
publish content, merge code, or perform another consequential action.

## LastPass workflow

Prefer an existing authenticated site session. Use LastPass only when the site
actually presents a login form.

1. Verify the exact HTTPS origin before requesting autofill. Stop on lookalike
   domains, unexpected redirects, certificate errors, or embedded login forms
   from an unverified origin.
2. Let the LastPass content script offer or perform autofill in the page. Use
   page elements or keyboard interaction exposed through Playwright before
   reaching for browser-toolbar UI.
3. Do not read LastPass IndexedDB, extension storage, network traffic, vault
   pages, password-field values, or copied credentials. Do not use JavaScript to
   extract an autofilled password. The goal is to submit the form without the
   model learning the secret.
4. Do not include login fields, one-time codes, recovery codes, or vault content
   in screenshots, videos, traces, snapshots, logs, or saved storage state.
5. If LastPass is locked, ask for one vault-unlock action. Never store or request
   the master password. Resume after the extension is unlocked.
6. Allow LastPass to fill a compatible TOTP only when the current task already
   authorizes the login. Hardware-key, biometric, CAPTCHA, passkey, and explicit
   consent prompts remain human steps unless an approved tool provides that
   capability without weakening the control.
7. Confirm successful authentication by page state, account identity, and
   expected origin. Never prove it by exposing cookie or credential values.

A toolbar popup belongs to browser chrome, not the web page. If page-level
LastPass controls are unavailable, try opening the extension's popup or status
page as a normal `chrome-extension://` tab through Playwright once. If Chrome
blocks it or the popup leaves the Playwright context, capture the visible window
and continue with Pi computer use. Click LastPass's fill action without reading
vault entries or password-field values. Ask the user only for a master-password
entry, MFA approval, CAPTCHA, biometric prompt, or hardware-key touch that the
agent cannot safely perform.

## Session-state rules

Do not run `state-save` against a personal or broad work profile merely to avoid
future logins. Storage-state files contain bearer cookies and may contain
IndexedDB data. Prefer extension attachment so the state remains in Chrome.

Use `state-save` only for a dedicated test identity when the repository's test
policy permits it. Store the file outside the repository or in a gitignored,
access-controlled location, record its scope and expiry, and delete it when the
task ends or the session is revoked.

Traces, videos, screenshots, console output, and network logs can also capture
secrets. Start them after authentication when possible and review them for
sensitive data before retaining or publishing them.

## Visual escalation

Rendered evidence outranks process titles, cached profile checks, and assumed tab
state. If the user says the browser shows something different, inspect it before
acting again.

Escalate after one failed Playwright approach when any of these occurs:

- the visible browser window or authentication popup is missing from `tab-list`;
- a navigation changes browser process or context and Playwright loses the page;
- browser chrome, the address bar, a toolbar extension, or a permission dialog is
  required;
- Chrome reports an internal error such as `ERR_BLOCKED_BY_CLIENT`;
- the CLI claims success but the rendered page was not verified; or
- another page steals focus and the active tab is uncertain.

Take a screenshot first. Use Pi computer use to inspect the exact window, tab,
visible origin, and controls. Prefer semantic accessibility targets. Use
coordinates only when the control has no semantic representation. Continue the
same authorized workflow without asking the user to perform routine clicks.
Return to Playwright when the page becomes reachable again.

On Windows, a topmost task dialog that fully covers Chrome can stall
Playwright's animation-frame actionability checks. If a locator resolves but
waits indefinitely for stability, check window overlap. Move or resize only
task-owned windows on the user's chosen monitor so part of Chrome is visible,
then retry once. Keep human approval dialogs open; do not answer them for the
user. In a verified case, the unchanged scroll-and-screenshot sequence passed
after Chrome was no longer fully covered.

A screen capture must show the target window, not the pixels covering an
occluded window. On Windows, `CopyFromScreen` captures whatever is in front of
the target. Bring the window forward or use an offscreen-safe capture such as
`PrintWindow`. Do not capture a Playwright token page, visible password, TOTP,
recovery code, vault content, or sensitive mailbox content. If capture is
necessary near one of those controls, crop or redact it locally before exposing
or retaining the image.

## Fallback order

1. Use direct APIs or CLIs when they already have safe authentication. For
   GitHub image and video attachments, prefer GitHub CLI 2.99.0 or newer with
   `--attach`.
2. Use a disposable Playwright session for public pages and test accounts.
3. Use Playwright Extension attachment for an existing real browser session,
   SSO continuity, or installed extensions.
4. Use CDP attachment to a dedicated non-default Chrome data directory when
   extension mode is unavailable and remote debugging is intentionally enabled.
5. After one failed browser-automation approach, use screenshots and Pi computer
   use for browser chrome, extension popups, authentication windows, lost page
   contexts, and visible-state conflicts.
6. Ask for human action only for secret entry, CAPTCHA, biometrics, hardware-key
   touches, MFA approval, or new consequential authority.

Never switch to a password-manager CLI, export a vault, or migrate credentials
merely because browser autofill failed. That is a separate security decision.
