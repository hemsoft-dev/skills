Set-StrictMode -Version Latest

function Get-DiaryEnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    foreach ($scope in 'Process', 'User', 'Machine') {
        $value = [System.Environment]::GetEnvironmentVariable($Name, $scope)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return $null
}

function Get-DiaryHtmlEntryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $true)]
        [string]$Date
    )

    $year = $Date.Substring(0, 4)
    $month = $Date.Substring(5, 2)
    $entriesDir = Join-Path $ScriptRoot '..' 'entries' $year $month
    if (-not (Test-Path $entriesDir)) {
        New-Item -ItemType Directory -Path $entriesDir -Force | Out-Null
    }

    return Join-Path $entriesDir "$Date.html"
}

function Write-Utf8NoBomFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function ConvertTo-DiaryHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markdown
    )

    return (ConvertFrom-Markdown -InputObject $Markdown).Html.Trim()
}

function ConvertTo-DiaryHtmlCard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markdown,

        [string]$Eyebrow
    )

    $html = ConvertTo-DiaryHtml -Markdown $Markdown
    $parts = [System.Collections.Generic.List[string]]::new()
    [void]$parts.Add('<div class="card diary-generated-markdown">')
    if ($Eyebrow) {
        [void]$parts.Add("  <div class=""eyebrow"">$Eyebrow</div>")
    }
    [void]$parts.Add($html)
    [void]$parts.Add('</div>')
    return ($parts -join "`n")
}

function Get-DiarySectionInnerHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EntryPath,

        [Parameter(Mandatory = $true)]
        [string]$SectionTitle
    )

    $entry = Get-Content $EntryPath -Raw
    $escapedTitle = [regex]::Escape($SectionTitle)
    $pattern = "(?s)<section class=""section"">\s*<div class=""section-title"">$escapedTitle</div>(.*?)\s*</section>"
    $match = [regex]::Match($entry, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

function Set-DiarySectionInnerHtml {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EntryPath,

        [Parameter(Mandatory = $true)]
        [string]$SectionTitle,

        [Parameter(Mandatory = $true)]
        [string]$InnerHtml
    )

    $entry = Get-Content $EntryPath -Raw
    $escapedTitle = [regex]::Escape($SectionTitle)
    $pattern = "(?s)(<section class=""section"">\s*<div class=""section-title"">$escapedTitle</div>)(.*?)(\s*</section>)"
    $match = [regex]::Match($entry, $pattern)
    if (-not $match.Success) {
        throw "Section not found in diary entry: $SectionTitle"
    }

    $updated = $entry.Substring(0, $match.Index) +
        $match.Groups[1].Value +
        "`n" + $InnerHtml.Trim() + "`n" +
        $match.Groups[3].Value +
        $entry.Substring($match.Index + $match.Length)

    if ($PSCmdlet.ShouldProcess($EntryPath, "Replace diary section '$SectionTitle'")) {
        Write-Utf8NoBomFile -Path $EntryPath -Content $updated
    }
}

function Get-DiaryOutputSnapshotPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $true)]
        [string]$Date,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $outputDir = Join-Path $ScriptRoot '..' 'output'
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    return Join-Path $outputDir "$Date-$Name.json"
}

function Save-DiarySnapshotJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $true)]
        [string]$Date,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [object]$Payload
    )

    $snapshotPath = Get-DiaryOutputSnapshotPath -ScriptRoot $ScriptRoot -Date $Date -Name $Name
    $json = $Payload | ConvertTo-Json -Depth 8
    Write-Utf8NoBomFile -Path $snapshotPath -Content $json
}

function Get-PreviousDiarySnapshotJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $true)]
        [string]$Date,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $outputDir = Join-Path $ScriptRoot '..' 'output'
    if (-not (Test-Path $outputDir)) {
        return $null
    }

    $previousDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null).AddDays(-1).ToString('yyyy-MM-dd')
    $candidatePath = Join-Path $outputDir "$previousDate-$Name.json"
    if (-not (Test-Path $candidatePath)) {
        return $null
    }

    try {
        return Get-Content -Path $candidatePath -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }

    return $null
}

