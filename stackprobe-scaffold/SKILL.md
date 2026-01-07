---
name: stackprobe-scaffold
description: V1.1 - Scaffolds a new project using the StackProbe stack (Next.js, shadcn/ui, Supabase, Vercel). Optimized for Bun and agentic workflows.
---

# StackProbe Scaffold

Expert guide for scaffolding a "StackProbe" project. This stack is optimized for speed, type safety, and AI integration.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Requirements
- **Bun**: Must be installed. If `bun` is not recognized, use the `env-manager` skill to fix the Windows PATH.
  - Installation: `powershell -c "irm bun.sh/install.ps1 | iex"`
- **Git**: Required for repository initialization.
- **Supabase CLI**: Required for migrations and linking to Supabase Cloud.
  - Installation: `scoop install supabase` or `npm install -g supabase`.
  - **Fallback**: If global installation is not possible, use the local binary: `.\node_modules\.bin\supabase.cmd` (after `bun add supabase --dev`).

## Core Stack
- **Runtime/PM**: Bun
- **Frontend**: Next.js 16+ (App Router, TypeScript, React 19)
- **UI**: shadcn/ui (Tailwind CSS 4+, Radix)
- **Backend/DB**: Supabase Cloud (Postgres, Auth, Storage, RLS)
- **Deployment**: Vercel
- **Default Port**: 5001

## Workflow

### 1. Repository Initialization
Use the `github-init` skill to set up the repository and initial history.

### 2. Project Scaffolding (Bun)
If the directory is not empty (e.g., after `github-init`), use this "Safe Scaffolding" approach:

```powershell
# 1. Create in a temp directory
bun create next-app tmp-app --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-bun --yes

# 2. Move files to root (preserving existing files)
Get-ChildItem -Path tmp-app -Force | ForEach-Object { 
    $dest = Join-Path . $_.Name
    if (Test-Path $dest) {
        if ($_.Name -eq "README.md") {
            Move-Item $_.FullName "$($_.FullName).bak" -Force
        } else {
            # Skip or handle other conflicts as needed
        }
    } else {
        Move-Item $_.FullName $dest -Force
    }
}

# 3. Cleanup
Remove-Item tmp-app -Recurse -Force

# 4. Initialize shadcn
bunx shadcn@latest init -d

# 5. Add core components
bunx shadcn@latest add button card input dialog table separator badge avatar dropdown-menu --yes

# 6. Create environment variable templates
$envContent = @"
NEXT_PUBLIC_SUPABASE_PROJECT_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_SERVICE_ROLE_KEY=
"@
$envContent | Out-File -FilePath .env.example -Encoding utf8
if (-not (Test-Path .env.local)) {
    $envContent | Out-File -FilePath .env.local -Encoding utf8
}

# 7. Update .gitignore to allow .env.example
$gitIgnorePath = ".gitignore"
if (Test-Path $gitIgnorePath) {
    $content = Get-Content $gitIgnorePath
    $newContent = $content | ForEach-Object {
        if ($_ -match "^\.env\*") {
            "# env files", ".env", ".env.local", ".env.development.local", ".env.test.local", ".env.production.local", "!.env.example"
        } else {
            $_
        }
    }
    $newContent | Out-File -FilePath $gitIgnorePath -Encoding utf8
}
```

### 3. Core Dependencies
```powershell
bun add lucide-react zod zod-form-data clsx tailwind-merge @supabase/supabase-js
bun add -d vitest @vitest/coverage-v8 jsdom @vitejs/plugin-react @testing-library/react @testing-library/jest-dom
```

### 4. Directory Structure
Ensure the following structure is established:
- `src/app/`: Next.js App Router pages.
- `src/components/ui/`: shadcn/ui components.
- `src/lib/`: Shared utilities (supabase client, zod schemas).
- `src/test/`: Test setup and mocks.
- `supabase/migrations/`: SQL migration files.

### 5. Database & Auth (Supabase Cloud)

#### Remote Setup (Primary Path)
Always use a remote Supabase project for POCs to ensure the environment is ready for deployment. Use the CLI to link and push migrations.

**Required Credentials:**
- `SUPABASE_ACCESS_TOKEN`: From [supabase.com/dashboard/account/tokens](https://supabase.com/dashboard/account/tokens).
- `SUPABASE_DB_PASSWORD`: The password set when creating the project.
- `SUPABASE_PROJECT_REF`: The unique ID in your project URL (e.g., `krdpxbpnvemzfxbnkgcq`).

**Workflow:**
```powershell
# 1. Link to the remote project
# Set credentials in the current session (do not store in .env.local)
$env:SUPABASE_ACCESS_TOKEN = "your_token"
$env:SUPABASE_DB_PASSWORD = "your_db_password"

# Use local binary if global is missing
.\node_modules\.bin\supabase.cmd link --project-ref your_project_ref --password $env:SUPABASE_DB_PASSWORD

# 2. Push migrations (Non-interactive)
# CRITICAL: Always use --yes to avoid interactive prompts in agentic workflows.
.\node_modules\.bin\supabase.cmd db push --password $env:SUPABASE_DB_PASSWORD --yes
```

#### Initial Schema
Define the initial schema in `supabase/migrations/00001_initial_schema.sql`:
```sql
-- Demo table
CREATE TABLE demo (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE demo ENABLE ROW LEVEL SECURITY;

-- Basic Policies (Allow anyone to read for POC purposes)
CREATE POLICY "Allow public read access" ON demo FOR SELECT USING (true);

-- Insert dummy records
INSERT INTO demo (name) VALUES ('First Demo Record'), ('Second Demo Record');
```

### 6. Environment Variables & Supabase Client
Create `src/lib/env.ts` for validation:
```typescript
import { z } from "zod";

const envSchema = z.object({
  NEXT_PUBLIC_SUPABASE_PROJECT_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z.string().min(1),
  SUPABASE_SECRET_SERVICE_ROLE_KEY: z.string().min(1),
});

export const env = envSchema.parse({
  NEXT_PUBLIC_SUPABASE_PROJECT_URL: process.env.NEXT_PUBLIC_SUPABASE_PROJECT_URL,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  SUPABASE_SECRET_SERVICE_ROLE_KEY: process.env.SUPABASE_SECRET_SERVICE_ROLE_KEY,
});
```

Create `src/lib/supabase.ts` for the client:
```typescript
import { createClient } from "@supabase/supabase-js";
import { env } from "./env";

export const supabase = createClient(
  env.NEXT_PUBLIC_SUPABASE_PROJECT_URL,
  env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
);

export const supabaseAdmin = createClient(
  env.NEXT_PUBLIC_SUPABASE_PROJECT_URL,
  env.SUPABASE_SECRET_SERVICE_ROLE_KEY
);
```

### 7. Initial CRUD Implementation
Create `src/app/actions.ts` for Server Actions:
```typescript
"use server";

import { supabase } from "@/lib/supabase";
import { revalidatePath } from "next/cache";

export async function addDemoRecord(formData: FormData) {
  const name = formData.get("name") as string;
  if (!name) return;

  const { error } = await supabase.from("demo").insert([{ name }]);
  if (error) {
    console.error("Error adding record:", error);
    return;
  }

  revalidatePath("/");
}
```

Update `src/app/page.tsx` with a working POC:
```tsx
import { supabase } from "@/lib/supabase";
import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { addDemoRecord } from "./actions";

export default async function Home() {
  const { data: records, error } = await supabase
    .from("demo")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) console.error("Error fetching records:", error);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-zinc-50 p-4 font-sans dark:bg-black sm:p-24">
      <main className="flex w-full max-w-4xl flex-col gap-8">
        <Card>
          <CardHeader>
            <CardTitle>Add Demo Record</CardTitle>
            <CardDescription>Enter a name to add a new record to Supabase.</CardDescription>
          </CardHeader>
          <CardContent>
            <form action={addDemoRecord} className="flex gap-4">
              <Input name="name" placeholder="Record name..." required className="max-w-sm" />
              <Button type="submit">Add Record</Button>
            </form>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Demo Records</CardTitle>
            <CardDescription>Records fetched from the `demo` table.</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ID</TableHead>
                  <TableHead>Name</TableHead>
                  <TableHead className="text-right">Created At</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {records?.map((record) => (
                  <TableRow key={record.id}>
                    <TableCell className="font-medium">{record.id.split("-")[0]}...</TableCell>
                    <TableCell>{record.name}</TableCell>
                    <TableCell className="text-right">{new Date(record.created_at).toLocaleString()}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
```

### 8. Testing (Vitest)
Create `vitest.config.ts` in the root:
```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      // Enforce coverage thresholds
      thresholds: {
        lines: 90,
        functions: 90,
        branches: 90,
        statements: 90,
      },
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

Create `src/test/setup.ts`:
```typescript
import '@testing-library/jest-dom'
import { vi } from 'vitest'

// Mock Supabase or other globals if needed
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: vi.fn(() => ({
      select: vi.fn().mockReturnThis(),
      order: vi.fn().mockReturnThis(),
    })),
  },
}))
```

Add test scripts to `package.json`:
```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage"
  }
}
```

## Post-Scaffold Checklist
After scaffolding, the agent MUST communicate the following steps to the user:

1. **GitHub Setup**:
   - Ensure the repository is pushed to GitHub.

2. **Supabase Setup**:
   - Create a project at [supabase.com](https://supabase.com).
   - Run the migrations in `supabase/migrations/00001_initial_schema.sql` via the SQL Editor.
   - Enable Auth providers as needed (Email is default).
   - Add `http://localhost:3000/**` and your Vercel deployment URL to Auth Redirect URLs.

3. **Vercel Deployment (One-time Setup)**:
   - Go to [vercel.com/new](https://vercel.com/new).
   - Import your GitHub repository.
   - In the **Environment Variables** section, add the following:
     - `NEXT_PUBLIC_SUPABASE_PROJECT_URL`: Your Supabase Project URL.
     - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: Your Supabase Anon/Public Key.
     - `SUPABASE_SECRET_SERVICE_ROLE_KEY`: Your Supabase Service Role Key (Secret).
   - Click **Deploy**.

4. **Environment Variables (Local)**:
   - Create a `.env.local` file in the root.
   - Populate it with the same values used in Vercel.

5. **Local Development**:
   - Run `bun install` to ensure all dependencies are locked.
   - Run `bun dev --port 5001` to start the Next.js dev server on the preferred port.

## Conventions
- **Server-First**: Perform DB writes and AI calls in Server Actions or API Routes.
- **Validation**: Use `zod` for all environment variables and request payloads.
- **Observability**: Every AI call must log to the `ai_runs` table (latency, tokens, provider, model).
- **Security**: Never prefix secret keys (like `SUPABASE_SERVICE_ROLE_KEY`) with `NEXT_PUBLIC_`.
- **Port Consistency**: Always use port **5001** for the development server to avoid conflicts with common services (like Grafana on 3000).

## Agentic Best Practices & Limitations (CRITICAL)

### 1. Strict Consent Protocol (Plan-First)
Agents MUST follow a "Plan-First, Execute-Second" workflow for any non-trivial changes:
1.  **Research**: Read necessary files to understand context.
2.  **Plan**: Present a numbered list of intended file creations, modifications, and terminal commands.
3.  **Wait**: Do NOT execute any tool calls (except `read_file`) until the user provides explicit approval (e.g., "Go", "Approved").
4.  **Execute**: Perform the approved steps exactly as planned.

### 2. CLI & Environment Limitations
- **Non-Interactive Only**: Agents cannot respond to interactive prompts (e.g., `[Y/n]`). Always use non-interactive flags:
  - `supabase db push --yes`
  - `supabase db reset --linked --yes`
  - `bunx shadcn@latest add ... --yes`
- **No "Rogue" Pivots**: If a remote setup (e.g., Supabase Cloud) is provided via environment variables, do NOT pivot to a local setup (e.g., Docker) without explicit permission. If credentials are missing, **ASK** the user.
- **Credential Management**: Provide placeholders in `.env.local` for the user to fill in. Never ask for secrets in plain text if they can be provided via the environment.

### 3. Port Management
- Always respect the user's preferred port (e.g., 5001).
- Use `Get-NetTCPConnection` and `Stop-Process` to clear conflicting processes before starting a server.

### 4. Persistence of Protocol
Since agents are stateless across sessions, these instructions MUST be treated as the primary source of truth for maintaining strict boundaries and following the "Plan-First, Execute-Second" workflow.

### 5. Quality Standards
- **Clean Lint Requirement**: ALL changes and improvements MUST result in a clean `bun lint` result. No code should be committed to the repository unless linting passes with zero errors and zero warnings. This requirement must be explicitly stated in the `AGENTS.md` file generated for the project.

## Related Skills
- `bun-manager`: For ongoing package and runtime management.
- `env-manager`: For PATH cleanup and environment variable optimization.
- `github-init`: For repository setup.

## Theme Management
Refer to the **Theme Management & Discovery** section in `AGENTS.md` for efficient theme research and OKLCH conversion protocols. Always preserve the "Finesse" visual system (mesh/grid/glass) when applying new themes.
