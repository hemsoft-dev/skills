---
name: playwright
description: V1.3 - Expert in browser automation using Playwright MCP tools for web
  scraping, testing, and task automation. Optimized for context efficiency with headless
  mode, minimal screenshots, and snapshot-first workflows.
compatibility: Requires Playwright MCP server (mcp_microsoft_pla_browser_* tools),
  Microsoft Edge or Chromium browser
metadata:
  edge_configured: "true"
  mcp_config: "C:\\Users\\User\\AppData\\Roaming\\Code - Insiders\\User\\mcp.json"
---

# Playwright Browser Automation Expert

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Executes browser automation tasks using the Playwright MCP server. Handles navigation, interaction, data extraction, and complex multi-step web workflows.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Task Definition Protocol

Before executing any browser automation, gather these details:

### 1. Task Name

One to three words identifying the task (e.g., `Get-LinkedIn-Messages`, `Check-Balance`, `Order-From-CostCo`)

### 2. Description

Headline description of what the task accomplishes

### 3. Goal(s)

Clearly defined objectives with success criteria

### 4. Workflow

Step-by-step breakdown with expectations:

- Navigation steps
- Required interactions (clicks, form fills, etc.)
- Data extraction points
- Validation checkpoints
- Error handling

### 5. Output

Define the expected result format:

- Extracted data structure
- Screenshots/artifacts
- Status reports
- Error messages

### 6. Receipt

After execution, provide:

```
🎭 PLAYWRIGHT TASK - {Task Name}
├─ ✅ Goal: {primary goal}
├─ 📊 Status: {Success/Partial/Failed}
├─ 🔗 URL: {final URL}
├─ 📸 Artifacts: {screenshots, data files}
└─ ⏱️ Duration: {execution time}
```

Then ask: **"Would you like to save this as a reusable task definition?"**

If yes, create: `tasks/{task-name}/TASK.md`

## Browser Configuration

**Current Setup**: Microsoft Edge (configured via MCP settings)

To change browser or channel, edit: `C:\Users\User\AppData\Roaming\Code - Insiders\User\mcp.json`

```json
"microsoft/playwright-mcp": {
  "env": {
    "PLAYWRIGHT_BROWSER_TYPE": "chromium",
    "PLAYWRIGHT_CHANNEL": "msedge"  // Options: msedge, msedge-beta, msedge-dev, chrome, chromium
  }
}
```

**Restart VS Code** after changing browser configuration.

## Available MCP Browser Tools

The following tools are available via the Playwright MCP server:

### Navigation

- `mcp_microsoft_pla_browser_navigate` - Go to URL
- `mcp_microsoft_pla_browser_navigate_back` - Go back
- `mcp_microsoft_pla_browser_tabs` - List/create/close/select tabs

### Inspection

- `mcp_microsoft_pla_browser_snapshot` - Get accessibility snapshot (preferred over screenshot for actions)
- `mcp_microsoft_pla_browser_take_screenshot` - Capture visual screenshot
- `mcp_microsoft_pla_browser_console_messages` - Get console logs
- `mcp_microsoft_pla_browser_network_requests` - Monitor network activity

### Interaction

- `mcp_microsoft_pla_browser_click` - Click element
- `mcp_microsoft_pla_browser_type` - Type text into element
- `mcp_microsoft_pla_browser_fill_form` - Fill multiple form fields
- `mcp_microsoft_pla_browser_select_option` - Select dropdown option
- `mcp_microsoft_pla_browser_hover` - Hover over element
- `mcp_microsoft_pla_browser_drag` - Drag and drop
- `mcp_microsoft_pla_browser_press_key` - Press keyboard key

### Advanced

- `mcp_microsoft_pla_browser_evaluate` - Run JavaScript on page/element
- `mcp_microsoft_pla_browser_run_code` - Execute Playwright code snippet
- `mcp_microsoft_pla_browser_handle_dialog` - Accept/dismiss dialogs
- `mcp_microsoft_pla_browser_file_upload` - Upload files
- `mcp_microsoft_pla_browser_wait_for` - Wait for text/time

### Lifecycle

- `mcp_microsoft_pla_browser_install` - Install browser (if missing)
- `mcp_microsoft_pla_browser_close` - Close page
- `mcp_microsoft_pla_browser_resize` - Resize window

## Workflow Pattern

1. **Understand the task** - Gather all 6 task definition elements
2. **Navigate** - Use `navigate` to reach starting URL
3. **Inspect** - Use `snapshot` ONLY (never screenshot yet)
4. **Interact** - Use appropriate interaction tools (click, type, fill_form)
5. **Extract** - Use `evaluate` for data (returns JSON text, efficient)
6. **Verify** - Check `console_messages` and `network_requests` for errors
7. **Screenshot** - ONLY if user explicitly asks or task absolutely requires visual proof (use JPEG, viewport only)
8. **Report** - Provide receipt with data/results
9. **Offer to save** - Ask if task should be saved for reuse

## Context Optimization (CRITICAL)

**Screenshots are EXTREMELY expensive** - A single full-page screenshot can consume 5-15KB of tokens. This quickly overwhelms context.

### Snapshot-First Architecture

1. **ALWAYS start with `snapshot`** - Returns lightweight accessibility tree with element refs
2. **Only use `take_screenshot` when ABSOLUTELY required** - Final verification, visual bugs, or user-requested proof
3. **Never use `fullPage: true`** - Captures entire scrollable page (huge overhead)
4. **Use JPEG not PNG** - 50-70% smaller file size than PNG

### Screenshot Optimization Rules

- **If just finding elements**: Use `snapshot` only (zero screenshot overhead)
- **If verifying interaction worked**: Use `console_messages` + `network_requests` instead
- **If must screenshot**:
  - Use `type: "jpeg"` to reduce file size
  - Omit `fullPage` parameter (defaults to viewport only)
  - Take ONE screenshot at end, not per step
- **Headless mode**: Already configured for speed/efficiency

### Context Math

- `snapshot`: ~0.5-1KB per page
- Viewport screenshot (JPEG): ~3-5KB
- Full-page screenshot (PNG): ~15-25KB

**Result**: Snapshot-only workflows use ~5% the tokens of screenshot-heavy ones.

## Best Practices

### Prefer Snapshot Over Screenshot

- `snapshot` provides actionable element references
- Use `take_screenshot` only for visual verification or final output
- **NEVER take multiple screenshots in one task** - Extract via `evaluate` instead

### Element References

- Always use exact `ref` values from snapshot
- Include human-readable `element` description for permission

### Error Handling

- Check `console_messages` for JavaScript errors (lightweight, accurate)
- Monitor `network_requests` for failed API calls
- Use `wait_for` to handle dynamic content

### Data Extraction

- Use `evaluate` to extract data as JSON (returns as text, very efficient)
- Use `snapshot` to verify structure before extracting
- Avoid screenshots for data validation

### Form Filling

- Use `fill_form` for multiple fields (more efficient)
- Use `type` + `submit` for single inputs with submission

### Background Processes

- For long-running tasks, inform user of progress
- Use `wait_for` with appropriate timeouts

## Task Definition Template

When saving a task, create `tasks/{task-name}/TASK.md`:

```markdown
---
task: {task-name}
created: {YYYY-MM-DD}
last_run: {YYYY-MM-DD or null}
success_rate: {0-100% or null}
difficulty: {Easy|Medium|Hard}
---

# {Task Name}

## Description

{Headline description}

## Goals

- [ ] {Goal 1}
- [ ] {Goal 2}
- [ ] {Goal 3}

## Workflow

### Step 1: {Step Name}
**Action**: {What to do}  
**Expected**: {What should happen}  
**Error Handling**: {How to handle failures}  

### Step 2: {Step Name}
...

## Output

**Format**: {JSON|Markdown|Screenshot|etc}  
**Location**: {Where output is saved}  

**Example**:
\```json
{
  "field": "value"
}
\```

## Notes

- {Important considerations}
- {Known limitations}
- {Dependencies}

## History

### {YYYY-MM-DD HH:MM}
- Status: {Success|Failed|Partial}
- Duration: {time}
- Notes: {observations}
```

## Common Task Patterns

### Data Extraction

1. Navigate to page
2. Wait for content to load
3. Use `snapshot` to find elements
4. Use `evaluate` to extract data
5. Return structured data

### Form Submission

1. Navigate to form page
2. Use `fill_form` with all fields
3. Click submit button
4. Wait for confirmation
5. Take screenshot of result

### Multi-Page Navigation

1. Navigate to start page
2. Use `click` to follow links
3. Track visited pages
4. Extract data at each step
5. Compile results

### Authentication Flows

1. Navigate to login page
2. Fill credentials (use `fill_form`)
3. Handle 2FA if needed
4. Verify successful login
5. Proceed with authenticated task

## Anti-Patterns

- ❌ Taking screenshots without `snapshot` first
- ❌ Taking MULTIPLE screenshots per task (screenshot once at end only)
- ❌ Using `fullPage: true` for screenshots (massive overhead)
- ❌ Using PNG screenshots instead of JPEG (2-3x larger)
- ❌ Clicking without verifying element exists
- ❌ Not waiting for dynamic content
- ❌ Ignoring console errors
- ❌ Hardcoding element selectors (use refs from snapshot)
- ❌ Extracting data via screenshot parsing instead of `evaluate`
- ❌ Taking a screenshot to verify interaction worked (use console messages instead)

## Example Task Definitions

See `tasks/` directory for saved task definitions. Common examples:

- `check-gmail-unread/` - Count unread emails
- `scrape-product-price/` - Monitor price changes
- `fill-form-template/` - Automate form submissions
- `extract-table-data/` - Scrape structured data

---

**Remember**: Always gather complete task definition before execution. Offer to save successful tasks for future reuse.
