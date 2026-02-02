#Requires -Version 7.0

<#
.SYNOPSIS
    View open issues in the hemsoft/skills repository.

.DESCRIPTION
    Switches to the HemSoft GitHub account and displays all open issues
    in the hemsoft/skills repository (the Claude Skills repo).

.EXAMPLE
    .\view-skill-repo-issue.ps1

.NOTES
    Requires: GitHub CLI (gh) installed and authenticated
#>

$InformationPreference = 'Continue'

try {
    # Switch to HemSoft account
    Write-Information "Switching to HemSoft account..."
    gh auth switch --user HemSoft | Out-Null
    
    # List open issues in hemsoft/skills
    Write-Information "Fetching issues from hemsoft/skills..."
    gh issue list --repo hemsoft/skills
}
catch {
    Write-Error "Failed to retrieve issues: $_"
    exit 1
}
