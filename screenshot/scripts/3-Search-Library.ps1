param(
    [Parameter(Mandatory=$false)]
    [string]$Skill = "",
    
    [Parameter(Mandatory=$false)]
    [string[]]$Tags = @(),
    
    [Parameter(Mandatory=$false)]
    [string]$SearchText = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowPaths
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Imported Screenshot Library ===" -ForegroundColor Cyan

$skillsRoot = "C:\Users\User\.claude\skills"
$allImages = @()

# Determine which skills to search
if ($Skill) {
    $skillsToSearch = @($Skill)
} else {
    # Search all skills with images/library folders
    $skillsToSearch = Get-ChildItem $skillsRoot -Directory | 
        Where-Object { Test-Path (Join-Path $_.FullName "images\library") } |
        Select-Object -ExpandProperty Name
}

if (-not $skillsToSearch) {
    Write-Host "No imported screenshots found in any skills." -ForegroundColor Yellow
    exit 0
}

# Scan for images
foreach ($skillName in $skillsToSearch) {
    $libraryPath = Join-Path $skillsRoot "$skillName\images\library"
    
    if (-not (Test-Path $libraryPath)) {
        continue
    }
    
    $metaFiles = Get-ChildItem $libraryPath -Filter "*.meta.json" -Recurse -File
    
    foreach ($metaFile in $metaFiles) {
        $meta = Get-Content $metaFile.FullName -Raw | ConvertFrom-Json
        
        # Apply filters
        $include = $true
        
        # Tag filter
        if ($Tags.Count -gt 0) {
            $hasTag = $false
            foreach ($tag in $Tags) {
                if ($meta.tags -contains $tag) {
                    $hasTag = $true
                    break
                }
            }
            if (-not $hasTag) {
                $include = $false
            }
        }
        
        # Text search filter
        if ($SearchText) {
            $searchIn = @($meta.description, $meta.filename, ($meta.tags -join ' ')) -join ' '
            if ($searchIn -notmatch [regex]::Escape($SearchText)) {
                $include = $false
            }
        }
        
        if ($include) {
            $allImages += [PSCustomObject]@{
                Skill = $meta.skill
                Date = $meta.imported_date
                Filename = $meta.filename
                Description = $meta.description
                Tags = ($meta.tags -join ', ')
                Path = $metaFile.FullName -replace '\.meta\.json$', ''
            }
        }
    }
}

if ($allImages.Count -eq 0) {
    Write-Host "No images found matching your criteria." -ForegroundColor Yellow
    exit 0
}

# Display results
Write-Host "Found $($allImages.Count) images:`n" -ForegroundColor Green

foreach ($img in ($allImages | Sort-Object Date -Descending)) {
    Write-Host "[$($img.Date)] " -ForegroundColor Gray -NoNewline
    Write-Host "$($img.Skill)/" -ForegroundColor Cyan -NoNewline
    Write-Host "$($img.Filename)" -ForegroundColor White
    
    if ($img.Description) {
        $desc = $img.Description
        if ($desc.Length -gt 100) {
            $desc = $desc.Substring(0, 97) + "..."
        }
        Write-Host "  $desc" -ForegroundColor Gray
    }
    
    if ($img.Tags) {
        Write-Host "  Tags: $($img.Tags)" -ForegroundColor DarkGray
    }
    
    if ($ShowPaths) {
        Write-Host "  Path: $($img.Path)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

Write-Host "Total: $($allImages.Count) images" -ForegroundColor Cyan
