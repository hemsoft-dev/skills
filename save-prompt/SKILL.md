---
name: save-prompt
description: "V1.2 - Commands: save, recover, status — Saves user prompts to .agents/prompt-history/YYYY-MM-DD.md with subject prefixes, deduplication, and stylish formatting. Can recover prompts from VS Code's internal SQLite database. Status command reports session inventory."
---

# Save Prompt

Saves the user's prompts (never agent responses) to a daily markdown log at `.agents/prompt-history/YYYY-MM-DD.md`.

## Commands

### `save` (default)

Saves current session prompts to the daily file. This is the default when user invokes `/save-prompt` without arguments.

### `recover`

Recovers **all** user prompts from VS Code's internal SQLite database — including those lost to context compression. Use when prompts are missing or the save command was invoked too late.

### `status`

Reports session inventory from the VS Code SQLite database for the current workspace. Shows total sessions, prompts, date range, and a per-session summary table.

## Behavior — Status

Queries the VS Code SQLite database for the current workspace and reports a session inventory.

### Steps

1. **Find Python** — Use `C:\Users\{user}\AppData\Local\Programs\Python\Python3*\python.exe` glob if `python` is not on PATH.
2. **Find workspace ID** — Scan `%APPDATA%\{vscode-variant}\User\workspaceStorage\` folders. Read `workspace.json` in each and match its `folder` URI against the current workspace path.
3. **Query the database** — Connect to `state.vscdb` in the matched workspace folder and extract:
   - **Session index**: `SELECT value FROM ItemTable WHERE key='chat.ChatSessionStore.index'` → `data.entries` (dict of sessions)
   - **Prompt count**: `SELECT value FROM ItemTable WHERE key='memento/interactive-session'` → `data.history.copilot` (list of prompt items)
   - **DB size**: `SELECT key, length(value) FROM ItemTable ORDER BY length(value) DESC LIMIT 5`
4. **Format the report** — Display using the Status Output Format below.

### Session Index Structure

```
chat.ChatSessionStore.index → JSON
{
  "version": 1,
  "entries": {
    "{sessionId}": {
      "sessionId": "uuid",
      "title": "Human-readable title",
      "lastMessageDate": 1771914564318,     // epoch ms
      "timing": {
        "created": 1771913241129,           // epoch ms
        "lastRequestStarted": ...,
        "lastRequestEnded": ...
      },
      "isEmpty": false,
      "isExternal": false,
      "lastResponseState": 1                // 1=success, 2=error
    }
  }
}
```

### Status Output Format

```markdown
## 📊 Prompt Store Status — {workspace-name}

| Metric | Value |
|--------|-------|
| Workspace ID | `{id}` (first 8 chars) |
| Sessions | {total} ({non-empty} with content, {empty} empty) |
| Prompts | {count} in interactive-session |
| Date range | {earliest} → {latest} |
| DB size | {top entry}: {size} |

### Sessions

| # | Created | Last Active | Title | State |
|---|---------|-------------|-------|-------|
| 1 | MM-DD HH:MM | MM-DD HH:MM | {title} | ✅/❌/🆕 |
| … | … | … | … | … |
```

State indicators:

- ✅ = `lastResponseState: 1` (success)
- ❌ = `lastResponseState: 2` (error)
- 🆕 = `isEmpty: true` (new/empty session)

### Matching the Workspace

The `folder` field in `workspace.json` is a URI like `file:///d%3A/github/Relias/hs-buddy`. Match it against the current workspace path. The drive letter is URL-encoded (e.g., `d:` → `d%3A`).

For VS Code Insiders: `%APPDATA%\Code - Insiders\User\workspaceStorage\`
For regular VS Code: `%APPDATA%\Code\User\workspaceStorage\`

Try Insiders first, fall back to regular.

## Behavior — Save

1. **Determine the date** — Use `Get-Date -Format "yyyy-MM-dd"` and `Get-Date -Format "HH:mm"` for the filename and entry timestamp.
2. **Subject prefix** — Each invocation should include a short subject tag (e.g., `[Setup]`, `[Bugfix]`, `[Feature]`). If the user doesn't provide one, infer a concise subject from the prompt content.
3. **Read or create the daily file** — If `.agents/prompt-history/{YYYY-MM-DD}.md` exists, read it. Otherwise, create it with the header template below.
4. **Deduplicate** — Before appending, check if a prompt with identical content already exists in today's file. If found, skip and inform the user. Compare the raw prompt text (ignoring timestamps and subject tags).
5. **Append the prompt** — Add the new entry at the end of the file using the entry template below.

## Behavior — Recover

Extracts verbatim prompts from VS Code's internal SQLite conversation store. This captures every prompt ever sent in the current workspace — even those lost to context window compression.

### Prerequisites

- **Python 3** must be available. Search common paths if `python` is not on PATH:
  - `C:\Users\{user}\AppData\Local\Programs\Python\Python3*\python.exe`
- The `sqlite3` and `json` standard library modules (always available in CPython).

### Database Location

VS Code stores workspace state in a SQLite database at:

```
%APPDATA%\Code - Insiders\User\workspaceStorage\{workspace-id}\state.vscdb
```

For regular VS Code (non-Insiders):

```
%APPDATA%\Code\User\workspaceStorage\{workspace-id}\state.vscdb
```

### Finding the Workspace ID

Each workspace folder gets a unique hash-based folder name. To find the right one:

1. List folders in `workspaceStorage\`
2. Read `workspace.json` in each — it contains the mapped folder URI
3. Match against the current workspace path (URL-encoded, e.g. `file:///d%3A/github/HemSoft/set-it-free-loop-site`)

### Extraction Steps

1. **Connect** to `state.vscdb` with Python's `sqlite3` module
2. **Query**: `SELECT value FROM ItemTable WHERE key='memento/interactive-session'`
3. **Parse** the JSON value — structure is:

   ```
   data['history']['copilot']  →  list of conversation items
   ```

4. **Extract** from each item:
   - `item['inputText']` — the verbatim user prompt
   - `item['selectedModel']['metadata']['id']` — model used (optional)
   - `item['mode']['id']` — mode (agent, ask, etc.) (optional)
5. **Write** to `.agents/prompt-history/{YYYY-MM-DD}.md` using the recovery template below

### Recovery Python Script Pattern

```python
import sqlite3, json, os

db_path = os.path.join(os.environ['APPDATA'],
    'Code - Insiders', 'User', 'workspaceStorage',
    '{workspace-id}', 'state.vscdb')

conn = sqlite3.connect(db_path)
c = conn.cursor()
c.execute("SELECT value FROM ItemTable WHERE key='memento/interactive-session'")
row = c.fetchone()
data = json.loads(row[0])

for i, item in enumerate(data['history']['copilot']):
    text = item.get('inputText', '')
    print(f"--- Prompt #{i+1} ---")
    print(text.strip())
    print()

conn.close()
```

### JSON Structure Reference

```
ItemTable (single table)
  └─ key: 'memento/interactive-session'  (largest blob, ~750KB+)
     └─ JSON → { "history": { "copilot": [ ... ] } }
                                            │
                                            ├─ [0] { "inputText": "...", "mode": {...}, "selectedModel": {...}, ... }
                                            ├─ [1] { "inputText": "...", ... }
                                            └─ [N] { ... }
```

Other useful keys in `ItemTable`:

- `memento/interactive-session-view-copilot` — current session metadata (model, account)
- `chat.ChatSessionStore.index` — session index

## File Template (new daily file — save mode)

```markdown
# 📋 Prompt History — {YYYY-MM-DD}

> Daily log of user prompts.

---
```

## File Template (recover mode)

```markdown
# 📋 Prompt History — {YYYY-MM-DD}

> Daily log of user prompts.
> Recovered **verbatim** from VS Code Insiders SQLite database (`state.vscdb`).

---
```

## Entry Template (save mode)

```markdown
### 🕐 {HH:MM} · `{Subject}`

> {User prompt text, block-quoted for readability. Preserve line breaks.}

---
```

## Entry Template (recover mode)

```markdown
### #{N} · `[{Subject}]` {Short Description}

> {Verbatim prompt text from inputText field. Preserve all original formatting.}

---
```

At the bottom of a recovered file, add a source citation:

```markdown
> **Source**: Extracted verbatim from `state.vscdb` → `ItemTable` → key `memento/interactive-session` → `data.history.copilot[].inputText`
```

## Rules

- **User prompts only** — Never log agent/assistant responses.
- **No duplicates** — If the same prompt text already exists in today's file (regardless of subject or timestamp), do not add it again. Notify the user it was already saved.
- **One file per day** — All prompts for a given day go into a single `YYYY-MM-DD.md` file.
- **Preserve formatting** — Keep the user's original prompt text intact, including line breaks and markdown.
- **Multi-line prompts** — Use a blockquote (`>`) with each line prefixed to maintain readability.
- **Recover merges, not overwrites** — When recovering into an existing daily file, skip prompts already present (deduplicate by content). Append only new ones.
- **Clean up temp files** — If a Python script is created for recovery, delete it after extraction is complete.
