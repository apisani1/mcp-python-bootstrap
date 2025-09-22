# Usage Guide

## Basic Usage

The MCP Python Bootstrap provides a universal way to run Python MCP servers without requiring pre-installed Python environments.

### Simple Server Launch

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-filesystem"
      ]
    }
  }
}
```

### With Specific Version

```json
{
  "mcpServers": {
    "database": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-database==1.2.0 --config ./config.json"
      ]
    }
  }
}
```

### Git Repositories

```json
{
  "mcpServers": {
    "custom": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- git+https://github.com/user/custom-mcp-server.git@main"
      ]
    }
  }
}
```

## Platform-Specific Usage

### Linux/macOS/WSL

```bash
# Direct execution
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-filesystem

# With caching
SCRIPT_PATH="$HOME/.mcp/universal-bootstrap.sh"
if [ ! -f "$SCRIPT_PATH" ] || [ $(($(date +%s) - $(stat -c %Y "$SCRIPT_PATH" 2>/dev/null || echo 0))) -gt 86400 ]; then
    mkdir -p "$(dirname "$SCRIPT_PATH")"
    curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
fi
"$SCRIPT_PATH" mcp-server-filesystem
```

### Windows PowerShell

```powershell
# Download and execute
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/bootstrap.ps1" | Invoke-Expression -ArgumentList "mcp-server-filesystem"

# Or save and execute
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/bootstrap.ps1" -OutFile "bootstrap.ps1"
.\bootstrap.ps1 mcp-server-filesystem
```

## Advanced Configuration

### Environment Variables

```bash
# Custom cache directory
export MCP_BOOTSTRAP_CACHE_DIR="/opt/mcp/cache"

# Custom script base URL (for corporate environments)
export MCP_BOOTSTRAP_BASE_URL="https://internal.company.com/mcp-bootstrap"

# Disable caching
export MCP_BOOTSTRAP_NO_CACHE="true"

# Custom bootstrap directory
export MCP_BOOTSTRAP_BOOTSTRAP_DIR="/opt/mcp/bootstrap"
```

### Proxy Support

```bash
# HTTP proxy
export http_proxy="http://proxy.company.com:8080"
export https_proxy="http://proxy.company.com:8080"

# With authentication
export http_proxy="http://user:pass@proxy.company.com:8080"
export https_proxy="http://user:pass@proxy.company.com:8080"
```

### Corporate Environments

```json
{
  "mcpServers": {
    "internal": {
      "command": "bash",
      "args": [
        "-c",
        "export MCP_BOOTSTRAP_BASE_URL='https://internal.company.com/mcp-bootstrap'; export https_proxy='http://proxy.company.com:8080'; curl -sSL $MCP_BOOTSTRAP_BASE_URL/scripts/universal-bootstrap.sh | sh -s -- internal-mcp-server==1.0.0"
      ]
    }
  }
}
```

## Package Specifications

### PyPI Packages

```bash
# Latest version
mcp-server-filesystem

# Specific version
mcp-server-database==1.2.0

# Version constraints
mcp-server-web>=2.0.0,<3.0.0

# With extras
mcp-server-database[postgresql]==1.2.0
```

### Git Repositories

```bash
# HTTPS URL
git+https://github.com/user/mcp-server.git

# Specific branch/tag
git+https://github.com/user/mcp-server.git@develop
git+https://github.com/user/mcp-server.git@v1.2.0

# Specific commit
git+https://github.com/user/mcp-server.git@abc1234

# SSH URL (if credentials are configured)
git+ssh://git@github.com/user/mcp-server.git
```

### Local Paths

```bash
# Absolute path
/path/to/local/mcp-server

# Relative path
./my-mcp-server

# Editable install
-e /path/to/local/mcp-server
```

## Server Arguments

All arguments after the package specification are passed to the MCP server:

```bash
# With configuration file
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-database --config config.json

# With multiple arguments
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-web --host 0.0.0.0 --port 8080 --debug

# With environment variables
DATABASE_URL=sqlite:///data.db curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-database
```

## Troubleshooting

### Enable Debug Logging

```bash
# Set debug mode
export MCP_BOOTSTRAP_DEBUG="true"

# Check log files
tail -f ~/.mcp/bootstrap.log
```

### Common Issues

1. **Network connectivity**: Check firewall and proxy settings
2. **Permissions**: Ensure write access to cache directories
3. **Package not found**: Verify package name and version
4. **Script download failed**: Check internet connection and URL

### Manual Installation

If automatic installation fails:

```bash
# Install uv manually
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"

# Use uvx directly
uvx mcp-server-filesystem
```

## Performance Tips

1. **Use caching**: Let the bootstrap cache scripts and environments
2. **Pin versions**: Use specific versions to avoid repeated downloads
3. **Local installation**: Install bootstrap script locally for frequent use
4. **Prebuilt images**: Use Docker images with pre-installed environments

## Security Considerations

1. **Verify checksums**: Always download from trusted sources
2. **Review scripts**: Inspect downloaded scripts before execution
3. **Use HTTPS**: Ensure all downloads use encrypted connections
4. **Corporate policies**: Follow your organization's software installation policies