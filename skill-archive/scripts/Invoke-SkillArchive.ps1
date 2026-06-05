[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string] $SkillName,

    [Parameter()]
    [string] $SkillRoot = (Join-Path -Path $HOME -ChildPath '.agents/skills'),

    [Parameter()]
    [string] $ArchiveRoot = (Join-Path -Path $HOME -ChildPath '.agents/skills-archived'),

    [Parameter()]
    [ValidateRange(1, 3650)]
    [int] $InactiveDays = 90,

    [Parameter()]
    [ValidateRange(1, 200)]
    [int] $Limit = 25,

    [Parameter()]
    [switch] $Force
)

function Get-SkillLastHistoryDate {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo] $SkillDirectory
    )

    $historyPath = Join-Path -Path $SkillDirectory.FullName -ChildPath 'History'
    if (-not (Test-Path -LiteralPath $historyPath -PathType Container)) {
        return $null
    }

    $historyFiles = Get-ChildItem -LiteralPath $historyPath -Filter '*.md' -File -ErrorAction SilentlyContinue
    if (-not $historyFiles) {
        return $null
    }

    $datedEntries = foreach ($file in $historyFiles) {
        if ($file.BaseName -match '^\d{4}-\d{2}-\d{2}$') {
            try {
                [datetime]::ParseExact($file.BaseName, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            }
            catch {
                $null
            }
        }
    }

    $latestDatedEntry = $datedEntries | Where-Object { $null -ne $_ } | Sort-Object -Descending | Select-Object -First 1
    if ($latestDatedEntry) {
        return $latestDatedEntry
    }

    return ($historyFiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.Date
}

function Get-SkillArchiveCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Root,

        [Parameter(Mandatory = $true)]
        [datetime] $CutoffDate
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "Skill root not found: $Root"
    }

    $skillDirectories = Get-ChildItem -LiteralPath $Root -Directory |
        Where-Object {
            $_.Name -notlike '_*' -and
            (Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'SKILL.md') -PathType Leaf)
        }

    foreach ($directory in $skillDirectories) {
        $lastHistoryDate = Get-SkillLastHistoryDate -SkillDirectory $directory
        if ($null -eq $lastHistoryDate -or $lastHistoryDate -lt $CutoffDate) {
            $daysSinceUse = $null
            if ($lastHistoryDate) {
                $daysSinceUse = [int]((Get-Date).Date - $lastHistoryDate.Date).TotalDays
            }

            [pscustomobject]@{
                SkillName       = $directory.Name
                LastHistoryDate = $lastHistoryDate
                DaysSinceUse    = $daysSinceUse
                SkillPath       = $directory.FullName
            }
        }
    }
}

function Move-SkillToArchive {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Root,

        [Parameter(Mandatory = $true)]
        [string] $DestinationRoot,

        [Parameter()]
        [switch] $AllowSelfArchive
    )

    if ($Name -eq 'skill-archive' -and -not $AllowSelfArchive) {
        throw "Refusing to archive skill-archive itself without -Force."
    }

    $sourcePath = Join-Path -Path $Root -ChildPath $Name
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
        throw "Skill not found: $sourcePath"
    }

    $skillFile = Join-Path -Path $sourcePath -ChildPath 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        throw "Folder is not a skill because SKILL.md is missing: $sourcePath"
    }

    if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
        New-Item -Path $DestinationRoot -ItemType Directory -Force | Out-Null
    }

    $destinationPath = Join-Path -Path $DestinationRoot -ChildPath $Name
    if (Test-Path -LiteralPath $destinationPath) {
        throw "Archive destination already exists: $destinationPath"
    }

    if ($PSCmdlet.ShouldProcess($sourcePath, "Move skill to $destinationPath")) {
        Move-Item -LiteralPath $sourcePath -Destination $destinationPath
    }

    [pscustomobject]@{
        SkillName   = $Name
        SourcePath  = $sourcePath
        ArchivePath = $destinationPath
        Archived    = -not (Test-Path -LiteralPath $sourcePath)
    }
}

if ($SkillName) {
    Move-SkillToArchive -Name $SkillName -Root $SkillRoot -DestinationRoot $ArchiveRoot -AllowSelfArchive:$Force
    return
}

$cutoff = (Get-Date).Date.AddDays(-1 * $InactiveDays)
Get-SkillArchiveCandidate -Root $SkillRoot -CutoffDate $cutoff |
    Sort-Object -Property @{ Expression = 'LastHistoryDate'; Ascending = $true }, SkillName |
    Select-Object -First $Limit
