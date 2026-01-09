# Todoist Helper Scripts

PowerShell scripts for interacting with the Todoist API.

## Prerequisites

Set your Todoist API token as an environment variable:

```powershell
$env:TODOIST_API_TOKEN = "your_token_here"
```

Get your token from: <https://todoist.com/app/settings/integrations/developer>

## Scripts

### Get-TodoistSummary.ps1

Get a comprehensive overview of your tasks.

```powershell
# Today's summary with completed tasks
.\Get-TodoistSummary.ps1 -IncludeCompleted

# Summary for a specific date
.\Get-TodoistSummary.ps1 -Date "2026-01-05" -IncludeCompleted
```

### Get-TodoistCompleted.ps1

Get completed tasks for a specific date.

```powershell
# Today's completed tasks (table format)
.\Get-TodoistCompleted.ps1

# Specific date
.\Get-TodoistCompleted.ps1 -Date "2026-01-05"

# List format
.\Get-TodoistCompleted.ps1 -Format List

# JSON output
.\Get-TodoistCompleted.ps1 -Format JSON
```

### Get-TodoistTasks.ps1

Get active tasks with filters.

```powershell
# Today's tasks
.\Get-TodoistTasks.ps1 -Filter "today"

# Overdue tasks
.\Get-TodoistTasks.ps1 -Filter "overdue"

# Priority tasks
.\Get-TodoistTasks.ps1 -Filter "p1 | p2"

# Custom filter
.\Get-TodoistTasks.ps1 -Filter "tomorrow & #Work"
```

## Output Formats

All scripts support multiple output formats:

- **Table** (default): Formatted table view
- **List**: Simple list with checkmarks
- **JSON**: JSON output for scripting
- **Raw**: Raw PowerShell objects

## Usage in Other Scripts

```powershell
# Get summary object
$summary = .\Get-TodoistSummary.ps1
Write-Host "You have $($summary.Today) tasks due today"

# Get completed tasks as objects
$completed = .\Get-TodoistCompleted.ps1 -Format Raw
$completed | ForEach-Object { "Completed: $($_.content)" }

# Get tasks as JSON
$tasks = .\Get-TodoistTasks.ps1 -Filter "today" -Format JSON | ConvertFrom-Json
```
