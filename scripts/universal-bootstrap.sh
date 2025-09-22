#!/bin/sh
# Universal MCP Python Server Bootstrap
# Detects platform and routes to appropriate implementation
# Version: 1.2.0

set -eu

SCRIPT_VERSION="1.2.0"
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

    if command -v curl >/dev/null 2>&1; then
        if curl -sSfL "$script_url" -o "$cache_file.tmp"; then
            mv "$cache_file.tmp" "$cache_file"
            cat "$cache_file"
        else
            error "Failed to download $script_name from $script_url"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -qO "$cache_file.tmp" "$script_url"; then
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
            download_script "bootstrap-bash.sh" | bash -s -- "$@"
            ;;
        linux-zsh-*|macos-zsh-*|freebsd-zsh-*|windows-unix-zsh-*)
            download_script "bootstrap-bash.sh" | zsh -s -- "$@"
            ;;
        alpine-*|linux-posix-*|macos-posix-*|*-posix-*|*-ksh-*)
            download_script "bootstrap-posix.sh" | sh -s -- "$@"
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

    log "MCP Python Server Bootstrap v$SCRIPT_VERSION starting"

    # Environment variables are handled at script initialization

    create_cache_dir

    validate_package_spec "$1"

    local platform
    platform=$(detect_platform)

    execute_platform_script "$platform" "$@"
}

main "$@"