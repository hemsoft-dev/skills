function Format-BigNumber {
    param([double]$value)
    
    $suffixes = @('', 'K', 'M', 'B', 'T', 'q', 'Q', 's', 'S', 'o', 'N', 'd', 'U')
    $powers = @(0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36)
    
    $index = 0
    while ($index -lt $powers.Length - 1 -and $value -ge [Math]::Pow(10, $powers[$index + 1])) {
        $index++
    }
    
    if ($index -eq 0) {
        return "{0:N0}" -f $value
    }
    
    $divisor = [Math]::Pow(10, $powers[$index])
    $formatted = $value / $divisor
    
    return "{0:N3}{1}" -f $formatted, $suffixes[$index]
}

function Format-EB {
    param([double]$eb)
    
    $suffixes = @('', 'K', 'M', 'B', 'T', 'q', 'Q', 's', 'S', 'o', 'N', 'd', 'U')
    $powers = @(0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36)
    
    $index = 0
    while ($index -lt $powers.Length - 1 -and $eb -ge [Math]::Pow(10, $powers[$index + 1])) {
        $index++
    }
    
    if ($index -eq 0) {
        return "{0:N3}%" -f $eb
    }
    
    $divisor = [Math]::Pow(10, $powers[$index])
    $formatted = $eb / $divisor
    
    return "{0:N3}{1}%" -f $formatted, $suffixes[$index]
}

function Get-ClothedEB {
    param(
        [double]$SoulEggs,
        [int]$ProphecyEggs,
        [int]$TruthEggs
    )

    try {
        return $SoulEggs * 150.0 * [Math]::Pow(1.1, $ProphecyEggs) * [Math]::Pow(1.035, $TruthEggs)
    }
    catch {
        return 0
    }
}

$dataDir = Join-Path $PSScriptRoot "..\data"

$accounts = @(
    @{Name='King Friday!'; File='king-friday.json'},
    @{Name='King Saturday!'; File='king-saturday.json'},
    @{Name='King Sunday!'; File='king-sunday.json'},
    @{Name='King Monday!'; File='king-monday.json'}
)

foreach ($acc in $accounts) {
    $filePath = Join-Path $dataDir $acc.File
    $data = Get-Content $filePath | ConvertFrom-Json
    
    $se = [double]$data.game.soulEggsD
    $pe = [int]$data.game.eggsOfProphecy
    $eovEarned = ($data.virtue.eovEarnedList | Measure-Object -Sum).Sum
    $resets = [int]$data.virtue.resets
    $shifts = [int]$data.virtue.shiftCount
    $clothedEB = Get-ClothedEB -SoulEggs $se -ProphecyEggs $pe -TruthEggs $eovEarned
    
    Write-Host ""
    Write-Host "$($acc.Name)" -ForegroundColor Cyan
    Write-Host ("-" * 50)
    Write-Host "Soul Eggs: $(Format-BigNumber $se)"
    Write-Host "Prophecy Eggs: $pe"
    Write-Host "Truth Eggs (Earned): $eovEarned"
    Write-Host "Virtue Resets: $resets"
    Write-Host "Shifts Completed: $shifts"
    if ($clothedEB -gt 0) {
        Write-Host "Clothed EB: $(Format-EB $clothedEB)"
    }
}
