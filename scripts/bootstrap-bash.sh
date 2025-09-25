#!/bin/bash
# Enhanced Bash MCP Python Server Bootstrap
# Supports Linux, macOS, FreeBSD, WSL
# Version: 1.2.2

set -euo pipefail

SCRIPT_VERSION="1.2.2"

# Parse arguments to handle --from syntax
if [[ "${1:-}" == "--from" ]] && [[ $# -ge 3 ]]; then
    # --from package_name executable_name [additional_args...]
    PACKAGE_SPEC="$2"
    EXECUTABLE_NAME="$3"
    SCRIPT_ARGS=("${@:4}")
    USE_FROM_SYNTAX=true
else
    # Regular syntax: package_name [args...]
    PACKAGE_SPEC="${1:-}"
    EXECUTABLE_NAME=""
    SCRIPT_ARGS=("${@:2}")
    USE_FROM_SYNTAX=false
fi

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

# Standardized UV PATH setup
setup_uv_path() {
    local uv_dirs="$HOME/.local/bin:$HOME/.cargo/bin"

    # Only add to PATH if not already present
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac

    case ":$PATH:" in
        *":$HOME/.cargo/bin:"*) ;;
        *) export PATH="$HOME/.cargo/bin:$PATH" ;;
    esac

    log "UV PATH configured: ~/.local/bin and ~/.cargo/bin added to PATH"
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
            if curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path >&2; then
                break
            fi
        elif command_exists wget; then
            if wget -qO- https://astral.sh/uv/install.sh | sh -s -- --no-modify-path >&2; then
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
    setup_uv_path

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

# Detect package type
detect_package_type() {
    local package_spec="$1"

    if [[ "$package_spec" == git+* ]]; then
        echo "git"
    elif [[ "$package_spec" == https://github.com/* ]] || [[ "$package_spec" == http://github.com/* ]] || [[ "$package_spec" == https://raw.githubusercontent.com/* ]] || [[ "$package_spec" == https://gitlab.com/* ]] || [[ "$package_spec" == https://bitbucket.org/* ]]; then
        echo "github_raw"
    elif [[ "$package_spec" == /* ]] || [[ "$package_spec" == ./* ]] || [[ "$package_spec" == ../* ]] || [[ "$package_spec" == */*.py ]] || [[ "$package_spec" == *.py ]]; then
        echo "local"
    elif [[ "$package_spec" == -e* ]]; then
        echo "editable"
    else
        echo "pypi"
    fi
}

# Validate git URL package
validate_git_package() {
    local package_spec="$1"

    # Basic git URL validation
    if [[ "$package_spec" =~ ^git\+https?://[a-zA-Z0-9.-]+/[a-zA-Z0-9._/-]+\.git ]]; then
        log "Git URL format appears valid"
        return 0
    else
        warn "Git URL format may be invalid: $package_spec"
        return 1
    fi
}

# Validate local path package
validate_local_package() {
    local package_spec="$1"
    local path="$package_spec"

    # Remove -e prefix for editable installs
    if [[ "$package_spec" == -e* ]]; then
        path="${package_spec#-e}"
        path="${path#[[:space:]]}"
    fi

    if [[ -d "$path" ]] || [[ -f "$path" ]]; then
        log "Local path exists: $path"
        return 0
    else
        warn "Local path does not exist: $path"
        return 1
    fi
}

# Verify PyPI package exists
verify_pypi_package() {
    local package_spec="$1"
    local package_name

    # Extract package name (remove version specifiers and extras)
    package_name=$(echo "$package_spec" | sed -E 's/([a-zA-Z0-9_-]+).*/\1/')

    log "Verifying PyPI package exists: $package_name"

    # Try with curl first (lighter weight)
    if command_exists curl; then
        local status_code
        status_code=$(curl -s -o /dev/null -w "%{http_code}" "https://pypi.org/pypi/$package_name/json" --connect-timeout 5)
        if [[ "$status_code" == "200" ]]; then
            log "Package found on PyPI: $package_name"
            return 0
        elif [[ "$status_code" == "404" ]]; then
            warn "Package not found on PyPI: $package_name"
            return 1
        else
            warn "Could not verify package on PyPI (HTTP $status_code)"
            return 0  # Don't fail on network issues
        fi
    fi

    # Fallback to Python if available
    if command_exists python3; then
        if python3 -c "
import urllib.request
import json
import sys

package_name = sys.argv[1]
url = f'https://pypi.org/pypi/{package_name}/json'

try:
    with urllib.request.urlopen(url, timeout=10) as response:
        if response.status == 200:
            data = json.loads(response.read())
            print(f'Package found: {data[\"info\"][\"name\"]} {data[\"info\"][\"version\"]}')
        else:
            sys.exit(1)
except Exception:
    sys.exit(1)
" "$package_name" 2>/dev/null; then
            log "Package verification successful"
            return 0
        else
            warn "Could not verify package on PyPI (may still work)"
            return 0  # Don't fail on verification issues
        fi
    else
        log "Cannot verify PyPI package - no curl or python3 available"
        return 0  # Don't fail if we can't verify
    fi
}

# Enhanced package verification
verify_package_exists() {
    local package_spec="$1"
    local package_type

    package_type=$(detect_package_type "$package_spec")
    log "Package type detected: $package_type"

    case "$package_type" in
        git)
            validate_git_package "$package_spec"
            ;;
        github_raw)
            log "GitHub raw URL detected, proceeding with download"
            return 0
            ;;
        local|editable)
            validate_local_package "$package_spec"
            ;;
        pypi)
            verify_pypi_package "$package_spec"
            ;;
        *)
            warn "Unknown package type, proceeding anyway"
            return 0
            ;;
    esac
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

# Clean environment for MCP server execution
setup_clean_mcp_environment() {
    # Preserve essential PATH components and UV installation
    local essential_paths="/usr/local/bin:/usr/bin:/bin"
    local uv_paths="${HOME}/.local/bin:${HOME}/.cargo/bin"
    export PATH="${uv_paths}:${essential_paths}"

    # Clean environment variables that might interfere
    unset STARTUP_MARKER 2>/dev/null || true
    unset BOOTSTRAP_* 2>/dev/null || true
    unset MCP_BOOTSTRAP_* 2>/dev/null || true

    # Set up clean temporary directory
    export TMPDIR="/tmp"

    # Ensure clean working directory
    cd /tmp || cd "$HOME" || true

    # Set up UV environment properly
    export UV_CACHE_DIR="${UV_CACHE_DIR:-${HOME}/.cache/uv}"
    export UV_NO_MODIFY_PATH=1

    log "Environment cleaned for MCP server execution"
}

# Direct server execution for MCP servers (no monitoring)
run_server_direct() {
    log "Starting MCP server (direct execution): $PACKAGE_SPEC"

    # Ensure PATH includes uv
    setup_uv_path
    export UV_CACHE_DIR="$UV_CACHE_DIR"

    # Direct execution without monitoring - essential for MCP stdio communication
    local package_type
    package_type=$(detect_package_type "$PACKAGE_SPEC")

    if [[ "$package_type" == "github_raw" ]]; then
        # For GitHub raw URLs, download and execute directly with Python
        local temp_file="/tmp/mcp_server_$$.py"
        if command_exists curl; then
            if curl -sSfL "$PACKAGE_SPEC" -o "$temp_file"; then
                log "Downloaded $PACKAGE_SPEC, executing directly"
                exec python3 "$temp_file" $SCRIPT_ARGS
            else
                error "Failed to download $PACKAGE_SPEC"
            fi
        else
            error "curl is required to download GitHub raw URLs"
        fi
    else
        # For PyPI/git packages, use uvx with direct exec

        # Clean environment for MCP server execution
        setup_clean_mcp_environment

        # Debug environment after cleaning
        log "=== MCP Server Execution Debug Info ==="
        log "Working directory: $(pwd)"
        log "PATH: $PATH"
        log "UV_CACHE_DIR: ${UV_CACHE_DIR:-not set}"
        log "TMPDIR: ${TMPDIR:-not set}"
        log "User: $(whoami)"
        log "Environment variables with BOOTSTRAP/MCP: $(env | grep -i 'bootstrap\|mcp' || echo 'none found')"

        # Create completely isolated execution for MCP
        log "Creating isolated execution environment..."

        # Create a wrapper script for completely clean execution
        cat > /tmp/mcp_wrapper_$$.sh << 'EOF'
#!/bin/bash
# Complete isolation wrapper for MCP server

# Clean environment
export PATH="/Users/antonio/.local/bin:/Users/antonio/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
export UV_CACHE_DIR="/Users/antonio/.mcp/cache/uv"
export UV_NO_MODIFY_PATH=1
export TMPDIR="/tmp"
cd /tmp

# Clear all signal handlers
trap - EXIT INT TERM HUP

# Execute with clean process group
exec uvx "$@"
EOF

        chmod +x /tmp/mcp_wrapper_$$.sh

        if [[ "$USE_FROM_SYNTAX" == "true" ]]; then
            log "Final command: /tmp/mcp_wrapper_$$.sh --from $PACKAGE_SPEC $EXECUTABLE_NAME ${SCRIPT_ARGS[*]-}"
            exec /tmp/mcp_wrapper_$$.sh --from "$PACKAGE_SPEC" "$EXECUTABLE_NAME" "${SCRIPT_ARGS[@]:-}"
        else
            log "Final command: /tmp/mcp_wrapper_$$.sh $PACKAGE_SPEC ${SCRIPT_ARGS[*]-}"
            exec /tmp/mcp_wrapper_$$.sh "$PACKAGE_SPEC" "${SCRIPT_ARGS[@]:-}"
        fi
    fi
}

# Enhanced server execution with monitoring
run_server_monitored() {
    log "Starting monitored MCP server: $PACKAGE_SPEC"

    # Ensure PATH includes uv
    setup_uv_path
    export UV_CACHE_DIR="$UV_CACHE_DIR"

    # Create startup marker
    STARTUP_MARKER="$BOOTSTRAP_DIR/server_startup_$$"
    echo "$(date +%s)" > "$STARTUP_MARKER"

    # Cleanup function
    cleanup() {
        rm -f "$STARTUP_MARKER" 2>/dev/null || true
        log "Server cleanup completed"
    }
    trap cleanup EXIT INT TERM

    # Start the server with timeout monitoring
    (
        sleep 30
        if [[ -f "$STARTUP_MARKER" ]]; then
            warn "Server startup taking longer than expected (30s)"
        fi
    ) &
    local monitor_pid=$!

    # Execute the server based on package type
    local package_type
    package_type=$(detect_package_type "$PACKAGE_SPEC")

    if [[ "$package_type" == "github_raw" ]]; then
        # For GitHub raw URLs, download and execute directly with Python
        log "Downloading GitHub raw URL for direct execution"
        local temp_file="/tmp/mcp_server_$$.py"

        if command_exists curl; then
            if curl -sSfL "$PACKAGE_SPEC" -o "$temp_file"; then
                log "Downloaded $PACKAGE_SPEC to $temp_file"
            else
                error "Failed to download $PACKAGE_SPEC"
            fi
        else
            error "curl is required to download GitHub raw URLs"
        fi

        # Execute directly with Python
        log "Executing: python3 $temp_file ${SCRIPT_ARGS[*]-}"
        if python3 "$temp_file" "${SCRIPT_ARGS[@]:-}"; then
            success "Server exited normally"
        else
            local exit_code=$?
            error "Server exited with code $exit_code"
        fi

        # Cleanup
        rm -f "$temp_file"
    elif [[ "$package_type" == "local" ]]; then
        # For local Python files, execute directly
        log "Executing local Python file: python3 $PACKAGE_SPEC ${SCRIPT_ARGS[*]-}"
        if python3 "$PACKAGE_SPEC" "${SCRIPT_ARGS[@]:-}"; then
            success "Server exited normally"
        else
            local exit_code=$?
            error "Server exited with code $exit_code"
        fi
    else
        # For PyPI/git packages, use uvx
        if [[ "$USE_FROM_SYNTAX" == "true" ]]; then
            # Use --from syntax: uvx --from package_name executable_name [args...]
            log "Executing: uvx --from $PACKAGE_SPEC $EXECUTABLE_NAME ${SCRIPT_ARGS[*]-}"
            if uvx --from "$PACKAGE_SPEC" "$EXECUTABLE_NAME" "${SCRIPT_ARGS[@]:-}"; then
                success "Server exited normally"
            else
                local exit_code=$?
                error "Server exited with code $exit_code"
            fi
        else
            # Regular uvx syntax
            log "Executing: uvx $PACKAGE_SPEC ${SCRIPT_ARGS[*]-}"
            if uvx "$PACKAGE_SPEC" "${SCRIPT_ARGS[@]:-}"; then
                success "Server exited normally"
            else
                local exit_code=$?
                error "Server exited with code $exit_code"
            fi
        fi
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
            setup_uv_path
            if ! check_uvx; then
                error "uv found but uvx not working"
            fi
        fi

        # Final verification that uvx is available after installation
        if ! check_uvx; then
            error "uvx still not available after installation process"
        fi
        success "uvx installation verified successfully"
    fi

    # Run the server (use direct execution for clean MCP stdio communication)
    run_server_direct
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