@{
    Severity = @('Error', 'Warning')
    
    ExcludeRules = @(
        # These features are intentionally used and require PowerShell 7+
        'PSUseCompatibleCommands',
        # Write-Host is used in temp/debug scripts intentionally
        'PSAvoidUsingWriteHost',
        # BOM encoding not required for UTF-8 files
        'PSUseBOMForUnicodeEncodedFile',
        # System.Web.HttpUtility is used intentionally with Add-Type fallback
        'PSUseCompatibleTypes'
    )
    
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('5.1', '7.0')
        }
    }
}
