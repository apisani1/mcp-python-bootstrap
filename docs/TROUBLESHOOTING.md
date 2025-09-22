# Troubleshooting Guide

## Common Issues

### 1. Script Download Failures

#### Symptoms
- "Failed to download script" error
- "Neither curl nor wget available" error
- Network timeout errors

#### Solutions

**Check Network Connectivity**
```bash
# Test basic connectivity
curl -I https://pypi.org
wget --spider https://pypi.org

# Test specific script URL
curl -I https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh
```

**Configure Proxy Settings**
```bash
export https_proxy="http://proxy.company.com:8080"
export http_proxy="http://proxy.company.com:8080"
```

**Install Download Tools**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install curl wget

# CentOS/RHEL
sudo yum install curl wget

# Alpine
sudo apk add curl wget

# macOS
brew install curl wget
```

### 2. Permission Errors

#### Symptoms
- "Permission denied" when creating directories
- "Cannot write to log file" warnings
- Cache directory creation failures

#### Solutions

**Check Directory Permissions**
```bash
# Check home directory permissions
ls -la $HOME

# Check cache directory
ls -la $HOME/.mcp

# Fix permissions
chmod 755 $HOME
mkdir -p $HOME/.mcp
chmod 755 $HOME/.mcp
```

**Use Alternative Cache Directory**
```bash
export MCP_BOOTSTRAP_CACHE_DIR="/tmp/mcp-cache"
export MCP_BOOTSTRAP_BOOTSTRAP_DIR="/tmp/mcp-bootstrap"
```

**Run with Elevated Permissions (if necessary)**
```bash
# Only if absolutely required
sudo -E bash -c "curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name"
```

### 3. UV/UVX Installation Issues

#### Symptoms
- "uv installation failed" error
- "uvx command not found" error
- "uv installed but not working properly" error

#### Solutions

**Manual UV Installation**
```bash
# Download and install uv manually
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add to PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Verify installation
uv --version
uvx --version
```

**Check PATH Configuration**
```bash
# Check current PATH
echo $PATH

# Add UV directories to PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Make permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
```

**Clear UV Cache**
```bash
# Remove UV cache
rm -rf $HOME/.cache/uv
rm -rf $HOME/.local/share/uv

# Or use custom cache directory
export UV_CACHE_DIR="/tmp/uv-cache"
```

### 4. Package Installation Failures

#### Symptoms
- "Package not found" errors
- PyPI connection timeouts
- Version resolution conflicts

#### Solutions

**Verify Package Name**
```bash
# Search PyPI for package
curl -s "https://pypi.org/pypi/mcp-server-filesystem/json" | jq .info.name

# Check available versions
curl -s "https://pypi.org/pypi/mcp-server-filesystem/json" | jq '.releases | keys[]'
```

**Use Specific Package Index**
```bash
export UV_INDEX_URL="https://pypi.org/simple/"
export UV_EXTRA_INDEX_URL="https://test.pypi.org/simple/"
```

**Try Alternative Package Specifications**
```bash
# Try without version constraint
mcp-server-filesystem

# Try with different version
mcp-server-filesystem>=1.0.0

# Try from git
git+https://github.com/modelcontextprotocol/servers.git#subdirectory=src/filesystem
```

### 5. Platform Detection Issues

#### Symptoms
- "Unsupported platform" errors
- Wrong script being downloaded
- Shell compatibility issues

#### Solutions

**Check Platform Detection**
```bash
# Check OS
uname -s

# Check architecture
uname -m

# Check shell
echo $0
echo $BASH_VERSION
echo $ZSH_VERSION
```

**Force Specific Script**
```bash
# Force bash script
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/bootstrap-bash.sh | bash -s -- mcp-server-name

# Force POSIX script
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/bootstrap-posix.sh | sh -s -- mcp-server-name

# Force PowerShell script
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/bootstrap.ps1" | Invoke-Expression -ArgumentList "mcp-server-name"
```

### 6. Corporate Environment Issues

#### Symptoms
- SSL certificate verification failures
- Proxy authentication required
- Internal package repositories not accessible

#### Solutions

**Configure SSL Certificates**
```bash
# Skip SSL verification (not recommended for production)
export PYTHONHTTPSVERIFY=0
export SSL_VERIFY=false

# Use custom CA bundle
export SSL_CERT_FILE=/path/to/corporate-ca-bundle.crt
export REQUESTS_CA_BUNDLE=/path/to/corporate-ca-bundle.crt
```

**Proxy Authentication**
```bash
# With username/password
export https_proxy="http://username:password@proxy.company.com:8080"

# With domain\username
export https_proxy="http://domain%5Cusername:password@proxy.company.com:8080"
```

**Use Internal Repositories**
```bash
export UV_INDEX_URL="https://pypi.company.com/simple/"
export MCP_BOOTSTRAP_BASE_URL="https://bootstrap.company.com/scripts"
```

## Debugging

### Enable Debug Logging

```bash
# Enable debug mode
export MCP_BOOTSTRAP_DEBUG="true"

# Run with verbose output
bash -x script.sh

# Check log files
tail -f ~/.mcp/bootstrap/bootstrap.log
```

### Manual Script Execution

```bash
# Download script first
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh -o bootstrap.sh

# Make executable
chmod +x bootstrap.sh

# Run with debugging
bash -x bootstrap.sh mcp-server-name
```

### Check System Requirements

```bash
# Check available tools
command -v curl
command -v wget
command -v python3
command -v pip

# Check disk space
df -h $HOME

# Check memory
free -h

# Check internet connectivity
ping -c 3 pypi.org
nslookup pypi.org
```

## Platform-Specific Issues

### Linux Issues

**Alpine Linux Package Manager**
```bash
# Install missing packages
apk add --no-cache curl wget bash python3

# If musl libc compatibility issues
export PYTHONUNBUFFERED=1
```

**SELinux Issues**
```bash
# Check SELinux status
getenforce

# Temporarily disable (if needed)
sudo setenforce 0

# Check SELinux denials
sudo ausearch -m avc -ts recent
```

### macOS Issues

**Xcode Command Line Tools**
```bash
# Install command line tools
xcode-select --install

# Check installation
xcode-select --print-path
```

**Homebrew Conflicts**
```bash
# Check for conflicting Python installations
which python3
which pip3

# Use system Python
export PATH="/usr/bin:$PATH"
```

### Windows Issues

**PowerShell Execution Policy**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass
powershell -ExecutionPolicy Bypass -File script.ps1
```

**Windows Subsystem for Linux (WSL)**
```bash
# Update WSL
wsl --update

# Check WSL version
wsl --list --verbose

# Use Windows PATH
export PATH="$PATH:/mnt/c/Windows/System32"
```

## Performance Issues

### Slow Downloads

```bash
# Use different mirror
export UV_INDEX_URL="https://pypi.douban.com/simple/"  # China
export UV_INDEX_URL="https://pypi.python.org/simple/"   # Official

# Increase timeout
export UV_HTTP_TIMEOUT=300

# Use parallel downloads
export UV_CONCURRENT_DOWNLOADS=10
```

### High Memory Usage

```bash
# Limit UV cache size
export UV_CACHE_SIZE="1GB"

# Use temporary cache
export UV_CACHE_DIR="/tmp/uv-cache"

# Clear cache regularly
uv cache clean
```

### Disk Space Issues

```bash
# Check cache size
du -sh ~/.cache/uv
du -sh ~/.mcp

# Clean up old caches
rm -rf ~/.cache/uv/builds
rm -rf ~/.mcp/bootstrap-cache/*

# Use temporary directories
export MCP_BOOTSTRAP_CACHE_DIR="/tmp/mcp-cache"
```

## Recovery Procedures

### Complete Reset

```bash
# Remove all MCP bootstrap data
rm -rf ~/.mcp
rm -rf ~/.cache/uv
rm -rf ~/.local/share/uv

# Clear environment variables
unset MCP_BOOTSTRAP_CACHE_DIR
unset MCP_BOOTSTRAP_BOOTSTRAP_DIR
unset MCP_BOOTSTRAP_BASE_URL

# Start fresh
curl -sSL https://raw.githubusercontent.com/mcp-tools/python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- mcp-server-name
```

### Backup and Restore

```bash
# Backup working configuration
tar -czf mcp-backup.tar.gz ~/.mcp ~/.cache/uv

# Restore from backup
tar -xzf mcp-backup.tar.gz -C /
```

## Getting Help

### Log Analysis

```bash
# Show recent errors
grep -i error ~/.mcp/bootstrap/bootstrap.log | tail -10

# Show network issues
grep -i "network\|timeout\|connection" ~/.mcp/bootstrap/bootstrap.log

# Show package issues
grep -i "package\|install\|download" ~/.mcp/bootstrap/bootstrap.log
```

### System Information

```bash
# Collect system information
echo "OS: $(uname -a)"
echo "Shell: $0 ($BASH_VERSION$ZSH_VERSION)"
echo "Python: $(python3 --version 2>/dev/null || echo 'Not found')"
echo "UV: $(uv --version 2>/dev/null || echo 'Not found')"
echo "Curl: $(curl --version 2>/dev/null | head -1 || echo 'Not found')"
echo "Cache Dir: $MCP_BOOTSTRAP_CACHE_DIR"
echo "Bootstrap Dir: $MCP_BOOTSTRAP_BOOTSTRAP_DIR"
```

### Reporting Issues

When reporting issues, please include:

1. **System Information**: OS, shell, architecture
2. **Error Messages**: Complete error output
3. **Configuration**: Environment variables and MCP config
4. **Log Files**: Contents of bootstrap.log
5. **Reproduction Steps**: Exact commands that cause the issue

```bash
# Generate issue report
echo "# MCP Bootstrap Issue Report"
echo "## System Information"
uname -a
echo "Shell: $0"
echo "## Error Log"
tail -50 ~/.mcp/bootstrap/bootstrap.log
echo "## Environment"
env | grep MCP_BOOTSTRAP
echo "## Configuration"
cat ~/.mcp/config.json 2>/dev/null || echo "No config file"
```