# PowerShell tests for MCP Python Bootstrap
# Version: 1.2.0

$ErrorActionPreference = "Stop"

$TestDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $TestDir
$TempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        default { "Blue" }
    }
    
    Write-Host "[PS-TEST $Level] $Message" -ForegroundColor $color
}

function Write-TestError {
    param([string]$Message)
    Write-TestLog -Message $Message -Level "ERROR"
    exit 1
}

function Write-TestSuccess {
    param([string]$Message)
    Write-TestLog -Message $Message -Level "SUCCESS"
}

# Cleanup function
function Cleanup {
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Test PowerShell script syntax
function Test-PowerShellSyntax {
    Write-TestLog "Testing PowerShell script syntax..."
    
    $script = Join-Path $RootDir "scripts\bootstrap.ps1"
    
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script -Raw), [ref]$null)
        Write-TestSuccess "PowerShell script syntax is valid"
    } catch {
        Write-TestError "PowerShell script syntax check failed: $($_.Exception.Message)"
    }
}

# Test PowerShell-specific features
function Test-PowerShellFeatures {
    Write-TestLog "Testing PowerShell-specific features..."
    
    $script = Join-Path $RootDir "scripts\bootstrap.ps1"
    
    # Test that the script can be dot-sourced
    try {
        $scriptContent = Get-Content $script -Raw
        $scriptBlock = [ScriptBlock]::Create($scriptContent)
        
        # Test parameter binding
        if ($scriptContent -match 'param\s*\(') {
            Write-TestSuccess "PowerShell parameter binding syntax found"
        } else {
            Write-TestError "PowerShell parameter binding not found"
        }
        
    } catch {
        Write-TestError "PowerShell features test failed: $($_.Exception.Message)"
    }
}

# Test logging functions
function Test-Logging {
    Write-TestLog "Testing logging functions..."
    
    $env:MCP_BOOTSTRAP_BOOTSTRAP_DIR = Join-Path $TempDir "bootstrap"
    $script = Join-Path $RootDir "scripts\bootstrap.ps1"
    
    try {
        # Extract and test logging functions
        $scriptContent = Get-Content $script -Raw
        
        # Create a minimal test script
        $testScript = @"
$scriptContent

Initialize-Environment
Write-Log "Test message"
Write-Warn-Log "Test warning"
"@
        
        Invoke-Expression $testScript
        
        $logFile = Join-Path $env:MCP_BOOTSTRAP_BOOTSTRAP_DIR "bootstrap.log"
        if (Test-Path $logFile) {
            Write-TestSuccess "Logging functions work correctly"
        } else {
            Write-TestError "Log file was not created"
        }
        
    } catch {
        Write-TestError "Logging test failed: $($_.Exception.Message)"
    }
}

# Test platform detection
function Test-PlatformDetection {
    Write-TestLog "Testing platform detection..."
    
    $script = Join-Path $RootDir "scripts\bootstrap.ps1"
    
    try {
        $scriptContent = Get-Content $script -Raw
        
        # Extract Get-PlatformInfo function
        $testScript = @"
$scriptContent

${'$'}platform = Get-PlatformInfo
Write-Output ${'$'}platform
"@
        
        $platform = Invoke-Expression $testScript
        
        if ([string]::IsNullOrWhiteSpace($platform)) {
            Write-TestError "Platform detection returned empty result"
        } else {
            Write-TestSuccess "Platform detection works: $platform"
        }
        
    } catch {
        Write-TestError "Platform detection test failed: $($_.Exception.Message)"
    }
}

# Main test execution
function Main {
    Write-TestLog "Starting PowerShell tests"
    
    try {
        Test-PowerShellSyntax
        Test-PowerShellFeatures
        Test-Logging
        Test-PlatformDetection
        
        Write-TestSuccess "All PowerShell tests passed!"
    } finally {
        Cleanup
    }
}

# Run tests
Main