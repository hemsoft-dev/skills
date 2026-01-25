#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Executes a browser-use agent task with specified LLM provider.

.DESCRIPTION
    Runs a browser-use agent with a given task and LLM provider. Supports multiple LLM providers
    including OpenAI, Anthropic, Google, DeepSeek, and Browser Use's optimized model.

.PARAMETER Task
    The task description for the browser agent to execute.

.PARAMETER LlmProvider
    LLM provider to use: OpenAI, Anthropic, Google, DeepSeek, BrowserUse (default: BrowserUse)

.PARAMETER Model
    Specific model name (optional, uses provider defaults)

.PARAMETER UseCloud
    Use Browser Use Cloud for stealth browser (requires BROWSER_USE_API_KEY)

.PARAMETER EnvFile
    Path to .env file containing API keys (default: .env in current directory)

.EXAMPLE
    .\Invoke-BrowserUseTask.ps1 -Task "Find the number of stars of the browser-use repo"
    Runs task with Browser Use optimized model.

.EXAMPLE
    .\Invoke-BrowserUseTask.ps1 -Task "Compare prices" -LlmProvider OpenAI -Model "gpt-4o-mini"
    Runs task with OpenAI GPT-4o-mini.

.EXAMPLE
    .\Invoke-BrowserUseTask.ps1 -Task "Fill form" -UseCloud
    Runs task using Browser Use Cloud stealth browser.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Task,

    [Parameter(Mandatory=$false)]
    [ValidateSet('OpenAI', 'Anthropic', 'Google', 'DeepSeek', 'BrowserUse', 'Grok', 'Novita', 'AzureOpenAI')]
    [string]$LlmProvider = 'BrowserUse',

    [Parameter(Mandatory=$false)]
    [string]$Model,

    [Parameter(Mandatory=$false)]
    [switch]$UseCloud,

    [Parameter(Mandatory=$false)]
    [string]$EnvFile = '.env'
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine skill directory (parent of scripts folder)
$skillDir = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $skillDir "venv"
$pythonExe = Join-Path $venvPath "Scripts\python.exe"

# Check if venv exists
if (-not (Test-Path $pythonExe)) {
    Write-Error "Virtual environment not found. Run Install-BrowserUse.ps1 first."
    exit 1
}

# Load environment variables if .env file exists
if (Test-Path $EnvFile) {
    Write-Information "`e[36mLoading environment variables from $EnvFile...`e[0m"
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

# Map GEMINI_API_KEY to GOOGLE_API_KEY if needed (for browser-use compatibility)
if (-not $env:GOOGLE_API_KEY -and $env:GEMINI_API_KEY) {
    Write-Information "`e[36mMapping GEMINI_API_KEY to GOOGLE_API_KEY for browser-use...`e[0m"
    [Environment]::SetEnvironmentVariable("GOOGLE_API_KEY", $env:GEMINI_API_KEY, 'Process')
}

# Create Python script
$pythonScript = @"
import asyncio
import os
from browser_use import Agent, Browser

# Import LLM providers (handle missing imports gracefully)
try:
    from browser_use.llm import ChatOpenAI
except ImportError:
    ChatOpenAI = None
try:
    from browser_use.llm import ChatAnthropic
except ImportError:
    ChatAnthropic = None
try:
    from browser_use.llm import ChatGoogle
except ImportError:
    ChatGoogle = None
try:
    from browser_use.llm import ChatDeepSeek
except ImportError:
    ChatDeepSeek = None
try:
    from browser_use.llm import ChatBrowserUse
except ImportError:
    ChatBrowserUse = None
try:
    from browser_use.llm import ChatGrok
except ImportError:
    ChatGrok = None
try:
    from browser_use.llm import ChatNovita
except ImportError:
    ChatNovita = None
try:
    from browser_use.llm import ChatAzureOpenAI
except ImportError:
    ChatAzureOpenAI = None

async def main():
    # Initialize browser (headless=False to see what's happening)
    browser = Browser(use_cloud=$($UseCloud -eq $true), headless=False)

    # Select LLM provider
    if "$LlmProvider" == "OpenAI":
        if ChatOpenAI is None:
            raise ValueError("ChatOpenAI is not available in this browser-use version")
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY not found in environment")
        model = "$Model" if "$Model" else "gpt-4o-mini"
        llm = ChatOpenAI(model=model, temperature=1.0)
    elif "$LlmProvider" == "Anthropic":
        if ChatAnthropic is None:
            raise ValueError("ChatAnthropic is not available in this browser-use version")
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY not found in environment")
        model = "$Model" if "$Model" else "claude-3-7-sonnet-latest"
        llm = ChatAnthropic(model=model, temperature=1.0)
    elif "$LlmProvider" == "Google":
        if ChatGoogle is None:
            raise ValueError("ChatGoogle is not available in this browser-use version")
        # Check both GOOGLE_API_KEY and GEMINI_API_KEY (mapped by PowerShell script)
        api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GOOGLE_API_KEY or GEMINI_API_KEY not found in environment")
        model = "$Model" if "$Model" else "gemini-2.0-flash-exp"
        llm = ChatGoogle(model=model, temperature=1.0)
    elif "$LlmProvider" == "DeepSeek":
        if ChatDeepSeek is None:
            raise ValueError("ChatDeepSeek is not available in this browser-use version")
        api_key = os.getenv("DEEPSEEK_API_KEY")
        if not api_key:
            raise ValueError("DEEPSEEK_API_KEY not found in environment")
        model = "$Model" if "$Model" else "deepseek-chat"
        llm = ChatDeepSeek(model=model, temperature=1.0)
    elif "$LlmProvider" == "Grok":
        if ChatGrok is None:
            raise ValueError("ChatGrok is not available in this browser-use version")
        api_key = os.getenv("GROK_API_KEY")
        if not api_key:
            raise ValueError("GROK_API_KEY not found in environment")
        model = "$Model" if "$Model" else "grok-beta"
        llm = ChatGrok(model=model, temperature=1.0)
    elif "$LlmProvider" == "Novita":
        if ChatNovita is None:
            raise ValueError("ChatNovita is not available in this browser-use version")
        api_key = os.getenv("NOVITA_API_KEY")
        if not api_key:
            raise ValueError("NOVITA_API_KEY not found in environment")
        model = "$Model" if "$Model" else "novita-llama-3.1-70b"
        llm = ChatNovita(model=model, temperature=1.0)
    elif "$LlmProvider" == "AzureOpenAI":
        if ChatAzureOpenAI is None:
            raise ValueError("ChatAzureOpenAI is not available in this browser-use version")
        endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        api_key = os.getenv("AZURE_OPENAI_KEY")
        if not endpoint or not api_key:
            raise ValueError("AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_KEY required")
        model = "$Model" if "$Model" else "gpt-4o"
        llm = ChatAzureOpenAI(endpoint=endpoint, api_key=api_key, model=model, temperature=1.0)
    else:  # BrowserUse (default)
        if ChatBrowserUse is None:
            raise ValueError("ChatBrowserUse is not available. Please check browser-use installation.")
        api_key = os.getenv("BROWSER_USE_API_KEY")
        if not api_key:
            raise ValueError("BROWSER_USE_API_KEY not found in environment")
        llm = ChatBrowserUse()

    # Create and run agent
    agent = Agent(
        task="$Task",
        llm=llm,
        browser=browser,
    )

    print(f"Running task: $Task")
    print(f"Using LLM: $LlmProvider")
    if "$Model":
        print(f"Model: $Model")
    if $($UseCloud -eq $true):
        print("Using Browser Use Cloud (stealth mode)")
    
    history = await agent.run()
    print("\nTask completed successfully!")
    return history

if __name__ == "__main__":
    asyncio.run(main())
"@

# Write temporary Python script
$tempScript = Join-Path $env:TEMP "browser-use-task-$(Get-Date -Format 'yyyyMMdd-HHmmss').py"
try {
    $pythonScript | Out-File -FilePath $tempScript -Encoding utf8

    Write-Information "`e[36mExecuting browser-use task...`e[0m"
    Write-Information "`e[36mTask: $Task`e[0m"
    Write-Information "`e[36mLLM Provider: $LlmProvider`e[0m"
    Write-Information "`e[36mUsing virtual environment: $venvPath`e[0m"

    & $pythonExe $tempScript

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Task execution failed"
        exit 1
    }

    Write-Information "`e[32m✓ Task completed successfully`e[0m"

} catch {
    Write-Error "Failed to execute task: $_"
    exit 1
} finally {
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -ErrorAction SilentlyContinue
    }
}
