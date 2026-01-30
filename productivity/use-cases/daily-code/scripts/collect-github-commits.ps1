#!/usr/bin/env pwsh
<#
.SYNOPSIS
Collects daily commit data from configured repositories using git log.

.DESCRIPTION
Queries all repositories in the daily-code configuration and collects commit
metrics within a specified time range. Outputs JSON data to the data folder.

.PARAMETER StartTime
Start time for the query range (defaults to 00:00 of current day).
Format: "YYYY-MM-DD HH:mm:ss" or just "YYYY-MM-DD"

.PARAMETER EndTime
End time for the query range (defaults to 23:59:59 of current day).
Format: "YYYY-MM-DD HH:mm:ss" or just "YYYY-MM-DD"

.PARAMETER ConfigPath
Path to the daily-code-config.json file.

.PARAMETER OutputDir
Directory where collected data will be stored.

.EXAMPLE
.\collect-github-commits.ps1

.EXAMPLE
.\collect-github-commits.ps1 -StartTime "2026-01-29" -EndTime "2026-01-30"

.EXAMPLE
.\collect-github-commits.ps1 -StartTime "2026-01-30 08:00:00" -EndTime "2026-01-30 17:00:00"
#>

param(
    [string]$StartTime,
    [string]$EndTime,
    [string]$ConfigPath = "$PSScriptRoot\..\config\daily-code-config.json",
    [string]$OutputDir = "$PSScriptRoot\..\data"
)

# Known author name patterns for your three GitHub accounts
# These are used to filter commits to only your own work
$KnownAuthors = @(
    @{ pattern = "Franz Hemmer"; source = "primary" },
    @{ pattern = "HemSoft"; source = "personal1" },
    @{ pattern = "F. Hemmer"; source = "variations" },
    @{ pattern = "F Hemmer"; source = "variations" },
    @{ pattern = "Relias"; source = "work1" }
)

# Repository-specific exclusion patterns (path-based, not extension-based)
# Only applied to specific repositories
$RepositoryExclusions = @{
    "skills" = @(
        "me/gpt-export/*",        # ChatGPT exports
        "**/*.log",               # Log files
        "**/*.tmp",               # Temporary files
        "**/.vscode/*",           # VS Code cache
        "**/.idea/*"              # IDE cache
    )
}

# Function to check if author matches known patterns
function Test-KnownAuthor {
    param([string]$AuthorName)
    
    foreach ($known in $KnownAuthors) {
        if ($AuthorName -like "*$($known.pattern)*" -or $AuthorName -eq $known.pattern) {
            return $true
        }
    }
    return $false
}

# Function to check if file should be excluded for a given repository
function Test-FileExcluded {
    param(
        [string]$FilePath,
        [string]$RepositoryName
    )
    
    # Check if repository has exclusion rules
    if (-not $RepositoryExclusions.ContainsKey($RepositoryName)) {
        return $false
    }
    
    $patterns = $RepositoryExclusions[$RepositoryName]
    $filePath = $FilePath -replace '\\', '/'
    
    foreach ($pattern in $patterns) {
        $pattern = $pattern -replace '\\', '/'
        
        # Simple glob pattern matching using -like operator
        # Convert glob patterns to -like format
        if ($pattern -eq "**/*.log" -and $filePath -match '\.log$') {
            return $true
        }
        elseif ($pattern -eq "**/*.tmp" -and $filePath -match '\.tmp$') {
            return $true
        }
        elseif ($pattern -match '^\*\*/') {
            # Pattern like **/.vscode/* or **/.idea/*
            $folder = $pattern -replace '\*\*/', ''
            if ($filePath -like "*/$folder*") {
                return $true
            }
        }
        elseif ($filePath -like $pattern) {
            return $true
        }
    }
    return $false
}

# Function to check if a commit modifies .gitignore files
function Test-GitignoreModified {
    param([string[]]$FilePaths)
    
    foreach ($file in $FilePaths) {
        if ($file -match '\.gitignore$') {
            return $true
        }
    }
    return $false
}

# Set default times to current day if not specified
$now = Get-Date
$today = $now.Date

if (-not $StartTime) {
    $startDateTime = $today
}
else {
    # Try parsing with time first, then just date
    try {
        $startDateTime = [datetime]::ParseExact($StartTime, "yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        try {
            $startDateTime = [datetime]::ParseExact($StartTime, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        }
        catch {
            Write-Error "Invalid StartTime format: $StartTime (use 'yyyy-MM-dd' or 'yyyy-MM-dd HH:mm:ss')"
            exit 1
        }
    }
}

if (-not $EndTime) {
    $endDateTime = $today.AddDays(1).AddSeconds(-1)
}
else {
    # Try parsing with time first, then just date
    try {
        $endDateTime = [datetime]::ParseExact($EndTime, "yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        try {
            $endDateTime = [datetime]::ParseExact($EndTime, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            # If only date was provided, set to end of that day
            $endDateTime = $endDateTime.AddDays(1).AddSeconds(-1)
        }
        catch {
            Write-Error "Invalid EndTime format: $EndTime (use 'yyyy-MM-dd' or 'yyyy-MM-dd HH:mm:ss')"
            exit 1
        }
    }
}

Write-Information "Collecting commits from $($startDateTime.ToString('yyyy-MM-dd HH:mm:ss')) to $($endDateTime.ToString('yyyy-MM-dd HH:mm:ss'))" -InformationAction Continue

# Ensure output directory exists
if (-not (Test-Path -Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Load configuration
if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

$config = Get-Content -Path $ConfigPath | ConvertFrom-Json
Write-Information "Loaded configuration with $($config.repositories.Count) repositories" -InformationAction Continue

# Collect commits
$allCommits = @()
$suspiciousCommits = @()
$commitCount = 0
$repositoriesScanned = 0

foreach ($repo in $config.repositories) {
    $repoPath = $repo.path
    
    if (-not (Test-Path -Path $repoPath)) {
        Write-Warning "Repository not found: $($repo.name) at $repoPath"
        continue
    }
    
    $repositoriesScanned++
    Write-Information "Scanning: $($repo.name)" -InformationAction Continue
    
    # Git log format: %H (hash) %ai (author-date ISO format) %an (author name) %s (subject)
    # --numstat shows additions and deletions per file
    
    try {
        # Git --since and --until work best with ISO timestamps
        $sinceStr = $startDateTime.ToString("o")
        $untilStr = $endDateTime.ToString("o")
        
        # Save current directory and change to repo
        $prevDir = Get-Location
        Set-Location -Path $repoPath -ErrorAction Stop
        
        # Create temp file to capture git output
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        try {
            # Run git and directly write to file to avoid PowerShell delimiter issues
            # Using commit-separator pattern: hash, newline, then numstat, then blank line
            & git log --all --since="$sinceStr" --until="$untilStr" --numstat --pretty="format:%H%n%ai%n%an%n%s" | Out-File -FilePath $tempFile -Encoding UTF8
            
            # Read file and parse
            $fileContent = Get-Content -Path $tempFile -Raw
            
            if ($fileContent) {
                Write-Information "  Processing git output for $($repo.name)" -InformationAction Continue
                
                # Split by double newline to separate commits
                $commits = $fileContent -split "`n`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                
                Write-Information "  Found $($commits.Count) commits" -InformationAction Continue
                
                foreach ($commitLines in $commits) {
                    $lines = $commitLines -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    
                    if ($lines.Count -lt 4) {
                        continue
                    }
                    
                    # Parse header lines
                    $hash = $lines[0].Trim()
                    $dateStr = $lines[1].Trim()
                    $author = $lines[2].Trim()
                    $subject = $lines[3].Trim()
                    
                    # Skip if hash is invalid
                    if ($hash.Length -lt 7) {
                        continue
                    }
                    
                    # Parse ISO date
                    try {
                        $commitDate = [datetime]::Parse($dateStr)
                    }
                    catch {
                        Write-Warning "Could not parse date in $($repo.name): $dateStr"
                        continue
                    }
                    
                    # Check if author matches known patterns
                    $isKnownAuthor = Test-KnownAuthor -AuthorName $author
                    if (-not $isKnownAuthor) {
                        # Log suspicious commit for review
                        $suspiciousCommits += @{
                            repository = $repo.name
                            hash = $hash.Substring(0, 7)
                            author = $author
                            subject = $subject
                            date = $commitDate.ToString("yyyy-MM-dd HH:mm:ss")
                            reason = "Unknown author name not matching known patterns"
                        }
                        Write-Information "  ⚠️ Suspicious commit in $($repo.name) by '$author': $subject" -InformationAction Continue
                        continue
                    }
                    
                    # Process numstat lines (remaining lines after first 4)
                    $additions = 0
                    $deletions = 0
                    $filesProcessed = @()
                    
                    for ($i = 4; $i -lt $lines.Count; $i++) {
                        $statLine = $lines[$i]
                        
                        # Split on tab
                        $statParts = $statLine -split "`t"
                        if ($statParts.Count -ge 3) {
                            $add = $statParts[0]
                            $del = $statParts[1]
                            $filepath = $statParts[2]
                            
                            # Skip binary files (marked with -)
                            if ($add -ne "-" -and $del -ne "-" -and $add -match '^\d+$' -and $del -match '^\d+$') {
                                # Check if file should be excluded for this repository
                                if (Test-FileExcluded -FilePath $filepath -RepositoryName $repo.name) {
                                    Write-Information "    [EXCLUDED] $filepath" -InformationAction Continue
                                    continue
                                }
                                
                                $additions += [int]$add
                                $deletions += [int]$del
                                $filesProcessed += $filepath
                            }
                        }
                    }
                    
                    # Check if .gitignore was modified
                    $gitignoreModified = Test-GitignoreModified -FilePaths $filesProcessed
                    
                    # Create commit object
                    $linesAffected = $additions + $deletions
                    $commitObj = @{
                        repositoryName = $repo.name
                        repositorySource = $repo.source
                        hash = $hash.Substring(0, 7)
                        fullHash = $hash
                        date = $commitDate.ToString("yyyy-MM-dd")
                        time = $commitDate.ToString("HH:mm:ss")
                        timestamp = $commitDate.ToString("o")
                        author = $author
                        subject = $subject
                        additions = $additions
                        deletions = $deletions
                        linesAffected = $linesAffected
                        netLOC = $additions - $deletions
                        gitignoreModified = $gitignoreModified
                    }
                    $allCommits += $commitObj
                    $commitCount++
                }
            }
        }
        finally {
            # Clean up temp file
            if (Test-Path -Path $tempFile) {
                Remove-Item -Path $tempFile -Force
            }
        }
        
        Set-Location -Path $prevDir
    }
    catch {
        Write-Warning "Error querying repository $($repo.name): $_"
        continue
    }
}

# Create output data structure
$outputData = @{
    collectionTime = (Get-Date).ToString("o")
    queryStartTime = $startDateTime.ToString("o")
    queryEndTime = $endDateTime.ToString("o")
    queryStartTimeLocal = $startDateTime.ToString("yyyy-MM-dd HH:mm:ss")
    queryEndTimeLocal = $endDateTime.ToString("yyyy-MM-dd HH:mm:ss")
    repositoriesScanned = $repositoriesScanned
    commitsFound = $commitCount
    commits = $allCommits
    suspiciousCommitsFound = @($suspiciousCommits).Count
    suspiciousCommits = $suspiciousCommits
    summary = @{
        totalAdditions = ($allCommits | Measure-Object -Property additions -Sum).Sum
        totalDeletions = ($allCommits | Measure-Object -Property deletions -Sum).Sum
        totalLinesAffected = ($allCommits | Measure-Object -Property linesAffected -Sum).Sum
        totalNetLOC = ($allCommits | Measure-Object -Property netLOC -Sum).Sum
        commitsByRepository = @()
    }
}

# Calculate summary by repository
$repoGroups = $allCommits | Group-Object -Property repositoryName
foreach ($group in $repoGroups) {
    $repoSummary = @{
        repository = $group.Name
        commits = $group.Count
        additions = ($group.Group | Measure-Object -Property additions -Sum).Sum
        deletions = ($group.Group | Measure-Object -Property deletions -Sum).Sum
        linesAffected = ($group.Group | Measure-Object -Property linesAffected -Sum).Sum
        netLOC = ($group.Group | Measure-Object -Property netLOC -Sum).Sum
    }
    $outputData.summary.commitsByRepository += $repoSummary
}

# Output filename with timestamp
$dateStr = $startDateTime.ToString("yyyy-MM-dd")
$outputFile = Join-Path $OutputDir "commits-$dateStr.json"

# Write JSON output
$outputData | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputFile -Encoding UTF8 -Force

# Log alerts to alerts skill if suspicious commits found
if ($suspiciousCommits.Count -gt 0) {
    # Use centralized alerts directory
    $alertsSkillDir = Resolve-Path -Path "$PSScriptRoot\..\..\..\..\alerts\productivity" -ErrorAction SilentlyContinue
    if (-not $alertsSkillDir) {
        $alertsSkillDir = Join-Path $env:USERPROFILE ".claude\skills\alerts\productivity"
    }
    
    if (-not (Test-Path -Path $alertsSkillDir)) {
        New-Item -ItemType Directory -Path $alertsSkillDir -Force | Out-Null
    }
    
    $historyFile = Join-Path $alertsSkillDir "history.json"
    
    # Read existing alerts or start with empty array
    $alertHistory = @()
    if (Test-Path -Path $historyFile) {
        try {
            $alertHistory = Get-Content -Path $historyFile -Raw | ConvertFrom-Json
            if ($null -eq $alertHistory) {
                $alertHistory = @()
            }
        }
        catch {
            Write-Warning "Could not parse existing alerts: $_"
            $alertHistory = @()
        }
    }
    
    # Add new suspicious commit alerts in standardized format
    $now = Get-Date -Format "o"
    foreach ($suspicious in $suspiciousCommits) {
        $alertEntry = @{
            timestamp = $now
            level = "warning"
            alertType = "suspicious-commit"
            skillName = "productivity"
            title = "Suspicious Commit Detected"
            description = "Unknown author detected in commit"
            details = @{
                repository = $suspicious.repository
                commit = $suspicious.hash
                author = $suspicious.author
                subject = $suspicious.subject
                date = $suspicious.date
                reason = $suspicious.reason
            }
            status = "active"
        }
        $alertHistory += $alertEntry
    }
    
    # Write updated alert history
    $alertHistory | ConvertTo-Json -Depth 5 | Out-File -FilePath $historyFile -Encoding UTF8 -Force
    Write-Information "⚠️ $($suspiciousCommits.Count) suspicious commits logged to alerts skill" -InformationAction Continue
}

Write-Information "Data collection complete" -InformationAction Continue
Write-Information "Total commits found: $commitCount" -InformationAction Continue
Write-Information "Total lines affected: $($outputData.summary.totalLinesAffected)" -InformationAction Continue
Write-Information "Total net LOC: $($outputData.summary.totalNetLOC)" -InformationAction Continue
Write-Information "Output file: $outputFile" -InformationAction Continue
Write-Output $outputData | ConvertTo-Json -Depth 3
