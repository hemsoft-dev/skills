---
name: convex
description: V1.0 - Expert in Convex serverless database platform - local development, schema design, queries/mutations/actions, cron jobs, React integration, CLI operations, and troubleshooting. Use when working with Convex backends.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the convex directory (path contains 'convex'), verify that history logging occurred.
            
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
            Before stopping, if convex was used (check if any files in convex directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in convex directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Convex

Expert guidance for Convex serverless database platform including local development, schema design, function authoring, React integration, and troubleshooting.

## Architecture Overview

Convex provides:

- **Database**: Document-relational DB with tables, auto-generated `_id` and `_creationTime` fields
- **Functions**: Queries (read-only), Mutations (read/write, transactional), Actions (side effects, external APIs)
- **Real-time**: WebSocket-based reactive subscriptions via sync engine
- **Scheduling**: Cron jobs and one-off scheduled functions
- **File Storage**: Built-in file storage with `_storage` system table

## Project Structure

```
project/
├── convex/                    # Backend functions directory
│   ├── schema.ts              # Table definitions and validators
│   ├── crons.ts               # Cron job definitions
│   ├── _generated/            # Auto-generated types (commit to repo!)
│   │   ├── api.d.ts           # Generated API types
│   │   ├── api.js
│   │   ├── dataModel.d.ts     # Document types from schema
│   │   ├── server.d.ts        # query/mutation/action constructors
│   │   └── server.js
│   └── *.ts                   # Your functions (queries, mutations, actions)
├── .env.local                 # CONVEX_DEPLOYMENT + VITE_CONVEX_URL
└── src/
    └── providers/
        └── ConvexClientProvider.tsx  # React provider setup
```

## Local Development

### Starting Local Backend

```powershell
npx convex dev          # Watches files, pushes to deployment, shows logs
npx convex dev --local  # Runs backend locally (beta)
```

Local backend state is stored at `~/.convex/anonymous-convex-backend-state/`.

### .env.local Configuration

For local development:

```
CONVEX_DEPLOYMENT=anonymous:anonymous-{project-name}
VITE_CONVEX_URL=http://127.0.0.1:3210
VITE_CONVEX_SITE_URL=http://127.0.0.1:3211
```

For cloud development:

```
CONVEX_DEPLOYMENT=dev:{deployment-name}
VITE_CONVEX_URL=https://{slug}.convex.cloud
```

### Common CLI Commands

```powershell
npx convex dev                    # Start dev server (watch mode)
npx convex dev --once             # Push once, don't watch
npx convex dev --configure        # Reconfigure project
npx convex codegen                # Regenerate _generated types
npx convex run <fn> '<json>'      # Run a function manually
npx convex data                   # List tables
npx convex data <table>           # Show table data
npx convex env list               # List env vars
npx convex env set KEY value      # Set env var
npx convex import --table T file  # Import data
npx convex export --path dir      # Export data
npx convex deploy                 # Deploy to production
```

## Schema Design

Define schemas in `convex/schema.ts`:

```typescript
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  messages: defineTable({
    body: v.string(),
    userId: v.id("users"),
    channel: v.string(),
  })
    .index("by_channel", ["channel"])
    .index("by_user_channel", ["userId", "channel"]),
    
  users: defineTable({
    name: v.string(),
    email: v.string(),
  })
    .index("by_email", ["email"]),
});
```

### Validator Types

| Validator | TypeScript Type |
|-----------|----------------|
| `v.string()` | `string` |
| `v.number()` | `number` |
| `v.boolean()` | `boolean` |
| `v.id("table")` | `Id<"table">` |
| `v.null()` | `null` |
| `v.any()` | `any` |
| `v.optional(v.string())` | `string \| undefined` |
| `v.union(v.string(), v.number())` | `string \| number` |
| `v.literal("foo")` | `"foo"` |
| `v.object({...})` | `{...}` |
| `v.array(v.string())` | `string[]` |
| `v.record(v.string(), v.boolean())` | `Record<string, boolean>` |

### Index Best Practices

- Indexes are on fields in order; `["a", "b"]` can filter on `a` alone or `a + b`
- Avoid redundant indexes: if you have `by_foo_and_bar`, you don't need `by_foo`
- Exception: if sorting by `_creationTime` matters, `by_foo` sorts by `foo, _creationTime` while `by_foo_and_bar` sorts by `foo, bar, _creationTime`
- Use `.withIndex()` instead of `.filter()` for performance
- Use `.take(N)` or pagination instead of `.collect()` for large result sets

## Function Types

### Queries (Read-Only)

```typescript
import { query } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: { channel: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("messages")
      .withIndex("by_channel", (q) => q.eq("channel", args.channel))
      .order("desc")
      .take(50);
  },
});
```

- Deterministic, cached, reactive
- Cannot use `fetch()` or `Date.now()` (avoid for cache correctness)
- Subscribed via `useQuery()` on the client

### Mutations (Read/Write, Transactional)

```typescript
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const send = mutation({
  args: { body: v.string(), channel: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db.insert("messages", {
      body: args.body,
      channel: args.channel,
      userId: /* from ctx.auth */,
    });
  },
});
```

- All reads/writes in a single transaction
- Deterministic — cannot call external APIs
- Called via `useMutation()` on the client

### Actions (Side Effects)

```typescript
import { action, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";

export const summarize = action({
  args: { channel: v.string() },
  handler: async (ctx, args) => {
    const messages = await ctx.runQuery(internal.messages.listInternal, { channel: args.channel });
    const response = await fetch("https://api.openai.com/...", { ... });
    await ctx.runMutation(internal.messages.saveSummary, { ... });
  },
});
```

- Can call external APIs, use `fetch()`
- Interact with DB via `ctx.runQuery()` / `ctx.runMutation()`
- NOT transactional — error handling is your responsibility
- 10 min timeout, 512MB (Node.js) / 64MB (Convex runtime) memory
- For Node.js-specific packages, add `"use node";` at top of file

### Internal Functions

```typescript
import { internalQuery, internalMutation, internalAction } from "./_generated/server";
```

- Not callable from clients — only from other server functions
- Use `internal.module.functionName` to reference them
- **Always use internal for**: scheduled functions, cron targets, `ctx.run*` calls

## Cron Jobs

Define in `convex/crons.ts`:

```typescript
import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval("cleanup", { hours: 1 }, internal.cleanup.run);
crons.daily("report", { hourUTC: 14, minuteUTC: 0 }, internal.reports.generate);
crons.cron("custom", "*/5 * * * *", internal.tasks.process);

export default crons;
```

Schedule types: `interval`, `cron`, `hourly`, `daily`, `weekly`, `monthly`.

## React Integration

### Provider Setup

```typescript
import { ConvexProvider, ConvexReactClient } from "convex/react";

const convex = new ConvexReactClient(import.meta.env.VITE_CONVEX_URL);

root.render(
  <ConvexProvider client={convex}>
    <App />
  </ConvexProvider>
);
```

### Hooks

```typescript
import { useQuery, useMutation, useAction } from "convex/react";
import { api } from "../convex/_generated/api";

// Subscribe to reactive query
const messages = useQuery(api.messages.list, { channel: "general" });

// Get mutation caller
const sendMessage = useMutation(api.messages.send);

// Get action caller  
const summarize = useAction(api.messages.summarize);
```

- `useQuery` returns `undefined` while loading, then the result
- `useQuery` automatically re-renders when data changes
- `useMutation` returns async function — mutations are queued and ordered
- `useAction` returns async function — actions run in parallel

### Skipping Queries

```typescript
const data = useQuery(api.fn.name, enabled ? { arg: value } : "skip");
```

## Best Practices

1. **Always use argument validators** (`args: { ... }`) for public functions
2. **Use internal functions** for cron targets, scheduled fns, and `ctx.run*` calls
3. **Use `.withIndex()` over `.filter()`** for performance
4. **Use `.take(N)` over `.collect()`** for potentially large result sets
5. **Avoid `Date.now()` in queries** — breaks caching/reactivity
6. **Await all promises** — `await ctx.db.patch(...)`, `await ctx.scheduler.runAfter(...)`
7. **One `runQuery`/`runMutation` per action** — combine reads/writes into single internal fns for consistency
8. **Use helper functions** — share logic between public and internal functions
9. **Include table name in `ctx.db` calls** — `ctx.db.get("table", id)` not `ctx.db.get(id)`
10. **Commit `_generated/` to repo** — needed for TypeScript typechecking

## Troubleshooting

### Port 3210 Already in Use

```powershell
# Kill orphaned backend
Get-Process -Name "convex-local-backend" -ErrorAction SilentlyContinue | Stop-Process -Force
# Or find by port
Get-NetTCPConnection -LocalPort 3210 -ErrorAction SilentlyContinue | 
  Select-Object OwningProcess -Unique | 
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

### 500 Error on start_push (Corrupted Local DB)

```powershell
# Kill backend, remove corrupted state, restart
Get-Process -Name "convex-local-backend" -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item "$env:USERPROFILE\.convex\anonymous-convex-backend-state\anonymous-{project}" -Recurse -Force
npx convex dev
```

Local state location: `~/.convex/anonymous-convex-backend-state/anonymous-{project-name}/`

### Missing _generated Types

```powershell
npx convex codegen    # Regenerate types
npx convex dev --once # Push schema and regenerate
```

### Schema Validation Failures on Push

- Existing documents must match new schema — migrate data first or use `schemaValidation: false` temporarily
- Check dashboard "Generate Schema" button to see what current data looks like

### Dashboard Access

- Local: `http://127.0.0.1:6790/`
- Cloud: `https://dashboard.convex.dev/`
- Safari/Brave may block localhost — use Chrome/Firefox/Edge for local dashboard

## Database Operations

### Reading

```typescript
const doc = await ctx.db.get("table", id);        // By ID
const docs = await ctx.db.query("table").collect(); // All docs (small tables only)
const docs = await ctx.db.query("table")
  .withIndex("by_field", q => q.eq("field", value))
  .order("desc")
  .take(100);                                       // Indexed, limited
```

### Writing

```typescript
const id = await ctx.db.insert("table", { field: "value" });
await ctx.db.patch("table", id, { field: "newValue" });       // Partial update
await ctx.db.replace("table", id, { field: "newValue" });     // Full replace
await ctx.db.delete("table", id);
```

### Scheduling

```typescript
// From mutations
await ctx.scheduler.runAfter(0, internal.module.fn, { arg: "value" });      // Immediately
await ctx.scheduler.runAfter(60000, internal.module.fn, { arg: "value" });  // In 1 min
await ctx.scheduler.runAt(timestamp, internal.module.fn, { arg: "value" }); // At specific time
```

## Environment Variables

- Set on dashboard or via `npx convex env set KEY value`
- Access in functions: `process.env.KEY`
- System vars: `CONVEX_CLOUD_URL`, `CONVEX_SITE_URL`
- Per-deployment (different values for dev vs prod)
- NOT sourced from `.env` files — `.env.local` is for CLI config only

## Electron App Integration

When using Convex with Electron:

- The React renderer connects to Convex via WebSocket (same as any web app)
- The `VITE_CONVEX_URL` env var is baked in at build time by Vite
- For local development, point to `http://127.0.0.1:3210`
- The `npx convex dev` process must be running for the local backend to work
- The Convex backend runs as a subprocess of `npx convex dev` and exits when stopped
