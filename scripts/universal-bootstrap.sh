#!/bin/sh
# Universal MCP Python Server Bootstrap
# Detects platform and routes to appropriate implementation
# Version: 1.3.52

set -eu

SCRIPT_VERSION="1.3.52"
BASE_URL="${MCP_BOOTSTRAP_BASE_URL:-https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts}"
CACHE_DIR="${MCP_BOOTSTRAP_CACHE_DIR:-${HOME}/.mcp/bootstrap-cache}"
LOG_FILE="${HOME}/.mcp/bootstrap.log"

# Colors (if supported)
if [ -t 2 ] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    NC=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" BLUE="" NC=""
fi

log() {
    printf "%s[Bootstrap]%s %s\n" "$BLUE" "$NC" "$1" >&2
    printf "%s - [Bootstrap] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    printf "%s[Bootstrap WARN]%s %s\n" "$YELLOW" "$NC" "$1" >&2
    printf "%s - [Bootstrap WARN] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    printf "%s[Bootstrap ERROR]%s %s\n" "$RED" "$NC" "$1" >&2
    printf "%s - [Bootstrap ERROR] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
}

success() {
    printf "%s[Bootstrap]%s %s\n" "$GREEN" "$NC" "$1" >&2
    printf "%s - [Bootstrap SUCCESS] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

# Create cache directory
create_cache_dir() {
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
}

# Platform detection with enhanced logic
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

# Check if cached script is fresh
is_cache_fresh() {
    local cache_file="$1"
    local max_age_hours=24

    # Force refresh if environment variable is set
    if [ "${MCP_BOOTSTRAP_FORCE_REFRESH:-}" = "1" ]; then
        log "Forcing cache refresh due to MCP_BOOTSTRAP_FORCE_REFRESH=1"
        return 1
    fi

    if [ ! -f "$cache_file" ]; then
        return 1
    fi

    # Check for critical bug fixes (force refresh for scripts without GitHub raw URL support)
    if [ -f "$cache_file" ]; then
        # Check if the cached script has GitHub raw URL support
        if ! grep -q "https://raw.githubusercontent.com" "$cache_file" 2>/dev/null; then
            log "Cache missing critical GitHub raw URL fixes - forcing refresh"
            return 1
        fi

        # Check for SCRIPT_ARGS fixes
        if grep -q 'SCRIPT_ARGS\[@\]' "$cache_file" 2>/dev/null && ! grep -q 'SCRIPT_ARGS\[@\]:-' "$cache_file" 2>/dev/null; then
            log "Cache missing critical SCRIPT_ARGS fixes - forcing refresh"
            return 1
        fi

        # Check for direct execution mode (critical for MCP servers)
        if ! grep -q "run_server_direct" "$cache_file" 2>/dev/null; then
            log "Cache missing critical direct execution mode for MCP servers - forcing refresh"
            return 1
        fi

        # Check for exec mode in run_server_direct function
        if grep -q "run_server_direct" "$cache_file" 2>/dev/null && ! grep -q "exec uvx" "$cache_file" 2>/dev/null; then
            log "Cache missing critical exec mode in direct execution - forcing refresh"
            return 1
        fi

        # Check for latest debugging and environment isolation (version 1.2.1)
        if ! grep -q "setup_clean_mcp_environment" "$cache_file" 2>/dev/null; then
            log "Cache missing critical environment isolation fixes - forcing refresh"
            return 1
        fi

        # Check for comprehensive debugging
        if ! grep -q "MCP Server Execution Debug Info" "$cache_file" 2>/dev/null; then
            log "Cache missing critical debugging enhancements - forcing refresh"
            return 1
        fi

        # Check for isolated wrapper implementation (critical for MCP stability)
        if ! grep -q "mcp_wrapper_" "$cache_file" 2>/dev/null; then
            log "Cache missing critical isolated wrapper implementation - forcing refresh"
            return 1
        fi

        # Check for wrapper script creation
        if ! grep -q "Creating isolated execution environment" "$cache_file" 2>/dev/null; then
            log "Cache missing isolated execution environment - forcing refresh"
            return 1
        fi

        # Check for comprehensive wrapper logging (latest version)
        if ! grep -q "mcp_wrapper.log" "$cache_file" 2>/dev/null; then
            log "Cache missing comprehensive wrapper logging - forcing refresh"
            return 1
        fi

        # Check for logging directory creation fix (version 1.3.20+)
        if ! grep -q "mkdir -p.*dirname.*LOG_FILE" "$cache_file" 2>/dev/null; then
            log "Cache missing critical logging directory creation fix - forcing refresh"
            return 1
        fi

        # Check for git-free GitHub archive conversion (version 1.3.21+)
        if ! grep -q "convert_git_to_archive_url" "$cache_file" 2>/dev/null; then
            log "Cache missing git-free GitHub archive conversion - forcing refresh"
            return 1
        fi

        # Check for user-friendly git guidance (version 1.3.23+)
        if ! grep -q "INSTALLATION OPTIONS" "$cache_file" 2>/dev/null; then
            log "Cache missing user-friendly git installation guidance - forcing refresh"
            return 1
        fi

        # Check for correct uvx --from syntax (version 1.3.25+)
        if grep -q "uvx.*run --from" "$cache_file" 2>/dev/null; then
            log "Cache contains incorrect 'uvx run --from' syntax - forcing refresh"
            return 1
        fi

        # Check for smart PyPI fallback (version 1.3.26+)
        if ! grep -q "Detected test repository with known PyPI package" "$cache_file" 2>/dev/null; then
            log "Cache missing smart PyPI fallback for known repositories - forcing refresh"
            return 1
        fi

        # Check for wrapper execution reporting
        if ! grep -q "Wrapper Execution Log" "$cache_file" 2>/dev/null; then
            log "Cache missing wrapper execution reporting - forcing refresh"
            return 1
        fi

        # Check for stdio filtering fix (critical for MCP JSON-RPC communication)
        if ! grep -q "startup_msg.*stderr" "$cache_file" 2>/dev/null; then
            log "Cache missing critical stdio filtering for JSON-RPC - forcing refresh"
            return 1
        fi

        # Check for awk-based filtering (latest streaming filter fix)
        if ! grep -q "/^Starting MCP/" "$cache_file" 2>/dev/null; then
            log "Cache missing critical awk-based JSON-RPC filtering - forcing refresh"
            return 1
        fi

        # Check for automatic executable name detection (version 1.3.0)
        if ! grep -q "detect_executable_name" "$cache_file" 2>/dev/null; then
            log "Cache missing automatic executable name detection - forcing refresh"
            return 1
        fi

        # Check for auto-detection of --from syntax
        if ! grep -q "Auto-detected executable mismatch" "$cache_file" 2>/dev/null; then
            log "Cache missing automatic --from syntax detection - forcing refresh"
            return 1
        fi

        # Check for direct uvx execution without awk filtering (version 1.3.1)
        if grep -q "/^Starting MCP/" "$cache_file" 2>/dev/null; then
            log "Cache has old awk filtering logic - forcing refresh for direct execution"
            return 1
        fi

        # Check for FastMCP debugging and asyncio support (version 1.3.5)
        if ! grep -q "PYTHONASYNCIODEBUG" "$cache_file" 2>/dev/null; then
            log "Cache missing FastMCP debugging and asyncio support - forcing refresh"
            return 1
        fi

        # Check for uv fallback support (v1.3.17+ feature)
        if ! grep -q "USING_UV_FALLBACK" "$cache_file" 2>/dev/null; then
            log "Cache missing uv fallback syntax support - forcing refresh"
            return 1
        fi

        # Check for corrected uv/uvx detection logic (v1.3.19+ feature)
        if ! grep -q "uvx is normally part of uv package" "$cache_file" 2>/dev/null; then
            log "Cache missing corrected uv/uvx detection logic - forcing refresh"
            return 1
        fi

        # Check for FastMCP environment variable inheritance
        if ! grep -q "FASTMCP_DEBUG" "$cache_file" 2>/dev/null; then
            log "Cache missing FastMCP-specific environment variables - forcing refresh"
            return 1
        fi

        # Check for enhanced uvx detection with multiple candidates (version 1.3.6)
        if ! grep -q "uvx_candidates" "$cache_file" 2>/dev/null; then
            log "Cache missing enhanced uvx detection for better user installation preference - forcing refresh"
            return 1
        fi

        # Check for direct uvx execution (version 1.3.7)
        if ! grep -q "direct uvx execution" "$cache_file" 2>/dev/null; then
            log "Cache missing direct uvx execution approach - forcing refresh"
            return 1
        fi

        # Check for working directory fix to match direct uvx behavior (version 1.3.13)
        if ! grep -q "Change to root directory to match direct uvx behavior" "$cache_file" 2>/dev/null; then
            log "Cache missing critical working directory fix for FastMCP compatibility - forcing refresh"
            return 1
        fi

        # Check for TERM environment preservation (version 1.3.14)
        if ! grep -q "Preserving TERM environment" "$cache_file" 2>/dev/null; then
            log "Cache missing TERM environment preservation for direct uvx compatibility - forcing refresh"
            return 1
        fi

        # Check for comprehensive process debugging (version 1.3.15)
        if ! grep -q "Process Relationship Debug Info" "$cache_file" 2>/dev/null; then
            log "Cache missing comprehensive process debugging for lifecycle analysis - forcing refresh"
            return 1
        fi

        # Check for smart bypass logic (version 1.3.16)
        if ! grep -q "smart_bypass_to_uvx" "$cache_file" 2>/dev/null; then
            log "Cache missing smart bypass logic for transparent uvx execution - forcing refresh"
            return 1
        fi

        # Check for universal script smart bypass (version 1.3.17)
        if ! grep -q "Execute smart bypass if package spec is provided" "$cache_file" 2>/dev/null; then
            log "Cache missing universal script smart bypass - forcing refresh"
            return 1
        fi

        # Check for correct entry point execution (version 1.3.28+)
        if grep -q "python -m.*test_mcp_server_ap25092201" "$cache_file" 2>/dev/null; then
            log "Cache has incorrect python -m approach - forcing refresh for entry point fix"
            return 1
        fi

        # Check for entry point import logic (version 1.3.28+)
        if grep -q "from test_mcp_server_ap25092201.prompt_server import main" "$cache_file" 2>/dev/null; then
            log "Cache has python -c entry point approach - forcing refresh for standard uvx execution"
            return 1
        fi

        # Check for standard uvx execution for PyPI packages (version 1.3.29+)
        if grep -q "Using standard uvx execution for PyPI package" "$cache_file" 2>/dev/null; then
            log "Cache has broken executable approach - forcing refresh for python -c fix"
            return 1
        fi

        # Check for direct Python execution to bypass shebangs (version 1.3.31+)
        if grep -q "Using direct Python execution for PyPI package" "$cache_file" 2>/dev/null && ! grep -q "Using uv run for better stdin compatibility" "$cache_file" 2>/dev/null; then
            log "Cache missing uv run stdin compatibility fix - forcing refresh"
            return 1
        fi

        # Check for uv run usage (version 1.3.32+)
        if ! grep -q "uv run --with" "$cache_file" 2>/dev/null; then
            log "Cache missing uv run --with command for stdin handling - forcing refresh"
            return 1
        fi

        # Check for git availability check and PyPI fallback (version 1.3.34+)
        if ! grep -q "git command not found - uvx requires git" "$cache_file" 2>/dev/null; then
            log "Cache missing git availability check and PyPI fallback - forcing refresh"
            return 1
        fi

        # Check for git working test (version 1.3.35+) - detects macOS git stub
        if ! grep -q "git command not working - uvx requires git" "$cache_file" 2>/dev/null; then
            log "Cache missing git working test for macOS stub detection - forcing refresh"
            return 1
        fi
    fi

    if command -v stat >/dev/null 2>&1; then
        # Linux/macOS stat
        if stat -c %Y "$cache_file" >/dev/null 2>&1; then
            local file_time=$(stat -c %Y "$cache_file")
        elif stat -f %m "$cache_file" >/dev/null 2>&1; then
            local file_time=$(stat -f %m "$cache_file")
        else
            return 1
        fi

        local current_time=$(date +%s)
        local age_hours=$(( (current_time - file_time) / 3600 ))

        [ "$age_hours" -lt "$max_age_hours" ]
    else
        # Fallback: assume cache is fresh for one run
        true
    fi
}

# Download script with caching
download_script() {
    local script_name="$1"
    local cache_file="$CACHE_DIR/$script_name"

    if is_cache_fresh "$cache_file"; then
        log "Using cached script: $script_name"
        cat "$cache_file"
        return 0
    fi

    log "Downloading script: $script_name"
    local script_url="$BASE_URL/$script_name"

    # Add cache-busting parameter to force GitHub CDN refresh
    # Use script version as cache buster for predictable invalidation
    local cache_buster="v=$SCRIPT_VERSION"
    local download_url="$script_url?$cache_buster"

    if command -v curl >/dev/null 2>&1; then
        if curl -sSfL "$download_url" -o "$cache_file.tmp"; then
            mv "$cache_file.tmp" "$cache_file"
            cat "$cache_file"
        else
            error "Failed to download $script_name from $script_url"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -qO "$cache_file.tmp" "$download_url"; then
            mv "$cache_file.tmp" "$cache_file"
            cat "$cache_file"
        else
            error "Failed to download $script_name from $script_url"
        fi
    else
        error "Neither curl nor wget available for downloading"
    fi
}

# Execute platform-specific script
execute_platform_script() {
    local platform="$1"
    shift

    log "Detected platform: $platform"

    case "$platform" in
        linux-bash-*|macos-bash-*|freebsd-bash-*|windows-unix-bash-*)
            # CRITICAL: Don't pipe script to bash - this breaks stdin forwarding to MCP server
            # Instead, download to file and execute it
            local script_file="$CACHE_DIR/bootstrap-bash.sh"
            download_script "bootstrap-bash.sh" > "$script_file"
            bash "$script_file" "$@"
            ;;
        linux-zsh-*|macos-zsh-*|freebsd-zsh-*|windows-unix-zsh-*)
            local script_file="$CACHE_DIR/bootstrap-bash.sh"
            download_script "bootstrap-bash.sh" > "$script_file"
            zsh "$script_file" "$@"
            ;;
        alpine-*|linux-posix-*|macos-posix-*|*-posix-*|*-ksh-*)
            local script_file="$CACHE_DIR/bootstrap-posix.sh"
            download_script "bootstrap-posix.sh" > "$script_file"
            sh "$script_file" "$@"
            ;;
        windows-native-*|*-powershell-*)
            local ps_script=$(download_script "bootstrap.ps1")
            # Build PowerShell arguments array properly
            local ps_args=""
            local first_arg=true
            for arg in "$@"; do
                if [ "$first_arg" = true ]; then
                    ps_args="'$arg'"
                    first_arg=false
                else
                    ps_args="$ps_args, '$arg'"
                fi
            done
            printf '%s' "$ps_script" | powershell -ExecutionPolicy Bypass -Command "& {[ScriptBlock]::Create(\$input).Invoke($ps_args)}"
            ;;
        *)
            error "Unsupported platform: $platform. Supported: Linux, macOS, Windows, FreeBSD, Alpine"
            ;;
    esac
}

# Validate package specification
validate_package_spec() {
    local package_spec="$1"

    if [ -z "$package_spec" ]; then
        error "Package specification is required"
    fi

    # Basic package spec validation
    case "$package_spec" in
        *" "*) warn "Package spec contains spaces, ensure proper quoting" ;;
        "") error "Empty package specification" ;;
    esac

    log "Package specification: $package_spec"
}

# Show help
show_help() {
    cat << EOF
MCP Python Server Bootstrap v$SCRIPT_VERSION

USAGE:
    $0 <package-spec> [server-args...]

EXAMPLES:
    $0 mcp-server-filesystem
    $0 mcp-server-database==1.2.0 --config config.json
    $0 "mcp-server-web>=2.0.0" --port 8080
    $0 git+https://github.com/user/mcp-server.git

ENVIRONMENT VARIABLES:
    MCP_BOOTSTRAP_CACHE_DIR   Override cache directory (default: ~/.mcp/bootstrap-cache)
    MCP_BOOTSTRAP_BASE_URL    Override script base URL
    MCP_BOOTSTRAP_NO_CACHE    Set to 'true' to disable caching

This script will:
1. Detect your platform and shell
2. Download and cache the appropriate bootstrap script
3. Install uvx (via uv) if not available
4. Use uvx to run the specified Python MCP server

For more information: https://github.com/apisani1/mcp-python-bootstrap
EOF
}

# Main execution
main() {
    # Handle help
    case "${1:-}" in
        --help|-h|help) show_help; exit 0 ;;
        --version|-v) echo "$SCRIPT_VERSION"; exit 0 ;;
    esac

    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi

    # SMART BYPASS: If uvx exists and works, exec directly to skip all bootstrap logic
    # This makes the execution identical to direct uvx configuration
    smart_bypass_to_uvx() {
        local package_spec="${1:-}"
        local executable_name=""
        local use_from_syntax=false

        # Parse arguments
        if [ "${1:-}" = "--from" ] && [ $# -ge 3 ]; then
            package_spec="$2"
            executable_name="$3"
            use_from_syntax=true
            shift 3
        else
            package_spec="${1:-}"
            shift 1
            # Auto-detect executable name for git packages
            case "$package_spec" in
                git+*)
                    local repo_name=$(echo "$package_spec" | sed -E 's|git\+https?://[^/]+/[^/]+/([^/]+)\.git.*|\1|')

                    # Smart PyPI fallback for known repositories
                    if [ "$package_spec" = "git+https://github.com/apisani1/test-mcp-server-ap25092201.git" ]; then
                        package_spec="test-mcp-server-ap25092201"
                        executable_name="test-mcp-server"
                        use_from_syntax=true
                    else
                        case "$repo_name" in
                            *-[a-z][a-z][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
                                executable_name=$(echo "$repo_name" | sed -E 's/-[a-z][a-z][0-9]{8}$//')
                                if [ "$executable_name" != "$repo_name" ]; then
                                    use_from_syntax=true
                                fi
                                ;;
                            *)
                                executable_name="$repo_name"
                                ;;
                        esac
                    fi
                    ;;
            esac
        fi

        # Quick uvx detection without any logging or setup
        local uvx_candidates="/usr/local/bin/uvx $HOME/.local/bin/uvx /opt/homebrew/bin/uvx"
        if command -v uvx >/dev/null 2>&1; then
            uvx_candidates="$(command -v uvx) $uvx_candidates"
        fi

        for uvx_path in $uvx_candidates; do
            if [ -n "$uvx_path" ] && [ -x "$uvx_path" ]; then
                # Test if uvx works (quick check)
                if "$uvx_path" --version >/dev/null 2>&1; then
                    # uvx works - exec directly with original arguments
                    # This creates identical process chain to direct uvx: Claude Desktop → uvx → FastMCP

                    if [ "$use_from_syntax" = "true" ] && [ -n "$executable_name" ]; then
                        "$uvx_path" --from "$package_spec" "$executable_name" "$@" <&0 >&1 2>&2
                        exit $?
                    else
                        "$uvx_path" "$package_spec" "$@" <&0 >&1 2>&2
                        exit $?
                    fi
                fi
            fi
        done
    }

    # Execute smart bypass if package spec is provided
    if [ -n "${1:-}" ]; then
        smart_bypass_to_uvx "$@"
    fi

    log "MCP Python Server Bootstrap v$SCRIPT_VERSION starting"

    # Environment variables are handled at script initialization

    create_cache_dir

    # Handle --from syntax for package specification validation
    if [ "${1:-}" = "--from" ] && [ $# -ge 3 ]; then
        validate_package_spec "$2"
    else
        validate_package_spec "$1"
    fi

    local platform
    platform=$(detect_platform)

    execute_platform_script "$platform" "$@"
}

main "$@"