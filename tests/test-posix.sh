#!/bin/sh
# POSIX shell tests for MCP Python Bootstrap
# Version: 1.2.0

set -eu

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
TEMP_DIR="${TMPDIR:-/tmp}/mcp-test-$$"

log() {
    printf "[POSIX-TEST] %s\n" "$1" >&2
}

error() {
    printf "[POSIX-TEST ERROR] %s\n" "$1" >&2
    exit 1
}

success() {
    printf "[POSIX-TEST SUCCESS] %s\n" "$1" >&2
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

# Create temp directory
mkdir -p "$TEMP_DIR"

# Test POSIX script syntax
test_posix_syntax() {
    log "Testing POSIX script syntax..."
    
    local script="$ROOT_DIR/scripts/bootstrap-posix.sh"
    if ! sh -n "$script"; then
        error "POSIX script syntax check failed"
    fi
    
    success "POSIX script syntax is valid"
}

# Test POSIX compliance
test_posix_compliance() {
    log "Testing POSIX compliance..."
    
    local script="$ROOT_DIR/scripts/bootstrap-posix.sh"
    
    # Check for bash-specific features that shouldn't be there
    if grep -E '\[\[|\$\(\(|\$\{.*#.*\}|\$\{.*%.*\}' "$script" >/dev/null; then
        error "POSIX script contains bash-specific features"
    fi
    
    success "POSIX compliance check passed"
}

# Test command existence check
test_command_exists() {
    log "Testing command existence check..."
    
    export MCP_BOOTSTRAP_BOOTSTRAP_DIR="$TEMP_DIR/bootstrap"
    local script="$ROOT_DIR/scripts/bootstrap-posix.sh"
    
    # Test command_exists function
    if ! sh -c "
        . '$script'
        if command_exists sh; then
            exit 0
        else
            exit 1
        fi
    "; then
        error "command_exists function failed"
    fi
    
    success "Command existence check works"
}

# Test platform detection
test_platform_detection() {
    log "Testing platform detection..."
    
    local script="$ROOT_DIR/scripts/bootstrap-posix.sh"
    
    local platform
    platform=$(sh -c ". '$script'; detect_platform") || error "Platform detection failed"
    
    if [ -z "$platform" ]; then
        error "Platform detection returned empty result"
    fi
    
    success "Platform detection works: $platform"
}

main() {
    log "Starting POSIX shell tests"
    
    test_posix_syntax
    test_posix_compliance
    test_command_exists
    test_platform_detection
    
    success "All POSIX tests passed!"
}

main "$@"