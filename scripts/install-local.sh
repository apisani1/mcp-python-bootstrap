#!/bin/bash
# Local installation script for development and testing
# Version: 1.2.0

set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
REPO_URL="https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main"

log() {
    echo "[Install] $1" >&2
}

error() {
    echo "[Install ERROR] $1" >&2
    exit 1
}

success() {
    echo "[Install SUCCESS] $1" >&2
}

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Download universal bootstrap script
log "Downloading universal bootstrap script..."
if curl -sSL "$REPO_URL/scripts/universal-bootstrap.sh" -o "$INSTALL_DIR/mcp-python-bootstrap"; then
    chmod +x "$INSTALL_DIR/mcp-python-bootstrap"
    success "Installed to $INSTALL_DIR/mcp-python-bootstrap"
else
    error "Failed to download bootstrap script"
fi

# Create convenience wrapper
cat > "$INSTALL_DIR/mcp-python" << 'EOF'
#!/bin/bash
# Convenience wrapper for MCP Python Bootstrap
exec "$(dirname "$0")/mcp-python-bootstrap" "$@"
EOF

chmod +x "$INSTALL_DIR/mcp-python"

log "Installation complete!"
log "Usage: mcp-python-bootstrap <package-spec> [args...]"
log "   or: mcp-python <package-spec> [args...]"

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log ""
    log "NOTE: $INSTALL_DIR is not in your PATH"
    log "Add this to your shell profile:"
    log "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi