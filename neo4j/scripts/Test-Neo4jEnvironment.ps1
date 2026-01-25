[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='User-facing script requires colored output')]
<#
.SYNOPSIS
    Validates Neo4j environment before running sync or import operations.

.DESCRIPTION
    Checks Docker Desktop status, Neo4j container status, port availability,
    network connectivity, and optionally validates script syntax.

.PARAMETER ValidateScripts
    Also validate PowerShell script syntax for Import and Sync scripts.

.EXAMPLE
    .\Test-Neo4jEnvironment.ps1

.EXAMPLE
    .\Test-Neo4jEnvironment.ps1 -ValidateScripts
#>

[CmdletBinding()]
param(
    [switch]$ValidateScripts
)

$errors = @()
$warnings = @()

Write-Host "🔍 Neo4j Environment Validation" -ForegroundColor Cyan
Write-Host ""

# Check 1: Docker Desktop Status
Write-Host "1. Checking Docker Desktop..." -ForegroundColor Yellow
try {
    $null = docker ps 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Docker Desktop is running" -ForegroundColor Green
    } else {
        $errors += "Docker Desktop is not running"
        Write-Host "   ❌ Docker Desktop is not running" -ForegroundColor Red
        Write-Host "      Solution: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" -ForegroundColor Yellow
    }
} catch {
    $errors += "Cannot access Docker: $_"
    Write-Host "   ❌ Cannot access Docker: $_" -ForegroundColor Red
}

# Check 2: Neo4j Container Exists
Write-Host "2. Checking Neo4j container..." -ForegroundColor Yellow
try {
    $container = docker ps -a --filter name=neo4j --format "{{.Names}}" 2>&1
    if ($container -and $container -eq "neo4j") {
        Write-Host "   ✅ Neo4j container exists" -ForegroundColor Green
        
        # Check if running
        $running = docker ps --filter name=neo4j --format "{{.Names}}" 2>&1
        if ($running -eq "neo4j") {
            Write-Host "   ✅ Neo4j container is running" -ForegroundColor Green
        } else {
            $warnings += "Neo4j container exists but is stopped"
            Write-Host "   ⚠️  Neo4j container is stopped" -ForegroundColor Yellow
            Write-Host "      Solution: docker start neo4j" -ForegroundColor Yellow
        }
    } else {
        $errors += "Neo4j container not found"
        Write-Host "   ❌ Neo4j container not found" -ForegroundColor Red
        Write-Host "      Solution: Create container using Installation section in SKILL.md" -ForegroundColor Yellow
    }
} catch {
    $errors += "Cannot check container status: $_"
    Write-Host "   ❌ Cannot check container status: $_" -ForegroundColor Red
}

# Check 3: Port Availability
Write-Host "3. Checking port availability..." -ForegroundColor Yellow

# Check port 7474 (HTTP)
try {
    $port7474 = Test-NetConnection -ComputerName localhost -Port 7474 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($port7474) {
        Write-Host "   ✅ Port 7474 (HTTP) is accessible" -ForegroundColor Green
    } else {
        $warnings += "Port 7474 (HTTP) is not accessible"
        Write-Host "   ⚠️  Port 7474 (HTTP) is not accessible" -ForegroundColor Yellow
        Write-Host "      This may be normal if Neo4j is still starting up" -ForegroundColor Gray
    }
} catch {
    $warnings += "Cannot test port 7474: $_"
    Write-Host "   ⚠️  Cannot test port 7474: $_" -ForegroundColor Yellow
}

# Check port 7687 (Bolt)
try {
    $port7687 = Test-NetConnection -ComputerName localhost -Port 7687 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($port7687) {
        Write-Host "   ✅ Port 7687 (Bolt) is accessible" -ForegroundColor Green
    } else {
        $warnings += "Port 7687 (Bolt) is not accessible"
        Write-Host "   ⚠️  Port 7687 (Bolt) is not accessible" -ForegroundColor Yellow
        Write-Host "      This may be normal if Neo4j is still starting up" -ForegroundColor Gray
    }
} catch {
    $warnings += "Cannot test port 7687: $_"
    Write-Host "   ⚠️  Port 7687 (Bolt) test failed: $_" -ForegroundColor Yellow
}

# Check 4: Neo4j Connectivity
Write-Host "4. Testing Neo4j connectivity..." -ForegroundColor Yellow
try {
    $uri = "http://localhost:7474/db/neo4j/tx/commit"
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("neo4j:password"))
    
    $body = @{
        statements = @(
            @{
                statement = "RETURN 1 AS test"
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -Headers @{
        Authorization = "Basic $auth"
    } -ErrorAction Stop
    
    if ($response.errors -and $response.errors.Count -gt 0) {
        $errorMsg = $response.errors[0].message
        if ($errorMsg -match "401|Unauthorized") {
            $warnings += "Neo4j authentication failed (may need password reset)"
            Write-Host "   ⚠️  Authentication failed - password may need reset" -ForegroundColor Yellow
            Write-Host "      Default credentials: neo4j/password" -ForegroundColor Gray
        } else {
            $warnings += "Neo4j returned error: $errorMsg"
            Write-Host "   ⚠️  Neo4j returned error: $errorMsg" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ✅ Neo4j is accessible and responding" -ForegroundColor Green
    }
} catch {
    if ($_.Exception.Message -match "Unable to connect|Connection refused") {
        $errors += "Cannot connect to Neo4j"
        Write-Host "   ❌ Cannot connect to Neo4j" -ForegroundColor Red
        Write-Host "      Ensure container is running: docker start neo4j" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "401|Unauthorized") {
        $warnings += "Neo4j authentication failed"
        Write-Host "   ⚠️  Authentication failed - check username/password" -ForegroundColor Yellow
    } else {
        $warnings += "Neo4j connectivity test failed: $_"
        Write-Host "   ⚠️  Connectivity test failed: $_" -ForegroundColor Yellow
    }
}

# Check 5: Script Syntax Validation (optional)
if ($ValidateScripts) {
    Write-Host "5. Validating script syntax..." -ForegroundColor Yellow
    
    $scripts = @(
        "$PSScriptRoot\Import-SkillsToNeo4j.ps1",
        "$PSScriptRoot\Sync-SkillsToNeo4j.ps1"
    )
    
    foreach ($script in $scripts) {
        $scriptName = Split-Path -Leaf $script
        if (Test-Path $script) {
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script -Raw), [ref]$null)
                Write-Host "   ✅ $scriptName syntax is valid" -ForegroundColor Green
            } catch {
                $errors += "$scriptName has syntax errors: $_"
                Write-Host "   ❌ $scriptName has syntax errors: $_" -ForegroundColor Red
            }
        } else {
            $warnings += "$scriptName not found"
            Write-Host "   ⚠️  $scriptName not found" -ForegroundColor Yellow
        }
    }
}

# Summary
Write-Host ""
Write-Host "📊 Validation Summary" -ForegroundColor Cyan

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✅ All checks passed! Environment is ready." -ForegroundColor Green
    exit 0
} elseif ($errors.Count -eq 0) {
    Write-Host "⚠️  Environment is functional but has warnings:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "   - $warning" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "You can proceed, but some issues may affect functionality." -ForegroundColor Gray
    exit 0
} else {
    Write-Host "❌ Environment validation failed with errors:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "   - $error" -ForegroundColor Red
    }
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Additional warnings:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "   - $warning" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "Please fix the errors before running sync or import operations." -ForegroundColor Yellow
    exit 1
}
