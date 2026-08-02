[CmdletBinding()]
param(
    [string]$DataPath = (Join-Path $PSScriptRoot '..\references\houses.json')
)

$ErrorActionPreference = 'Stop'

function ConvertTo-NormalizedHouseKey {
    param([Parameter(Mandatory)][string]$Value)

    return ($Value -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}

if (-not (Test-Path -LiteralPath $DataPath -PathType Leaf)) {
    throw "House data file not found: $DataPath"
}

$data = Get-Content -LiteralPath $DataPath -Raw | ConvertFrom-Json
$errors = [System.Collections.Generic.List[string]]::new()

if ($data.houses.Count -ne 25) {
    $errors.Add("Expected 25 houses; found $($data.houses.Count).")
}

$requiredFields = @(
    'name', 'aliases', 'representative', 'bloc', 'specialization', 'mapId', 'region', 'directions', 'point',
    'sourcePointId', 'locationConfidence', 'weeklyRecheck'
)
$seenNames = @{}
$seenAliases = @{}
$seenPointIds = @{}

foreach ($house in $data.houses) {
    foreach ($field in $requiredFields) {
        if ($null -eq $house.$field) {
            $errors.Add("House '$($house.name)' is missing '$field'.")
        }
    }

    $nameKey = ConvertTo-NormalizedHouseKey -Value $house.name
    if ($seenNames.ContainsKey($nameKey)) {
        $errors.Add("Duplicate canonical house name '$($house.name)'.")
    }
    $seenNames[$nameKey] = $true

    foreach ($alias in @($house.name) + @($house.aliases)) {
        $aliasKey = ConvertTo-NormalizedHouseKey -Value $alias
        if ($seenAliases.ContainsKey($aliasKey)) {
            $errors.Add("Duplicate house name or alias '$alias'.")
        }
        $seenAliases[$aliasKey] = $house.name
    }

    if (-not $data.maps.PSObject.Properties.Name.Contains($house.mapId)) {
        $errors.Add("House '$($house.name)' references unknown map '$($house.mapId)'.")
    }

    foreach ($axis in 'x', 'y', 'z') {
        if ($null -eq $house.point.$axis -or $house.point.$axis -isnot [ValueType]) {
            $errors.Add("House '$($house.name)' has an invalid '$axis' coordinate.")
        }
    }

    if ($seenPointIds.ContainsKey($house.sourcePointId)) {
        $errors.Add("Duplicate source point ID '$($house.sourcePointId)'.")
    }
    $seenPointIds[$house.sourcePointId] = $true

    if ($house.mapId -eq 'deepdesert_1' -and -not $house.weeklyRecheck) {
        $errors.Add("Deep Desert house '$($house.name)' must require a weekly recheck.")
    }
}

$expectedSpecializations = @('Combat', 'Crafting', 'Exploration', 'Gathering', 'Sabotage')
foreach ($specialization in $expectedSpecializations) {
    $count = @($data.houses | Where-Object specialization -eq $specialization).Count
    if ($count -ne 5) {
        $errors.Add("Expected 5 $specialization houses; found $count.")
    }
}

$expectedMapCounts = @{
    survival_1      = 18
    sh_harkovillage = 2
    sh_arrakeen     = 3
    deepdesert_1    = 2
}
foreach ($entry in $expectedMapCounts.GetEnumerator()) {
    $count = @($data.houses | Where-Object mapId -eq $entry.Key).Count
    if ($count -ne $entry.Value) {
        $errors.Add("Expected $($entry.Value) houses on '$($entry.Key)'; found $count.")
    }
}

foreach ($source in $data.metadata.sources.PSObject.Properties) {
    $uri = $null
    if (-not [Uri]::TryCreate([string]$source.Value, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https') {
        $errors.Add("Source '$($source.Name)' must be an absolute HTTPS URL.")
    }
}

if ([string]::IsNullOrWhiteSpace($data.metadata.gameVersion)) {
    $errors.Add('Metadata gameVersion is required.')
}
if ([string]::IsNullOrWhiteSpace($data.metadata.verifiedOn)) {
    $errors.Add('Metadata verifiedOn is required.')
}

if ($errors.Count -gt 0) {
    throw "House data validation failed:`n- $($errors -join "`n- ")"
}

Write-Output "PASS: 25 houses, 5 specializations, 4 maps, coordinates, aliases, and sources validated."
