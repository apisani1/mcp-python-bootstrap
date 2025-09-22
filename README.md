# MCP Python Bootstrap

Universal cross-platform bootstrap solution for Python MCP (Model Context Protocol) servers.

## Quick Start

### Basic Usage
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

### Advanced Usage
```json
{
  "mcpServers": {
    "database": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-database==1.2.0 --config config.json"
      ]
    }
  }
}
```

## Features

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