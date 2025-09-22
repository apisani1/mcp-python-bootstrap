# Enhanced PowerShell MCP Python Server Bootstrap
# Windows native support
# Version: 1.2.0

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$PackageSpec,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ServerArgs = @()
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.2.0"

# Configuration
$CacheDir = if ($env:MCP_BOOTSTRAP_CACHE_DIR) { $env:MCP_BOOTSTRAP_CACHE_DIR } else { Join-Path $env:USERPROFILE ".mcp\cache" }
$BootstrapDir = if ($env:MCP_BOOTSTRAP_BOOTSTRAP_DIR) { $env:MCP_BOOTSTRAP_BOOTSTRAP_DIR } else { Join-Path $env:USERPROFILE ".mcp\bootstrap" }
$LogFile = Join-Path $BootstrapDir "bootstrap.log"
$UvCacheDir = Join-Path $CacheDir "uv"

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - [$Level] $Message"

    switch ($Level) {
        "ERROR" { Write-Host "[MCP-Python ERROR] $Message" -ForegroundColor Red }
        "WARN"  { Write-Host "[MCP-Python WARN] $Message" -ForegroundColor Yellow }
        "SUCCESS" { Write-Host "[MCP-Python] $Message" -ForegroundColor Green }
        default { Write-Host "[MCP-Python] $Message" -ForegroundColor Blue }
    }

    # Write to log file
    try {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {
        # Ignore logging errors
    }
}

function Write-Error-Log {
    param([string]$Message)
    Write-Log -Message $Message -Level "ERROR"
    exit 1
}

function Write-Warn-Log {
    param([string]$Message)
    Write-Log -Message $Message -Level "WARN"
}

function Write-Success-Log {
    param([string]$Message)
    Write-Log -Message $Message -Level "SUCCESS"
}

# Initialize environment
function Initialize-Environment {
    Write-Log "Initializing PowerShell bootstrap environment"

    # Create directories
    @($CacheDir, $BootstrapDir, $UvCacheDir) | ForEach-Object {
        if (!(Test-Path $_)) {
            try {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
                Write-Log "Created directory: $_"
            } catch {
                Write-Warn-Log "Failed to create directory: $_"
            }
        }
    }

    # Rotate log if too large (>10MB)
    if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 10MB) {
        try {
            Move-Item $LogFile "$LogFile.old" -Force
            Write-Log "Rotated large log file"
        } catch {
            Write-Warn-Log "Failed to rotate log file"
        }
    }

    Write-Log "Cache directory: $CacheDir"
    Write-Log "Bootstrap directory: $BootstrapDir"
}

# Platform detection
function Get-PlatformInfo {
    $os = "windows"
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { "x64" }
        "ARM64" { "arm64" }
        "x86"   { "x86" }
        default { $env:PROCESSOR_ARCHITECTURE }
    }

    Write-Log "Detected platform: $os-$arch"
    return "$os-$arch"
}

# Check if command exists
function Test-CommandExists {
    param([string]$Command)

    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Network connectivity check
function Test-NetworkConnectivity {
    Write-Log "Checking network connectivity..."

    try {
        $response = Invoke-WebRequest -Uri "https://pypi.org" -Method Head -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Log "Network connectivity OK"
            return $true
        }
    } catch {
        Write-Warn-Log "Cannot reach PyPI - check your network connection"
        return $false
    }

    return $false
}

# Check if uvx is available
function Test-Uvx {
    if (Test-CommandExists "uvx") {
        try {
            $version = uvx --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "uvx found: $version"
                return $true
            }
        } catch {
            Write-Warn-Log "uvx command exists but not working properly"
        }
    }

    Write-Log "uvx not found, will install"
    return $false
}

# Check if uv is available
function Test-Uv {
    if (Test-CommandExists "uv") {
        try {
            $version = uv --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "uv found: $version"
                return $true
            }
        } catch {
            Write-Warn-Log "uv command exists but not working properly"
        }
    }

    Write-Log "uv not found, will install"
    return $false
}

# Install uv with retry logic
function Install-UvWithRetry {
    $maxAttempts = 3
    $platform = Get-PlatformInfo

    Write-Log "Installing uv for platform: $platform"

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Log "Installation attempt $attempt/$maxAttempts"

        try {
            # Set UV_CACHE_DIR for installation
            $env:UV_CACHE_DIR = $UvCacheDir

            # Download and execute uv installer
            $installerUrl = "https://astral.sh/uv/install.ps1"
            Write-Log "Downloading uv installer from $installerUrl"

            $installer = Invoke-RestMethod -Uri $installerUrl -UseBasicParsing

            # Execute installer with no PATH modification
            $installer | Invoke-Expression

            # Add to PATH for current session
            $uvPath = Join-Path $env:USERPROFILE ".cargo\bin"
            if ($env:PATH -notlike "*$uvPath*") {
                $env:PATH = "$uvPath;$env:PATH"
            }

            # Verify installation
            if (Test-CommandExists "uv") {
                if (Test-Uv) {
                    Write-Success-Log "uv installed and verified successfully"
                    return
                }
            }

            throw "uv installation verification failed"

        } catch {
            Write-Warn-Log "Installation attempt $attempt failed: $($_.Exception.Message)"

            if ($attempt -lt $maxAttempts) {
                Write-Log "Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
        }
    }

    Write-Error-Log "Failed to install uv after $maxAttempts attempts"
}

# Verify package exists on PyPI
function Test-PackageExists {
    param([string]$PackageSpec)

    # Extract package name (remove version specifiers)
    $packageName = ($PackageSpec -split '[>=<!~]')[0].Trim()
    $packageName = ($packageName -split '\[')[0].Trim()

    Write-Log "Verifying package exists: $packageName"

    # Skip verification for git URLs and local paths
    if ($PackageSpec -match '^git\+' -or $PackageSpec -match '^[a-zA-Z]:\\' -or $PackageSpec -match '^\.') {
        Write-Log "Skipping PyPI verification for non-PyPI package"
        return $true
    }

    try {
        $url = "https://pypi.org/pypi/$packageName/json"
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 10 -UseBasicParsing

        if ($response.info.name) {
            Write-Log "Package found: $($response.info.name) $($response.info.version)"
            return $true
        }
    } catch {
        Write-Warn-Log "Could not verify package on PyPI (may still work): $($_.Exception.Message)"
    }

    return $false
}

# Validate package specification
function Test-PackageSpec {
    param([string]$PackageSpec)

    if ([string]::IsNullOrWhiteSpace($PackageSpec)) {
        Write-Error-Log "Package specification is required"
    }

    Write-Log "Validating package specification: $PackageSpec"

    # Check for common issues
    if ($PackageSpec -match '\s') {
        Write-Warn-Log "Package spec contains spaces - ensure proper quoting in MCP config"
    }

    # Basic format validation
    $validPatterns = @(
        '^[a-zA-Z0-9_.-]+(\[[a-zA-Z0-9_,-]+\])?(==|>=|<=|>|<|!=|~=)?[0-9a-zA-Z._-]*$',
        '^git\+https?://',
        '^[a-zA-Z]:\\',
        '^\.'
    )

    $isValid = $false
    foreach ($pattern in $validPatterns) {
        if ($PackageSpec -match $pattern) {
            $isValid = $true
            break
        }
    }

    if (-not $isValid) {
        Write-Warn-Log "Package spec format may be invalid: $PackageSpec"
    }

    # Verify package exists
    if (-not (Test-PackageExists -PackageSpec $PackageSpec)) {
        Write-Warn-Log "Package verification failed, but will continue anyway"
    }
}

# Check environment freshness
function Test-EnvironmentFreshness {
    $lastCheckFile = Join-Path $BootstrapDir "last_env_check"
    $checkIntervalHours = 24

    if (Test-Path $lastCheckFile) {
        try {
            $lastCheck = Get-Content $lastCheckFile -ErrorAction Stop
            $lastCheckTime = [DateTime]::FromFileTime($lastCheck)
            $hoursSinceCheck = ((Get-Date) - $lastCheckTime).TotalHours

            if ($hoursSinceCheck -gt $checkIntervalHours) {
                Write-Log "Environment check is $([int]$hoursSinceCheck) hours old, may need updates"
            }
        } catch {
            Write-Log "Could not read last check time"
        }
    }

    # Save current time
    try {
        (Get-Date).ToFileTime() | Set-Content $lastCheckFile
    } catch {
        Write-Warn-Log "Could not save check time"
    }
}

# Run server with monitoring
function Start-ServerMonitored {
    param([string]$PackageSpec, [string[]]$ServerArgs)

    Write-Log "Starting monitored MCP server: $PackageSpec"

    # Ensure PATH includes uv
    $uvPath = Join-Path $env:USERPROFILE ".cargo\bin"
    if ($env:PATH -notlike "*$uvPath*") {
        $env:PATH = "$uvPath;$env:PATH"
    }

    # Set UV_CACHE_DIR
    $env:UV_CACHE_DIR = $UvCacheDir

    # Create startup marker
    $startupMarker = Join-Path $BootstrapDir "server_startup_$PID"
    (Get-Date).ToFileTime() | Set-Content $startupMarker

    # Cleanup function
    $cleanup = {
        if (Test-Path $startupMarker) {
            Remove-Item $startupMarker -Force -ErrorAction SilentlyContinue
        }
        Write-Log "Server cleanup completed"
    }

    try {
        # Log the command being executed
        $argsString = $ServerArgs -join ' '
        Write-Log "Executing: uvx $PackageSpec $argsString"

        # Start timeout monitor
        $monitor = Start-Job -ScriptBlock {
            param($marker)
            Start-Sleep 30
            if (Test-Path $marker) {
                Write-Warning "Server startup taking longer than expected (30s)"
            }
        } -ArgumentList $startupMarker

        # Build arguments array
        $uvxArgs = @($PackageSpec) + $ServerArgs

        # Execute the server
        & uvx @uvxArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Success-Log "Server exited normally"
        } else {
            Write-Error-Log "Server exited with code $LASTEXITCODE"
        }

    } finally {
        # Cleanup
        & $cleanup

        # Stop monitor
        if ($monitor) {
            Stop-Job $monitor -ErrorAction SilentlyContinue
            Remove-Job $monitor -ErrorAction SilentlyContinue
        }
    }
}

# Main execution function
function Main {
    param([string]$PackageSpec, [string[]]$ServerArgs)

    Write-Log "Enhanced MCP Python Server Bootstrap v$ScriptVersion (PowerShell)"
    Write-Log "Platform: $(Get-PlatformInfo)"

    # Initialize environment
    Initialize-Environment

    # Validate inputs
    Test-PackageSpec -PackageSpec $PackageSpec

    # Check environment freshness
    Test-EnvironmentFreshness

    # Check network connectivity
    if (-not (Test-NetworkConnectivity)) {
        Write-Warn-Log "Network issues detected, but continuing anyway"
    }

    # Ensure uvx is available
    if (-not (Test-Uvx)) {
        if (-not (Test-Uv)) {
            Install-UvWithRetry
        } else {
            Write-Log "uv found, uvx should be available"
            $uvPath = Join-Path $env:USERPROFILE ".cargo\bin"
            if ($env:PATH -notlike "*$uvPath*") {
                $env:PATH = "$uvPath;$env:PATH"
            }
            if (-not (Test-Uvx)) {
                Write-Error-Log "uv found but uvx not working"
            }
        }
    }

    # Run the server
    Start-ServerMonitored -PackageSpec $PackageSpec -ServerArgs $ServerArgs
}

# Handle help and version
if ($PackageSpec -eq "--help" -or $PackageSpec -eq "-h" -or $PackageSpec -eq "help") {
    Write-Host "Enhanced MCP Python Server Bootstrap (PowerShell) v$ScriptVersion"
    Write-Host ""
    Write-Host "This script will install uvx (if needed) and run a Python MCP server."
    Write-Host ""
    Write-Host "USAGE: .\bootstrap.ps1 package-spec [server-args...]"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "    .\bootstrap.ps1 mcp-server-filesystem"
    Write-Host "    .\bootstrap.ps1 mcp-server-database==1.2.0 --config config.json"
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES:"
    Write-Host "    MCP_BOOTSTRAP_CACHE_DIR      Cache directory"
    Write-Host "    MCP_BOOTSTRAP_BOOTSTRAP_DIR  Bootstrap data directory"
    Write-Host ""
    exit 0
}

if ($PackageSpec -eq "--version" -or $PackageSpec -eq "-v") {
    Write-Host $ScriptVersion
    exit 0
}

# Run main function
try {
    Main -PackageSpec $PackageSpec -ServerArgs $ServerArgs
} catch {
    Write-Error-Log "Bootstrap failed: $($_.Exception.Message)"
}