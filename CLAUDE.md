# MCP Python Bootstrap - Project Context

## Overview

This repository contains a **cross-platform bootstrap solution** that enables MCP clients to dynamically download and execute Python-based MCP servers. The solution eliminates the need for users to manually dowload and install the MCP servers

## Architecture

### Core Concept

The bootstrap system uses a **curl-based shell script** that:
1. Detects the platform and available tools
2. Ensures `uvx` (from the `uv` package manager) is installed
3. Downloads and executes Python MCP servers from **PyPI** or **GitHub**
4. Manages all dependencies automatically in isolated environments

### Key Components

- **Universal Bootstrap Script** (`universal-bootstrap.sh`): Platform detection and routing
- **Platform-Specific Scripts**:
  - `bootstrap-bash.sh` (Linux/macOS/WSL)
  - `bootstrap-posix.sh` (Alpine/minimal environments)
  - `bootstrap.ps1` (Windows PowerShell)
- **Enhanced Features**: Caching, logging, retry logic, package verification, automatic git installation detection
- **mcp_config.py**: Utility script that generates the json MCP Server configuration file using curl

## MCP Server Configuration

### Example Configuration

```json
{
  "mcpServers": {
    "my-test-server": {
      "command": "bash",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- git+https://github.com/apisani1/test-mcp-server-ap25092201.git"
      ]
    }
  }
}
```

### Configuration Patterns

**PyPI Package:**
```json
"args": ["-c", "curl -sSL [BOOTSTRAP_URL] | sh -s -- mcp-server-name==1.0.0"]
```

**GitHub Repository:**
```json
"args": ["-c", "curl -sSL [BOOTSTRAP_URL] | sh -s -- git+https://github.com/user/repo.git"]
```

**With Additional Arguments:**
```json
"args": ["-c", "curl -sSL [BOOTSTRAP_URL] | sh -s -- mcp-server-name --config /path/to/config.json"]
```

## Bootstrap Workflow

### Scenario 1: uvx Already Installed
1. Bootstrap script detects `uvx` is available
2. Validates the package specification
3. Executes: `uvx <package-spec> [args]`
4. uvx handles dependency resolution and isolation

### Scenario 2: uvx Not Installed
1. Bootstrap script detects `uvx` is missing
2. Installs `uv` (which includes `uvx`) via official installer
3. Adds `uv`/`uvx` to PATH for current session
4. Executes: `uvx <package-spec> [args]`
5. All installations happen in user space (no sudo required)

### Scenario 3: git Not Installed (git+ URLs)

**IMPORTANT**: When git is not installed and a git+ URL is used:

**On macOS:**
1. Bootstrap script detects git+ URL package specification
2. Checks if `git` command is available and working
3. Attempts to trigger Xcode Command Line Tools installation
4. **Fails immediately** with clear error message (does not wait)
5. User must manually complete git installation
6. User restarts Claude Desktop and reconnects

**Why immediate failure?**
- Claude Desktop has a 60-second timeout for MCP initialization
- Git installation takes 5+ minutes to complete
- macOS background processes cannot reliably trigger system dialogs
- The installation dialog may appear but not come to foreground

**Expected User Workflow:**
1. First connection attempt: Fails with error message in logs
2. User sees error: "git installation required but not yet complete"
3. User manually runs: `xcode-select --install` in Terminal
4. User completes installation (may take several minutes)
5. User restarts Claude Desktop
6. Second connection attempt: Succeeds immediately

**On Linux:**
- Fails immediately with platform-specific git installation instructions
- User must install git via package manager
- User reconnects after installation

### Dependency Management
- **uv/uvx** creates isolated virtual environments per package
- Each MCP server runs in its own environment
- No conflicts between different servers or versions
- Automatic caching for faster subsequent launches
- **git** is automatically detected and installation guided for git+ URLs

## Platform Support

| Platform | Implementation | Status |
|----------|---------------|--------|
| Linux (bash/zsh) | `bootstrap-bash.sh` | ✅ Full |
| macOS (bash/zsh) | `bootstrap-bash.sh` | ✅ Full |
| Alpine/Minimal | `bootstrap-posix.sh` | ✅ Full |
| Windows (PowerShell) | `bootstrap.ps1` | ✅ Full |
| Windows (WSL/Git Bash) | `bootstrap-bash.sh` | ✅ Full |
| FreeBSD | `bootstrap-bash.sh` | ✅ Full |

## Key Features

- **Zero Prerequisites**: No Python or pip installation required
- **Cross-Platform**: Automatic platform detection and appropriate script selection
- **Smart Caching**: Scripts and environments cached for faster startup
- **Enhanced Logging**: Detailed logs in `~/.mcp/bootstrap/bootstrap.log`
- **Error Recovery**: Retry logic for network failures
- **Package Verification**: Validates packages exist before installation
- **Version Pinning**: Support for exact versions, git refs, and version ranges
- **Automatic Git Detection**: Detects missing git and guides installation for git+ URLs

## Environment Variables

Configure bootstrap behavior via environment variables:

- `MCP_BOOTSTRAP_CACHE_DIR`: Override cache directory (default: `~/.mcp/cache`)
- `MCP_BOOTSTRAP_BASE_URL`: Override script base URL for corporate environments
- `MCP_BOOTSTRAP_NO_CACHE`: Set to 'true' to disable caching
- `UV_CACHE_DIR`: Override uv's cache directory

## File Structure

```
scripts/
├── universal-bootstrap.sh    # Entry point - platform detection
├── bootstrap-bash.sh          # Enhanced bash implementation  
├── bootstrap-posix.sh         # POSIX-compliant for minimal environments
├── bootstrap.ps1              # Windows PowerShell implementation
└── mcp_config.py              # json MCP Server configuration generator

examples/
├── basic-mcp-config.json      # Simple configurations
├── advanced-mcp-config.json   # Complex scenarios
├── docker-compose.yml         # Container based example
└── corporate-mcp-config.json  # Enterprise setups

tests/
├── test-bash.sh               # Bash-specific tests
├── test-posix.sh              # POSIX shell tests
└── test-integration.sh        # Integration tests
```

## Development Guidelines

### Testing Changes

```bash
# Test the universal bootstrap
./scripts/universal-bootstrap.sh --help

# Run integration tests
./tests/test-integration.sh

# Test with a specific package
./scripts/universal-bootstrap.sh test-package-name
```

### Common Issues to Watch For

1. **Shell Compatibility**: Ensure POSIX compliance for maximum compatibility
2. **Path Handling**: Use proper quoting for paths with spaces
3. **Error Handling**: Always check command success and provide clear error messages
4. **Caching Logic**: Verify cache freshness checks work correctly
5. **Platform Detection**: Test edge cases (Git Bash on Windows, Alpine, etc.)

### When Making Changes

- Update version numbers in all scripts
- Test on multiple platforms (Linux, macOS, Windows)
- Update documentation if adding new features
- Run integration tests before committing
- Consider backward compatibility with existing MCP configs

## Debugging Tips

**Enable verbose logging:**
```bash
export MCP_BOOTSTRAP_DEBUG=true
```

**Check logs:**
```bash
tail -f ~/.mcp/bootstrap/bootstrap.log
```

**Test without cache:**
```bash
export MCP_BOOTSTRAP_NO_CACHE=true
```

**Manually test uvx installation:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
uvx --version
```
## Testing server
To test the scripts we are using a Python server developed and packaged with uv and that can be found at:
- https://github.com/apisani1/test-mcp-server-ap25092201.git
- PyPI (test-mcp-server-ap25092201)

This server have been tested the following ways:
### 1) Local installation:
In a terminal window I typed:
```bash
    pip install test-mcp-server-ap25092201
    test-mcp-server
```
the server executed succesfully and printed out: "Starting MCP PromptServer version 0.1.4..." and then it seems to "hang" but actually is waiting for an input.

### 2) Claude destop with local direct configuration:
After installing the test server on a conda environment named test_env, I used this json configuration with Claude desktop:
```json
{
  "mcpServers": {
    "My Prompts": {
      "command": "/Users/antonio/miniconda3/envs/test_env/bin/test-mcp-server"
    }
  }
}
```
Claude loaded the server successfully and the server offered the prompts available as expected

### 3) Using uvx directly:
In a terminal window I typed:
```bash
    uvx --from git+https://github.com/apisani1/test-mcp-server-ap25092201.git test-mcp-server
```
uvx succesfully downloaded and excuted the sever that behaved exactly as in testing scenario 1

### 4) Claude desktop with uvx configuration:
I used this json configuration with Claude desktop:
```json
{
  "mcpServers": {
    "My Prompts": {
      "command": "/Users/antonio/.local/bin/uvx",
      "args": [
        "--from",
        "git+https://github.com/apisani1/test-mcp-server-ap25092201.git",
        "test-mcp-server"
      ]
    }
  }
}
```
Claude loaded the server successfully and the server offered the prompts available as expected.

Note that we had to use an absolut path for Claude desktop find the uvx installation.

For our scripts do not assume that you can use a fixed absolut path for uvx because if uvx is not installed you will need to installed on a local virtual environment. 

## Related Technologies

- **uv/uvx**: Fast Python package installer and runner (https://github.com/astral-sh/uv)
- **MCP (Model Context Protocol)**: Protocol for AI model interactions
- **MCP Python SDK**: located at https://github.com/modelcontextprotocol/python-sdk/tree/main
- **Virtual Environments**: Python's built-in isolation mechanism

## Security Considerations

- Scripts are downloaded via HTTPS with certificate validation
- No sudo/admin privileges required
- All installations in user space
- Can pin to specific script versions/git commits for reproducibility
- Support for corporate proxies and internal registries

# Important instructions to follow:
1) When stating a new session read all the scripts and the last 10 commits to understand where we were. Ackwnoledge to the user that you executed this important step
2) Remember that this repo does not have makefile or run.sh becuase becuase is just scripts
3) Check whether you need to change the scripts version to force an invalidation of the script cache
4) Do not assume that the testing server is to blame. The testing server works
- Read CLAUDE.md and execute this important step: "When stating a new session read all the scripts and the last 10 commits to understand where we were. Ackwnoledge to the user that you executed this important step"