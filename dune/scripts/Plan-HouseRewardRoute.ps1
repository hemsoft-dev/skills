[CmdletBinding(DefaultParameterSetName = 'Route')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Route')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Houses,

    [Parameter(Mandatory, ParameterSetName = 'List')]
    [switch]$ListHouses,

    [Parameter(ParameterSetName = 'Route')]
    [string]$StartHouse,

    [Parameter(ParameterSetName = 'Route')]
    [ValidateSet('Markdown', 'Json', 'Object')]
    [string]$OutputFormat = 'Markdown',

    [string]$DataPath = (Join-Path $PSScriptRoot '..\references\houses.json')
)

$ErrorActionPreference = 'Stop'

function ConvertTo-NormalizedHouseKey {
    param([Parameter(Mandatory)][string]$Value)

    $withoutLabels = $Value -replace '(?i)\bhouse\b', '' -replace '(?i)\brepresentative\b', ''
    return ($withoutLabels -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}

function Get-PointDistance {
    param(
        [Parameter(Mandatory)]$From,
        [Parameter(Mandatory)]$To
    )

    $deltaX = [double]$To.point.x - [double]$From.point.x
    $deltaY = [double]$To.point.y - [double]$From.point.y
    return [Math]::Sqrt(($deltaX * $deltaX) + ($deltaY * $deltaY))
}

function Measure-HouseRoute {
    param(
        [Parameter(Mandatory)][object[]]$Route,
        $Anchor
    )

    if ($Route.Count -eq 0) {
        return 0.0
    }

    $distance = 0.0
    if ($null -ne $Anchor) {
        $distance += Get-PointDistance -From $Anchor -To $Route[0]
    }

    for ($index = 1; $index -lt $Route.Count; $index++) {
        $distance += Get-PointDistance -From $Route[$index - 1] -To $Route[$index]
    }

    return $distance
}

function Get-NearestHouseRoute {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [Parameter(Mandatory)]$First
    )

    $route = [System.Collections.Generic.List[object]]::new()
    $remaining = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in $Candidates) {
        if ($candidate.name -ne $First.name) {
            $remaining.Add($candidate)
        }
    }

    $route.Add($First)
    while ($remaining.Count -gt 0) {
        $current = $route[$route.Count - 1]
        $nearest = $remaining |
            Sort-Object @{ Expression = { Get-PointDistance -From $current -To $_ } }, name |
            Select-Object -First 1
        $route.Add($nearest)
        [void]$remaining.Remove($nearest)
    }

    return @($route)
}

function Optimize-HouseRoute {
    param(
        [Parameter(Mandatory)][object[]]$Route,
        $Anchor
    )

    [object[]]$best = @($Route)
    $bestDistance = Measure-HouseRoute -Route $best -Anchor $Anchor
    $improved = $true

    while ($improved) {
        $improved = $false
        for ($start = 1; $start -lt ($best.Count - 1); $start++) {
            for ($end = $start + 1; $end -lt $best.Count; $end++) {
                [object[]]$prefix = if ($start -gt 0) { @($best[0..($start - 1)]) } else { @() }
                [object[]]$middle = @($best[$start..$end])
                [array]::Reverse($middle)
                [object[]]$suffix = if ($end -lt ($best.Count - 1)) {
                    @($best[($end + 1)..($best.Count - 1)])
                }
                else {
                    @()
                }
                $candidateList = [System.Collections.Generic.List[object]]::new()
                foreach ($item in $prefix) { $candidateList.Add($item) }
                foreach ($item in $middle) { $candidateList.Add($item) }
                foreach ($item in $suffix) { $candidateList.Add($item) }
                [object[]]$candidate = $candidateList.ToArray()
                $candidateDistance = Measure-HouseRoute -Route $candidate -Anchor $Anchor

                if ($candidateDistance -lt ($bestDistance - 0.001)) {
                    [object[]]$best = @($candidate)
                    $bestDistance = $candidateDistance
                    $improved = $true
                }
            }
        }
    }

    return [pscustomobject]@{
        Route    = $best
        Distance = $bestDistance
    }
}

function Get-BestHouseRoute {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        $Anchor,
        [switch]$RequireAnchorFirst
    )

    if ($Candidates.Count -eq 1) {
        return [pscustomobject]@{
            Route    = @($Candidates[0])
            Distance = Measure-HouseRoute -Route @($Candidates[0]) -Anchor $Anchor
        }
    }

    $starts = @($Candidates)
    if ($RequireAnchorFirst -and $null -ne $Anchor) {
        $starts = @($Candidates | Where-Object name -eq $Anchor.name)
    }

    $bestResult = $null
    foreach ($first in $starts) {
        $nearestRoute = @(Get-NearestHouseRoute -Candidates $Candidates -First $first)
        $optimized = Optimize-HouseRoute -Route $nearestRoute -Anchor $Anchor
        if ($null -eq $bestResult -or $optimized.Distance -lt $bestResult.Distance) {
            $bestResult = $optimized
        }
    }

    return $bestResult
}

if (-not (Test-Path -LiteralPath $DataPath -PathType Leaf)) {
    throw "House data file not found: $DataPath"
}

$data = Get-Content -LiteralPath $DataPath -Raw | ConvertFrom-Json
$houseLookup = @{}
foreach ($house in $data.houses) {
    $keys = @($house.name) + @($house.aliases)
    foreach ($keyValue in $keys) {
        $key = ConvertTo-NormalizedHouseKey -Value $keyValue
        $houseLookup[$key] = $house
    }
}

if ($ListHouses) {
    $data.houses |
        Sort-Object specialization, name |
        Select-Object name, specialization, bloc,
            @{ Name = 'map'; Expression = { $data.maps.($_.mapId).name } }, region, representative
    return
}

function Resolve-HouseRecord {
    param([Parameter(Mandatory)][string]$Value)

    $key = ConvertTo-NormalizedHouseKey -Value $Value
    if ($houseLookup.ContainsKey($key)) {
        return $houseLookup[$key]
    }

    $suggestions = $data.houses.name |
        Where-Object { (ConvertTo-NormalizedHouseKey -Value $_).StartsWith($key.Substring(0, [Math]::Min(2, $key.Length))) } |
        Select-Object -First 5
    $suggestionText = if ($suggestions) { " Did you mean: $($suggestions -join ', ')?" } else { '' }
    throw "Unknown Landsraad house '$Value'.$suggestionText"
}

$selectedByName = @{}
foreach ($requestedHouse in $Houses) {
    $resolved = Resolve-HouseRecord -Value $requestedHouse
    $selectedByName[$resolved.name] = $resolved
}
$selected = @($selectedByName.Values)

$anchor = $null
if ($StartHouse) {
    $anchor = Resolve-HouseRecord -Value $StartHouse
}

$requestedMapIds = @($selected | Select-Object -ExpandProperty mapId -Unique)
$mapOrder = [System.Collections.Generic.List[string]]::new()
if ($null -ne $anchor -and $requestedMapIds -contains $anchor.mapId) {
    $mapOrder.Add($anchor.mapId)
}
foreach ($mapId in $data.metadata.defaultMapOrder) {
    if ($requestedMapIds -contains $mapId -and -not $mapOrder.Contains($mapId)) {
        $mapOrder.Add($mapId)
    }
}

$mapRoutes = [System.Collections.Generic.List[object]]::new()
$orderedStops = [System.Collections.Generic.List[object]]::new()
foreach ($mapId in $mapOrder) {
    $mapCandidates = @($selected | Where-Object mapId -eq $mapId)
    $mapAnchor = if ($null -ne $anchor -and $anchor.mapId -eq $mapId) { $anchor } else { $null }
    $requireAnchorFirst = $null -ne $mapAnchor -and ($mapCandidates.name -contains $mapAnchor.name)
    $routeParameters = @{
        Candidates         = $mapCandidates
        Anchor             = $mapAnchor
        RequireAnchorFirst = $requireAnchorFirst
    }
    $routeResult = Get-BestHouseRoute @routeParameters

    $stops = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $routeResult.Route.Count; $index++) {
        $house = $routeResult.Route[$index]
        $from = if ($index -eq 0) { $mapAnchor } else { $routeResult.Route[$index - 1] }
        $legDistance = if ($null -eq $from) { 0.0 } else { Get-PointDistance -From $from -To $house }
        $stop = [pscustomobject]@{
            order             = $orderedStops.Count + 1
            house             = $house.name
            representative    = $house.representative
            specialization    = $house.specialization
            map               = $data.maps.$mapId.name
            mapId             = $mapId
            region            = $house.region
            directions        = $house.directions
            relativeLegUnits  = [Math]::Round($legDistance)
            weeklyRecheck     = [bool]$house.weeklyRecheck
            locationConfidence = $house.locationConfidence
            point             = $house.point
        }
        $stops.Add($stop)
        $orderedStops.Add($stop)
    }

    $mapRoutes.Add([pscustomobject]@{
        map                  = $data.maps.$mapId.name
        mapId                = $mapId
        transitionNote       = $data.maps.$mapId.transitionNote
        relativeRouteUnits   = [Math]::Round($routeResult.Distance)
        stops                = @($stops)
    })
}

$result = [pscustomobject]@{
    gameVersion        = $data.metadata.gameVersion
    verifiedOn         = $data.metadata.verifiedOn
    startHouse         = if ($null -ne $anchor) { $anchor.name } else { $null }
    routeClaim         = $data.metadata.routeClaim
    interMapOrderClaim = 'Operational heuristic; cross-map travel times are not measured.'
    mapRoutes          = @($mapRoutes)
    stops              = @($orderedStops)
    sources            = $data.metadata.sources
}

switch ($OutputFormat) {
    'Object' {
        $result
    }
    'Json' {
        $result | ConvertTo-Json -Depth 10
    }
    default {
        "# Landsraad reward route"
        ""
        "Data: Dune: Awakening $($result.gameVersion), verified $($result.verifiedOn)."
        "Route scope: $($result.routeClaim)."
        "Inter-map order: $($result.interMapOrderClaim)"
        ""
        foreach ($mapRoute in $result.mapRoutes) {
            "## $($mapRoute.map)"
            ""
            "$($mapRoute.transitionNote) Relative within-map route: $($mapRoute.relativeRouteUnits) units."
            ""
            foreach ($stop in $mapRoute.stops) {
                $recheck = if ($stop.weeklyRecheck) { ' **Recheck after the weekly Coriolis cycle.**' } else { '' }
                "$($stop.order). **House $($stop.house)** - $($stop.representative), $($stop.region). " +
                    "$($stop.directions) Leg: $($stop.relativeLegUnits) relative map units.$recheck"
                ""
            }
        }
        "Coordinates: [interactive map]($($result.sources.interactiveMap))"
        "Locations: [representative guide]($($result.sources.locationGuide))"
    }
}
