# MCP Python Bootstrap

Universal cross-platform bootstrap solution for Python MCP (Model Context Protocol) servers. Provides NPX-like functionality for Python packages using uvx.

## Quick Start

### 🚀 Easy Configuration Generator

The fastest way to add Python MCP servers to your configuration:

```bash
# Install from PyPI
python3 scripts/mcp_config.py mcp-server-filesystem

# Local development
python3 scripts/mcp_config.py ./src/my_server.py --name my-server

# With specific version and arguments
python3 scripts/mcp_config.py mcp-server-database==1.2.0 --args "--port,8080,--verbose"

# From Git repository
python3 scripts/mcp_config.py git+https://github.com/user/mcp-server.git --name custom-server
```

### 📋 Generated Configuration

The `mcp_config.py` script automatically generates optimized MCP configurations:

```json
{
  "mcpServers": {
    "mcp-server-filesystem": {
      "command": "bash",
      "args": [
        "./scripts/universal-bootstrap.sh",
        "mcp-server-filesystem"
      ],
      "_metadata": {
        "package_type": "pypi",
        "package_spec": "mcp-server-filesystem",
        "generated_by": "mcp_config.py",
        "bootstrap_version": "1.2.0"
      }
    }
  }
}
```

### 🔧 Manual Configuration

For advanced use cases, you can configure servers manually with direct HTTP bootstrap:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "bash",
      "args": [
        "-c",
        "TEMP_SCRIPT=$(mktemp) && curl -sSL https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh?$(date +%s) -o \"$TEMP_SCRIPT\" && sh \"$TEMP_SCRIPT\" mcp-server-filesystem && rm \"$TEMP_SCRIPT\""
      ]
    }
  }
}
```

This configuration:
- Downloads the latest bootstrap script with cache-busting
- Works on systems with or without uvx installed
- Automatically installs uvx if needed
- Cleans up temp files after execution

**For GitHub repositories:**
```json
{
  "mcpServers": {
    "my-server": {
      "command": "bash",
      "args": [
        "-c",
        "TEMP_SCRIPT=$(mktemp) && curl -sSL https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh?$(date +%s) -o \"$TEMP_SCRIPT\" && sh \"$TEMP_SCRIPT\" git+https://github.com/user/my-mcp-server.git && rm \"$TEMP_SCRIPT\""
      ]
    }
  }
}
```

## Features

### 🎯 Configuration Generator (`mcp_config.py`)
- **Smart Package Detection**: Supports PyPI, Git, and local packages automatically
- **Server Name Auto-Detection**: Extracts server names from FastMCP patterns
- **Flexible Arguments**: Pass custom arguments to your MCP servers
- **Configuration Management**: Updates existing configs safely
- **Metadata Tracking**: Tracks package type and generation details

### 🛠️ Bootstrap System
- **Zero Prerequisites**: No Python, pip, or uvx installation required
- **Cross-Platform**: Works on Linux, macOS, Windows, Alpine, FreeBSD
- **Smart Caching**: Caches environments and scripts for faster startup
- **Automatic Detection**: Detects platform and shell, uses appropriate implementation
- **Version Control**: Pin to specific script and package versions
- **Corporate Friendly**: Proxy support, custom registries, offline caching
- **Comprehensive Logging**: Detailed logs for troubleshooting
- **Error Recovery**: Retry logic and graceful fallbacks

## Platform Support

| Platform | Shell | Support | Notes |
|----------|-------|---------|-------|
| Linux | bash/zsh | ✅ Full | Primary platform |
| Linux | POSIX shell | ✅ Full | Alpine, minimal containers |
| macOS | bash/zsh | ✅ Full | Intel and Apple Silicon |
| Windows | PowerShell | ✅ Full | Windows 10+ |
| Windows | WSL/Git Bash | ✅ Full | Unix environment on Windows |
| FreeBSD | bash/zsh | ✅ Full | BSD systems |

## How It Works

1. **Platform Detection**: Automatically detects OS, shell, and architecture
2. **Script Selection**: Downloads appropriate platform-specific script
3. **Environment Setup**: Installs uv/uvx if not available
4. **Server Launch**: Uses uvx to run the Python MCP server in isolation

## Environment Variables

- `MCP_BOOTSTRAP_CACHE_DIR`: Override cache directory (default: ~/.mcp/cache)
- `MCP_BOOTSTRAP_BASE_URL`: Override script base URL
- `MCP_BOOTSTRAP_NO_CACHE`: Set to 'true' to disable caching

## Examples

See the `examples/` directory for:

- Basic MCP configurations
- Advanced usage patterns
- Corporate environment setups
- Docker integration

## Development

### Local Installation
```bash
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/install-local.sh | bash
```

### Testing
```bash
./tests/test-integration.sh
```

## Contributing

See `CONTRIBUTING.md` for development guidelines.

## Troubleshooting

### Git Not Installed (git+ URLs)

When using `git+https://` URLs without git installed:

**Expected Behavior:**
1. Connection fails immediately (within 2 seconds)
2. Error message appears in Claude Desktop logs
3. Script attempts to trigger git installation (may not show dialog)

**What to do:**
1. Open Terminal and run: `xcode-select --install` (macOS) or your package manager (Linux)
2. Complete the installation (takes several minutes)
3. Restart Claude Desktop
4. Reconnect - server will work immediately

**Why it fails fast:**
- Claude Desktop has a 60-second initialization timeout
- Git installation takes 5+ minutes
- Background processes cannot reliably trigger system dialogs
- Waiting would cause timeout errors and poor user experience

**Alternative:** Use PyPI packages instead of git+ URLs when available:
```json
// Instead of: git+https://github.com/user/mcp-server.git
// Use: mcp-server-name (if published to PyPI)
```

See `TROUBLESHOOTING.md` for more common issues and solutions.

## License

MIT License - see `LICENSE` for details.