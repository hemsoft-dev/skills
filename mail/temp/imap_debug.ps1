
$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'

$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$client = Connect-Imap
try {
    $inbox = $client.Inbox
    $inbox.Open([MailKit.FolderAccess]::ReadWrite) | Out-Null
    Write-Information "Inbox type: $($inbox.GetType().FullName)"
    $uid = [MailKit.UniqueId]::new([uint64]19140)
    Write-Information "UniqueId type: $($uid.GetType().FullName) Value: $($uid.Id)"

    try {
        $uidArr = [MailKit.UniqueId[]]@($uid)
        Write-Information "Typed array type: $($uidArr.GetType().FullName) Count: $($uidArr.Length)"
        $inbox.AddFlags($uidArr, [MailKit.MessageFlags]::Seen, $true)
        Write-Information 'AddFlags OK'
    }
    catch {
        Write-Information 'AddFlags failed:' $_.Exception.Message
        Write-Information $_.Exception | Format-List -Force
    }
}
finally {
    Disconnect-Imap -Client $client
}