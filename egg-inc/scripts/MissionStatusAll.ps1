$InformationPreference = 'Continue'

# MissionStatusAll.ps1 - Shows spaceship mission status for all tracked accounts
param(
    [switch]$Refresh  # Force refresh data from API
)

# Ship name lookup (0-indexed based on game's internal IDs)
$ShipNames = @{
    0 = "Chicken One"
    1 = "Chicken Nine"
    2 = "Chicken Heavy"
    3 = "BCR"
    4 = "Quintillion Chicken"
    5 = "Cornish-Hen Corvette"
    6 = "Galeggtica"
    7 = "Defihent"
    8 = "Voyegger"
    9 = "Henerprise"
    10 = "Atreggies Henliner"
}

# Duration type lookup
$DurationTypes = @{
    0 = "Short"
    1 = "Standard"
    2 = "Extended"
}

# Mission type lookup
$MissionTypes = @{
    0 = "Normal"
    1 = "Virtue"
}

# Status lookup
$StatusNames = @{
    0 = "Fueling"
    5 = "Prepared"
    10 = "In-Flight"
    15 = "Returned"
    20 = "Analyzing"
    25 = "Complete"
}

# Account definitions
$Accounts = @(
    @{ Name = "King Friday!"; EID = "EI6335140328505344" }
    @{ Name = "King Saturday!"; EID = "EI5435770400276480" }
    @{ Name = "King Sunday!"; EID = "EI6306349753958400" }
    @{ Name = "King Monday!"; EID = "EI6725967592947712" }
)

function Format-TimeRemaining {
    param([double]$Seconds)
    
    if ($Seconds -le 0) {
        return "Ready!"
    }
    
    $ts = [TimeSpan]::FromSeconds($Seconds)
    if ($ts.TotalDays -ge 1) {
        return "{0}d {1}h {2}m" -f [math]::Floor($ts.TotalDays), $ts.Hours, $ts.Minutes
    } elseif ($ts.TotalHours -ge 1) {
        return "{0}h {1}m" -f [math]::Floor($ts.TotalHours), $ts.Minutes
    } else {
        return "{0}m" -f [math]::Ceiling($ts.TotalMinutes)
    }
}

function Get-ActualTimeRemaining {
    param(
        [double]$StartTime,      # Unix timestamp when mission started
        [double]$DurationSeconds # Total mission duration
    )
    
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $endTime = $StartTime + $DurationSeconds
    $remaining = $endTime - $now
    
    return $remaining
}

# Collect all mission data
$allMissions = @()

foreach ($account in $Accounts) {
    try {
        $response = Invoke-RestMethod "https://ei_worker.tylertms.workers.dev/backup?EID=$($account.EID)" -ErrorAction Stop
        
        $missions = $response.artifactsDb.missionInfosList
        $fueling = $response.artifactsDb.fuelingMission
        
        # Process active missions
        foreach ($m in $missions) {
            $shipName = if ($ShipNames.ContainsKey([int]$m.ship)) { $ShipNames[[int]$m.ship] } else { "Ship $($m.ship)" }
            $durationType = if ($DurationTypes.ContainsKey([int]$m.durationType)) { $DurationTypes[[int]$m.durationType] } else { $m.durationType }
            $missionType = if ($MissionTypes.ContainsKey([int]$m.type)) { $MissionTypes[[int]$m.type] } else { $m.type }
            $status = if ($StatusNames.ContainsKey([int]$m.status)) { $StatusNames[[int]$m.status] } else { "Status $($m.status)" }
            
            # Calculate actual time remaining from start time + duration
            $actualRemaining = Get-ActualTimeRemaining -StartTime $m.startTimeDerived -DurationSeconds $m.durationSeconds
            $timeRemaining = Format-TimeRemaining -Seconds $actualRemaining
            
            if ($actualRemaining -le 0) {
                $status = "Ready!"
            }
            
            $allMissions += [PSCustomObject]@{
                Account      = $account.Name
                Ship         = $shipName
                Duration     = $durationType
                Type         = $missionType
                Stars        = $m.level
                Capacity     = $m.capacity
                Status       = $status
                TimeLeft     = $timeRemaining
            }
        }
        
        # Show fueling mission if present
        if ($fueling -and $fueling.ship -gt 0) {
            $shipName = if ($ShipNames.ContainsKey([int]$fueling.ship)) { $ShipNames[[int]$fueling.ship] } else { "Ship $($fueling.ship)" }
            $durationType = if ($DurationTypes.ContainsKey([int]$fueling.durationType)) { $DurationTypes[[int]$fueling.durationType] } else { $fueling.durationType }
            
            $allMissions += [PSCustomObject]@{
                Account      = $account.Name
                Ship         = $shipName
                Duration     = $durationType
                Type         = "Normal"
                Stars        = $fueling.level
                Capacity     = $fueling.capacity
                Status       = "Fueling"
                TimeLeft     = "-"
            }
        }
    }
    catch {
        Write-Warning "Failed to fetch data for $($account.Name): $_"
    }
}

# Display results
if ($allMissions.Count -gt 0) {
    $allMissions | Format-Table -AutoSize
} else {
    Write-Information "No active missions found."
}
