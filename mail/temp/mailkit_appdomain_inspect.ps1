$ErrorActionPreference = 'Stop'

$asm = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'MailKit' } | Select-Object -First 1
if (-not $asm) { Write-Host 'MailKit not loaded in AppDomain.'; return }

$methods = @()
foreach ($t in $asm.GetTypes()) {
    foreach ($m in $t.GetMethods([Reflection.BindingFlags] 'Public,Instance,Static')) {
        if ($m.Name -in @('AddFlags','RemoveFlags','SetFlags')) {
            $methods += [PSCustomObject]@{ Type=$t.FullName; Method=$m.Name }
        }
    }
}
if ($methods.Count -eq 0) { Write-Host 'No matching methods found in loaded MailKit assembly.' } else { $methods | Format-Table -AutoSize }
