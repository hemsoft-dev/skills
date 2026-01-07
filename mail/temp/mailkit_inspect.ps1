$ErrorActionPreference = 'Stop'

$path = 'c:\Users\franz\.claude\skills\mail\packages\MailKit.dll'
$asm = [Reflection.Assembly]::LoadFile($path)

$names = @('AddFlags','RemoveFlags','SetFlags','Store','StoreFlags','SetMessageFlags')
$results = @()
foreach ($t in $asm.GetTypes()) {
    foreach ($m in $t.GetMethods([Reflection.BindingFlags] 'Public,Static,Instance')) {
        if ($names -contains $m.Name) {
            $results += [PSCustomObject]@{ Type=$t.FullName; Method=$m.Name }
        }
    }
}
$results | Format-Table -AutoSize
