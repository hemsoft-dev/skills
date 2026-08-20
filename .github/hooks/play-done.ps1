$raw = try { [Console]::In.ReadToEnd() } catch { '' }
if ($raw) {
    try {
        $json = $raw | ConvertFrom-Json
        if ($json.toolName -eq 'task_complete') {
            $audioEnabled = $true
            # Resolve paths relative to script location (CWD-independent)
            $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
            $settingsPath = Join-Path $scriptDir 'hooks-settings.json'
            if (-not (Test-Path $settingsPath)) {
                # Fallback: check CWD-relative path (for when script runs in project context)
                $settingsPath = '.github/hooks/hooks-settings.json'
            }
            if (Test-Path $settingsPath) {
                try {
                    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
                    if ($null -ne $settings.audioEnabled) { $audioEnabled = $settings.audioEnabled }
                } catch {
                    Write-Verbose "Unable to read hook settings from '$settingsPath': $_"
                }
            }
            if ($audioEnabled) {
                $mp3Path = Join-Path $scriptDir 'done.mp3'
                if (-not (Test-Path $mp3Path)) { $mp3Path = '.github/hooks/done.mp3' }
                Start-Process -NoNewWindow -FilePath 'ffplay' -ArgumentList '-nodisp', '-autoexit', '-volume', '50', $mp3Path
            }
        }
    } catch { Write-Error "Failed to parse or handle task_complete: $_" }
}
