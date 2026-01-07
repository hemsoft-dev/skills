<#
.SYNOPSIS
    Shared Gmail authentication module.
.DESCRIPTION
    Token management for Gmail API using OAuth 2.0 localhost redirect.
    Used by Gmail child scripts in tasks/gmail/.
#>

$script:ClientId = $env:GMAIL_CLIENT_ID
$script:ClientSecret = $env:GMAIL_CLIENT_SECRET
$script:TokenCachePath = Join-Path $env:USERPROFILE ".my-mail-gmail.json"
$script:Scopes = @("https://www.googleapis.com/auth/gmail.modify", "email", "profile")
$script:AuthUrl = "https://accounts.google.com/o/oauth2/v2/auth"
$script:TokenUrl = "https://oauth2.googleapis.com/token"
$script:ApiBaseUrl = "https://gmail.googleapis.com/gmail/v1"
$script:RedirectPort = 8914
$script:RedirectUri = "http://localhost:$($script:RedirectPort)"

function Test-GmailConfigured {
    if (-not $script:ClientId -or -not $script:ClientSecret) {
        return $false
    }
    return $true
}

function Get-CachedTokens {
    if (Test-Path $script:TokenCachePath) {
        try {
            return Get-Content $script:TokenCachePath -Raw | ConvertFrom-Json
        }
        catch { return $null }
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

function Get-GmailAccessTokenInteractive {
    Write-Host "Authentication required for Gmail. Opening browser..." -ForegroundColor Cyan
    $scopeString = $script:Scopes -join " "
    $state = [guid]::NewGuid().ToString("N")
    
    $authParams = @{
        client_id     = $script:ClientId
        redirect_uri  = $script:RedirectUri
        response_type = "code"
        scope         = $scopeString
        state         = $state
        access_type   = "offline"
        prompt        = "consent"
    }
    
    $authQuery = ($authParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" }) -join "&"
    $authUrl = "$($script:AuthUrl)?$authQuery"
    
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("$($script:RedirectUri)/")
    
    try { $listener.Start() }
    catch { throw "Failed to start listener on port $($script:RedirectPort)" }
    
    Write-Host "`nOpening browser for Google sign-in..." -ForegroundColor Yellow
    try { Start-Process $authUrl } catch { Write-Host "Open: $authUrl" -ForegroundColor Yellow }
    
    Write-Host "Waiting for authentication..." -ForegroundColor Cyan
    
    $asyncResult = $listener.BeginGetContext($null, $null)
    $waitResult = $asyncResult.AsyncWaitHandle.WaitOne(120000)
    
    if (-not $waitResult) { $listener.Stop(); throw "Authentication timed out." }
    
    $context = $listener.EndGetContext($asyncResult)
    $request = $context.Request
    $response = $context.Response
    
    $queryParams = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
    $code = $queryParams["code"]
    $returnedState = $queryParams["state"]
    $error = $queryParams["error"]
    
    $responseHtml = if ($error) { "<html><body><h2>Authentication failed</h2><p>Error: $error</p></body></html>" } else { "<html><body><h2>Authentication successful!</h2><p>You can close this window.</p></body></html>" }
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()
    $listener.Stop()
    
    if ($error) { throw "Authentication failed: $error" }
    if ($returnedState -ne $state) { throw "State mismatch." }
    if (-not $code) { throw "No authorization code received." }
    
    $tokenBody = @{
        code          = $code
        client_id     = $script:ClientId
        client_secret = $script:ClientSecret
        redirect_uri  = $script:RedirectUri
        grant_type    = "authorization_code"
    }
    
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
            } catch { }
        }
    }
    
    $expiresAt = (Get-Date).AddSeconds($tokenResponse.expires_in)
    Save-TokenCache -AccessToken $tokenResponse.access_token -RefreshToken $tokenResponse.refresh_token -ExpiresAt $expiresAt -AccountEmail $accountEmail
    Write-Host "Authenticated as: $accountEmail" -ForegroundColor Green
    return $tokenResponse.access_token
}

function Get-AccessTokenFromRefresh {
    param([string]$RefreshToken)
    $body = @{
        grant_type    = "refresh_token"
        client_id     = $script:ClientId
        client_secret = $script:ClientSecret
        refresh_token = $RefreshToken
    }
    try {
        $response = Invoke-RestMethod -Uri $script:TokenUrl -Method POST -Body $body
        $cache = Get-CachedTokens
        $expiresAt = (Get-Date).AddSeconds($response.expires_in)
        Save-TokenCache -AccessToken $response.access_token -RefreshToken ($response.refresh_token ?? $RefreshToken) -ExpiresAt $expiresAt -AccountEmail $cache.Account
        return $response.access_token
    }
    catch { return $null }
}

function Get-GmailAccessToken {
    $cache = Get-CachedTokens
    if ($cache) {
        $expiresAt = [datetime]::Parse($cache.ExpiresAt)
        if ($expiresAt -gt (Get-Date).AddMinutes(5)) { return $cache.AccessToken }
        if ($cache.RefreshToken) {
            $newToken = Get-AccessTokenFromRefresh -RefreshToken $cache.RefreshToken
            if ($newToken) { return $newToken }
        }
    }
    return Get-GmailAccessTokenInteractive
}

function Invoke-GmailApi {
    param([string]$AccessToken, [string]$Uri, [string]$Method = "GET", [object]$Body = $null)
    if (-not $Uri.StartsWith("https://")) { $Uri = "$script:ApiBaseUrl$Uri" }
    $headers = @{ Authorization = "Bearer $AccessToken"; "Content-Type" = "application/json" }
    $params = @{ Uri = $Uri; Method = $Method; Headers = $headers }
    if ($Body) { $params.Body = $Body | ConvertTo-Json -Depth 10 }
    Invoke-RestMethod @params
}

function Get-GmailHeader {
    param([object]$Message, [string]$HeaderName)
    $header = $Message.payload.headers | Where-Object { $_.name -ieq $HeaderName } | Select-Object -First 1
    return $header.value
}

function Get-GmailMessageDetails {
    param([string]$AccessToken, [string]$MessageId, [string]$Format = "metadata")
    Invoke-GmailApi -AccessToken $AccessToken -Uri "/users/me/messages/$MessageId`?format=$Format"
}
