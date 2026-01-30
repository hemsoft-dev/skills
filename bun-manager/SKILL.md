---
name: bun-manager
description: V1.2 - Expert in Bun runtime, package manager, bundler, and test runner. Use for all Bun-related tasks including installation, builds, and best practices.
---

# Bun Manager

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert guidance for using Bun as an all-in-one toolkit for JavaScript and TypeScript development.

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Core Commands

### Package Management

- **Install all**: `bun install`
- **Add package**: `bun add {package}` (use `-d` for devDependencies)
- **Remove package**: `bun remove {package}`
- **Clean install (CI)**: `bun ci` (enforces `bun.lock` consistency)
- **Update lockfile**: `bun install --save-text-lockfile` (upgrades from binary `bun.lockb`)

### Runtime & Execution

- **Run file**: `bun {file.ts}` or `bun run {file.ts}`
- **Run script**: `bun run {script-name}` (or `bun {script-name}` if no name collision with built-in commands)
- **Watch mode**: `bun --watch run {file.ts}` (Flags must come BEFORE `run`)
- **Hot reload**: `bun --hot run {file.ts}`
- **Force Bun for Node scripts**: `bun run --bun {command}` (e.g., `bun run --bun next dev`)
- **Execute remote package**: `bunx {package}`

### Bundling & Building

- **Basic build**: `bun build {entry} --outdir {dir}`
- **Targeted build**: `bun build {entry} --outdir {dir} --target {browser|bun|node}`
- **Compile to executable**: `bun build {entry} --outfile {name} --compile`
- **Minify**: `bun build {entry} --outdir {dir} --minify`

### Testing

- **Run tests**: `bun test`
- **Watch tests**: `bun test --watch`

## Best Practices

1. **Lockfiles**: Always commit `bun.lock` (text-based) to version control.
2. **TypeScript**: No extra configuration needed; Bun runs `.ts` and `.tsx` natively.
3. **Command Collisions**: Use `bun run {script}` explicitly if the script name matches a Bun built-in (like `test`, `build`, `init`, `add`).
4. **Flag Order**: Always place Bun-specific flags (e.g., `--watch`, `--hot`, `--bun`, `--smol`) immediately after `bun` and before the command/script name.
5. **Environment Variables**: Bun automatically loads `.env` files. Use `process.env.VAR` or `import.meta.env.VAR`.
6. **Lifecycle Scripts**: For security, Bun doesn't run scripts by default. Add to `trustedDependencies` in `package.json` if needed.
7. **Performance**: Use `--smol` in memory-constrained environments (e.g., small Docker containers).
8. **Shell**: Use `bun shell` (via `import { $ } from "bun"`) for cross-platform scripting instead of complex shell commands.

## Configuration (`bunfig.toml`)

```toml
[install]
optional = true
dev = true
peer = true

[test]
root = "./tests"
```

## Troubleshooting

- **Cache issues**: `bun pm cache rm`
- **Node compatibility**: If a package fails, try `bun run --bun {command}` to force Bun's implementation of Node APIs.
