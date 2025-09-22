#!/bin/bash
# Bash-specific tests for MCP Python Bootstrap
# Version: 1.2.0

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
TEMP_DIR=$(mktemp -d)

log() {
    echo "[BASH-TEST] $1" >&2
}

error() {
    echo "[BASH-TEST ERROR] $1" >&2
    exit 1
}

success() {
    echo "[BASH-TEST SUCCESS] $1" >&2
}

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Test bash script syntax
test_bash_syntax() {
    log "Testing bash script syntax..."
    
    local script="$ROOT_DIR/scripts/bootstrap-bash.sh"
    if ! bash -n "$script"; then
        error "Bash script syntax check failed"
    fi
    
    success "Bash script syntax is valid"
}

# Test bash-specific features
test_bash_features() {
    log "Testing bash-specific features..."
    
    local script="$ROOT_DIR/scripts/bootstrap-bash.sh"
    
    # Test array handling
    if ! bash -c "source '$script'; declare -a test_array=(one two three); echo \${test_array[@]}" >/dev/null; then
        error "Bash array handling failed"
    fi
    
    success "Bash features test passed"
}

# Test logging functions
test_logging() {
    log "Testing logging functions..."
    
    export MCP_BOOTSTRAP_BOOTSTRAP_DIR="$TEMP_DIR/bootstrap"
    local script="$ROOT_DIR/scripts/bootstrap-bash.sh"
    
    # Test that logging functions work
    bash -c "
        source '$script'
        init_environment
        log 'Test message'
        warn 'Test warning'
    " 2>/dev/null
    
    if [[ ! -f "$TEMP_DIR/bootstrap/bootstrap.log" ]]; then
        error "Log file was not created"
    fi
    
    success "Logging functions work correctly"
}

main() {
    log "Starting bash-specific tests"
    
    test_bash_syntax
    test_bash_features
    test_logging
    
    success "All bash tests passed!"
}

main "$@"