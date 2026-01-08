<#
.SYNOPSIS
    Shared Work Outlook (Microsoft Graph) authentication module.
.DESCRIPTION
    Token management for Microsoft Graph API using device code flow.
    Uses "organizations" tenant to support work/school accounts.
    Attempts to reuse existing GRAPH_CLIENT_ID (multi-tenant scenario).
#>

$InformationPreference = 'Continue'

# Try to reuse existing client ID - it may work if app is multi-tenant
$script:ClientId = $env:GRAPH_WORK_CLIENT_ID
if (-not $script:ClientId) {
    # Fall back to personal Outlook client ID - may work if configured as multi-tenant
    $script:ClientId = $env:GRAPH_CLIENT_ID
}

$script:TokenCachePath = Join-Path $env:USERPROFILE ".my-mail-work.json"
$script:Scopes = @("Mail.ReadWrite", "offline_access")
# Use "organizations" for work/school accounts only (not consumers)
$script:TenantId = "organizations"
$script:DeviceCodeUrl = "https://login.microsoftonline.com/$script:TenantId/oauth2/v2.0/devicecode"
$script:TokenUrl = "https://login.microsoftonline.com/$script:TenantId/oauth2/v2.0/token"
$script:ApiBaseUrl = "https://graph.microsoft.com/v1.0"

function Test-WorkConfigured {
    if (-not $script:ClientId) {
        return $false
    }
    return $true
}

function Get-CachedToken {
    if (Test-Path $script:TokenCachePath) {
        try {
            return Get-Content $script:TokenCachePath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Verbose "Failed to parse token cache: $_"
            return $null
        }
    }
    return $null
}

function Save-TokenCache {
    param([string]$AccessToken, [string]$RefreshToken, [datetime]$ExpiresAt, [string]$AccountEmail)
    $cache = @{
        AccessToken  = $AccessToken
        RefreshToken = $RefreshToken
        ExpiresAt    = $ExpiresAt.ToString("o")
        Account      = $AccountEmail
        SavedAt      = (Get-Date).ToString("o")
    }
    $cache | ConvertTo-Json | Set-Content $script:TokenCachePath -Force
}

function Get-WorkAccessTokenInteractive {
    Write-Information "[36mAuthentication required for Work Outlook. Starting device code flow...`e[0m"
    Write-Information "[90mUsing client ID: $($script:ClientId.Substring(0,8))...`e[0m"
    
    $scopeString = $script:Scopes -join " "
    $deviceCodeBody = @{ client_id = $script:ClientId; scope = $scopeString }
    
    try {
        $deviceCodeResponse = Invoke-RestMethod -Uri $script:DeviceCodeUrl -Method POST -Body $deviceCodeBody
    }
    catch {
        $errMsg = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $errDetails = $_.ErrorDetails.Message | ConvertFrom-Json
                $errMsg = "$($errDetails.error): $($errDetails.error_description)"
            } catch {
                Write-Verbose "Failed to parse error details: $_"
            }
        }
        throw "Failed to start device code flow: $errMsg"
    }

    Write-Information "`nTo sign in with your WORK account, open: " -NoNewline
    Write-Information "[33m$($deviceCodeResponse.verification_uri)`e[0m"
    Write-Information "Enter code: " -NoNewline
    Write-Information "[32m$($deviceCodeResponse.user_code)`e[0m"
    Write-Information "[35m`nIMPORTANT: Sign in with your WORK email, not personal!`e[0m"

    try {
        Start-Process $deviceCodeResponse.verification_uri
    } catch {
        Write-Verbose "Failed to open browser: $_"
    }

    $interval = if ($deviceCodeResponse.interval) { $deviceCodeResponse.interval } else { 5 }
    $expiresIn = $deviceCodeResponse.expires_in
    $startTime = Get-Date
    $tokenBody = @{
        grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
        client_id   = $script:ClientId
        device_code = $deviceCodeResponse.device_code
    }

    Write-Information "[36mWaiting for authentication...`e[0m"

    while (((Get-Date) - $startTime).TotalSeconds -lt $expiresIn) {
        Start-Sleep -Seconds $interval
        try {
            $tokenResponse = Invoke-RestMethod -Uri $script:TokenUrl -Method POST -Body $tokenBody
            $accountEmail = "Unknown"
            if ($tokenResponse.id_token) {
                $parts = $tokenResponse.id_token.Split('.')
                if ($parts.Length -ge 2) {
                    $payload = $parts[1]
                    $padding = 4 - ($payload.Length % 4)
                    if ($padding -ne 4) { $payload += '=' * $padding }
                    try {
                        $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
                        $claims = $decoded | ConvertFrom-Json
                        $accountEmail = $claims.email
                        if (-not $accountEmail) { $accountEmail = $claims.preferred_username }
                        if (-not $accountEmail) { $accountEmail = $claims.upn }
                        if (-not $accountEmail) { $accountEmail = $claims.name }
                    } catch {
                        Write-Verbose "Failed to decode ID token: $_"
                    }
                }
            }
            $expiresAt = (Get-Date).AddSeconds($tokenResponse.expires_in)
            Save-TokenCache -AccessToken $tokenResponse.access_token -RefreshToken $tokenResponse.refresh_token -ExpiresAt $expiresAt -AccountEmail $accountEmail
            Write-Information "[32mAuthenticated as: $accountEmail`e[0m"
            return $tokenResponse.access_token
        }
        catch {
            $errContent = $_.ErrorDetails.Message
            $err = $null
            if ($errContent) {
                try {
                    $err = $errContent | ConvertFrom-Json
                } catch {
                    Write-Verbose "Failed to parse error response: $_"
                }
            }
            if ($err.error -eq "authorization_pending") { continue }
            elseif ($err.error -eq "slow_down") { $interval += 5; continue }
            else {
                $errMsg = if ($err.error_description) { $err.error_description } else { $_.Exception.Message }
                throw "Authentication failed: $errMsg"
            }
        }
    }
    throw "Authentication timed out."
}

function Get-AccessTokenFromRefresh {
    param([string]$RefreshToken)
    $body = @{
        grant_type    = "refresh_token"
        client_id     = $script:ClientId
        refresh_token = $RefreshToken
        scope         = $script:Scopes -join " "
    }
    try {
        $response = Invoke-RestMethod -Uri $script:TokenUrl -Method POST -Body $body
        $cache = Get-CachedToken
        $expiresAt = (Get-Date).AddSeconds($response.expires_in)
        Save-TokenCache -AccessToken $response.access_token -RefreshToken ($response.refresh_token ?? $RefreshToken) -ExpiresAt $expiresAt -AccountEmail $cache.Account
        return $response.access_token
    }
    catch { return $null }
}

function Get-WorkAccessToken {
    $cache = Get-CachedTokens
    if ($cache) {
        $expiresAt = [datetime]::Parse($cache.ExpiresAt)
        if ($expiresAt -gt (Get-Date).AddMinutes(5)) { return $cache.AccessToken }
        if ($cache.RefreshToken) {
            $newToken = Get-AccessTokenFromRefresh -RefreshToken $cache.RefreshToken
            if ($newToken) { return $newToken }
        }
    }
    return Get-WorkAccessTokenInteractive
}

function Invoke-WorkApi {
    param([string]$AccessToken, [string]$Uri, [string]$Method = "GET", [object]$Body = $null)
    if (-not $Uri.StartsWith("https://")) { $Uri = "$script:ApiBaseUrl$Uri" }
    $headers = @{ Authorization = "Bearer $AccessToken"; "Content-Type" = "application/json" }
    $params = @{ Uri = $Uri; Method = $Method; Headers = $headers }
    if ($Body) { $params.Body = $Body | ConvertTo-Json -Depth 10 }
    Invoke-RestMethod @params
}
