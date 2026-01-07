param(
    [Parameter(Mandatory=$true)] [string]$RepoName,
    [Parameter(Mandatory=$true)] [string]$Owner,
    [Parameter(Mandatory=$true)] [ValidateSet("Personal", "Work")] [string]$Profile,
    [bool]$Private = $true
)

$ErrorActionPreference = "Stop"

# 1. Validate Environment
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) is not installed." }

# 2. Create GitHub Repository
$visibility = if ($Private) { "--private" } else { "--public" }
Write-Host "Creating repository $Owner/$RepoName..."
gh repo create "$Owner/$RepoName" $visibility --confirm

# 3. Initialize Local Repository
if (Test-Path .git) {
    Write-Warning "Git repository already initialized. Skipping git init."
} else {
    Write-Host "Initializing local git repository..."
    git init -b main
}

# 3.5 Set Local Git Identity
$gitName = if ($Profile -eq "Personal") { "Franz Hemmer" } else { "Franz Hemmer" }
$gitEmail = if ($Profile -eq "Personal") { "franz_hemmer@hotmail.com" } else { "fhemmer@relias.com" }

Write-Host "Setting local git identity to $gitName <$gitEmail>..."
git config --local user.name "$gitName"
git config --local user.email "$gitEmail"

# 4. Commit and Push
$alias = if ($Profile -eq "Personal") { "github-personal" } else { "github-work" }
$remoteUrl = "git@$($alias):$($Owner)/$($RepoName).git"

git add .
# Only commit if there are changes to commit
if (git status --porcelain) {
    git commit -m "Initial commit"
} else {
    Write-Warning "No files to commit. Creating an empty commit to initialize the branch."
    git commit --allow-empty -m "Initial commit"
}

if (git remote | Select-String "origin") {
    git remote set-url origin $remoteUrl
} else {
    git remote add origin $remoteUrl
}

Write-Host "Pushing to $remoteUrl..."
git push -u origin main

# 5. Report Success
$repoUrl = "https://github.com/$Owner/$RepoName"
Write-Host "`nSUCCESS: Repository initialized and pushed."
Write-Host "Repository URL: $repoUrl"
