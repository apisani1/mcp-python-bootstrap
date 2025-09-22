#!/bin/bash
# Enhanced Bash MCP Python Server Bootstrap
# Supports Linux, macOS, FreeBSD, WSL
# Version: 1.2.0

set -euo pipefail

SCRIPT_VERSION="1.2.0"
PACKAGE_SPEC="${1:-}"
SCRIPT_ARGS=("${@:2}")

# Configuration
CACHE_DIR="${MCP_BOOTSTRAP_CACHE_DIR:-$HOME/.mcp/cache}"
BOOTSTRAP_DIR="${MCP_BOOTSTRAP_BOOTSTRAP_DIR:-$HOME/.mcp/bootstrap}"
LOG_FILE="$BOOTSTRAP_DIR/bootstrap.log"
UV_CACHE_DIR="$CACHE_DIR/uv"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[MCP-Python]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[MCP-Python WARN]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARN] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[MCP-Python ERROR]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >> "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[MCP-Python]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1" >> "$LOG_FILE"
}

# Initialize directories and logging
init_environment() {
    mkdir -p "$CACHE_DIR" "$BOOTSTRAP_DIR" "$UV_CACHE_DIR"

    # Rotate log if it gets too large (>10MB)
    if [[ -f "$LOG_FILE" && $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
    fi

    log "Bootstrap environment initialized"
    log "Cache directory: $CACHE_DIR"
    log "Bootstrap directory: $BOOTSTRAP_DIR"
}

# Platform and architecture detection
detect_platform() {
    local os=$(uname -s)
    local arch=$(uname -m)

    case $arch in
        x86_64|amd64) arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        armv7l) arch="armv7" ;;
        *) log "Architecture: $arch (may not be officially supported)" ;;
    esac

    case $os in
        Linux) echo "linux-$arch" ;;
        Darwin) echo "macos-$arch" ;;
        FreeBSD) echo "freebsd-$arch" ;;
        *) echo "unknown-$arch" ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Network connectivity check
check_network() {
    log "Checking network connectivity..."

    if command_exists curl; then
        if ! curl -sSf --connect-timeout 10 https://pypi.org >/dev/null 2>&1; then
            warn "Cannot reach PyPI - check your network connection"
            return 1
        fi
    elif command_exists wget; then
        if ! wget -q --timeout=10 --spider https://pypi.org >/dev/null 2>&1; then
            warn "Cannot reach PyPI - check your network connection"
            return 1
        fi
    else
        warn "Neither curl nor wget available - cannot test network"
        return 1
    fi

    log "Network connectivity OK"
    return 0
}

# Check if uvx is available and working
check_uvx() {
    if command_exists uvx; then
        local version
        if version=$(uvx --version 2>/dev/null); then
            log "uvx found: $version"
            return 0
        else
            warn "uvx command exists but not working properly"
            return 1
        fi
    else
        log "uvx not found, will install"
        return 1
    fi
}

# Check if uv is available
check_uv() {
    if command_exists uv; then
        local version
        if version=$(uv --version 2>/dev/null); then
            log "uv found: $version"
            return 0
        else
            warn "uv command exists but not working properly"
            return 1
        fi
    else
        log "uv not found, will install"
        return 1
    fi
}

# Install uv with retry logic and verification
install_uv_with_retry() {
    local max_attempts=3
    local attempt=1
    local platform
    platform=$(detect_platform)

    log "Installing uv for platform: $platform"

    while [[ $attempt -le $max_attempts ]]; do
        log "Installation attempt $attempt/$max_attempts"

        # Set UV_CACHE_DIR for installation
        export UV_CACHE_DIR="$UV_CACHE_DIR"

        if command_exists curl; then
            if curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path; then
                break
            fi
        elif command_exists wget; then
            if wget -qO- https://astral.sh/uv/install.sh | sh -s -- --no-modify-path; then
                break
            fi
        else
            error "Neither curl nor wget available for downloading uv installer"
        fi

        warn "Installation attempt $attempt failed"
        ((attempt++))

        if [[ $attempt -le $max_attempts ]]; then
            log "Retrying in 5 seconds..."
            sleep 5
        fi
    done

    if [[ $attempt -gt $max_attempts ]]; then
        error "Failed to install uv after $max_attempts attempts"
    fi

    # Add uv to PATH for current session
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    # Verify installation
    if ! command_exists uv; then
        error "uv installation completed but command not found in PATH"
    fi

    # Verify uv is working
    if ! uv --version >/dev/null 2>&1; then
        error "uv installed but not working properly"
    fi

    success "uv installed and verified successfully"
}

# Verify package exists on PyPI
verify_package_exists() {
    local package_spec="$1"
    local package_name

    # Extract package name (remove version specifiers)
    package_name=$(echo "$package_spec" | sed -E 's/([a-zA-Z0-9_-]+).*/\1/' | sed 's/git+https:\/\/.*\///' | sed 's/\.git.*//')

    log "Verifying package exists: $package_name"

    # Skip verification for git URLs and local paths
    if [[ "$package_spec" == git+* ]] || [[ "$package_spec" == /* ]] || [[ "$package_spec" == ./* ]]; then
        log "Skipping PyPI verification for non-PyPI package"
        return 0
    fi

    # Use Python to check PyPI if available
    if command_exists python3; then
        if python3 -c "
import urllib.request
import json
import sys
import ssl

package_name = sys.argv[1]
url = f'https://pypi.org/pypi/{package_name}/json'

try:
    # Handle SSL issues in some environments
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    with urllib.request.urlopen(url, context=context, timeout=10) as response:
        data = json.loads(response.read())
        print(f'✓ Package found: {data[\"info\"][\"name\"]} {data[\"info\"][\"version\"]}')
except Exception as e:
    print(f'✗ Package verification failed: {e}', file=sys.stderr)
    sys.exit(1)
" "$package_name" 2>/dev/null; then
            log "Package verification successful"
        else
            warn "Could not verify package on PyPI (may still work)"
        fi
    else
        log "Python not available for package verification"
    fi
}

# Validate package specification
validate_package_spec() {
    if [[ -z "$PACKAGE_SPEC" ]]; then
        error "Package specification is required"
    fi

    log "Validating package specification: $PACKAGE_SPEC"

    # Check for common issues
    if [[ "$PACKAGE_SPEC" =~ [[:space:]] ]]; then
        warn "Package spec contains spaces - ensure proper quoting in MCP config"
    fi

    # Basic format validation
    if [[ ! "$PACKAGE_SPEC" =~ ^[a-zA-Z0-9_.-]+(\[[a-zA-Z0-9_,-]+\])?(==|>=|<=|>|<|!=|~=)?[0-9a-zA-Z._-]*$ ]] &&
       [[ ! "$PACKAGE_SPEC" =~ ^git\+https?:// ]] &&
       [[ ! "$PACKAGE_SPEC" =~ ^\./ ]] &&
       [[ ! "$PACKAGE_SPEC" =~ ^/ ]]; then
        warn "Package spec format may be invalid: $PACKAGE_SPEC"
    fi

    # Verify package exists
    if ! verify_package_exists "$PACKAGE_SPEC"; then
        warn "Package verification failed, but will continue anyway"
    fi
}

# Check script and environment freshness
check_environment_freshness() {
    local last_check_file="$BOOTSTRAP_DIR/last_env_check"
    local check_interval_hours=24

    if [[ -f "$last_check_file" ]]; then
        local last_check=$(cat "$last_check_file")
        local current_time=$(date +%s)
        local hours_since_check=$(( (current_time - last_check) / 3600 ))

        if [[ $hours_since_check -gt $check_interval_hours ]]; then
            log "Environment check is $hours_since_check hours old, may need updates"
        fi
    fi

    echo "$(date +%s)" > "$last_check_file"
}

# Enhanced server execution with monitoring
run_server_monitored() {
    log "Starting monitored MCP server: $PACKAGE_SPEC"

    # Ensure PATH includes uv
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    export UV_CACHE_DIR="$UV_CACHE_DIR"

    # Create startup marker
    local startup_marker="$BOOTSTRAP_DIR/server_startup_$$"
    echo "$(date +%s)" > "$startup_marker"

    # Cleanup function
    cleanup() {
        rm -f "$startup_marker"
        log "Server cleanup completed"
    }
    trap cleanup EXIT INT TERM

    # Log the command being executed
    log "Executing: uvx $PACKAGE_SPEC ${SCRIPT_ARGS[*]}"

    # Start the server with timeout monitoring
    (
        sleep 30
        if [[ -f "$startup_marker" ]]; then
            warn "Server startup taking longer than expected (30s)"
        fi
    ) &
    local monitor_pid=$!

    # Execute the server
    if uvx "$PACKAGE_SPEC" "${SCRIPT_ARGS[@]}"; then
        success "Server exited normally"
    else
        local exit_code=$?
        error "Server exited with code $exit_code"
    fi

    # Stop monitor
    kill $monitor_pid 2>/dev/null || true
}

# Main execution function
main() {
    log "Enhanced MCP Python Server Bootstrap v$SCRIPT_VERSION (Bash)"

    # Initialize environment
    init_environment

    # Validate inputs
    validate_package_spec

    # Check environment freshness
    check_environment_freshness

    # Check network connectivity
    if ! check_network; then
        warn "Network issues detected, but continuing anyway"
    fi

    # Ensure uvx is available
    if ! check_uvx; then
        if ! check_uv; then
            install_uv_with_retry
        else
            log "uv found, uvx should be available"
            export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
            if ! check_uvx; then
                error "uv found but uvx not working"
            fi
        fi
    fi

    # Run the server
    run_server_monitored
}

# Handle help and version
case "${1:-}" in
    --help|-h|help)
        cat << EOF
Enhanced MCP Python Server Bootstrap (Bash) v$SCRIPT_VERSION

This script will install uvx (if needed) and run a Python MCP server.

USAGE: $0 <package-spec> [server-args...]

EXAMPLES:
    $0 mcp-server-filesystem
    $0 mcp-server-database==1.2.0 --config config.json

ENVIRONMENT VARIABLES:
    MCP_BOOTSTRAP_CACHE_DIR      Cache directory (default: ~/.mcp/cache)
    MCP_BOOTSTRAP_BOOTSTRAP_DIR  Bootstrap data directory (default: ~/.mcp/bootstrap)

EOF
        exit 0
        ;;
    --version|-v)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
esac

# Run main function
main "$@"