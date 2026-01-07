# Get-OneDriveLocations.ps1
# Returns all OneDrive folder locations found on the system

param(
    [switch]$IncludeRegistry,
    [switch]$IncludeEnvironment
)

$locations = @()

# Check common filesystem locations
$commonPaths = @(
    "$env:USERPROFILE\OneDrive",
    "C:\Users\$env:USERNAME\OneDrive",
    "D:\OneDrive",
    "F:\OneDrive"
)

foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $item = Get-Item $path
        $fileCount = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        
        $locations += [PSCustomObject]@{
            Source = "Filesystem"
            Path = $item.FullName
            FileCount = $fileCount
            LastModified = $item.LastWriteTime
            IsEmpty = ($fileCount -eq 0)
        }
    }
}

# Check registry if requested
if ($IncludeRegistry) {
    $regPaths = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "UserFolder" -ErrorAction SilentlyContinue
    foreach ($reg in $regPaths) {
        if ($reg.UserFolder) {
            $locations += [PSCustomObject]@{
                Source = "Registry"
                Path = $reg.UserFolder
                FileCount = $null
                LastModified = $null
                IsEmpty = $null
            }
        }
    }
}

# Check environment variables if requested
if ($IncludeEnvironment) {
    $envVars = Get-ChildItem env: | Where-Object Name -like "*OneDrive*"
    foreach ($var in $envVars) {
        $locations += [PSCustomObject]@{
            Source = "Environment"
            Path = $var.Value
            FileCount = $null
            LastModified = $null
            IsEmpty = $null
        }
    }
}

return $locations
