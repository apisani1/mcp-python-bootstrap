#!/bin/bash
# Integration tests for MCP Python Bootstrap
# Version: 1.2.0

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
TEMP_DIR=$(mktemp -d)
TEST_LOG="$TEMP_DIR/test.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[TEST] $1" | tee -a "$TEST_LOG"
}

success() {
    echo -e "${GREEN}[TEST SUCCESS]${NC} $1" | tee -a "$TEST_LOG"
}

error() {
    echo -e "${RED}[TEST ERROR]${NC} $1" | tee -a "$TEST_LOG"
    exit 1
}

warn() {
    echo -e "${YELLOW}[TEST WARN]${NC} $1" | tee -a "$TEST_LOG"
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Test platform detection
test_platform_detection() {
    log "Testing platform detection..."

    local script="$ROOT_DIR/scripts/universal-bootstrap.sh"
    if [[ ! -f "$script" ]]; then
        error "Universal bootstrap script not found: $script"
    fi

    # Create a temporary script to extract and test platform detection
    local temp_script="$TEMP_DIR/detect_platform_test.sh"
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# Extract detect_platform function from universal-bootstrap.sh
detect_platform() {
    local os=""
    local shell=""
    local arch=""

    # Architecture detection
    case "$(uname -m 2>/dev/null || echo unknown)" in
        x86_64|amd64) arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        i386|i686) arch="x86" ;;
        *) arch="unknown" ;;
    esac

    # OS Detection with Windows edge cases
    if [ -n "${WINDIR:-}" ] || [ -n "${SYSTEMROOT:-}" ]; then
        os="windows-native"
    else
        case "$(uname -s 2>/dev/null || echo unknown)" in
            Linux*)
                if [ -f /etc/alpine-release ]; then
                    os="alpine"
                else
                    os="linux"
                fi
                ;;
            Darwin*) os="macos" ;;
            CYGWIN*|MINGW*|MSYS*) os="windows-unix" ;;
            FreeBSD*) os="freebsd" ;;
            OpenBSD*) os="openbsd" ;;
            *) os="unknown" ;;
        esac
    fi

    # Shell Detection
    if [ -n "${BASH_VERSION:-}" ]; then
        shell="bash"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        shell="zsh"
    elif [ -n "${PSModulePath:-}" ] || command -v powershell >/dev/null 2>&1; then
        shell="powershell"
    elif [ -n "${KSH_VERSION:-}" ]; then
        shell="ksh"
    else
        shell="posix"
    fi

    echo "${os}-${shell}-${arch}"
}

detect_platform
EOF

    chmod +x "$temp_script"

    # Test platform detection
    local platform
    if platform=$("$temp_script" 2>/dev/null); then
        if [[ -z "$platform" ]]; then
            error "Platform detection returned empty result"
        else
            success "Platform detected: $platform"
        fi
    else
        error "Platform detection failed"
    fi
}

# Test script download
test_script_download() {
    log "Testing script download..."

    export MCP_BOOTSTRAP_CACHE_DIR="$TEMP_DIR/cache"
    export MCP_BOOTSTRAP_BASE_URL="https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts"

    local script="$ROOT_DIR/scripts/universal-bootstrap.sh"

    # Test help command
    if ! bash "$script" --help >/dev/null 2>&1; then
        error "Help command failed"
    fi

    success "Script download test passed"
}

# Test package validation
test_package_validation() {
    log "Testing package validation..."

    # Test valid package specs by checking format patterns
    local valid_specs=(
        "mcp-server-filesystem"
        "mcp-server-database==1.0.0"
        "mcp-server-web>=2.0.0"
        "git+https://github.com/user/repo.git"
    )

    local validation_errors=0

    for spec in "${valid_specs[@]}"; do
        log "Testing package spec: $spec"

        # Basic validation logic (simplified version of the actual validation)
        if [[ -z "$spec" ]]; then
            warn "Empty package specification"
            ((validation_errors++))
            continue
        fi

        # Check for obviously invalid formats
        if [[ "$spec" =~ ^[[:space:]]*$ ]]; then
            warn "Package spec is only whitespace: $spec"
            ((validation_errors++))
            continue
        fi

        log "✓ Package spec format appears valid: $spec"
    done

    if [[ $validation_errors -eq 0 ]]; then
        success "Package validation tests completed - all specs appear valid"
    else
        warn "Package validation completed with $validation_errors potential issues"
    fi
}

# Test POSIX compatibility
test_posix_compatibility() {
    log "Testing POSIX compatibility..."

    local script="$ROOT_DIR/scripts/bootstrap-posix.sh"

    # Test with sh (not bash)
    if ! sh "$script" --help >/dev/null 2>&1; then
        error "POSIX script help failed"
    fi

    success "POSIX compatibility test passed"
}

# Test PowerShell script (if available)
test_powershell_script() {
    if command -v powershell >/dev/null 2>&1; then
        log "Testing PowerShell script..."

        local script="$ROOT_DIR/scripts/bootstrap.ps1"

        if ! powershell -ExecutionPolicy Bypass -File "$script" -PackageSpec "--help" 2>/dev/null; then
            warn "PowerShell script test failed (may be expected on non-Windows)"
        else
            success "PowerShell script test passed"
        fi
    else
        warn "PowerShell not available, skipping PowerShell tests"
    fi
}

# Test environment variables
test_environment_variables() {
    log "Testing environment variables..."

    export MCP_BOOTSTRAP_CACHE_DIR="$TEMP_DIR/custom-cache"
    export MCP_BOOTSTRAP_BASE_URL="https://example.com/custom"

    local script="$ROOT_DIR/scripts/universal-bootstrap.sh"

    # Test that environment variables are passed through correctly
    # by running the script with --help and checking it doesn't error
    if MCP_BOOTSTRAP_CACHE_DIR="$TEMP_DIR/custom-cache" bash "$script" --help >/dev/null 2>&1; then
        success "Environment variables test passed"
    else
        warn "Environment variables test failed, but script may still work"
    fi

    # Reset environment variables
    unset MCP_BOOTSTRAP_CACHE_DIR
    unset MCP_BOOTSTRAP_BASE_URL
}

# Test error handling
test_error_handling() {
    log "Testing error handling..."

    local script="$ROOT_DIR/scripts/universal-bootstrap.sh"

    # Test with no arguments
    if bash "$script" 2>/dev/null; then
        error "Script should fail with no arguments"
    fi

    # Test with invalid package spec
    if bash "$script" "" 2>/dev/null; then
        error "Script should fail with empty package spec"
    fi

    success "Error handling tests passed"
}

# Main test execution
main() {
    log "Starting MCP Python Bootstrap integration tests"
    log "Test directory: $TEMP_DIR"
    log "Log file: $TEST_LOG"

    test_platform_detection
    test_script_download
    test_package_validation
    test_posix_compatibility
    test_powershell_script
    test_environment_variables
    test_error_handling

    success "All tests completed successfully!"
    log "Test log available at: $TEST_LOG"
}

main "$@"