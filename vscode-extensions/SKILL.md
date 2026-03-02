---
name: vscode-extensions
description: "V1.0 - Expert in VS Code extension development including scaffolding, Extension API, webview panels, commands, tree views, and publishing. Use when creating, debugging, or architecting VS Code extensions."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the vscode-extensions directory (path contains 'vscode-extensions'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if vscode-extensions was used (check if any files in vscode-extensions directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in vscode-extensions directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# VS Code Extension Development

Expert guidance for creating, debugging, and publishing VS Code extensions.

## Scaffolding

```powershell
npm install -g yo generator-code
yo code  # Interactive scaffold — choose TypeScript
```

This generates a ready-to-run extension with `launch.json` (press F5 to test in Extension Development Host).

## Extension Anatomy

```text
my-extension/
├── package.json          # Extension manifest (commands, activation, contributes)
├── src/
│   └── extension.ts      # activate() and deactivate() entry points
├── tsconfig.json
└── .vscode/
    └── launch.json       # F5 debugging config
```

## Core APIs

### Commands

Register commands that appear in the Command Palette (`Ctrl+Shift+P`):

```typescript
// extension.ts
import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
  context.subscriptions.push(
    vscode.commands.registerCommand('myExt.doSomething', () => {
      vscode.window.showInformationMessage('Hello!');
    })
  );
}
```

```jsonc
// package.json
{
  "contributes": {
    "commands": [{
      "command": "myExt.doSomething",
      "title": "Do Something",
      "category": "My Extension"
    }]
  },
  "activationEvents": ["onCommand:myExt.doSomething"]
}
```

### Webview Panels

Full HTML/CSS/JS panels (like the Agent Debug Panel):

```typescript
const panel = vscode.window.createWebviewPanel(
  'myPanel',           // Internal ID
  'My Panel',          // Tab title
  vscode.ViewColumn.One,
  {
    enableScripts: true,                    // Allow JS in webview
    retainContextWhenHidden: true,          // Keep state when tab hidden
    localResourceRoots: [                   // Security: restrict resource access
      vscode.Uri.joinPath(context.extensionUri, 'media')
    ]
  }
);
panel.webview.html = getWebviewContent(panel.webview, context.extensionUri);
```

**Message passing (extension ↔ webview):**

```typescript
// Extension side
panel.webview.postMessage({ type: 'update', data: items });
panel.webview.onDidReceiveMessage(msg => {
  if (msg.type === 'clicked') { /* handle */ }
});

// Webview HTML/JS side
const vscode = acquireVsCodeApi();
vscode.postMessage({ type: 'clicked', id: 42 });
window.addEventListener('message', event => {
  const msg = event.data;
  if (msg.type === 'update') { renderList(msg.data); }
});
```

### Tree Views

Sidebar tree (like Explorer, Source Control):

```typescript
class MyTreeProvider implements vscode.TreeDataProvider<MyItem> {
  getTreeItem(element: MyItem): vscode.TreeItem { return element; }
  getChildren(element?: MyItem): MyItem[] { return this.items; }
}

vscode.window.registerTreeDataProvider('myTreeView', new MyTreeProvider());
```

```jsonc
// package.json
{
  "contributes": {
    "views": {
      "explorer": [{ "id": "myTreeView", "name": "My Items" }]
    }
  }
}
```

### Status Bar

```typescript
const item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
item.text = '$(check) Ready';
item.command = 'myExt.doSomething';
item.show();
```

### Webview Views (Sidebar panels)

```typescript
class MyViewProvider implements vscode.WebviewViewProvider {
  resolveWebviewView(webviewView: vscode.WebviewView) {
    webviewView.webview.options = { enableScripts: true };
    webviewView.webview.html = '<h1>Sidebar Panel</h1>';
  }
}

context.subscriptions.push(
  vscode.window.registerWebviewViewProvider('myView', new MyViewProvider())
);
```

## package.json Contributes Reference

| Section | Purpose |
|---|---|
| `commands` | Command Palette entries |
| `menus` | Context menus, editor title bar, SCM |
| `keybindings` | Keyboard shortcuts |
| `views` | Sidebar tree/webview views |
| `viewsContainers` | Custom sidebar/panel containers with icons |
| `configuration` | User/workspace settings |
| `languages` | Language support declarations |
| `themes` | Color themes |
| `snippets` | Code snippet definitions |

## Activation Events

Control when your extension loads:

| Event | Triggers on |
|---|---|
| `onCommand:myExt.cmd` | Command execution |
| `onView:myViewId` | View becomes visible |
| `onLanguage:python` | File of language opened |
| `workspaceContains:**/*.xyz` | Workspace has matching files |
| `onStartupFinished` | After VS Code fully starts |
| `*` | Always (avoid — slows startup) |

## Security Best Practices

- Set `localResourceRoots` to restrict webview file access
- Use `nonce` attributes on `<script>` tags in webviews
- Set Content Security Policy (CSP) in webview HTML:

  ```html
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; script-src 'nonce-${nonce}'; style-src ${webview.cspSource};">
  ```

- Never use `enableCommandUris: true` unless required
- Validate all messages received from webviews

## Publishing

```powershell
npm install -g @vscode/vsce
vsce package         # Creates .vsix file
vsce publish         # Publishes to VS Code Marketplace (needs PAT)
```

Requires a publisher account at <https://marketplace.visualstudio.com/manage>.

## Debugging

- **F5** launches Extension Development Host with your extension loaded
- **Developer: Open Extension Host Log** shows extension errors
- **Developer: Toggle Developer Tools** opens Chrome DevTools for webviews
- Use `console.log()` in extension code → appears in Debug Console
- Use `console.log()` in webview JS → appears in Developer Tools

## Common Patterns

- **State persistence**: `context.globalState` (across sessions) / `context.workspaceState` (per workspace)
- **File watchers**: `vscode.workspace.createFileSystemWatcher('**/*.md')`
- **Quick picks**: `vscode.window.showQuickPick(items)` for selection lists
- **Input boxes**: `vscode.window.showInputBox({ prompt: 'Enter name' })`
- **Progress**: `vscode.window.withProgress({ location: ProgressLocation.Notification }, async (progress) => { ... })`
- **Output channel**: `vscode.window.createOutputChannel('My Extension')` for logging
