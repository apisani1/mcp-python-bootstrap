# Configuration Guide

## Configuration Generator (`mcp_config.py`)

The easiest way to configure MCP servers is using our automated configuration generator.

### Quick Configuration

```bash
# Generate config for PyPI package
python3 scripts/mcp_config.py mcp-server-filesystem

# Generate config for Git repository
python3 scripts/mcp_config.py git+https://github.com/user/repo.git --name custom-server

# Generate config for local development
python3 scripts/mcp_config.py ./src/server.py --name dev-server --args "--debug,--reload"
```

### Configuration Options

| Option | Description | Example |
|--------|-------------|---------|
| `--name` | Server name (auto-detected if not provided) | `--name my-server` |
| `--config` | Config file path | `--config ./custom-config.json` |
| `--args` | Server arguments (comma-separated) | `--args "--port,8080,--verbose"` |

### Generated Configuration Format

The generator creates optimized configurations using the universal bootstrap system:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "bash",
      "args": [
        "/path/to/universal-bootstrap.sh",
        "package-spec",
        "--server-arg1",
        "--server-arg2"
      ],
      "_metadata": {
        "package_type": "pypi|git|local",
        "package_spec": "original-specification",
        "generated_by": "mcp_config.py",
        "bootstrap_version": "1.2.0"
      }
    }
  }
}
```

### Custom Configuration File Location

```bash
# Use custom config file location
python3 scripts/mcp_config.py mcp-server-database \
  --config "~/my-custom-config.json"

# For different Claude profiles
python3 scripts/mcp_config.py mcp-server-web \
  --config "~/Library/Application Support/Claude/dev_config.json"
```

## Manual Configuration

For advanced use cases where you need full control over the configuration.

## Environment Variables

The MCP Python Bootstrap system can be configured using environment variables:

### Core Configuration

#### `MCP_BOOTSTRAP_CACHE_DIR`
- **Description**: Directory for caching downloaded scripts and Python environments
- **Default**: `~/.mcp/cache` (Linux/macOS), `%USERPROFILE%\.mcp\cache` (Windows)
- **Example**: `/opt/mcp/cache`

#### `MCP_BOOTSTRAP_BOOTSTRAP_DIR`
- **Description**: Directory for bootstrap metadata and logs
- **Default**: `~/.mcp/bootstrap` (Linux/macOS), `%USERPROFILE%\.mcp\bootstrap` (Windows)
- **Example**: `/var/log/mcp`

#### `MCP_BOOTSTRAP_BASE_URL`
- **Description**: Base URL for downloading bootstrap scripts
- **Default**: `https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts`
- **Example**: `https://internal.company.com/mcp-bootstrap/scripts`

#### `MCP_BOOTSTRAP_NO_CACHE`
- **Description**: Disable all caching mechanisms
- **Default**: `false`
- **Values**: `true`, `false`

### UV Configuration

These variables are passed through to the `uv` package manager:

#### `UV_CACHE_DIR`
- **Description**: Cache directory for uv
- **Default**: Set automatically to `$MCP_BOOTSTRAP_CACHE_DIR/uv`

#### `UV_INDEX_URL`
- **Description**: Base URL for PyPI index
- **Default**: `https://pypi.org/simple/`
- **Example**: `https://pypi.company.com/simple/`

#### `UV_EXTRA_INDEX_URL`
- **Description**: Additional PyPI index URLs
- **Example**: `https://internal.pypi.company.com/simple/`

#### `UV_NO_CACHE`
- **Description**: Disable uv caching
- **Values**: `true`, `false`

### Network Configuration

#### `http_proxy` / `https_proxy`
- **Description**: HTTP/HTTPS proxy settings
- **Example**: `http://proxy.company.com:8080`
- **With auth**: `http://user:pass@proxy.company.com:8080`

#### `no_proxy`
- **Description**: Domains to exclude from proxy
- **Example**: `localhost,127.0.0.1,.company.com`

## MCP Server Configuration

### Basic Manual Configuration

When you need to configure servers manually without the generator:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "bash",
      "args": [
        "/path/to/universal-bootstrap.sh",
        "package-name",
        "server-args..."
      ]
    }
  }
}
```

### Remote Bootstrap Configuration

```json
{
  "mcpServers": {
    "server-name": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- package-name server-args..."
      ]
    }
  }
}
```

### Advanced Configuration

```json
{
  "mcpServers": {
    "filesystem-server": {
      "command": "bash",
      "args": [
        "-c",
        "export MCP_BOOTSTRAP_CACHE_DIR='/opt/mcp/cache'; export MCP_BOOTSTRAP_BASE_URL='https://internal.company.com/mcp-bootstrap'; curl -sSL $MCP_BOOTSTRAP_BASE_URL/scripts/universal-bootstrap.sh | sh -s -- mcp-server-filesystem==1.2.0 --root /data --config /etc/mcp/filesystem.json"
      ],
      "env": {
        "MCP_LOG_LEVEL": "DEBUG",
        "MCP_CACHE_SIZE": "1000"
      }
    }
  }
}
```

### Platform-Specific Configuration

#### Linux/macOS
```json
{
  "mcpServers": {
    "server": {
      "command": "bash",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | bash -s -- mcp-server-name"
      ]
    }
  }
}
```

#### Windows PowerShell
```json
{
  "mcpServers": {
    "server": {
      "command": "powershell",
      "args": [
        "-ExecutionPolicy", "Bypass",
        "-Command",
        "Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/bootstrap.ps1' | Invoke-Expression -ArgumentList 'mcp-server-name'"
      ]
    }
  }
}
```

#### Alpine Linux (POSIX)
```json
{
  "mcpServers": {
    "server": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name"
      ]
    }
  }
}
```

## Corporate Environment Configuration

### Proxy Configuration

```json
{
  "mcpServers": {
    "corporate-server": {
      "command": "bash",
      "args": [
        "-c",
        "export https_proxy='http://proxy.company.com:8080'; export http_proxy='http://proxy.company.com:8080'; curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name"
      ]
    }
  }
}
```

### Internal Package Index

```json
{
  "mcpServers": {
    "internal-server": {
      "command": "bash",
      "args": [
        "-c",
        "export UV_INDEX_URL='https://pypi.company.com/simple/'; export UV_EXTRA_INDEX_URL='https://pypi.org/simple/'; curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- internal-mcp-server"
      ]
    }
  }
}
```

### Custom Bootstrap Scripts

```json
{
  "mcpServers": {
    "custom-bootstrap": {
      "command": "bash",
      "args": [
        "-c",
        "export MCP_BOOTSTRAP_BASE_URL='https://internal.company.com/mcp-bootstrap'; curl -sSL $MCP_BOOTSTRAP_BASE_URL/scripts/universal-bootstrap.sh | sh -s -- company-mcp-server"
      ]
    }
  }
}
```

## Caching Configuration

### Aggressive Caching

```json
{
  "mcpServers": {
    "cached-server": {
      "command": "bash",
      "args": [
        "-c",
        "SCRIPT_PATH='$HOME/.mcp/bootstrap.sh'; if [ ! -f \"$SCRIPT_PATH\" ] || [ $(($(date +%s) - $(stat -c %Y \"$SCRIPT_PATH\" 2>/dev/null || echo 0))) -gt 86400 ]; then mkdir -p \"$(dirname \"$SCRIPT_PATH\")\"; curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh -o \"$SCRIPT_PATH\"; chmod +x \"$SCRIPT_PATH\"; fi; \"$SCRIPT_PATH\" mcp-server-name"
      ]
    }
  }
}
```

### No Caching

```json
{
  "mcpServers": {
    "no-cache-server": {
      "command": "bash",
      "args": [
        "-c",
        "export MCP_BOOTSTRAP_NO_CACHE='true'; export UV_NO_CACHE='true'; curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name"
      ]
    }
  }
}
```

## Version Pinning

### Pin Bootstrap Script Version

```json
{
  "mcpServers": {
    "stable-server": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/v1.2.0/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name==1.0.0"
      ]
    }
  }
}
```

### Pin Package Version

```json
{
  "mcpServers": {
    "pinned-server": {
      "command": "sh",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-database==1.2.0"
      ]
    }
  }
}
```

## Docker Configuration

### Basic Docker Setup

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install bootstrap dependencies
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV MCP_BOOTSTRAP_CACHE_DIR=/app/cache
ENV MCP_BOOTSTRAP_BOOTSTRAP_DIR=/app/bootstrap

# Create cache directories
RUN mkdir -p /app/cache /app/bootstrap

# Download and cache bootstrap script
RUN curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh -o /usr/local/bin/mcp-bootstrap && \
    chmod +x /usr/local/bin/mcp-bootstrap

CMD ["/usr/local/bin/mcp-bootstrap", "mcp-server-name"]
```

### Alpine Docker Setup

```dockerfile
FROM alpine:latest

WORKDIR /app

# Install dependencies
RUN apk add --no-cache curl bash

# Set environment variables
ENV MCP_BOOTSTRAP_CACHE_DIR=/app/cache
ENV MCP_BOOTSTRAP_BOOTSTRAP_DIR=/app/bootstrap

# Create directories
RUN mkdir -p /app/cache /app/bootstrap

# Download bootstrap script
RUN curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh -o /usr/local/bin/mcp-bootstrap && \
    chmod +x /usr/local/bin/mcp-bootstrap

CMD ["/usr/local/bin/mcp-bootstrap", "mcp-server-name"]
```

## Logging Configuration

### Enable Debug Logging

```bash
export MCP_BOOTSTRAP_DEBUG="true"
```

### Custom Log Location

```bash
export MCP_BOOTSTRAP_BOOTSTRAP_DIR="/var/log/mcp"
```

### Log Rotation

The bootstrap system automatically rotates logs when they exceed 10MB. To configure custom log rotation:

```bash
# Using logrotate (Linux)
cat > /etc/logrotate.d/mcp-bootstrap << EOF
/home/*/.mcp/bootstrap/bootstrap.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
```

## Performance Tuning

### Optimize for Cold Starts

```json
{
  "mcpServers": {
    "fast-server": {
      "command": "bash",
      "args": [
        "-c",
        "export MCP_BOOTSTRAP_CACHE_DIR='/tmp/mcp-cache'; curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name"
      ]
    }
  }
}
```

### Optimize for Reliability

```json
{
  "mcpServers": {
    "reliable-server": {
      "command": "bash",
      "args": [
        "-c",
        "export MCP_BOOTSTRAP_CACHE_DIR='$HOME/.mcp/cache'; export UV_NO_CACHE='false'; curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name==1.0.0"
      ]
    }
  }
}
```

## Security Configuration

### Verify Script Integrity

```bash
# Download and verify checksum
SCRIPT_URL="https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh"
EXPECTED_SHA256="your-expected-sha256-here"

curl -sSL "$SCRIPT_URL" -o bootstrap.sh
echo "$EXPECTED_SHA256  bootstrap.sh" | sha256sum -c
./bootstrap.sh mcp-server-name
```

### Restrict Network Access

```json
{
  "mcpServers": {
    "restricted-server": {
      "command": "bash",
      "args": [
        "-c",
        "export UV_INDEX_URL='https://trusted-pypi.company.com/simple/'; export MCP_BOOTSTRAP_BASE_URL='https://trusted-bootstrap.company.com'; curl -sSL $MCP_BOOTSTRAP_BASE_URL/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name"
      ]
    }
  }
}
```