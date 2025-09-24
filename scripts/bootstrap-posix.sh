#!/bin/sh
# POSIX-compliant MCP Python Server Bootstrap
# Supports Alpine Linux and minimal environments
# Version: 1.2.0

set -eu

SCRIPT_VERSION="1.2.0"

# Parse arguments to handle --from syntax (POSIX-compliant)
if [ "${1:-}" = "--from" ] && [ $# -ge 3 ]; then
    # --from package_name executable_name [additional_args...]
    PACKAGE_SPEC="$2"
    EXECUTABLE_NAME="$3"
    shift 3
    USE_FROM_SYNTAX="true"
else
    # Regular syntax: package_name [args...]
    PACKAGE_SPEC="${1:-}"
    EXECUTABLE_NAME=""
    shift 1
    USE_FROM_SYNTAX="false"
fi

# Store remaining arguments
SCRIPT_ARGS="$*"

# Configuration
CACHE_DIR="${MCP_BOOTSTRAP_CACHE_DIR:-$HOME/.mcp/cache}"
BOOTSTRAP_DIR="${MCP_BOOTSTRAP_BOOTSTRAP_DIR:-$HOME/.mcp/bootstrap}"
LOG_FILE="$BOOTSTRAP_DIR/bootstrap.log"

# Logging functions (POSIX-compliant)
log() {
    printf "[MCP-Python] %s\n" "$1" >&2
    printf "%s - [INFO] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    printf "[MCP-Python WARN] %s\n" "$1" >&2
    printf "%s - [WARN] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    printf "[MCP-Python ERROR] %s\n" "$1" >&2
    printf "%s - [ERROR] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
}

success() {
    printf "[MCP-Python] %s\n" "$1" >&2
    printf "%s - [SUCCESS] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

# Initialize environment
init_environment() {
    # Create directories (POSIX-compliant way)
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
    fi
    if [ ! -d "$BOOTSTRAP_DIR" ]; then
        mkdir -p "$BOOTSTRAP_DIR" 2>/dev/null || true
    fi

    log "POSIX bootstrap environment initialized"
}

# Check if command exists (POSIX way)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Standardized UV PATH setup (POSIX-compliant)
setup_uv_path() {
    # Only add to PATH if not already present
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:$PATH" ;;
    esac

    case ":$PATH:" in
        *":$HOME/.cargo/bin:"*) ;;
        *) PATH="$HOME/.cargo/bin:$PATH" ;;
    esac

    export PATH
    log "UV PATH configured: ~/.local/bin and ~/.cargo/bin added to PATH"
}

# Platform detection (POSIX-compliant)
detect_platform() {
    # Simple platform detection
    if command_exists uname; then
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

# Check for uvx
check_uvx() {
    if command_exists uvx; then
        if uvx --version >/dev/null 2>&1; then
            log "uvx found and working"
            return 0
        fi
    fi
    log "uvx not found or not working"
    return 1
}

# Check for uv
check_uv() {
    if command_exists uv; then
        if uv --version >/dev/null 2>&1; then
            log "uv found and working"
            return 0
        fi
    fi
    log "uv not found or not working"
    return 1
}

# Install uv (POSIX-compliant)
install_uv() {
    log "Installing uv (POSIX mode)..."

    if command_exists curl; then
        curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path
    elif command_exists wget; then
        wget -qO- https://astral.sh/uv/install.sh | sh -s -- --no-modify-path
    else
        error "Neither curl nor wget available"
    fi

    # Add to PATH
    setup_uv_path

    # Verify installation
    if ! command_exists uv; then
        error "uv installation failed"
    fi

    if ! uv --version >/dev/null 2>&1; then
        error "uv installed but not working"
    fi

    success "uv installed successfully"
}

# Detect package type (POSIX-compliant)
detect_package_type() {
    case "$1" in
        git+*) echo "git" ;;
        https://github.com/*|http://github.com/*|https://raw.githubusercontent.com/*|https://gitlab.com/*|https://bitbucket.org/*) echo "github_raw" ;;
        /*|./*|../*) echo "local" ;;
        -e*) echo "editable" ;;
        *) echo "pypi" ;;
    esac
}

# Validate package spec (POSIX-compliant)
validate_package_spec() {
    if [ -z "$PACKAGE_SPEC" ]; then
        error "Package specification is required"
    fi

    log "Package specification: $PACKAGE_SPEC"

    # Detect and log package type
    package_type=$(detect_package_type "$PACKAGE_SPEC")
    log "Package type detected: $package_type"

    # Basic validation
    case "$PACKAGE_SPEC" in
        "") error "Empty package specification" ;;
        *" "*) warn "Package spec contains spaces" ;;
    esac
}

# Run server (POSIX-compliant)
run_server() {
    log "Starting MCP server: $PACKAGE_SPEC"

    # Ensure PATH
    setup_uv_path

    # Detect package type and execute accordingly
    package_type=$(detect_package_type "$PACKAGE_SPEC")

    if [ "$package_type" = "github_raw" ]; then
        # For GitHub raw URLs, download and execute
        log "Downloading GitHub raw URL for execution"
        temp_file="/tmp/mcp_server_$$.py"

        if command -v curl >/dev/null 2>&1; then
            if curl -sSfL "$PACKAGE_SPEC" -o "$temp_file"; then
                log "Downloaded $PACKAGE_SPEC to $temp_file"
                log "Executing: python3 $temp_file $*"
                exec python3 "$temp_file" "$@"
            else
                error "Failed to download $PACKAGE_SPEC"
            fi
        else
            error "curl is required to download GitHub raw URLs"
        fi
    else
        # For PyPI/git packages, use uvx
        if [ "$USE_FROM_SYNTAX" = "true" ]; then
            # Use --from syntax: uvx --from package_name executable_name [args...]
            log "Executing: uvx --from $PACKAGE_SPEC $EXECUTABLE_NAME $SCRIPT_ARGS"
            exec uvx --from "$PACKAGE_SPEC" "$EXECUTABLE_NAME" $SCRIPT_ARGS
        else
            # Regular uvx syntax
            log "Executing: uvx $PACKAGE_SPEC $SCRIPT_ARGS"
            exec uvx "$PACKAGE_SPEC" $SCRIPT_ARGS
        fi
    fi
}

# Main function
main() {
    log "POSIX MCP Python Server Bootstrap v$SCRIPT_VERSION"
    log "Platform: $(detect_platform)"

    init_environment
    validate_package_spec

    # Ensure uvx is available
    if ! check_uvx; then
        if ! check_uv; then
            install_uv
        else
            log "uv found, setting up PATH for uvx"
            setup_uv_path
        fi

        # Final verification after installation/setup
        if ! check_uvx; then
            error "uvx still not available after installation process"
        fi
        success "uvx installation verified successfully"
    fi

    # Run the server (shift to remove package spec, pass remaining args)
    shift
    run_server "$@"
}

# Handle help
case "${1:-}" in
    --help|-h|help)
        cat << EOF
POSIX MCP Python Server Bootstrap v$SCRIPT_VERSION

USAGE: $0 <package-spec> [server-args...]

This is the POSIX-compliant version for minimal environments.

EXAMPLES:
    $0 mcp-server-filesystem
    $0 mcp-server-database==1.2.0

EOF
        exit 0
        ;;
    --version|-v)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
esac

# Run main
main "$@"