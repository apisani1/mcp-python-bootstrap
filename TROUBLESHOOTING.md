# Troubleshooting Guide

This guide covers common issues and solutions when using the MCP Python Bootstrap system.

## Table of Contents

- [Git Not Installed](#git-not-installed)
- [Server Connection Fails](#server-connection-fails)
- [Slow Startup Times](#slow-startup-times)
- [Package Not Found](#package-not-found)
- [Permission Errors](#permission-errors)
- [Network Issues](#network-issues)
- [Cache Problems](#cache-problems)

---

## Git Not Installed

### Problem
Connection fails with error: "git installation required but not yet complete"

### Cause
You're using a `git+https://` URL but git is not installed on your system.

### Solution

**macOS:**
```bash
xcode-select --install
```
Then complete the installation dialog (may take several minutes).

**Ubuntu/Debian:**
```bash
sudo apt-get update && sudo apt-get install -y git
```

**CentOS/RHEL:**
```bash
sudo yum install -y git
```

**Fedora:**
```bash
sudo dnf install -y git
```

**After installation:**
1. Restart Claude Desktop
2. Reconnect to the server

### Why it fails immediately
- Claude Desktop has a 60-second initialization timeout
- Git installation takes 5+ minutes to complete
- The script fails fast to avoid timeout errors
- This provides better UX than hanging for 10 minutes

### Alternative
Use PyPI packages instead of git+ URLs when available:
```json
{
  "mcpServers": {
    "my-server": {
      "command": "bash",
      "args": ["-c", "curl -sSL [URL] | sh -s -- mcp-server-name"]
    }
  }
}
```

---

## Server Connection Fails

### Problem
Server disconnects immediately or shows "Server transport closed unexpectedly"

### Common Causes

**1. Package doesn't exist**
```
Error: Package not found on PyPI
```
Solution: Verify the package name is correct and published to PyPI.

**2. Network connectivity issues**
```
Error: Cannot reach PyPI
```
Solution: Check your internet connection and proxy settings.

**3. Python version incompatibility**
The server may require a specific Python version.

Solution: Check the package requirements.

**4. Missing dependencies**
Some packages require system libraries.

Solution: Check package documentation for system requirements.

### Debugging Steps

1. **Check the logs:**
   ```bash
   tail -f ~/.mcp/bootstrap/bootstrap.log
   ```

2. **Test the package manually:**
   ```bash
   uvx mcp-server-name --help
   ```

3. **Enable debug logging:**
   ```bash
   export MCP_BOOTSTRAP_DEBUG=true
   ```

4. **Clear cache and retry:**
   ```bash
   rm -rf ~/.mcp/cache
   ```

---

## Slow Startup Times

### Problem
Server takes a long time to start (30+ seconds)

### Causes

**1. First-time installation**
- uvx needs to download and install the package
- Python dependencies are being resolved
- Normal for first connection

**2. Cache invalidation**
- Script version changed
- Cache was cleared
- Package version updated

**3. Network speed**
- Slow connection to PyPI
- Large package with many dependencies

### Solutions

**Speed up subsequent connections:**
- Cache is automatic after first install
- Second connection should be <5 seconds

**For development:**
Use local installation instead of bootstrap:
```json
{
  "mcpServers": {
    "my-server": {
      "command": "/path/to/venv/bin/my-server"
    }
  }
}
```

---

## Package Not Found

### Problem
```
Error: Package not found on PyPI
Error: Could not verify package on PyPI
```

### Solutions

**1. Verify package name:**
Check PyPI: https://pypi.org/project/your-package-name/

**2. Check package is published:**
```bash
pip search your-package-name
```

**3. Use correct version syntax:**
```json
"args": ["-c", "curl -sSL [URL] | sh -s -- mcp-server-name==1.2.0"]
```

**4. For git repositories:**
Ensure the URL is correct:
```json
"args": ["-c", "curl -sSL [URL] | sh -s -- git+https://github.com/user/repo.git"]
```

---

## Permission Errors

### Problem
```
Error: Permission denied
Error: Cannot write to directory
```

### Causes
- Trying to install in system directories
- Cache directory not writable
- Running as restricted user

### Solutions

**1. Check directory permissions:**
```bash
ls -la ~/.mcp
ls -la ~/.cache/uv
```

**2. Fix permissions:**
```bash
chmod -R u+w ~/.mcp
chmod -R u+w ~/.cache/uv
```

**3. Override cache location:**
```bash
export MCP_BOOTSTRAP_CACHE_DIR=~/custom-cache
```

**4. Never use sudo:**
The bootstrap system is designed to run without elevated privileges.

---

## Network Issues

### Problem
```
Error: Failed to download script
Error: Cannot reach PyPI
Error: Connection timeout
```

### Solutions

**1. Check internet connection:**
```bash
curl -I https://pypi.org
```

**2. Check corporate proxy:**
```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
```

**3. Use custom registry:**
```bash
export MCP_BOOTSTRAP_BASE_URL=https://internal-server.company.com/scripts
```

**4. Retry with longer timeout:**
The script has automatic retry logic (3 attempts with 5-second delays).

**5. Download scripts manually:**
```bash
curl -sSL https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh -o ~/bootstrap.sh
chmod +x ~/bootstrap.sh
```

Then use local script in config:
```json
{
  "mcpServers": {
    "my-server": {
      "command": "bash",
      "args": ["~/bootstrap.sh", "mcp-server-name"]
    }
  }
}
```

---

## Cache Problems

### Problem
- Old version of script being used
- Server not updating despite new version
- Stale package installations

### Solutions

**1. Clear bootstrap cache:**
```bash
rm -rf ~/.mcp/bootstrap-cache
rm -rf ~/.mcp/cache
```

**2. Clear uvx cache:**
```bash
rm -rf ~/.cache/uv
```

**3. Force cache refresh:**
Use cache-busting parameter (already in recommended config):
```bash
curl -sSL https://[...]/universal-bootstrap.sh?$(date +%s)
```

**4. Disable caching temporarily:**
```bash
export MCP_BOOTSTRAP_NO_CACHE=true
```

**5. Check cache freshness:**
Scripts are cached for 24 hours. After that, they auto-update.

---

## Platform-Specific Issues

### macOS

**Problem: "xcrun: error: invalid active developer path"**
```bash
xcode-select --install
```

**Problem: "command not found: uvx" after installation**
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Windows

**Problem: PowerShell execution policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Problem: WSL/Git Bash issues**
Use the bash-based bootstrap (automatically detected).

### Linux

**Problem: Alpine/musl compatibility**
The system automatically detects Alpine and uses POSIX-compliant script.

**Problem: Missing system libraries**
Install build essentials:
```bash
# Ubuntu/Debian
sudo apt-get install build-essential

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
```

---

## Getting Help

If you're still experiencing issues:

1. **Check logs:**
   ```bash
   cat ~/.mcp/bootstrap/bootstrap.log
   ```

2. **Get debug output:**
   ```bash
   export MCP_BOOTSTRAP_DEBUG=true
   ```

3. **Report issues:**
   - GitHub Issues: https://github.com/apisani1/mcp-python-bootstrap/issues
   - Include log output
   - Include your OS and shell version
   - Include the package specification you're using

4. **Community support:**
   - MCP Discord server
   - Stack Overflow (tag: model-context-protocol)

---

## Quick Reference

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `MCP_BOOTSTRAP_CACHE_DIR` | Cache directory | `~/.mcp/cache` |
| `MCP_BOOTSTRAP_BASE_URL` | Script base URL | GitHub raw URL |
| `MCP_BOOTSTRAP_NO_CACHE` | Disable caching | `false` |
| `MCP_BOOTSTRAP_DEBUG` | Enable debug logs | `false` |
| `UV_CACHE_DIR` | uvx cache directory | `~/.cache/uv` |

### Log Locations

- Bootstrap logs: `~/.mcp/bootstrap/bootstrap.log`
- Cache directory: `~/.mcp/cache`
- Script cache: `~/.mcp/bootstrap-cache`
- uvx cache: `~/.cache/uv`

### Common Commands

```bash
# View logs
tail -f ~/.mcp/bootstrap/bootstrap.log

# Clear all caches
rm -rf ~/.mcp ~/.cache/uv

# Test package manually
uvx mcp-server-name --help

# Check uvx installation
which uvx
uvx --version

# Test bootstrap script
./scripts/universal-bootstrap.sh --help
```
