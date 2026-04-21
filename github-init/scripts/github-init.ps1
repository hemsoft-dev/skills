param(
    [Parameter(Mandatory=$true)] [string]$RepoName,
    [Parameter(Mandatory=$true)] [string]$Owner,
    [Parameter(Mandatory=$true)] [ValidateSet("Personal1", "Work1")] [string]$Profile,
    [ValidateSet("private", "public", "internal")] [string]$Visibility = "private"
)

$ErrorActionPreference = "Stop"

# 1. Validate Environment
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) is not installed." }

# 2. Create GitHub Repository
Write-Information "Creating repository $Owner/$RepoName ($Visibility)..."
gh repo create "$Owner/$RepoName" --$Visibility

# 3. Initialize Local Repository
if (Test-Path .git) {
    Write-Warning "Git repository already initialized. Skipping git init."
} else {
    Write-Information "Initializing local git repository..."
    git init -b main
}

# 3.5 Set Local Git Identity
$gitName = "Franz Hemmer"
$gitEmail = switch ($Profile) {
    "Personal1" { "franz_hemmer@hotmail.com" }
    "Work1"     { "fhemmer@relias.com" }
}

Write-Information "Setting local git identity to $gitName <$gitEmail>..."
git config --local user.name "$gitName"
git config --local user.email "$gitEmail"

# 4. Commit and Push
$alias = switch ($Profile) {
    "Personal1" { "github-personal1" }
    "Work1"     { "github-work1" }
}
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

Write-Information "Pushing to $remoteUrl..."
git push -u origin main

# 5. Report Success
$repoUrl = "https://github.com/$Owner/$RepoName"
Write-Information "`nSUCCESS: Repository initialized and pushed."
Write-Information "Repository URL: $repoUrl"
