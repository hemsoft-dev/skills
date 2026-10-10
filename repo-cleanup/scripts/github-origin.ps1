# Resolve repository identity without changing either transport or credentials.
function Resolve-CleanupSshHost {
    param([string]$HostName)
    $start = [Diagnostics.ProcessStartInfo]::new('ssh')
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('-G', $HostName)) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            throw 'SSH destination resolution timed out; no repository changes made.'
        }
        $configuration = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw 'SSH destination could not be resolved; no repository changes made.' }
        $hostMatch = [regex]::Match($configuration, '(?m)^hostname (\S+)\r?$')
        $userMatch = [regex]::Match($configuration, '(?m)^user (\S+)\r?$')
        [pscustomobject]@{ HostName = $hostMatch.Groups[1].Value; User = $userMatch.Groups[1].Value }
    }
    finally { $process.Dispose() }
}

function Get-CleanupGitHubRepository {
    param([string]$Url)
    $path = $null
    if ($Url -cmatch '^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$') {
        $path = $Matches[1]
    }
    elseif ($Url -cmatch '^(?:ssh://git@([A-Za-z0-9][A-Za-z0-9.-]*)/|git@([A-Za-z0-9][A-Za-z0-9.-]*):)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$') {
        $hostName = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
        $path = $Matches[3]
        if ($hostName -ne 'github.com') {
            $resolved = Resolve-CleanupSshHost $hostName
            if ($resolved.HostName -ne 'github.com' -or $resolved.User -ne 'git') { return $null }
        }
    }
    else { return $null }
    $path -replace '\.git$', ''
}

function Test-CleanupOriginPair {
    param([string]$FetchUrl, [string[]]$PushUrls)
    if ($PushUrls.Count -ne 1) { return $false }
    if ($FetchUrl -ceq $PushUrls[0]) { return $true }
    $fetchRepository = Get-CleanupGitHubRepository $FetchUrl
    $pushRepository = Get-CleanupGitHubRepository $PushUrls[0]
    $fetchRepository -and $pushRepository -and $fetchRepository -ieq $pushRepository
}
