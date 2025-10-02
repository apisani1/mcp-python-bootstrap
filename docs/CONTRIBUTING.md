# Contributing Guide

## Getting Started

Thank you for your interest in contributing to MCP Python Bootstrap! This guide will help you get started with development and contributing.

### Prerequisites

- Basic understanding of shell scripting (bash, POSIX shell)
- PowerShell knowledge (for Windows support)
- Git and GitHub workflow knowledge
- Understanding of Python packaging and virtual environments

### Development Environment Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/python-bootstrap.git
   cd python-bootstrap
   ```

2. **Set up Development Tools**
   ```bash
   # Install shellcheck for script linting
   # macOS
   brew install shellcheck
   
   # Ubuntu/Debian
   sudo apt install shellcheck
   
   # Or download from https://github.com/koalaman/shellcheck
   ```

3. **Verify Installation**
   ```bash
   # Test all scripts
   ./tests/test-integration.sh
   
   # Test individual platforms
   ./tests/test-bash.sh
   ./tests/test-posix.sh
   ```

## Project Structure

```
mcp-python-bootstrap/
├── scripts/                    # Bootstrap scripts
│   ├── universal-bootstrap.sh  # Universal entry point
│   ├── bootstrap-bash.sh       # Bash implementation
│   ├── bootstrap-posix.sh      # POSIX shell implementation
│   ├── bootstrap.ps1           # PowerShell implementation
│   └── install-local.sh        # Local installation script
├── examples/                   # Example configurations
├── tests/                      # Test scripts
├── docs/                       # Documentation
└── .github/                    # GitHub workflows
```

**Note:** Version numbers are managed within each script file via the `SCRIPT_VERSION` variable.

## Development Guidelines

### Shell Script Standards

1. **POSIX Compatibility**: Core functionality should work in POSIX shell
2. **Error Handling**: Use `set -eu` and proper error checking
3. **Logging**: Consistent logging format across all scripts
4. **Documentation**: Comment complex logic and functions

### Code Style

#### Bash/POSIX Shell
```bash
#!/bin/bash
# or #!/bin/sh for POSIX

set -euo pipefail  # bash
set -eu           # POSIX

# Function naming: snake_case
check_network() {
    local url="$1"
    # Implementation
}

# Variable naming: UPPER_CASE for globals, lower_case for locals
GLOBAL_VAR="value"
local local_var="value"

# Always quote variables
if [ "$var" = "value" ]; then
    echo "Match found"
fi
```

#### PowerShell
```powershell
# Function naming: PascalCase
function Test-NetworkConnectivity {
    param([string]$Url)
    # Implementation
}

# Variable naming: PascalCase
$GlobalVar = "value"
$localVar = "value"

# Use approved verbs
function Get-PlatformInfo { }
function Set-Configuration { }
function Test-Connectivity { }
```

### Testing Requirements

1. **Script Syntax**: All scripts must pass syntax checking
2. **Platform Testing**: Test on target platforms when possible
3. **Integration Tests**: Add tests for new functionality
4. **Error Handling**: Test error conditions and recovery

### Documentation Requirements

1. **Code Comments**: Explain complex logic
2. **Function Documentation**: Document parameters and return values
3. **User Documentation**: Update relevant docs for user-facing changes
4. **Examples**: Provide usage examples for new features

## Making Changes

### Adding New Features

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Implement Changes**
   - Follow existing patterns and conventions
   - Add appropriate error handling
   - Include logging for debugging

3. **Add Tests**
   ```bash
   # Add to existing test files or create new ones
   ./tests/test-your-feature.sh
   ```

4. **Update Documentation**
   - Update README.md if needed
   - Add to appropriate docs/ files
   - Update examples if applicable

5. **Test Thoroughly**
   ```bash
   # Run all tests
   ./tests/test-integration.sh
   
   # Test on different platforms
   # Test with different package specifications
   ```

### Bug Fixes

1. **Reproduce the Issue**
   - Create a minimal test case
   - Document the problem clearly

2. **Fix the Root Cause**
   - Don't just fix symptoms
   - Consider edge cases

3. **Add Regression Tests**
   - Ensure the bug doesn't reoccur
   - Test both fix and edge cases

4. **Update Documentation**
   - Add to troubleshooting guide if relevant
   - Update any incorrect documentation

## Testing

### Local Testing

```bash
# Syntax checking
shellcheck scripts/*.sh

# POSIX compliance
checkbashisms scripts/bootstrap-posix.sh

# Integration tests
./tests/test-integration.sh

# Platform-specific tests
./tests/test-bash.sh
./tests/test-posix.sh
powershell ./tests/test-powershell.ps1
```

### Manual Testing

```bash
# Test with different package specs
./scripts/universal-bootstrap.sh mcp-server-filesystem
./scripts/universal-bootstrap.sh mcp-server-database==1.0.0
./scripts/universal-bootstrap.sh git+https://github.com/user/repo.git

# Test error conditions
./scripts/universal-bootstrap.sh nonexistent-package
./scripts/universal-bootstrap.sh ""

# Test different environments
export MCP_BOOTSTRAP_CACHE_DIR="/tmp/test-cache"
./scripts/universal-bootstrap.sh mcp-server-filesystem
```

### CI/CD Testing

The project uses GitHub Actions for automated testing:

- **Syntax Validation**: Checks all scripts for syntax errors
- **Cross-Platform Testing**: Tests on Linux, macOS, and Windows
- **Container Testing**: Tests in Alpine, Debian, and Ubuntu containers
- **Integration Testing**: End-to-end functionality tests

## Submitting Changes

### Pull Request Process

1. **Ensure Tests Pass**
   ```bash
   ./tests/test-integration.sh
   ```

2. **Update Version** (if needed)
   ```bash
   # Update SCRIPT_VERSION in the modified script file(s)
   # For example, in scripts/universal-bootstrap.sh:
   SCRIPT_VERSION="1.3.51"

   # And in scripts/bootstrap-bash.sh:
   SCRIPT_VERSION="1.3.40"
   ```
   **Important:** Each script maintains its own version number. Update only the scripts you modified.

3. **Create Pull Request**
   - Use descriptive title and description
   - Reference any related issues
   - Include testing information

4. **Respond to Reviews**
   - Address all feedback
   - Update tests if requested
   - Rebase if needed

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring

## Testing
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Tested on multiple platforms
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

## Release Process

### Version Numbering

We use Semantic Versioning (SemVer):
- **MAJOR.MINOR.PATCH** (e.g., 1.2.0)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Creating a Release

1. **Update Version**
   ```bash
   # Update SCRIPT_VERSION in each modified script
   # Example: In scripts/universal-bootstrap.sh
   SCRIPT_VERSION="1.4.0"

   git add scripts/universal-bootstrap.sh scripts/bootstrap-bash.sh
   git commit -m "Bump version to 1.2.0"
   ```

2. **Create Tag**
   ```bash
   git tag -a v1.2.0 -m "Release version 1.2.0"
   git push origin v1.2.0
   ```

3. **Create GitHub Release**
   - Use the GitHub web interface
   - Include release notes
   - Highlight breaking changes

## Code Review Guidelines

### For Contributors

1. **Self-Review**: Review your own code before submitting
2. **Small PRs**: Keep changes focused and reviewable
3. **Clear Commits**: Use descriptive commit messages
4. **Documentation**: Update docs for user-facing changes

### For Reviewers

1. **Functionality**: Does the code do what it's supposed to?
2. **Style**: Does it follow project conventions?
3. **Safety**: Are there security or reliability concerns?
4. **Maintainability**: Is the code readable and well-structured?
5. **Testing**: Are there adequate tests?

## Security Considerations

### Security Guidelines

1. **Input Validation**: Validate all user inputs
2. **Secure Downloads**: Use HTTPS and verify checksums when possible
3. **Temporary Files**: Clean up temporary files securely
4. **Environment Variables**: Be careful with sensitive data

### Reporting Security Issues

For security vulnerabilities:
1. **Don't** create public issues
2. **Do** email security concerns privately
3. Allow time for fixes before disclosure

## Getting Help

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Requests**: Code review and discussion

### Resources

- [Bash Manual](https://www.gnu.org/software/bash/manual/)
- [POSIX Shell Standard](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [ShellCheck](https://www.shellcheck.net/)

## Recognition

Contributors are recognized in:
- GitHub contributor graphs
- Release notes for significant contributions
- Special recognition for major features or fixes

Thank you for contributing to MCP Python Bootstrap!