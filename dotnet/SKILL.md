---
name: dotnet
description: V1.0 - Expert in .NET SDK installation, CLI tooling, project templates, NuGet packages, and development workflows on Windows.
---

# .NET Expert

Comprehensive guidance for .NET SDK installation, CLI commands, project management, and development on Windows.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Installation on Windows

### Recommended: WinGet (System-Wide)

```powershell
# Install latest SDK (includes all runtimes)
winget install --id Microsoft.DotNet.SDK.10 -e --source winget

# Install LTS SDK (includes all runtimes)
winget install --id Microsoft.DotNet.SDK.8 -e --source winget

# Install specific versions
winget install --id Microsoft.DotNet.SDK.9 -e --source winget

# Install runtimes only (for deployment, not development)
winget install --id Microsoft.DotNet.DesktopRuntime.10 -e --source winget
winget install --id Microsoft.DotNet.AspNetCore.10 -e --source winget
```

**Install location:** `C:\Program Files\dotnet\`

**⚠️ Important:** Install the **SDK** for development (not just runtime). The SDK includes all runtimes plus build tools.

### Alternative: PowerShell Script (User Directory)

```powershell
# Download and run installer for LTS channel
Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile "$env:TEMP\dotnet-install.ps1"
& "$env:TEMP\dotnet-install.ps1" -Channel LTS

# Install specific versions
& "$env:TEMP\dotnet-install.ps1" -Channel 10.0
& "$env:TEMP\dotnet-install.ps1" -Channel 9.0
```

**Install location:** `$env:USERPROFILE\AppData\Local\Microsoft\dotnet`

#### Add to PowerShell Profile

```powershell
@"
##---------------------------------------
## PATH Additions
##---------------------------------------
# .NET SDK (installed via dotnet-install.ps1)
`$dotnetPath = "`$env:USERPROFILE\AppData\Local\Microsoft\dotnet"
if ((Test-Path `$dotnetPath) -and (`$env:PATH -notlike "*`$dotnetPath*")) {
    `$env:PATH = "`$dotnetPath;`$env:PATH"
}
"@ | Add-Content -Path $PROFILE
```

### Verify Installation

```powershell
dotnet --version
dotnet --list-sdks
dotnet --list-runtimes
dotnet --info
```

## .NET CLI Commands

### Project Creation

```powershell
# List all templates
dotnet new list

# Common templates
dotnet new console              # Console app
dotnet new console -f net10.0   # Specific framework
dotnet new classlib             # Class library
dotnet new web                  # ASP.NET Core empty
dotnet new webapi               # ASP.NET Core Web API
dotnet new mvc                  # ASP.NET Core MVC
dotnet new blazor               # Blazor Web App
dotnet new razor                # Razor Pages
dotnet new worker               # Worker Service
dotnet new xunit                # xUnit test project
dotnet new nunit                # NUnit test project
dotnet new mstest               # MSTest project
dotnet new sln                  # Solution file

# With options
dotnet new console -n MyApp -o ./src/MyApp -f net10.0
dotnet new webapi --no-https --use-controllers
```

**Common Options:**

- `-n|--name` - Project name
- `-o|--output` - Output directory
- `-f|--framework` - Target framework (net10.0, net9.0, net8.0)
- `--dry-run` - Preview what would be created
- `--force` - Overwrite existing files

### Build & Run

```powershell
# Restore packages (implicit in most commands)
dotnet restore

# Build
dotnet build
dotnet build --configuration Release
dotnet build --no-restore

# Run
dotnet run
dotnet run --project ./src/MyApp
dotnet run --configuration Release

# Clean
dotnet clean
```

### Testing

```powershell
# Run all tests
dotnet test

# With options
dotnet test --configuration Release
dotnet test --no-build
dotnet test --verbosity normal
dotnet test --logger "console;verbosity=detailed"
dotnet test --filter "FullyQualifiedName~MyNamespace"
dotnet test --collect:"XPlat Code Coverage"
```

### Publishing

```powershell
# Framework-dependent deployment
dotnet publish -c Release

# Self-contained deployment (includes runtime)
dotnet publish -c Release --self-contained -r win-x64
dotnet publish -c Release --self-contained -r win-arm64

# Single-file executable
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true

# Trimmed (smaller size)
dotnet publish -c Release -r win-x64 --self-contained -p:PublishTrimmed=true
```

**Common Runtime Identifiers (RIDs):**

- `win-x64` - Windows 64-bit
- `win-x86` - Windows 32-bit
- `win-arm64` - Windows ARM64
- `linux-x64` - Linux 64-bit
- `osx-x64` - macOS Intel
- `osx-arm64` - macOS Apple Silicon

## NuGet Package Management

### Add/Remove Packages

```powershell
# Add package (latest version)
dotnet package add Newtonsoft.Json

# Add specific version
dotnet package add Microsoft.EntityFrameworkCore -v 8.0.0

# Add with framework constraint
dotnet package add Serilog -f net10.0

# Add from specific source
dotnet package add MyPackage -s https://my-nuget-feed.com/v3/index.json

# Add prerelease
dotnet package add Microsoft.Extensions.Logging --prerelease

# Remove package
dotnet package remove Newtonsoft.Json

# List packages
dotnet package list
dotnet package list --outdated
dotnet package list --deprecated
```

**Note:** .NET 10+ uses `dotnet package add`. Earlier versions use `dotnet add package`.

### Package Restore & Update

```powershell
# Restore packages
dotnet restore

# Update all packages (via package list)
dotnet package update
```

### NuGet Sources

```powershell
# List sources
dotnet nuget list source

# Add source
dotnet nuget add source https://my-feed.com/v3/index.json -n MyFeed

# Remove source
dotnet nuget remove source MyFeed

# Enable/disable source
dotnet nuget enable source MyFeed
dotnet nuget disable source MyFeed
```

### Global Package Cache

```powershell
# List cached packages
dotnet nuget locals all --list

# Clear cache
dotnet nuget locals all --clear
dotnet nuget locals http-cache --clear
dotnet nuget locals global-packages --clear
```

## Solution Management

```powershell
# Create solution
dotnet new sln -n MySolution

# Add projects to solution
dotnet sln add ./src/MyApp/MyApp.csproj
dotnet sln add ./tests/MyApp.Tests/MyApp.Tests.csproj

# Remove project from solution
dotnet sln remove ./src/MyApp/MyApp.csproj

# List projects in solution
dotnet sln list
```

## Project References

```powershell
# Add project reference
dotnet reference add ../MyLibrary/MyLibrary.csproj

# Add multiple references
dotnet reference add ../Lib1/Lib1.csproj ../Lib2/Lib2.csproj

# List references
dotnet reference list

# Remove reference
dotnet reference remove ../MyLibrary/MyLibrary.csproj
```

## Global Tools

```powershell
# Install global tool
dotnet tool install -g dotnet-ef
dotnet tool install -g dotnet-outdated
dotnet tool install -g dotnet-format

# List installed tools
dotnet tool list -g

# Update tool
dotnet tool update -g dotnet-ef

# Uninstall tool
dotnet tool uninstall -g dotnet-ef

# Run tool
dotnet ef migrations add InitialCreate
dotnet format
```

**Popular Global Tools:**

- `dotnet-ef` - Entity Framework Core CLI
- `dotnet-format` - Code formatter
- `dotnet-outdated` - Check for outdated packages
- `dotnet-script` - Run C# scripts
- `dotnet-suggest` - Shell completions

## SDK Management

```powershell
# Check installed SDKs
dotnet --list-sdks

# Check for updates
dotnet sdk check

# Use specific SDK via global.json
dotnet new globaljson --sdk-version 10.0.100
dotnet new globaljson --sdk-version 9.0.100 --roll-forward latestFeature
```

**global.json example:**

```json
{
  "sdk": {
    "version": "10.0.100",
    "rollForward": "latestFeature"
  }
}
```

## Target Frameworks

### Framework Monikers (TFMs)

- `net10.0` - .NET 10
- `net9.0` - .NET 9
- `net8.0` - .NET 8 (LTS)
- `net6.0` - .NET 6 (LTS, extended support)
- `net48` - .NET Framework 4.8
- `netstandard2.0` - .NET Standard 2.0 (for libraries)
- `netstandard2.1` - .NET Standard 2.1

### Multi-Targeting

```xml
<PropertyGroup>
  <TargetFrameworks>net10.0;net8.0;net48</TargetFrameworks>
</PropertyGroup>
```

## Runtimes vs SDK

### Runtime Types

- **.NET Runtime** - Runs .NET apps only
- **.NET Desktop Runtime** - Runs desktop apps (WPF, WinForms)
- **ASP.NET Core Runtime** - Runs web apps
- **.NET SDK** - Includes all runtimes + build tools

**For Development:** Install SDK
**For Deployment:** Install appropriate runtime(s)

## Workload Management

```powershell
# List available workloads
dotnet workload search

# Install workload
dotnet workload install maui
dotnet workload install wasm-tools
dotnet workload install aspire

# List installed workloads
dotnet workload list

# Update workloads
dotnet workload update

# Uninstall workload
dotnet workload uninstall maui
```

**Common Workloads:**

- `maui` - .NET MAUI (cross-platform UI)
- `wasm-tools` - WebAssembly tools
- `aspire` - .NET Aspire (cloud-native)

## Common Project File Settings

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <!-- Target Framework -->
    <TargetFramework>net10.0</TargetFramework>
    
    <!-- Output Type -->
    <OutputType>Exe</OutputType>
    
    <!-- Language Version -->
    <LangVersion>latest</LangVersion>
    
    <!-- Nullable Reference Types -->
    <Nullable>enable</Nullable>
    
    <!-- Implicit Usings -->
    <ImplicitUsings>enable</ImplicitUsings>
    
    <!-- Treat Warnings as Errors -->
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    
    <!-- Assembly Info -->
    <AssemblyName>MyApp</AssemblyName>
    <RootNamespace>MyCompany.MyApp</RootNamespace>
    <Version>1.0.0</Version>
  </PropertyGroup>
</Project>
```

## Troubleshooting

### No .NET SDK Found

```powershell
# Check if both x86 and x64 are installed
where.exe dotnet

# If C:\Program Files (x86)\dotnet comes first, fix PATH
# Windows Key → "Edit the system environment variables"
# Environment Variables → System variables → Path
# Move "C:\Program Files\dotnet\" above "C:\Program Files (x86)\dotnet\"
```

### Missing DLLs (hostfxr.dll, api-ms-win-crt-runtime-l1-1-0.dll)

Install Visual C++ 2015-2019 Redistributable:

- [64-bit](https://aka.ms/vs/16/release/vc_redist.x64.exe)
- [32-bit](https://aka.ms/vs/16/release/vc_redist.x86.exe)

### Slow Builds (Smart App Control)

Disable Smart App Control in Windows Settings:

- Settings → Privacy & Security → Windows Security → App & browser control → Smart App Control → Off

### Clear NuGet Cache

```powershell
dotnet nuget locals all --clear
dotnet restore --force
```

### SDK Version Conflicts

Create `global.json` to pin SDK version:

```powershell
dotnet new globaljson --sdk-version 10.0.100
```

## Development Workflows

### Create New Console App

```powershell
# Create project
dotnet new console -n MyApp -o ./MyApp
cd ./MyApp

# Add packages
dotnet package add Newtonsoft.Json
dotnet package add Serilog

# Build and run
dotnet build
dotnet run
```

### Create Solution with Projects

```powershell
# Create solution structure
mkdir MySolution
cd MySolution
dotnet new sln -n MySolution

# Create projects
dotnet new webapi -n MySolution.Api -o ./src/MySolution.Api
dotnet new classlib -n MySolution.Core -o ./src/MySolution.Core
dotnet new xunit -n MySolution.Tests -o ./tests/MySolution.Tests

# Add to solution
dotnet sln add ./src/MySolution.Api
dotnet sln add ./src/MySolution.Core
dotnet sln add ./tests/MySolution.Tests

# Add project references
dotnet reference ./src/MySolution.Api add ./src/MySolution.Core
dotnet reference ./tests/MySolution.Tests add ./src/MySolution.Api
```

### Hot Reload (dotnet watch)

```powershell
# Run with hot reload
dotnet watch run

# Test with hot reload
dotnet watch test
```

## Quick Reference

### Most Used Commands

```powershell
dotnet new console -n MyApp    # Create console app
dotnet new webapi -n MyApi     # Create Web API
dotnet build                   # Build project
dotnet run                     # Run project
dotnet test                    # Run tests
dotnet package add {Package}   # Add NuGet package
dotnet publish -c Release      # Publish release build
dotnet --version               # Check SDK version
```

### Version Check

```powershell
dotnet --version               # SDK version
dotnet --list-sdks             # All installed SDKs
dotnet --list-runtimes         # All installed runtimes
dotnet --info                  # Full environment info
```

### Help

```powershell
dotnet --help
dotnet new --help
dotnet build --help
dotnet {command} --help
```

## Related Resources

- [.NET Download](https://dotnet.microsoft.com/download)
- [.NET Documentation](https://learn.microsoft.com/en-us/dotnet/)
- [NuGet Gallery](https://www.nuget.org/)
- [.NET CLI Reference](https://learn.microsoft.com/en-us/dotnet/core/tools/)
