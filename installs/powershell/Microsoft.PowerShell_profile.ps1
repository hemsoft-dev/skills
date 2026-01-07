##---------------------------------------
## Theming
##---------------------------------------

# Or: oh-my-posh init pwsh --config "C:\Users\Admin\AppData\Local\Programs\oh-my-posh\themes\jandedobbeleer.omp.json" | Invoke-

# Initialize oh-my-posh with a theme
oh-my-posh init pwsh --config "$env:USERPROFILE\.config\omp\hemsoft.omp.json" | Invoke-Expression
Import-Module posh-git

New-Alias st "C:\Program Files\Sublime Text\sublime_text.exe"
Set-Alias -name k -value kubectl

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

