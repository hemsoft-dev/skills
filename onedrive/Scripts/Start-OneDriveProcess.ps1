$InformationPreference = 'Continue'

# Start-OneDriveProcess.ps1
# Starts OneDrive and verifies it's running

param(
    [int]$WaitSeconds = 3
)

# Check if already running
$existingProcess = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($existingProcess) {
    Write-Information "[32m✅ OneDrive is already running (PID: $($existingProcess.Id))`e[0m"
    exit 0
}

# Find OneDrive executable
$oneDrivePath = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
if (-not (Test-Path $oneDrivePath)) {
    Write-Information "[31m❌ OneDrive executable not found at: $oneDrivePath`e[0m"
    exit 1
}

# Start OneDrive
Write-Information "[36mStarting OneDrive...`e[0m"
try {
    Start-Process $oneDrivePath -ErrorAction Stop
    Write-Information "[32m✅ OneDrive process started`e[0m"
    
    # Wait for process to initialize
    Start-Sleep -Seconds $WaitSeconds
    
    # Verify it's running
    $process = Get-Process OneDrive -ErrorAction SilentlyContinue
    if ($process) {
        Write-Information "[32m✅ OneDrive is running (PID: $($process.Id))`e[0m"
        Write-Information "[90m   Path: $($process.Path)`e[0m"
    } else {
        Write-Information "[33m⚠️  OneDrive started but process not detected`e[0m"
    }
} catch {
    Write-Information "[31m❌ Failed to start OneDrive: $_`e[0m"
    exit 1
}
