#!/bin/bash
# Enhanced Bash MCP Python Server Bootstrap
# Supports Linux, macOS, FreeBSD, WSL
# Version: 1.3.6

set -euo pipefail

SCRIPT_VERSION="1.3.6"

# Store original arguments for later processing
ORIGINAL_ARGS=("$@")

# Parse arguments to handle --from syntax (initial parsing)
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
    # Auto-detection will happen later in init_arguments() after functions are defined
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

# Detect existing uvx or install in isolated environment
# Sets global UVX_PATH variable to absolute path of uvx
detect_or_install_uvx() {
    log "Detecting or installing uvx (intelligent preference approach)..."

    # Phase 1: Try to detect existing uvx installation (prefer user installation)
    # Check both PATH and common installation locations
    local uvx_candidates=(
        "$(command -v uvx 2>/dev/null)"
        "$HOME/.local/bin/uvx"
        "$HOME/.cargo/bin/uvx"
        "/usr/local/bin/uvx"
        "/opt/homebrew/bin/uvx"
    )

    for candidate in "${uvx_candidates[@]}"; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            UVX_PATH="$candidate"
            local version
            if version=$("$UVX_PATH" --version 2>/dev/null); then
                log "Found existing uvx at: $UVX_PATH"
                log "Version: $version"

                # Test if this uvx can actually run our test package to avoid environment issues
                log "Testing existing uvx compatibility..."
                if "$UVX_PATH" --help >/dev/null 2>&1; then
                    log "Existing uvx is compatible, using user installation (preferred for environment compatibility)"
                    return 0
                else
                    warn "uvx at $UVX_PATH failed compatibility test, trying next candidate..."
                fi
            else
                log "uvx found at $UVX_PATH but version check failed, trying next candidate..."
            fi
        fi
    done

    log "No compatible uvx found in common locations"

    # Phase 2: Check if uv is available and use it instead of isolated installation
    if command -v uv >/dev/null 2>&1; then
        local uv_version
        if uv_version=$(uv --version 2>/dev/null); then
            log "Found existing uv installation: $uv_version"
            log "Using existing uv ecosystem instead of isolated installation (better environment compatibility)"

            # Set UVX_PATH to use the system uv with explicit tool execution
            UVX_PATH="$(command -v uv)"
            return 0
        fi
    fi

    # Phase 3: No working uvx/uv found, install in isolated environment as last resort
    log "No compatible uvx/uv found, installing in isolated environment..."
    log "Note: Isolated installations may have environment compatibility issues"

    # Create isolated installation directory
    local isolated_dir="/tmp/mcp-bootstrap-$$"
    mkdir -p "$isolated_dir"

    # Set up isolated installation environment
    export UV_INSTALL_DIR="$isolated_dir"
    export UV_CACHE_DIR="$isolated_dir/cache"
    export UV_NO_MODIFY_PATH=1

    local max_attempts=3
    local attempt=1
    local platform
    platform=$(detect_platform)

    log "Installing uv in isolated mode for platform: $platform"
    log "Installation directory: $isolated_dir"

    while [[ $attempt -le $max_attempts ]]; do
        log "Installation attempt $attempt/$max_attempts"

        # Download and run installer with isolated settings
        if command_exists curl; then
            if curl -LsSf https://astral.sh/uv/install.sh | \
               UV_INSTALL_DIR="$isolated_dir" sh -s -- --no-modify-path >&2; then
                break
            fi
        elif command_exists wget; then
            if wget -qO- https://astral.sh/uv/install.sh | \
               UV_INSTALL_DIR="$isolated_dir" sh -s -- --no-modify-path >&2; then
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

    # Set UVX_PATH to isolated installation - try different possible locations
    # 1. Direct installation directory (when using UV_INSTALL_DIR)
    UVX_PATH="$isolated_dir/uvx"

    # Verify isolated installation
    if [[ ! -x "$UVX_PATH" ]]; then
        # 2. Try bin subdirectory
        UVX_PATH="$isolated_dir/bin/uvx"
        if [[ ! -x "$UVX_PATH" ]]; then
            # 3. Try .local/bin subdirectory
            UVX_PATH="$isolated_dir/.local/bin/uvx"
            if [[ ! -x "$UVX_PATH" ]]; then
                # Debug: list what's actually in the directory
                log "Contents of $isolated_dir:"
                ls -la "$isolated_dir" 2>/dev/null || true
                error "uvx not found in isolated installation at $isolated_dir"
            fi
        fi
    fi

    # Test that isolated uvx works
    if ! "$UVX_PATH" --version >/dev/null 2>&1; then
        error "Isolated uvx at $UVX_PATH not working properly"
    fi

    local version
    version=$("$UVX_PATH" --version 2>/dev/null)
    success "uvx installed and verified in isolated environment: $UVX_PATH"
    log "Version: $version"

    return 0
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

# Auto-detect executable name for git packages
detect_executable_name() {
    local package_spec="$1"
    local package_type=$(detect_package_type "$package_spec")

    if [[ "$package_type" == "git" ]]; then
        # Extract repository name from git URL
        local repo_name
        if [[ "$package_spec" =~ git\+https?://[^/]+/[^/]+/([^/]+)(\.git)?$ ]]; then
            repo_name="${BASH_REMATCH[1]}"

            # Remove .git suffix if present
            repo_name="${repo_name%.git}"

            # Common patterns for test MCP servers
            # Pattern: test-mcp-server-ap25092201 -> test-mcp-server
            if [[ "$repo_name" =~ ^(.+)-[a-z]{2}[0-9]{8}$ ]]; then
                echo "${BASH_REMATCH[1]}"
                return 0
            fi

            # Pattern: mcp-server-something -> mcp-server-something (keep as is)
            if [[ "$repo_name" =~ ^mcp-server-.+ ]]; then
                echo "$repo_name"
                return 0
            fi

            # For other git packages, assume executable matches repo name
            echo "$repo_name"
            return 0
        fi
    fi

    # For PyPI packages, assume executable matches package name
    if [[ "$package_type" == "pypi" ]]; then
        # Remove version constraints
        local package_name=$(echo "$package_spec" | sed -E 's/([a-zA-Z0-9_-]+).*/\1/')
        echo "$package_name"
        return 0
    fi

    # Default: no executable name detected
    return 1
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

# Initialize arguments with auto-detection (called after functions are defined)
init_arguments() {
    # If we didn't use --from syntax initially, try auto-detection
    if [[ "$USE_FROM_SYNTAX" == "false" && -n "$PACKAGE_SPEC" ]]; then
        local detected_executable=""
        if detected_executable=$(detect_executable_name "$PACKAGE_SPEC"); then
            # Extract package name from git URL for comparison
            local package_name="$PACKAGE_SPEC"
            if [[ "$PACKAGE_SPEC" == git+* ]]; then
                # Extract repo name from git URL
                if [[ "$PACKAGE_SPEC" =~ git\+https?://[^/]+/[^/]+/([^/]+)(\.git)?$ ]]; then
                    package_name="${BASH_REMATCH[1]}"
                    # Remove .git suffix if present
                    package_name="${package_name%.git}"
                fi
            fi

            # If detected executable differs from package name, use --from syntax
            if [[ "$detected_executable" != "$package_name" ]]; then
                log "Auto-detected executable name mismatch - using --from syntax"
                log "Package: $package_name, Executable: $detected_executable"
                EXECUTABLE_NAME="$detected_executable"
                USE_FROM_SYNTAX=true
            fi
        fi
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

# Clean environment for MCP server execution

# Direct server execution for MCP servers (no monitoring)
run_server_direct() {
    log "Starting MCP server (direct execution): $PACKAGE_SPEC"

    # Set UV cache directory
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
        # For PyPI/git packages, use uvx with detected/installed path

        # Debug environment
        log "=== MCP Server Execution Debug Info ==="
        log "Working directory: $(pwd)"
        log "UVX_PATH: $UVX_PATH"
        log "UV_CACHE_DIR: ${UV_CACHE_DIR:-not set}"
        log "User: $(whoami)"
        log "Package: $PACKAGE_SPEC"
        log "Arguments: ${SCRIPT_ARGS[*]-}"
        log "Use from syntax: $USE_FROM_SYNTAX"

        # Create completely isolated execution for MCP
        log "Creating isolated execution environment..."

        # Create a wrapper script for completely clean execution with dynamic uvx path
        cat > /tmp/mcp_wrapper_$$.sh << EOF
#!/bin/bash
# Complete isolation wrapper for MCP server

# Use the dynamically detected/installed uvx path
UVX_BINARY="$UVX_PATH"

# Enhanced environment setup for MCP server compatibility
export UV_CACHE_DIR="${UV_CACHE_DIR}"
export UV_NO_MODIFY_PATH=1

# Inherit critical environment variables for FastMCP servers
export HOME="${HOME:-/Users/\$(whoami)}"
export USER="\${USER:-\$(whoami)}"
export LOGNAME="\${LOGNAME:-\$(whoami)}"
export SHELL="\${SHELL:-/bin/bash}"

# Python environment variables
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONIOENCODING="utf-8"

# FastMCP-specific debugging and asyncio flags
export PYTHONDEBUG=1
export PYTHONASYNCIODEBUG=1
export PYTHONDEVMODE=1
export PYTHON_TRACEMALLOC=1

# FastMCP logging configuration
export FASTMCP_DEBUG=1
export FASTMCP_LOG_LEVEL="DEBUG"
export MCP_LOG_LEVEL="DEBUG"

# Path inheritance for tool access
export PATH="\${PATH:-/usr/local/bin:/usr/bin:/bin}"

# macOS-specific environment for GUI app compatibility
export TMPDIR="\${TMPDIR:-/tmp}"
export LANG="\${LANG:-en_US.UTF-8}"
export LC_ALL="\${LC_ALL:-en_US.UTF-8}"

# Use user's home directory (critical for FastMCP file access)
cd "\$HOME" || cd /tmp

# Clear signal handlers
trap - EXIT INT TERM HUP QUIT

# Debug environment inheritance
echo "[Wrapper] Environment setup complete" >&2
echo "[Wrapper] HOME=\$HOME" >&2
echo "[Wrapper] USER=\$USER" >&2
echo "[Wrapper] Working directory: \$(pwd)" >&2

# Debug FastMCP-specific environment
echo "[Wrapper] FastMCP debugging enabled:" >&2
echo "[Wrapper] PYTHONDEBUG=\$PYTHONDEBUG" >&2
echo "[Wrapper] PYTHONASYNCIODEBUG=\$PYTHONASYNCIODEBUG" >&2
echo "[Wrapper] PYTHONDEVMODE=\$PYTHONDEVMODE" >&2
echo "[Wrapper] FASTMCP_DEBUG=\$FASTMCP_DEBUG" >&2

# Add debugging to wrapper - redirect to both stderr and a log file
echo "[Wrapper] Starting uvx with args: \$*" | tee -a /tmp/mcp_wrapper.log >&2
echo "[Wrapper] UVX_BINARY: \$UVX_BINARY" | tee -a /tmp/mcp_wrapper.log >&2
echo "[Wrapper] UV_CACHE_DIR: \$UV_CACHE_DIR" | tee -a /tmp/mcp_wrapper.log >&2

# Test if uvx command exists at detected/installed location
if ! test -x "\$UVX_BINARY"; then
    echo "[Wrapper] ERROR: uvx not found at \$UVX_BINARY" | tee -a /tmp/mcp_wrapper.log >&2
    exit 127
fi

# Skip version check to minimize interference

# Debug: Show the exact command that will be executed
echo "[Wrapper] About to execute: \$UVX_BINARY \$*" >&2

# Execute uvx directly to preserve stdio for MCP communication
exec "\$UVX_BINARY" "\$@"
EOF

        chmod +x /tmp/mcp_wrapper_$$.sh

        # Clear any previous wrapper log
        rm -f /tmp/mcp_wrapper.log

        if [[ "$USE_FROM_SYNTAX" == "true" ]]; then
            # Clear uvx cache for this package to ensure latest version
            log "Clearing uvx cache for package to ensure latest version..."
            "$UVX_PATH" cache clean "$PACKAGE_SPEC" 2>/dev/null || true

            log "Final command: /tmp/mcp_wrapper_$$.sh --from $PACKAGE_SPEC $EXECUTABLE_NAME ${SCRIPT_ARGS[*]-}"

            # Execute wrapper with clean exec for MCP
            exec /tmp/mcp_wrapper_$$.sh --from "$PACKAGE_SPEC" "$EXECUTABLE_NAME" "${SCRIPT_ARGS[@]:-}"
        else
            # Clear uvx cache for this package to ensure latest version
            log "Clearing uvx cache for package to ensure latest version..."
            "$UVX_PATH" cache clean "$PACKAGE_SPEC" 2>/dev/null || true

            log "Final command: /tmp/mcp_wrapper_$$.sh $PACKAGE_SPEC ${SCRIPT_ARGS[*]-}"

            # Execute wrapper with clean exec for MCP
            exec /tmp/mcp_wrapper_$$.sh "$PACKAGE_SPEC" "${SCRIPT_ARGS[@]:-}"
        fi
    fi
}

# Enhanced server execution with monitoring
run_server_monitored() {
    log "Starting monitored MCP server: $PACKAGE_SPEC"

    # Set UV cache directory
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

    # Initialize arguments with auto-detection
    init_arguments

    # Validate inputs
    validate_package_spec

    # Check environment freshness
    check_environment_freshness

    # Check network connectivity
    if ! check_network; then
        warn "Network issues detected, but continuing anyway"
    fi

    # Detect existing uvx or install in isolated environment
    detect_or_install_uvx

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