---
name: hs-cli-tool
description: V1.1 - Expert in creating, converting, and maintaining HemSoft CLI Tools using the standardized hs-cli-template framework for unified branding, stack, and quality tooling.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the hs-cli-tool directory (path contains 'hs-cli-tool'), verify that history logging occurred.
            
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
            Before stopping, if hs-cli-tool was used (check if any files in hs-cli-tool directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in hs-cli-tool directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
              - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# HemSoft CLI Tool Expert

Expert in creating, converting, and maintaining HemSoft CLI Tools using the standardized template framework.

## Template Location

**Primary Template**: `D:\github\HemSoft\hs-cli-template`

This is the production-ready template with:

- AI capabilities via GitHub Copilot CLI SDK
- Beautiful terminal UI (gradients, banners, styled help)
- Configuration system with persistent storage
- Authentication via GitHub CLI
- Pre-commit hooks (Husky + lint-staged)
- Strict TypeScript with ESLint and Prettier
- Commander.js argument parsing

## When to Use This Skill

Use this skill when:

- Creating a new CLI tool from scratch
- Converting an existing project to the hs-cli-tool framework
- Maintaining consistency across HemSoft CLI tools
- Adding commands to an existing hs-cli-tool
- Troubleshooting hs-cli-tool issues

## Creating a New CLI Tool

### 1. Clone the Template

```powershell
# Navigate to your HemSoft projects folder
Set-Location "D:\github\HemSoft"

# Clone the template
Copy-Item -Recurse -Path "hs-cli-template" -Destination "{new-cli-name}"

# Enter the new project
Set-Location "{new-cli-name}"

# Initialize fresh git history
Remove-Item -Recurse -Force .git
git init
```

### 2. Customize package.json

Update these fields:

```json
{
  "name": "@hemsoft/{cli-name}",
  "description": "{Your CLI description}",
  "bin": {
    "{cli-command}": "dist/index.js"
  }
}
```

### 3. Update Branding

**src/lib/banner.ts**:

- Generate new ASCII logo at [patorjk.com/software/taag](https://patorjk.com/software/taag/)
- Update `LOGO_LINES` array
- Customize gradient colors if desired
- Update taglines and version

**src/lib/config.ts**:

- Change `projectName` in Conf constructor: `projectName: '{your-cli-name}'`
- Add any CLI-specific config fields to `CLIConfig` interface

**src/index.ts**:

- Update `program.name('{cli-command}')`
- Update description
- Update version

### 4. Update Auth References

Find and replace in `src/commands/auth.ts` and `src/commands/config.ts`:

- `"HS CLI"` → Your CLI display name
- `"hs-cli"` → Your CLI command name

### 5. Install Dependencies

```powershell
npm install
# This automatically sets up Husky pre-commit hooks
```

### 6. Add Your Commands

**Create command file** (`src/commands/{command-name}.ts`):

```typescript
import chalk from 'chalk';
import ora from 'ora';
import boxen from 'boxen';
import logSymbols from 'log-symbols';
import { AIService } from '../lib/ai.js';

interface YourCommandOptions {
  option1?: string;
  model?: string;
}

export async function yourCommand(options: YourCommandOptions) {
  const ai = new AIService(
    'Your custom system prompt for this command',
    options.model
  );
  const spinner = ora();

  try {
    spinner.start('Processing...');

    // Your command logic
    const result = await ai.prompt('Your AI prompt here');

    spinner.succeed('Complete!');

    console.log(
      boxen(chalk.cyan(result), {
        padding: 1,
        margin: 1,
        borderStyle: 'round',
        borderColor: 'cyan',
      })
    );
  } catch (error) {
    spinner.fail('Operation failed');
    console.error(
      chalk.red(logSymbols.error),
      error instanceof Error ? error.message : 'Unknown error'
    );
    process.exit(1);
  } finally {
    await ai.close();
  }
}
```

**Register in src/index.ts**:

```typescript
import { yourCommand } from './commands/your-command.js';

program
  .command('your-command')
  .description('Your command description')
  .option('-o, --option1 <value>', 'Option description')
  .showHelpAfterError(true)
  .action((options) => yourCommand({ ...options, model: globalModel }));
```

### 7. Remove Demo Command

Delete or replace `src/commands/hello.ts` and remove its registration from `src/index.ts`.

### 8. Build and Test

```powershell
# Build TypeScript
npm run build

# Test the CLI
npm run dev {command}

# Run quality checks
npm run check
```

### 9. Publish (Optional)

```powershell
# Update version
npm version patch|minor|major

# Publish to npm
npm publish --access public

# Install globally
npm install -g @hemsoft/{cli-name}
```

## Converting an Existing Project

### Assessment Checklist

Before converting, verify the project:

- [ ] Is a CLI tool or can benefit from CLI interface
- [ ] Would benefit from AI capabilities
- [ ] Needs better terminal UI/UX
- [ ] Could use quality tooling (pre-commit hooks, linting)
- [ ] Should match HemSoft branding standards

### Conversion Workflow

**1. Analyze Current Project**

Identify:

- Current commands and their functionality
- Dependencies that overlap with template
- Custom logic that needs preservation
- Configuration requirements
- Any existing services or utilities

**2. Set Up New Structure**

```powershell
# Create from template (steps 1-3 from "Creating a New CLI Tool")
# Then copy over existing functionality
```

**3. Migrate Commands**

For each existing command:

- Create new command file following template pattern
- Wrap logic in try/catch with spinner
- Use AIService if the command can benefit from AI
- Maintain original functionality while improving UX

**4. Migrate Services/Utilities**

- Move non-CLI logic to `src/lib/` if reusable
- Adapt to TypeScript if needed
- Integrate with AIService or ConfigService where appropriate

**5. Update Dependencies**

- Merge package.json dependencies
- Remove redundant packages already in template
- Keep project-specific dependencies

**6. Test Thoroughly**

- Verify all commands work as before
- Test error handling
- Validate AI integrations
- Ensure config persistence

**7. Update Documentation**

- Update README for new CLI structure
- Document all commands
- Include migration notes if needed

## Maintaining Consistency

### HemSoft CLI Standards

All hs-cli-tools must have:

**✅ Branding**:

- ASCII logo with gradient styling (vice, gold, greenGlow themes)
- "✦ by HemSoft Developments ✦" branding line
- Consistent gradient-decorated help screens

**✅ Architecture**:

- Commander.js for CLI framework
- AIService for Copilot integration
- ConfigService for persistent settings
- Styled help with section decorations

**✅ Quality Tooling**:

- Pre-commit hooks (Husky + lint-staged)
- ESLint with TypeScript
- Prettier formatting
- Strict TypeScript configuration

**✅ User Experience**:

- Spinners for long operations
- Boxen for important messages
- Chalk for colored output
- Log symbols for status
- Interactive prompts with Inquirer

**✅ Configuration**:

- Model selection and aliases
- First-run setup wizard
- Persistent storage with Conf
- Config show/set/reset commands

**✅ Authentication**:

- GitHub CLI integration
- Multi-account support
- Auth status/login/switch/logout/help commands

### Code Patterns

**Command Structure** (always follow this pattern):

```typescript
export async function commandName(options: Options) {
  const ai = new AIService(systemPrompt, options.model);
  const spinner = ora();

  try {
    // 1. Validate inputs
    // 2. Start spinner
    spinner.start('Processing...');
    
    // 3. Perform operations
    const result = await ai.prompt(prompt);
    
    // 4. Success feedback
    spinner.succeed('Complete!');
    
    // 5. Display results
    console.log(boxen(result, { ... }));
    
  } catch (error) {
    spinner.fail('Operation failed');
    console.error(chalk.red(logSymbols.error), error.message);
    process.exit(1);
  } finally {
    await ai.close();
  }
}
```

**AIService Usage**:

```typescript
// Custom system message per command
const ai = new AIService(
  `You are an expert in {domain}.
Provide {type} responses.
{Additional guidance}.`,
  options.model
);

// Always close in finally block
try {
  const result = await ai.prompt(userPrompt);
} finally {
  await ai.close();
}
```

**Styled Output**:

```typescript
// Success messages
console.log(chalk.green(`${logSymbols.success} Operation successful`));

// Info messages
console.log(chalk.cyan(`${logSymbols.info} Information here`));

// Warnings
console.log(chalk.yellow(`${logSymbols.warning} Warning text`));

// Errors
console.log(chalk.red(`${logSymbols.error} Error details`));

// Important boxes
console.log(boxen(content, {
  padding: 1,
  margin: 1,
  borderStyle: 'round',
  borderColor: 'cyan',
  title: 'Title',
  titleAlignment: 'center',
}));
```

**Clickable Links in Terminal**:

Use `terminal-link` package for clickable hyperlinks (Ctrl+click to open in browser):

```typescript
import terminalLink from 'terminal-link';

// CRITICAL: Use `fallback: false` to force hyperlink mode
// The library's auto-detection doesn't recognize VS Code terminal
// as supporting OSC 8 hyperlinks, so detection falls back to plain text
const link = terminalLink('Click here', 'https://example.com', { fallback: false });
console.log(link);

// In tables (e.g., cli-table3):
const titleLink = terminalLink(pr.title, pr.url, { fallback: false });
table.push([titleLink, ...otherColumns]);
```

**Why `fallback: false` is required**:

- `terminal-link` uses `supports-hyperlinks` to detect terminal capability
- VS Code terminal supports OSC 8 hyperlinks but isn't detected correctly
- Without `fallback: false`, the library outputs plain text: `"Click here https://example.com"`
- With `fallback: false`, proper escape sequences are generated: `"\u001b]8;;https://example.com\u0007Click here\u001b]8;;\u0007"`

Supported terminals: Windows Terminal, VS Code integrated terminal, iTerm2, Hyper, and most modern terminal emulators.

## Common Tasks

### Adding a Command to Existing Tool

1. Create command file in `src/commands/{name}.ts`
2. Follow the command structure pattern
3. Register in `src/index.ts`
4. Build and test
5. Commit with pre-commit hooks

### Updating Template Version

When the template is updated:

1. Review changelog/commits for breaking changes
2. Copy updated files (selectively):
   - Infrastructure: `package.json`, `tsconfig.json`, `eslint.config.js`
   - Services: Check for improvements in `src/lib/`
   - Commands: Check for improvements in auth/config
3. Test thoroughly after updates
4. Update version in your CLI's package.json

### Troubleshooting

**Build errors**:

- Run `npm run type-check` for TypeScript errors
- Check imports end with `.js` extension
- Verify all required dependencies installed

**Pre-commit hook failures**:

- Run `npm run lint:fix` to auto-fix linting
- Run `npm run format` to format code
- Skip hooks only when absolutely necessary: `git commit --no-verify`

**AI/Copilot issues**:

- Verify auth: `{cli} auth status`
- Re-authenticate: `{cli} auth login`
- Check Copilot access at github.com/settings/copilot

**Config issues**:

- Check config location: `{cli} config show`
- Reset if needed: `{cli} config reset`

## Best Practices

**✅ Do**:

- Use the template as foundation for all new CLI tools
- Follow the established command structure pattern
- Include progress feedback (spinners)
- Provide helpful error messages
- Use AI where it adds value
- Keep commands focused and single-purpose
- Write self-documenting code with good types

**❌ Don't**:

- Skip pre-commit hooks without good reason
- Use `any` types
- Leave AIService sessions open
- Mix console.log with styled output
- Bypass error handling
- Forget to close resources in finally blocks

## Reference Documentation

Template README: `D:\github\HemSoft\hs-cli-template\README.md`

Architecture guide: Review the template's comprehensive README for:

- Full customization guide
- Detailed project structure
- TypeScript configuration details
- Publishing workflow
- Contributing guidelines
