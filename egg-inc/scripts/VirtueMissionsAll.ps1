$InformationPreference = 'Continue'

# VirtueMissionsAll.ps1 - Shows Virtue (enlightenment) spaceship missions for all tracked accounts

# Account definitions
$Accounts = @(
    @{ Name = "King Friday!"; EID = "EI6335140328505344" },
    @{ Name = "King Saturday!"; EID = "EI5435770400276480" },
    @{ Name = "King Sunday!"; EID = "EI6306349753958400" },
    @{ Name = "King Monday!"; EID = "EI6725967592947712" }
)

# Ship name lookup
$ShipNames = @{
    0 = "Chicken One"; 1 = "Chicken Nine"; 2 = "Chicken Heavy"; 3 = "BCR"
    4 = "Quintillion Chicken"; 5 = "Cornish-Hen Corvette"; 6 = "Galeggtica"
    7 = "Defihent"; 8 = "Voyegger"; 9 = "Henerprise"; 10 = "Henliner"
}

# Duration type lookup
$DurationTypes = @{ 0 = "Short"; 1 = "Standard"; 2 = "Extended" }

$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$results = @()

foreach ($acct in $Accounts) {
    try {
        $response = Invoke-RestMethod "https://ei_worker.tylertms.workers.dev/backup?EID=$($acct.EID)" -ErrorAction Stop
        $virtueMissions = @($response.artifactsDb.missionInfosList | Where-Object { $_.type -eq 1 })
        
        foreach ($m in $virtueMissions) {
            $shipName = if ($ShipNames.ContainsKey([int]$m.ship)) { $ShipNames[[int]$m.ship] } else { "Ship $($m.ship)" }
            $durationType = if ($DurationTypes.ContainsKey([int]$m.durationType)) { $DurationTypes[[int]$m.durationType] } else { $m.durationType }
            
            # Calculate arrival time
            $arrivalUnix = $m.startTimeDerived + $m.durationSeconds
            $arrivalTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$arrivalUnix).ToLocalTime()
            
            # Format arrival - show "Ready!" if already arrived
            if ($arrivalUnix -le $now) {
                $arrivalStr = "Ready!"
            } else {
                $arrivalStr = $arrivalTime.ToString("h:mm tt")
            }
            
            $results += [PSCustomObject]@{
                Account  = $acct.Name
                Ship     = $shipName
                Duration = $durationType
                Stars    = $m.level
                Capacity = $m.capacity
                Arrival  = $arrivalStr
            }
        }
    }
    catch {
        Write-Warning "Failed to fetch data for $($acct.Name): $_"
    }
}

# Display results
if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize
} else {
    Write-Information "No active Virtue missions found."
}
