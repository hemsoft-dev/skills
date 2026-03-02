<#
.SYNOPSIS
    TOON (Token-Oriented Object Notation) encoder wrapper using the official @toon-format/cli.
.DESCRIPTION
    A PowerShell wrapper around the official TOON CLI tool (npx @toon-format/cli).
    TOON achieves 30-60% token reduction compared to JSON while remaining human-readable
    and LLM-parseable. Uses the official implementation for spec compliance.
    
    Prerequisites:
    - Node.js with npm/npx installed
    
.PARAMETER InputObject
    The PowerShell object to encode to TOON format. Can be passed via pipeline.
    
.PARAMETER Json
    A JSON string to encode to TOON format (alternative to InputObject).
    
.PARAMETER Delimiter
    Array delimiter: comma (default), tab, or pipe.
    Tab delimiters often tokenize more efficiently than commas.
    
.PARAMETER ShowStats
    Display token count estimates and savings percentage.
    
.PARAMETER KeyFolding
    Enable key folding to collapse nested wrapper chains (off, safe).
    Example: {"a":{"b":{"c":1}}} -> a.b.c: 1
    
.PARAMETER FlattenDepth
    Maximum segments to fold when key folding is enabled (default: Infinity).
    
.EXAMPLE
    # Encode a PowerShell object
    @{name="Alice"; age=30} | ConvertTo-Toon
    
.EXAMPLE
    # Encode with stats
    $emails | ConvertTo-Toon -ShowStats
    
.EXAMPLE
    # Encode with tab delimiter for better token efficiency
    $data | ConvertTo-Toon -Delimiter tab
    
.EXAMPLE
    # Encode a JSON string directly
    ConvertTo-Toon -Json '{"users":[{"id":1,"name":"Alice"}]}'
#>
[CmdletBinding(DefaultParameterSetName = 'Object')]
param(
    [Parameter(ParameterSetName = 'Object', ValueFromPipeline, Position = 0)]
    [object]$InputObject,
    
    [Parameter(ParameterSetName = 'Json', Mandatory)]
    [string]$Json,
    
    [ValidateSet('comma', 'tab', 'pipe')]
    [string]$Delimiter = 'comma',
    
    [switch]$ShowStats,
    
    [ValidateSet('off', 'safe')]
    [string]$KeyFolding = 'off',
    
    [int]$FlattenDepth
)

begin {
    $ErrorActionPreference = 'Stop'
    
    # Verify npx is available
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw "npx not found. Please install Node.js from https://nodejs.org"
    }
    
    # Collect pipeline input
    $allInput = @()
}

process {
    if ($PSCmdlet.ParameterSetName -eq 'Object' -and $InputObject) {
        $allInput += $InputObject
    }
}

end {
    # Build the JSON to encode
    if ($PSCmdlet.ParameterSetName -eq 'Json') {
        $jsonInput = $Json
    }
    else {
        # Convert collected pipeline input to JSON
        if ($allInput.Count -eq 0) {
            Write-Warning "No input provided"
            return
        }
        elseif ($allInput.Count -eq 1) {
            $jsonInput = $allInput[0] | ConvertTo-Json -Depth 20 -Compress
        }
        else {
            $jsonInput = $allInput | ConvertTo-Json -Depth 20 -Compress
        }
    }
    
    # Build npx command arguments
    $npxArgs = @('@toon-format/cli')
    
    # Add delimiter option
    switch ($Delimiter) {
        'tab' { $npxArgs += '--delimiter', "`t" }
        'pipe' { $npxArgs += '--delimiter', '|' }
        # comma is default, no arg needed
    }
    
    # Add stats option
    if ($ShowStats) {
        $npxArgs += '--stats'
    }
    
    # Add key folding options
    if ($KeyFolding -ne 'off') {
        $npxArgs += '--keyFolding', $KeyFolding
        if ($FlattenDepth) {
            $npxArgs += '--flattenDepth', $FlattenDepth
        }
    }
    
    # Run the encoder via npx
    try {
        $result = $jsonInput | npx @npxArgs 2>&1
        
        # Output the result
        $result | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                Write-Error $_
            }
            else {
                $_
            }
        }
    }
    catch {
        throw "TOON encoding failed: $_"
    }
}
