---
name: dotnet11
description: "V1.0 - .NET 11 (STS, GA Nov 2026, currently in preview) reference covering runtime-native async, C# 15 union types & collection expression arguments, library APIs, SDK/CLI changes, ASP.NET Core, Blazor, EF Core, MAUI, and support lifecycle. Use when working with .NET 11 previews, targeting net11.0, evaluating migration, or answering questions about new .NET 11 / C# 15 features."
license: Apache-2.0
compatibility: Requires network access for live docs lookups. .NET 11 SDK (preview) optional for hands-on use.
metadata:
  author: User
  version: "1.0"
  last_verified: "2026-06-02"
  based_on: "Preview 4 (2026-05-12)"
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the dotnet11 directory (path contains 'dotnet11'), verify that history logging occurred.

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
            Before stopping, if dotnet11 was used (check if any files in dotnet11 directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in dotnet11 directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# .NET 11

Expert reference for **.NET 11** and **C# 15**. As of this skill's last verification (2026-06-02), .NET 11 is **in preview** (latest: **Preview 4**, released 2026-05-12). GA is expected **November 2026**. Details may shift between previews — for anything version-critical, confirm against the live links in the References section.

## Quick Facts

| Item | Value |
|------|-------|
| Release type | **STS** (Standard Term Support) — *not* LTS |
| GA (expected) | **November 2026** |
| Support window | Nov 10, 2026 → **Nov 9, 2028** (2 years) |
| Target Framework Moniker | `net11.0` |
| Language | **C# 15** (also F#, Visual Basic) |
| Latest preview (verified) | Preview 4 — SDK `11.0.100-preview.4` (2026-05-12) |
| Previous LTS | .NET 10 (Nov 2025, 3-year support) |
| Downloads | <https://dotnet.microsoft.com/download/dotnet/11.0> |

> ⚠️ **STS vs LTS**: If a project needs long-term support, recommend **.NET 10 (LTS)** instead. Choose .NET 11 for newest features with a 2-year horizon, or as a stepping stone to the next LTS (.NET 12).

## Runtime

- **Runtime-native async ("Runtime Async")** — the headline feature. Async methods are managed at the runtime level instead of being purely compiler-generated state machines. Benefits: cleaner/accurate async stack traces, lower allocation overhead, better perf for async-heavy workloads. For projects targeting `net11.0` it **no longer requires** `<EnablePreviewFeatures>true</EnablePreviewFeatures>`; the runtime libraries themselves are compiled with `runtime-async=on`.
- **Updated minimum hardware requirements** for x86/x64 and Arm64 — requires more modern instruction sets (improves perf, reduces maintenance). Flag this for old hardware / CI agents.
- **JIT improvements**: bounds-check elimination, redundant checked-context removal, switch-expression folding, constant-folding `SequenceEqual`, redundant branch elimination, new **Arm SVE2 intrinsics**, improved hardware-intrinsic cost modeling.
- **CoreCLR on WebAssembly** — foundational transition from Mono toward CoreCLR for Wasm, targeting better perf and server/browser parity (in progress).

## Libraries — New / Improved APIs

- **`System.Diagnostics.Process`**: run-and-capture helpers, fire-and-forget launches, `SafeProcessHandle` lifecycle methods, tighter handle control.
- **Compression** (`System.IO.Compression`): native **Zstandard** compression, improved Base64 APIs, new ZIP archive-entry methods, CRC32 validation when reading ZIP entries.
- **`System.Text.Json`**: generic type-info retrieval, **`JsonNamingPolicy.PascalCase`**, per-member naming-policy overrides, type-level ignore conditions, **F# discriminated-union support**, `Utf8JsonWriter.Reset` with options.
- **Discriminated-union scaffolding**: `UnionAttribute` and `IUnion` in `System.Runtime.CompilerServices` (backs C# 15 union types).
- **OpenTelemetry**: built-in metrics for `MemoryCache` (`Microsoft.Extensions.Caching.Memory`).
- **Tar**: archive format selection + GNU sparse format 1.0 support.
- **Console**: honors the `FORCE_COLOR` environment variable.
- **Security/Networking**: TLS handshake hardening + certificate-validation alerts on Linux; HTTP/2 automatic downgrade for Windows authentication.
- Other notables across previews: hard-link creation, `BFloat16` floating-point type, HMAC/KMAC verification, GC heap hard limit for 32-bit processes.

## SDK & CLI

- **Smaller installers** on Linux/macOS via assembly deduplication; skips crossgen for `DotnetTools`-only assemblies.
- **`dotnet sln`**: create and edit **solution filters (`.slnf`)** from the CLI.
- **`dotnet run -e KEY=VALUE`**: pass environment variables from the command line.
- **File-based apps**: `#:include` directive to split single-file apps across multiple files.
- **`dotnet watch`**: Aspire app-host integration, automatic crash recovery, device selection for MAUI/mobile.
- **Telemetry**: OpenTelemetry replaces Application Insights for CLI telemetry.
- **Analyzer**: improved `CA1873` (less noise, clearer messages).
- Foundation for a **NativeAOT entry point** for the `dotnet` CLI.

## C# 15

Two confirmed headline features (ships with .NET 11; needs C# 15 / preview SDK):

### Collection expression arguments

Pass constructor/factory arguments via a `with(...)` element as the **first** element of a collection expression:

```csharp
string[] values = ["one", "two", "three"];

// capacity into List<T>
List<string> names = [with(capacity: values.Length * 2), .. values];

// comparer into HashSet<T>
HashSet<string> set = [with(StringComparer.OrdinalIgnoreCase), "Hello", "HELLO", "hello"];
// -> single element (case-insensitive)
```

### Union types

A value that is exactly one of several **case types**, declared with the `union` keyword:

```csharp
public record class Cat(string Name);
public record class Dog(string Name);
public record class Bird(string Name);

public union Pet(Cat, Dog, Bird);

Pet pet = new Dog("Rex");          // implicit conversion from each case type
string name = pet switch           // compiler enforces exhaustive switch
{
    Dog d => d.Name,
    Cat c => c.Name,
    Bird b => b.Name,
};
```

> Union types first appeared in Preview 2. In **early** previews `UnionAttribute`/`IUnion` weren't in the runtime and had to be declared in-project; **later** previews include them. Some proposal features aren't yet implemented — verify against the C# 15 docs.

Set the language version explicitly when needed:

```xml
<LangVersion>preview</LangVersion>
```

## ASP.NET Core & Blazor

- Richer **OpenTelemetry** semantic attributes for metrics/tracing.
- **Blazor**: `EnvironmentBoundary` component (render by hosting environment), `IHostedService` support in WebAssembly, improved Hot Reload for project-reference changes.
- HTTP/2 automatic downgrade for Windows auth; TLS hardening (shared with libraries).
- See live: <https://learn.microsoft.com/aspnet/core/release-notes/aspnetcore-11>

## EF Core 11

- Continued vector-search / cloud-native investments and API refinements.
- See live: <https://learn.microsoft.com/ef/core/what-is-new/ef-core-11.0/whatsnew>

## .NET MAUI

- XAML source generation on by default, **CoreCLR as default for Android**, improved Hot Reload workflows.

## Other Languages

- **F#**: parallel compilation on by default, optimized computation expressions, new FSI flags (`--disableLanguageFeature`, `--typecheck-only`).
- **Visual Basic**: no major language features this cycle.

## Getting Started

```bash
# Verify installed SDKs (look for 11.0.x preview)
dotnet --list-sdks

# Create a project targeting .NET 11
dotnet new console -o MyApp
# ensure <TargetFramework>net11.0</TargetFramework> in the .csproj

# Pass env vars at runtime (new in 11)
dotnet run -e ASPNETCORE_ENVIRONMENT=Development
```

Install side-by-side with existing SDKs; preview SDKs don't disturb GA installs. Visual Studio 2026 Insiders bundles the .NET 11 preview SDK.

## Guidance / Pushback Cues

- Recommending .NET 11 for a long-lived production system → note it's **STS (2 yr)**; suggest .NET 10 LTS unless they specifically want the new features.
- Anything marked "in preview" here may change before GA — when correctness matters, fetch the live link.
- Runtime-native async changes stack-trace shape; warn teams that parse/scrape stack traces.
- Updated minimum hardware requirements may break old CI agents / VMs.

## References (authoritative — fetch for current detail)

- What's new in .NET 11: <https://learn.microsoft.com/dotnet/core/whats-new/dotnet-11/overview>
- Release notes (GitHub): <https://github.com/dotnet/core/blob/main/release-notes/11.0/README.md>
- C# 15: <https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-15>
- Downloads: <https://dotnet.microsoft.com/download/dotnet/11.0>
- .NET Blog: <https://devblogs.microsoft.com/dotnet/>
- Support policy: <https://learn.microsoft.com/dotnet/core/releases-and-support>
