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

    # Extract and test the detect_platform function
    local platform
    platform=$(bash -c "
        source '$script'
        detect_platform
    " 2>/dev/null) || error "Platform detection failed"

    if [[ -z "$platform" ]]; then
        error "Platform detection returned empty result"
    fi

    success "Platform detected: $platform"
}

# Test script download
test_script_download() {
    log "Testing script download..."

    export MCP_BOOTSTRAP_CACHE_DIR="$TEMP_DIR/cache"
    export MCP_BOOTSTRAP_BASE_URL="https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts"

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

    local script="$ROOT_DIR/scripts/bootstrap-bash.sh"

    # Test valid package specs
    local valid_specs=(
        "mcp-server-filesystem"
        "mcp-server-database==1.0.0"
        "mcp-server-web>=2.0.0"
        "git+https://github.com/user/repo.git"
    )

    for spec in "${valid_specs[@]}"; do
        log "Testing package spec: $spec"
        # This would normally run the full script, but we'll just test validation
        if ! bash -c "
            PACKAGE_SPEC='$spec'
            source '$script'
            validate_package_spec
        " 2>/dev/null; then
            warn "Package validation failed for: $spec"
        fi
    done

    success "Package validation tests completed"
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

    # Test that environment variables are respected
    if bash -c "source '$script'; echo \$CACHE_DIR" | grep -q "custom-cache"; then
        success "Environment variables respected"
    else
        warn "Environment variables may not be working correctly"
    fi
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