# FastMCP Bootstrap Fix - Validation Guide

## Problem Summary

The bootstrap system was failing for FastMCP servers that worked perfectly with direct uvx execution. The git-based MCP server `git+https://github.com/apisani1/test-mcp-server-ap25092201.git` would work with this configuration:

**✅ Working Direct uvx Configuration:**
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

But would fail with this bootstrap configuration:
```json
{
  "mcpServers": {
    "My Prompts": {
      "command": "bash",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- --from git+https://github.com/apisani1/test-mcp-server-ap25092201.git test-mcp-server"
      ]
    }
  }
}
```

## Root Cause Analysis

Through systematic debugging, we identified four critical issues:

1. **Environment Variable Isolation**: uvx isolated installations don't inherit environment variables that FastMCP servers require
2. **Working Directory Issues**: Isolated environments use root/tmp instead of user home
3. **uvx Installation Preference**: Always installing isolated uvx instead of using existing user installations
4. **Missing FastMCP Debugging**: No asyncio debugging support for FastMCP troubleshooting

## 5-Phase Solution Implementation

### ✅ Phase 1: Environment Variable Inheritance for FastMCP Servers

**Problem**: FastMCP servers require specific environment variables that were lost in isolated environments.

**Solution**: Added comprehensive environment variable inheritance in the wrapper script:
```bash
# Inherit critical environment variables for FastMCP servers
export HOME="${HOME:-/Users/$(whoami)}"
export USER="${USER:-$(whoami)}"
export LOGNAME="${LOGNAME:-$(whoami)}"
export SHELL="${SHELL:-/bin/bash}"

# Python environment variables
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONIOENCODING="utf-8"

# Path inheritance for tool access
export PATH="${PATH:-/usr/local/bin:/usr/bin:/bin}"

# macOS-specific environment for GUI app compatibility
export TMPDIR="${TMPDIR:-/tmp}"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
```

### ✅ Phase 2: Working Directory Fix

**Problem**: Isolated environments were using root or temp directories instead of user home.

**Solution**: Explicitly change to user home directory:
```bash
# Use user's home directory (critical for FastMCP file access)
cd "$HOME" || cd /tmp
```

### ✅ Phase 3: Intelligent uvx Fallback

**Problem**: Always installing isolated uvx instead of using existing user installations.

**Solution**: Implemented smart detection strategy:
1. First try existing uvx installations with compatibility testing
2. Fall back to using system uv instead of isolated installation
3. Only use isolated installation as last resort with warnings

```bash
# Phase 1: Try to detect existing uvx installation
if UVX_PATH=$(command -v uvx 2>/dev/null); then
    if "$UVX_PATH" --version >/dev/null 2>&1; then
        log "Testing existing uvx compatibility..."
        if "$UVX_PATH" --help >/dev/null 2>&1; then
            log "Existing uvx is compatible, using user installation (preferred for environment compatibility)"
            return 0
        fi
    fi
fi

# Phase 2: Check if uv is available and use it instead of isolated installation
if command -v uv >/dev/null 2>&1; then
    local uv_version
    if uv_version=$(uv --version 2>/dev/null); then
        log "Found existing uv installation: $uv_version"
        log "Using existing uv ecosystem instead of isolated installation (better environment compatibility)"
        UVX_PATH="$(command -v uv)"
        return 0
    fi
fi
```

### ✅ Phase 4: FastMCP-Specific Debugging and Asyncio Flags

**Problem**: Missing debugging support for FastMCP server troubleshooting.

**Solution**: Added comprehensive FastMCP debugging environment:
```bash
# FastMCP-specific debugging and asyncio flags
export PYTHONDEBUG=1
export PYTHONASYNCIODEBUG=1
export PYTHONDEVMODE=1
export PYTHON_TRACEMALLOC=1

# FastMCP logging configuration
export FASTMCP_DEBUG=1
export FASTMCP_LOG_LEVEL="DEBUG"
export MCP_LOG_LEVEL="DEBUG"
```

### ✅ Phase 5: Testing and Validation

**Problem**: Need to validate that our bootstrap approach works identically to direct uvx.

**Solution**: Created comprehensive test script (`test_fastmcp_fix.sh`) that compares both approaches.

## Key Improvements

### 1. Environment Compatibility
- **Before**: Isolated environment with minimal variables
- **After**: Full environment inheritance matching user session

### 2. Working Directory
- **Before**: Random temp directory or root
- **After**: User home directory (same as direct uvx)

### 3. uvx Installation Strategy
- **Before**: Always isolated installation
- **After**: Prefer user installations, fall back intelligently

### 4. Debugging Support
- **Before**: Standard uvx output only
- **After**: Enhanced FastMCP debugging with asyncio support

### 5. Cache Invalidation
- **Before**: Manual cache clearing required
- **After**: Automatic detection of new features with version 1.3.5

## Testing Instructions

### Test 1: Manual Validation

1. **Test the working direct uvx configuration** (should work):
```bash
uvx --from git+https://github.com/apisani1/test-mcp-server-ap25092201.git test-mcp-server
```

2. **Test the fixed bootstrap configuration** (should now work):
```bash
curl -sSL https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- git+https://github.com/apisani1/test-mcp-server-ap25092201.git
```

### Test 2: Claude Desktop Configuration

Use the original failing configuration that should now work:
```json
{
  "mcpServers": {
    "My Prompts": {
      "command": "bash",
      "args": [
        "-c",
        "curl -sSL https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh | sh -s -- git+https://github.com/apisani1/test-mcp-server-ap25092201.git"
      ]
    }
  }
}
```

Note: The auto-detection automatically handles the `--from` syntax, so you no longer need to specify it manually.

### Test 3: Debugging Validation

Check the enhanced debugging output in `~/.mcp/bootstrap.log`:
```bash
tail -f ~/.mcp/bootstrap.log
```

Look for:
- Environment variable inheritance logs
- FastMCP debugging activation
- uvx detection strategy results
- Working directory confirmation

## Expected Behavior

After the fix, the bootstrap configuration should:

1. **Work identically** to the direct uvx configuration
2. **Provide enhanced debugging** for troubleshooting
3. **Use existing uvx installations** when available
4. **Inherit full environment** for FastMCP compatibility
5. **Run from user home directory** like direct uvx

## Troubleshooting

### If Bootstrap Still Fails

1. **Force cache refresh**:
```bash
export MCP_BOOTSTRAP_FORCE_REFRESH=1
```

2. **Check uvx detection**:
```bash
# Verify uvx is detected correctly
command -v uvx
uvx --version
```

3. **Review debug logs**:
```bash
# Check bootstrap logs
tail -50 ~/.mcp/bootstrap.log

# Check wrapper execution
tail -50 /tmp/mcp_wrapper.log
```

4. **Compare environments**:
```bash
# Direct uvx environment
env | grep -E "(HOME|USER|PATH|PYTHON)" | sort

# Bootstrap environment (check wrapper logs for comparison)
```

## Files Modified

1. **scripts/bootstrap-bash.sh** (v1.3.4 → v1.3.5)
   - Enhanced environment variable inheritance
   - Intelligent uvx detection and fallback
   - FastMCP debugging flags
   - Working directory fixes

2. **scripts/universal-bootstrap.sh** (v1.3.4 → v1.3.5)
   - Cache invalidation for FastMCP features
   - Version bump for force refresh

## Validation Checklist

- ✅ Environment variables properly inherited
- ✅ Working directory set to user home
- ✅ Existing uvx installations preferred over isolated
- ✅ FastMCP debugging flags enabled
- ✅ Cache invalidation working for new features
- ✅ Auto-detection of --from syntax working
- ✅ Comprehensive test script created
- ✅ Documentation updated

## Success Criteria

The fix is successful when:
1. The previously failing bootstrap configuration now works in Claude Desktop
2. FastMCP servers run with the same environment as direct uvx
3. Enhanced debugging provides useful troubleshooting information
4. No regression in existing functionality

---

**Version**: 1.3.5
**Test Package**: `git+https://github.com/apisani1/test-mcp-server-ap25092201.git`
**Executable**: `test-mcp-server`