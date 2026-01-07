# Start-OneDriveProcess.ps1
# Starts OneDrive and verifies it's running

param(
    [int]$WaitSeconds = 3
)

# Check if already running
$existingProcess = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($existingProcess) {
    Write-Host "✅ OneDrive is already running (PID: $($existingProcess.Id))" -ForegroundColor Green
    exit 0
}

# Find OneDrive executable
$oneDrivePath = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
if (-not (Test-Path $oneDrivePath)) {
    Write-Host "❌ OneDrive executable not found at: $oneDrivePath" -ForegroundColor Red
    exit 1
}

# Start OneDrive
Write-Host "Starting OneDrive..." -ForegroundColor Cyan
try {
    Start-Process $oneDrivePath -ErrorAction Stop
    Write-Host "✅ OneDrive process started" -ForegroundColor Green
    
    # Wait for process to initialize
    Start-Sleep -Seconds $WaitSeconds
    
    # Verify it's running
    $process = Get-Process OneDrive -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "✅ OneDrive is running (PID: $($process.Id))" -ForegroundColor Green
        Write-Host "   Path: $($process.Path)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  OneDrive started but process not detected" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Failed to start OneDrive: $_" -ForegroundColor Red
    exit 1
}
