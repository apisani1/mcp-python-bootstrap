#!/bin/sh
# POSIX-compliant MCP Python Server Bootstrap
# Supports Alpine Linux and minimal environments
# Version: 1.3.6

set -eu

SCRIPT_VERSION="1.3.6"

# Handle help and version first
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

# Convert git+ URL to GitHub archive URL (avoids git dependency)
convert_git_to_archive_url_posix() {
    git_url="$1"

    # Extract components from git+https://github.com/user/repo.git format
    # Using POSIX-compliant sed expressions
    if echo "$git_url" | grep -q "^git+https://github\.com/"; then
        # Extract user/repo from the URL
        user_repo=$(echo "$git_url" | sed -E 's|git\+https://github\.com/([^/]+/[^/]+)(\.git)?(#.*)?$|\1|')
        user=$(echo "$user_repo" | cut -d'/' -f1)
        repo=$(echo "$user_repo" | cut -d'/' -f2)

        # Extract ref if present, default to main
        ref="main"
        if echo "$git_url" | grep -q "#"; then
            ref=$(echo "$git_url" | sed -E 's|.*#(.+)$|\1|')
        fi

        # Remove .git suffix from repo name if present
        repo=$(echo "$repo" | sed 's/\.git$//')

        # Convert to GitHub archive URL
        archive_url="https://github.com/$user/$repo/archive/$ref.zip"
        printf "[MCP-Python] Converting git+ URL to archive URL (no git required): %s\n" "$archive_url" >&2
        echo "$archive_url"
        return 0
    fi

    # If conversion fails, return original
    printf "[MCP-Python WARN] Could not convert git URL to archive format: %s\n" "$git_url" >&2
    echo "$git_url"
    return 1
}

# Auto-detect executable name for git packages (POSIX-compliant)
detect_executable_name_posix() {
    package_spec="$1"

    # Check if it's a git package
    case "$package_spec" in
        git+*)
            # Extract repository name from git URL
            repo_name=$(echo "$package_spec" | sed -E 's|git\+https?://[^/]+/[^/]+/([^/]+)(\.git)?.*|\1|')

            # Pattern: test-mcp-server-ap25092201 -> test-mcp-server
            case "$repo_name" in
                *-[a-z][a-z][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
                    # Remove the suffix pattern
                    echo "$repo_name" | sed -E 's/-[a-z][a-z][0-9]{8}$//'
                    return 0
                    ;;
                mcp-server-*)
                    # Keep MCP server names as-is
                    echo "$repo_name"
                    return 0
                    ;;
                *)
                    # Default: use repo name
                    echo "$repo_name"
                    return 0
                    ;;
            esac
            ;;
        *)
            # For PyPI packages, remove version constraints
            echo "$package_spec" | sed -E 's/([a-zA-Z0-9_-]+).*/\1/'
            return 0
            ;;
    esac

    return 1
}

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

    # Auto-detect if we need --from syntax for git packages
    if [ -n "$PACKAGE_SPEC" ]; then
        detected_executable=$(detect_executable_name_posix "$PACKAGE_SPEC")
        if [ $? -eq 0 ] && [ -n "$detected_executable" ]; then
            # Extract package name from git URL for comparison
            package_name="$PACKAGE_SPEC"
            case "$PACKAGE_SPEC" in
                git+*)
                    package_name=$(echo "$PACKAGE_SPEC" | sed -E 's|git\+https?://[^/]+/[^/]+/([^/]+)(\.git)?.*|\1|')
                    ;;
            esac

            # If detected executable differs from package name, use --from syntax
            if [ "$detected_executable" != "$package_name" ]; then
                printf "[MCP-Python] Auto-detected executable mismatch: package='%s', executable='%s'\n" "$package_name" "$detected_executable" >&2
                printf "[MCP-Python] Automatically using --from syntax to resolve executable name\n" >&2
                EXECUTABLE_NAME="$detected_executable"
                USE_FROM_SYNTAX="true"
            fi
        fi
    fi
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
    # Ensure log directory exists before writing
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    printf "%s - [INFO] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    printf "[MCP-Python WARN] %s\n" "$1" >&2
    # Ensure log directory exists before writing
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    printf "%s - [WARN] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    printf "[MCP-Python ERROR] %s\n" "$1" >&2
    # Ensure log directory exists before writing
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    printf "%s - [ERROR] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
}

success() {
    printf "[MCP-Python] %s\n" "$1" >&2
    # Ensure log directory exists before writing
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
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

# Detect existing uvx or install in isolated environment (POSIX-compliant)
# Sets global UVX_PATH variable to absolute path of uvx
detect_or_install_uvx() {
    log "Detecting or installing uvx (non-invasive approach)..."

    # Phase 1: Try to detect existing uvx installation
    if UVX_PATH=$(command -v uvx 2>/dev/null); then
        if "$UVX_PATH" --version >/dev/null 2>&1; then
            log "Found existing uvx at: $UVX_PATH"
            version=$("$UVX_PATH" --version 2>/dev/null || echo "unknown")
            log "Version: $version"
            return 0
        else
            log "uvx found at $UVX_PATH but not working properly"
        fi
    fi

    # Phase 2: No working uvx found, install in isolated environment
    log "No working uvx found, installing in isolated environment..."

    # Create isolated installation directory
    isolated_dir="/tmp/mcp-bootstrap-$$"
    mkdir -p "$isolated_dir" || error "Cannot create isolated directory"

    # Set up isolated installation environment
    UV_INSTALL_DIR="$isolated_dir"
    UV_CACHE_DIR="$isolated_dir/cache"
    UV_NO_MODIFY_PATH=1
    export UV_INSTALL_DIR UV_CACHE_DIR UV_NO_MODIFY_PATH

    max_attempts=3
    attempt=1
    platform=$(detect_platform)

    log "Installing uv in isolated mode for platform: $platform"
    log "Installation directory: $isolated_dir"

    while [ $attempt -le $max_attempts ]; do
        log "Installation attempt $attempt/$max_attempts"

        # Download and run installer with isolated settings
        if command_exists curl; then
            if UV_INSTALL_DIR="$isolated_dir" curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path >/dev/null 2>&1; then
                break
            fi
        elif command_exists wget; then
            if UV_INSTALL_DIR="$isolated_dir" wget -qO- https://astral.sh/uv/install.sh | sh -s -- --no-modify-path >/dev/null 2>&1; then
                break
            fi
        else
            error "Neither curl nor wget available for downloading uv installer"
        fi

        warn "Installation attempt $attempt failed"
        attempt=$(expr $attempt + 1)

        if [ $attempt -le $max_attempts ]; then
            log "Retrying in 5 seconds..."
            sleep 5
        fi
    done

    if [ $attempt -gt $max_attempts ]; then
        error "Failed to install uv after $max_attempts attempts"
    fi

    # Set UVX_PATH to isolated installation - try different possible locations
    # 1. Direct installation directory (when using UV_INSTALL_DIR)
    UVX_PATH="$isolated_dir/uvx"

    # Verify isolated installation
    if [ ! -x "$UVX_PATH" ]; then
        # 2. Try bin subdirectory
        UVX_PATH="$isolated_dir/bin/uvx"
        if [ ! -x "$UVX_PATH" ]; then
            # 3. Try .local/bin subdirectory
            UVX_PATH="$isolated_dir/.local/bin/uvx"
            if [ ! -x "$UVX_PATH" ]; then
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

    version=$("$UVX_PATH" --version 2>/dev/null || echo "unknown")
    success "uvx installed and verified in isolated environment: $UVX_PATH"
    log "Version: $version"

    return 0
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


    # Detect package type and execute accordingly
    package_type=$(detect_package_type "$PACKAGE_SPEC")

    if [ "$package_type" = "github_raw" ]; then
        # For GitHub raw URLs, download and execute
        log "Downloading GitHub raw URL for execution"
        temp_file="/tmp/mcp_server_$$.py"

        if command -v curl >/dev/null 2>&1; then
            if curl -sSfL "$PACKAGE_SPEC" -o "$temp_file"; then
                log "Downloaded $PACKAGE_SPEC to $temp_file"
                log "Executing: python3 $temp_file $SCRIPT_ARGS"
                exec python3 "$temp_file" $SCRIPT_ARGS
            else
                error "Failed to download $PACKAGE_SPEC"
            fi
        else
            error "curl is required to download GitHub raw URLs"
        fi
    elif [ "$package_type" = "git" ]; then
        # For git+ URLs, check if git is available AND working
        git_working=false
        if command -v git >/dev/null 2>&1; then
            # Git command exists, but test if it actually works
            if git --version >/dev/null 2>&1; then
                git_working=true
            fi
        fi

        if [ "$git_working" = "false" ]; then
            warn "git command not working - uvx requires git for git+ URLs"
            warn "Attempting to detect and trigger git installation..."

            # Detect OS and attempt to trigger git installation
            platform=$(uname -s)
            case "$platform" in
                Darwin)
                    # macOS - trigger Xcode Command Line Tools installation
                    warn "On macOS, git is part of Xcode Command Line Tools"
                    warn "Triggering installation dialog..."

                    # Trigger installation dialog and show notification
                    log "Triggering installation dialog and notification..."

                    # Try multiple methods to show the dialog, redirect all output to avoid JSON-RPC issues
                    (
                        # Method 1: Direct xcode-select (works from terminal)
                        xcode-select --install 2>&1 || true

                        # Method 2: Use osascript (works from background process)
                        if command -v osascript >/dev/null 2>&1; then
                            osascript -e 'do shell script "xcode-select --install"' 2>&1 || true
                        fi
                    ) >/dev/null 2>&1

                    # Show macOS dialog box so user definitely sees it
                    if command -v osascript >/dev/null 2>&1; then
                        # Use display dialog instead of notification - much more visible
                        server_name="${EXECUTABLE_NAME:-MCP Server}"
                        osascript -e "display dialog \"Git is required but not installed.\n\nFollow the instructions in the Xcode installation dialog box or, alternatively:\n\n1. Open Terminal\n2. Run: xcode-select --install\n3. Complete the installation\n4. Restart Claude Desktop\n\nThe installation may take several minutes.\" buttons {\"OK\"} default button \"OK\" with title \"MCP Server ${server_name}: Git Required\" with icon caution" >/dev/null 2>&1 &

                        # Also show notification as backup
                        osascript -e "display notification \"Please install git to use ${server_name}\" with title \"MCP Server ${server_name}: Git Required\" sound name \"default\"" >/dev/null 2>&1 || true
                    fi

                    # Wait briefly to let the dialog appear
                    sleep 1

                    # Check if git appeared quickly (user had CLT ready to install)
                    if command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1; then
                        success "git is now available!"
                        git_version=$(git --version 2>/dev/null || echo "unknown")
                        log "Git version: $git_version"
                    else
                        # Git not ready - fail fast with helpful message
                        error "git installation required but not yet complete.

The installation dialog should have appeared on your screen.
Please complete the git installation, then reconnect to Claude Desktop.

STEPS:
1. Look for the 'Install Command Line Developer Tools' dialog
2. Click 'Install' and wait for installation to complete (may take several minutes)
3. After installation completes, restart Claude Desktop
4. Reconnect to this MCP server

If the dialog didn't appear, open Terminal and run:
    xcode-select --install

For more help: https://github.com/apisani1/mcp-python-bootstrap#troubleshooting"
                    fi
                    ;;
                Linux)
                    # Linux - try to show dialog with zenity or kdialog if available
                    server_name="${EXECUTABLE_NAME:-MCP Server}"
                    dialog_shown=false

                    # Try zenity (GNOME/Ubuntu/Debian)
                    if command -v zenity >/dev/null 2>&1; then
                        zenity --warning \
                            --title="MCP Server ${server_name}: Git Required" \
                            --text="Git is required but not installed.\n\nGit installation cannot start automatically on Linux.\n\nTo install git, open Terminal and run:\n\nUbuntu/Debian:\n  sudo apt-get update && sudo apt-get install -y git\n\nCentOS/RHEL:\n  sudo yum install -y git\n\nFedora:\n  sudo dnf install -y git\n\nAlpine:\n  apk add git\n\nAfter installation, reconnect to the MCP server." \
                            --width=500 2>/dev/null &
                        dialog_shown=true
                    # Try kdialog (KDE)
                    elif command -v kdialog >/dev/null 2>&1; then
                        kdialog --title "MCP Server ${server_name}: Git Required" \
                            --sorry "Git is required but not installed.\n\nGit installation cannot start automatically on Linux.\n\nTo install git, open Terminal and run:\n\nUbuntu/Debian:\n  sudo apt-get update && sudo apt-get install -y git\n\nCentOS/RHEL:\n  sudo yum install -y git\n\nFedora:\n  sudo dnf install -y git\n\nAlpine:\n  apk add git\n\nAfter installation, reconnect to the MCP server." 2>/dev/null &
                        dialog_shown=true
                    fi

                    # Always show error in logs too
                    error "git command not found. Please install git:

Ubuntu/Debian:  sudo apt-get update && sudo apt-get install -y git
CentOS/RHEL:    sudo yum install -y git
Fedora:         sudo dnf install -y git
Alpine:         apk add git

Then retry the MCP server connection."
                    ;;
                *)
                    error "git command not found. Please install git for your platform, then retry."
                    ;;
            esac
        fi

        log "Using git+ URL directly for maximum compatibility"

        # Continue with uvx execution using the (possibly converted) package spec
        # For PyPI/git packages, use uvx with filtering wrapper
        log "Creating isolated execution environment..."

        # Create wrapper script for clean MCP execution
        cat > /tmp/mcp_wrapper_$$.sh << EOF
#!/bin/sh
# POSIX wrapper for MCP server execution

# Use detected/installed uvx path
UVX_BINARY="$UVX_PATH"

# Environment setup
export UV_CACHE_DIR="${UV_CACHE_DIR:-}"
export UV_NO_MODIFY_PATH=1
export PYTHONUNBUFFERED=1

# Debug logging
echo "[Wrapper] Starting uvx with args: \$*" >&2
echo "[Wrapper] UVX_BINARY: \$UVX_BINARY" >&2

# Test uvx availability
if ! test -x "\$UVX_BINARY"; then
    echo "[Wrapper] ERROR: uvx not found at \$UVX_BINARY" >&2
    exit 127
fi

# Execute uvx directly to preserve stdio for MCP communication
exec "\$UVX_BINARY" "\$@"
EOF

        chmod +x /tmp/mcp_wrapper_$$.sh

        if [ "$USE_FROM_SYNTAX" = "true" ]; then
            log "Final command: /tmp/mcp_wrapper_$$.sh --from $PACKAGE_SPEC $EXECUTABLE_NAME $SCRIPT_ARGS"
            exec /tmp/mcp_wrapper_$$.sh --from "$PACKAGE_SPEC" "$EXECUTABLE_NAME" $SCRIPT_ARGS
        else
            log "Final command: /tmp/mcp_wrapper_$$.sh $PACKAGE_SPEC $SCRIPT_ARGS"
            exec /tmp/mcp_wrapper_$$.sh "$PACKAGE_SPEC" $SCRIPT_ARGS
        fi
    else
        # For PyPI/git packages, use uvx with filtering wrapper
        log "Creating isolated execution environment..."

        # Create wrapper script for clean MCP execution
        cat > /tmp/mcp_wrapper_$$.sh << EOF
#!/bin/sh
# POSIX wrapper for MCP server execution

# Use detected/installed uvx path
UVX_BINARY="$UVX_PATH"

# Environment setup
export UV_CACHE_DIR="${UV_CACHE_DIR:-}"
export UV_NO_MODIFY_PATH=1
export PYTHONUNBUFFERED=1

# Debug logging
echo "[Wrapper] Starting uvx with args: \$*" >&2
echo "[Wrapper] UVX_BINARY: \$UVX_BINARY" >&2

# Test uvx availability
if ! test -x "\$UVX_BINARY"; then
    echo "[Wrapper] ERROR: uvx not found at \$UVX_BINARY" >&2
    exit 127
fi

# Execute uvx directly to preserve stdio for MCP communication
exec "\$UVX_BINARY" "\$@"
EOF

        chmod +x /tmp/mcp_wrapper_$$.sh

        if [ "$USE_FROM_SYNTAX" = "true" ]; then
            log "Final command: /tmp/mcp_wrapper_$$.sh --from $PACKAGE_SPEC $EXECUTABLE_NAME $SCRIPT_ARGS"
            exec /tmp/mcp_wrapper_$$.sh --from "$PACKAGE_SPEC" "$EXECUTABLE_NAME" $SCRIPT_ARGS
        else
            log "Final command: /tmp/mcp_wrapper_$$.sh $PACKAGE_SPEC $SCRIPT_ARGS"
            exec /tmp/mcp_wrapper_$$.sh "$PACKAGE_SPEC" $SCRIPT_ARGS
        fi
    fi
}

# Main function
main() {
    log "POSIX MCP Python Server Bootstrap v$SCRIPT_VERSION"
    log "Platform: $(detect_platform)"

    init_environment
    validate_package_spec

    # Detect existing uvx or install in isolated environment
    detect_or_install_uvx

    # Run the server (pass remaining args)
    run_server
}

# Run main
main "$@"