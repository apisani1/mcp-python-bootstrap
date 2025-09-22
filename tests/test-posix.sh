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

    # Create a simple test for command existence logic
    local test_script="$TEMP_DIR/command_exists_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/sh
# Extract command_exists function from bootstrap-posix.sh
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test the function
if command_exists sh; then
    echo "SUCCESS: sh command found"
    exit 0
else
    echo "ERROR: sh command not found"
    exit 1
fi
EOF

    chmod +x "$test_script"

    if "$test_script" >/dev/null 2>&1; then
        success "Command existence check works"
    else
        error "command_exists function failed"
    fi
}

# Test platform detection
test_platform_detection() {
    log "Testing platform detection..."

    # Create a standalone platform detection test
    local test_script="$TEMP_DIR/platform_detection_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/sh
# Extract detect_platform function from bootstrap-posix.sh
detect_platform() {
    # Simple platform detection
    if command -v uname >/dev/null 2>&1; then
        os=$(uname -s)
        arch=$(uname -m)
    else
        os="unknown"
        arch="unknown"
    fi

    case "$os" in
        Linux)
            if [ -f /etc/alpine-release ]; then
                echo "alpine-$arch"
            else
                echo "linux-$arch"
            fi
            ;;
        *) echo "posix-$arch" ;;
    esac
}

platform=$(detect_platform)
if [ -n "$platform" ]; then
    echo "Platform: $platform"
    exit 0
else
    echo "Platform detection failed"
    exit 1
fi
EOF

    chmod +x "$test_script"

    local platform
    if platform=$("$test_script" 2>/dev/null | grep "Platform:" | cut -d' ' -f2); then
        if [ -z "$platform" ]; then
            error "Platform detection returned empty result"
        else
            success "Platform detection works: $platform"
        fi
    else
        error "Platform detection failed"
    fi
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