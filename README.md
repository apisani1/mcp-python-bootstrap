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

For advanced use cases, you can configure servers manually:

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

See `TROUBLESHOOTING.md` for common issues and solutions.

## License

MIT License - see `LICENSE` for details.