# Cleanup script for qwen3-tts reorganization
# This removes old files from User folder that have been moved to proper locations

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Qwen3-TTS Cleanup Script" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

$userFolder = "C:\Users\User"
$filesToDelete = @(
    "$userFolder\qwen3_voice_profiles.ps1",
    "$userFolder\qwen3_tts_voicedesign.py",
    "$userFolder\qwen3_tts_clone.py",
    "$userFolder\qwen3_reference_voice.wav",
    "$userFolder\qwen3_output.wav",
    "$userFolder\qwen3_consistency_notes.md",
    "$userFolder\test_voice_consistency.ps1"
)

# Also clean up any consistency test wav files
$consistencyFiles = Get-ChildItem "$userFolder\consistency_test_*.wav" -ErrorAction SilentlyContinue

Write-Host "Files to delete:" -ForegroundColor Yellow
foreach ($file in $filesToDelete) {
    if (Test-Path $file) {
        Write-Host "  [X] $file" -ForegroundColor Red
    } else {
        Write-Host "  [ ] $file (not found)" -ForegroundColor DarkGray
    }
}

foreach ($file in $consistencyFiles) {
    Write-Host "  [X] $($file.FullName)" -ForegroundColor Red
}

Write-Host ""
$confirm = Read-Host "Delete these files? (y/n)"

if ($confirm -eq 'y') {
    $deletedCount = 0
    
    foreach ($file in $filesToDelete) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "  Deleted: $file" -ForegroundColor Green
            $deletedCount++
        }
    }
    
    foreach ($file in $consistencyFiles) {
        Remove-Item $file.FullName -Force
        Write-Host "  Deleted: $($file.FullName)" -ForegroundColor Green
        $deletedCount++
    }
    
    Write-Host ""
    Write-Host "Cleanup complete! Deleted $deletedCount file(s)." -ForegroundColor Green
} else {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Note: Scripts have been moved to:" -ForegroundColor Cyan
Write-Host "  $env:USERPROFILE\.claude\skills\qwen3-tts\scripts\" -ForegroundColor White
