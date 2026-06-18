[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [string]$Owner = 'relias-engineering',

    [Parameter()]
    [ValidateSet('Table', 'Json', 'Csv')]
    [string]$Format = 'Table',

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $raw = & gh api @Arguments 2>$stderrPath
        $exitCode = $LASTEXITCODE
        $stderr = ''
        if (Test-Path -LiteralPath $stderrPath) {
            $stderr = ((Get-Content -LiteralPath $stderrPath -Raw) -as [string]).Trim()
        }

        if ($exitCode -ne 0) {
            throw "gh api failed. ExitCode=$exitCode Message=$stderr Arguments=$($Arguments -join ' ')"
        }

        if (-not $raw) {
            return $null
        }

        return (($raw -join "`n") | ConvertFrom-Json)
    }
    finally {
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-GhPaginatedItem {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $pages = Invoke-GhApiJson -Arguments @('--paginate', '--slurp', $Path)
    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($page in @($pages)) {
        if ($null -eq $page) {
            continue
        }

        foreach ($item in @($page)) {
            if ($null -ne $item) {
                $items.Add($item)
            }
        }
    }

    return @($items)
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required.'
}

$adminPath = "/orgs/$Owner/members?role=admin&per_page=100"
$admins = @(Get-GhPaginatedItem -Path $adminPath | Sort-Object { ([string]$_.login).ToLowerInvariant() })
$rows = [System.Collections.Generic.List[object]]::new()

foreach ($admin in $admins) {
    $login = [string]$admin.login
    if ([string]::IsNullOrWhiteSpace($login)) {
        continue
    }

    $userProfile = Invoke-GhApiJson -Arguments @("/users/$login")
    $name = [string]$userProfile.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = '(not public)'
    }

    $rows.Add([pscustomobject]@{
        Name = $name
        Login = $login
        Role = 'admin'
        Type = [string]$admin.type
        SiteAdmin = [bool]$admin.site_admin
        Url = [string]$admin.html_url
    })
}

$result = @($rows | Sort-Object { $_.Login.ToLowerInvariant() })

switch ($Format) {
    'Json' {
        $json = $result | ConvertTo-Json -Depth 5
        if ($OutputPath) {
            $json | Set-Content -LiteralPath $OutputPath
        }
        else {
            $json
        }
    }
    'Csv' {
        if ($OutputPath) {
            $result | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
        }
        else {
            $result | ConvertTo-Csv -NoTypeInformation
        }
    }
    default {
        if ($OutputPath) {
            $result | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath $OutputPath
        }
        else {
            $result | Format-Table -AutoSize
        }
    }
}
