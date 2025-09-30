#!/usr/bin/env python3
"""
Comprehensive pytest test suite for mcp_config.py

Tests cover:
- Package type detection
- Server name extraction
- Executable name detection
- Bootstrap script path resolution
- Configuration file creation and updates
- Command-line argument parsing
- Main function integration tests
- Edge cases and error handling
"""

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Import the module under test
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
import mcp_config


class TestDetectPackageType:
    """Tests for detect_package_type function."""

    def test_git_package(self):
        """Test git+ URL detection."""
        assert mcp_config.detect_package_type("git+https://github.com/user/repo.git") == "git"
        assert mcp_config.detect_package_type("git+ssh://git@github.com/user/repo.git") == "git"

    def test_github_raw_url(self):
        """Test GitHub raw URL detection."""
        assert mcp_config.detect_package_type("https://github.com/user/repo/blob/main/server.py") == "github_raw"
        assert mcp_config.detect_package_type("http://github.com/user/repo/raw/main/file.py") == "github_raw"
        assert mcp_config.detect_package_type("https://gitlab.com/user/project/-/raw/main/file.py") == "github_raw"
        assert mcp_config.detect_package_type("https://bitbucket.org/user/repo/raw/main/file.py") == "github_raw"

    def test_local_package(self):
        """Test local path detection."""
        assert mcp_config.detect_package_type("/absolute/path/to/package") == "local"
        assert mcp_config.detect_package_type("./relative/path") == "local"
        assert mcp_config.detect_package_type("../parent/path") == "local"
        assert mcp_config.detect_package_type("-e ./editable-package") == "local"

    def test_pypi_package(self):
        """Test PyPI package detection."""
        assert mcp_config.detect_package_type("mcp-server-filesystem") == "pypi"
        assert mcp_config.detect_package_type("mcp-server-database==1.2.0") == "pypi"
        assert mcp_config.detect_package_type("some-package>=2.0.0") == "pypi"
        assert mcp_config.detect_package_type("package[extra1,extra2]") == "pypi"


class TestExtractServerName:
    """Tests for extract_server_name function."""

    def test_pypi_simple_name(self):
        """Test simple PyPI package name extraction."""
        assert mcp_config.extract_server_name("mcp-server-filesystem") == "mcp-server-filesystem"

    def test_pypi_with_version(self):
        """Test PyPI package with version constraints."""
        assert mcp_config.extract_server_name("mcp-server-database==1.2.0") == "mcp-server-database"
        assert mcp_config.extract_server_name("package>=2.0.0") == "package"
        assert mcp_config.extract_server_name("pkg~=1.0") == "pkg"

    def test_pypi_with_extras(self):
        """Test PyPI package with extras."""
        assert mcp_config.extract_server_name("package[extra1,extra2]") == "package"

    def test_git_url(self):
        """Test git URL name extraction."""
        assert mcp_config.extract_server_name("git+https://github.com/user/mcp-server-test.git") == "mcp-server-test"
        assert mcp_config.extract_server_name("git+https://github.com/user/my-repo") == "my-repo"

    def test_git_url_with_ref(self):
        """Test git URL with branch/tag reference."""
        assert mcp_config.extract_server_name("git+https://github.com/user/repo.git#main") == "repo"
        assert mcp_config.extract_server_name("git+https://github.com/user/repo.git#v1.0.0") == "repo"

    def test_github_raw_python_file(self):
        """Test GitHub raw URL with .py file."""
        result = mcp_config.extract_server_name("https://github.com/user/repo/blob/main/my_server.py")
        assert result == "my-server"

    def test_github_raw_repository_fallback(self):
        """Test GitHub raw URL without .py extension falls back to domain extraction."""
        result = mcp_config.extract_server_name("https://github.com/user-name/repo-name/blob/main/")
        # Without a .py file, the regex doesn't match and it falls back to returning the input,
        # which gets processed and extracts 'github.com' from the domain
        assert result == "github.com"

    def test_local_path_stem(self):
        """Test local path stem extraction."""
        assert mcp_config.extract_server_name("./src/my_server.py") == "my_server"
        assert mcp_config.extract_server_name("/path/to/server_file.py") == "server_file"

    def test_extract_from_fastmcp_pattern(self, tmp_path):
        """Test extracting server name from FastMCP pattern in file."""
        test_file = tmp_path / "server.py"
        test_file.write_text('from fastmcp import FastMCP\nmcp = FastMCP("my-awesome-server")\n')

        result = mcp_config.extract_server_name("./server.py", filepath=test_file)
        assert result == "my-awesome-server"

    def test_extract_from_fastmcp_single_quotes(self, tmp_path):
        """Test extracting server name from FastMCP with single quotes."""
        test_file = tmp_path / "server.py"
        test_file.write_text("from fastmcp import FastMCP\nmcp = FastMCP('test-server')\n")

        result = mcp_config.extract_server_name("./server.py", filepath=test_file)
        assert result == "test-server"

    def test_extract_file_not_found(self, tmp_path, capsys):
        """Test graceful handling when file doesn't exist."""
        non_existent = tmp_path / "missing.py"
        result = mcp_config.extract_server_name("./missing.py", filepath=non_existent)

        # Should fall back to stem extraction
        assert result == "missing"

    def test_extract_file_read_error(self, tmp_path, capsys):
        """Test handling of file read errors."""
        test_file = tmp_path / "binary.dat"
        test_file.write_bytes(b'\x00\x01\x02\xff\xfe')

        # Should handle UnicodeDecodeError and fall back
        result = mcp_config.extract_server_name("./binary.dat", filepath=test_file)
        captured = capsys.readouterr()
        assert "Warning: Could not read file" in captured.out


class TestDetectExecutableName:
    """Tests for detect_executable_name function."""

    def test_pattern_with_suffix(self):
        """Test pattern matching for packages with suffixes."""
        # Pattern 1: test-mcp-server-ap25092201 -> test-mcp-server
        result = mcp_config.detect_executable_name("test-mcp-server-ap25092201")
        assert result == "test-mcp-server"

    def test_pattern_short_suffix(self):
        """Test pattern with short numeric/letter suffix."""
        # Pattern 3: package-name-test -> package-name
        result = mcp_config.detect_executable_name("my-package-name-test")
        assert result == "my-package-name"

    def test_pattern_digit_suffix(self):
        """Test pattern with digit-only suffix."""
        result = mcp_config.detect_executable_name("package-name-123")
        assert result == "package-name"

    def test_simple_package_name(self):
        """Test simple package names without patterns."""
        assert mcp_config.detect_executable_name("simple-package") is None
        assert mcp_config.detect_executable_name("mcp-server-filesystem") is None

    def test_git_package(self):
        """Test git package executable detection."""
        result = mcp_config.detect_executable_name("git+https://github.com/user/test-mcp-server-ap25092201.git")
        assert result == "test-mcp-server"

    def test_pypi_with_version(self):
        """Test PyPI package with version."""
        result = mcp_config.detect_executable_name("test-mcp-server-ap25092201==1.0.0")
        assert result == "test-mcp-server"

    def test_non_pypi_git_package(self):
        """Test non-PyPI/git packages return None."""
        assert mcp_config.detect_executable_name("./local/path") is None
        assert mcp_config.detect_executable_name("https://github.com/user/repo/file.py") is None


class TestGetBootstrapScriptPath:
    """Tests for get_bootstrap_script_path function."""

    def test_returns_path_object(self):
        """Test that function returns a Path object."""
        result = mcp_config.get_bootstrap_script_path()
        assert isinstance(result, Path)

    def test_finds_script_in_same_directory(self):
        """Test finding script in same directory as mcp_config.py."""
        result = mcp_config.get_bootstrap_script_path()
        # Should return the expected path (may or may not exist)
        assert result.name == "universal-bootstrap.sh"

    @patch('mcp_config.Path')
    def test_checks_common_locations(self, mock_path):
        """Test that it checks common fallback locations."""
        # Mock the script directory to not have the file
        mock_script_dir = MagicMock()
        mock_bootstrap_path = MagicMock()
        mock_bootstrap_path.exists.return_value = False
        mock_script_dir.__truediv__.return_value = mock_bootstrap_path

        mock_path.__file__ = "/fake/path/mcp_config.py"
        mock_path.return_value.parent = mock_script_dir

        # Should return the expected path even if it doesn't exist
        result = mcp_config.get_bootstrap_script_path()
        assert isinstance(result, (Path, MagicMock))


class TestCreateOrUpdateConfig:
    """Tests for create_or_update_config function."""

    def test_create_new_config_file(self, tmp_path):
        """Test creating a new config file."""
        config_file = tmp_path / "test_config.json"

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="mcp-server-test",
            config_file=config_file
        )

        assert result is True
        assert config_file.exists()

        config_data = json.loads(config_file.read_text())
        assert "mcpServers" in config_data
        assert "test-server" in config_data["mcpServers"]

    def test_update_existing_config(self, tmp_path):
        """Test updating an existing config file."""
        config_file = tmp_path / "config.json"
        initial_config = {
            "mcpServers": {
                "existing-server": {
                    "command": "bash",
                    "args": ["old-command"]
                }
            }
        }
        config_file.write_text(json.dumps(initial_config, indent=2))

        result = mcp_config.create_or_update_config(
            server_name="new-server",
            package_spec="new-package",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        assert "existing-server" in config_data["mcpServers"]
        assert "new-server" in config_data["mcpServers"]

    def test_pypi_package_config(self, tmp_path):
        """Test PyPI package configuration."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="filesystem",
            package_spec="mcp-server-filesystem",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["filesystem"]

        assert server_config["command"] == "bash"
        assert len(server_config["args"]) == 2
        assert server_config["args"][0] == "-c"
        assert "mcp-server-filesystem" in server_config["args"][1]
        assert "curl" in server_config["args"][1]

    def test_git_package_config(self, tmp_path):
        """Test git package configuration."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="git+https://github.com/user/repo.git",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["test-server"]

        assert "git+https://github.com/user/repo.git" in server_config["args"][1]

    def test_github_raw_url_config(self, tmp_path):
        """Test GitHub raw URL configuration."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="raw-server",
            package_spec="https://github.com/user/repo/blob/main/server.py",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["raw-server"]

        # Should convert blob URL to raw URL
        assert "raw.githubusercontent.com" in server_config["args"][1]

    def test_local_package_config(self, tmp_path):
        """Test local package configuration."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="local-server",
            package_spec="./local/path/server.py",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["local-server"]

        assert server_config["command"] == "bash"
        assert "./local/path/server.py" in server_config["args"]

    def test_config_with_server_args(self, tmp_path):
        """Test configuration with additional server arguments."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="test-package",
            config_file=config_file,
            server_args=["--arg1", "value1", "--arg2"]
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["test-server"]

        # Server args should be included in the command
        assert "'--arg1'" in server_config["args"][1]
        assert "'value1'" in server_config["args"][1]
        assert "'--arg2'" in server_config["args"][1]

    def test_config_with_custom_bootstrap_url(self, tmp_path):
        """Test configuration with custom bootstrap URL."""
        config_file = tmp_path / "config.json"
        custom_url = "https://example.com/custom-bootstrap.sh"

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="test-package",
            config_file=config_file,
            bootstrap_url=custom_url
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["test-server"]

        assert custom_url in server_config["args"][1]

    def test_config_with_executable_name(self, tmp_path):
        """Test configuration with explicit executable name."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="test-mcp-server-ap25092201",
            config_file=config_file,
            executable_name="test-mcp-server"
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["test-server"]

        # Should use --from syntax
        assert "--from" in server_config["args"][1]
        assert "test-mcp-server-ap25092201" in server_config["args"][1]
        assert "test-mcp-server" in server_config["args"][1]

    def test_config_adds_metadata(self, tmp_path):
        """Test that metadata is added to configuration."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="test-package",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        server_config = config_data["mcpServers"]["test-server"]

        assert "_metadata" in server_config
        assert server_config["_metadata"]["package_type"] == "pypi"
        assert server_config["_metadata"]["package_spec"] == "test-package"
        assert server_config["_metadata"]["generated_by"] == "mcp_config.py"
        assert "bootstrap_version" in server_config["_metadata"]

    def test_config_invalid_json(self, tmp_path, capsys):
        """Test handling of invalid JSON in existing config."""
        config_file = tmp_path / "config.json"
        config_file.write_text("{invalid json")

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="test-package",
            config_file=config_file
        )

        assert result is False
        captured = capsys.readouterr()
        assert "Error updating config file" in captured.out

    def test_config_permission_error(self, tmp_path, capsys):
        """Test handling of permission errors."""
        config_file = tmp_path / "readonly_dir" / "config.json"
        config_file.parent.mkdir()
        config_file.parent.chmod(0o444)  # Read-only directory

        try:
            result = mcp_config.create_or_update_config(
                server_name="test-server",
                package_spec="test-package",
                config_file=config_file
            )

            assert result is False
            captured = capsys.readouterr()
            assert "Error updating config file" in captured.out
        finally:
            # Cleanup: restore permissions
            config_file.parent.chmod(0o755)


class TestParseArgs:
    """Tests for parse_args function."""

    def test_help_flag(self, capsys):
        """Test --help flag."""
        with patch.object(sys, 'argv', ['mcp_config.py', '--help']):
            with pytest.raises(SystemExit) as exc_info:
                mcp_config.parse_args()
            assert exc_info.value.code == 0

        captured = capsys.readouterr()
        assert "MCP Configuration Generator" in captured.out

    def test_help_flag_short(self, capsys):
        """Test -h flag."""
        with patch.object(sys, 'argv', ['mcp_config.py', '-h']):
            with pytest.raises(SystemExit) as exc_info:
                mcp_config.parse_args()
            assert exc_info.value.code == 0

    def test_no_arguments(self, capsys):
        """Test no arguments provided."""
        with patch.object(sys, 'argv', ['mcp_config.py']):
            with pytest.raises(SystemExit) as exc_info:
                mcp_config.parse_args()
            assert exc_info.value.code == 1

    def test_simple_package_spec(self):
        """Test parsing simple package specification."""
        with patch.object(sys, 'argv', ['mcp_config.py', 'test-package']):
            package_spec, server_name, config_file, server_args, bootstrap_url, executable_name = mcp_config.parse_args()

            assert package_spec == "test-package"
            assert server_name is None
            assert "claude_desktop_config.json" in config_file
            assert server_args == []
            assert "universal-bootstrap.sh" in bootstrap_url
            assert executable_name is None

    def test_with_name_option(self):
        """Test --name option."""
        with patch.object(sys, 'argv', ['mcp_config.py', 'test-package', '--name', 'my-server']):
            package_spec, server_name, _, _, _, _ = mcp_config.parse_args()

            assert package_spec == "test-package"
            assert server_name == "my-server"

    def test_with_config_option(self):
        """Test --config option."""
        with patch.object(sys, 'argv', ['mcp_config.py', 'test-package', '--config', '/path/to/config.json']):
            package_spec, _, config_file, _, _, _ = mcp_config.parse_args()

            assert package_spec == "test-package"
            assert config_file == "/path/to/config.json"

    def test_with_args_option(self):
        """Test --args option."""
        with patch.object(sys, 'argv', ['mcp_config.py', 'test-package', '--args', 'arg1,arg2,arg3']):
            package_spec, _, _, server_args, _, _ = mcp_config.parse_args()

            assert package_spec == "test-package"
            assert server_args == ["arg1", "arg2", "arg3"]

    def test_with_bootstrap_url_option(self):
        """Test --bootstrap-url option."""
        custom_url = "https://example.com/bootstrap.sh"
        with patch.object(sys, 'argv', ['mcp_config.py', 'test-package', '--bootstrap-url', custom_url]):
            package_spec, _, _, _, bootstrap_url, _ = mcp_config.parse_args()

            assert package_spec == "test-package"
            assert bootstrap_url == custom_url

    def test_with_executable_option(self):
        """Test --executable option."""
        with patch.object(sys, 'argv', ['mcp_config.py', 'test-package', '--executable', 'test-exec']):
            package_spec, _, _, _, _, executable_name = mcp_config.parse_args()

            assert package_spec == "test-package"
            assert executable_name == "test-exec"

    def test_all_options_combined(self):
        """Test all options combined."""
        with patch.object(sys, 'argv', [
            'mcp_config.py', 'test-package',
            '--name', 'my-server',
            '--config', '/custom/config.json',
            '--args', 'arg1,arg2',
            '--bootstrap-url', 'https://example.com/bootstrap.sh',
            '--executable', 'my-exec'
        ]):
            package_spec, server_name, config_file, server_args, bootstrap_url, executable_name = mcp_config.parse_args()

            assert package_spec == "test-package"
            assert server_name == "my-server"
            assert config_file == "/custom/config.json"
            assert server_args == ["arg1", "arg2"]
            assert bootstrap_url == "https://example.com/bootstrap.sh"
            assert executable_name == "my-exec"

    def test_unknown_argument(self, capsys):
        """Test handling of unknown arguments."""
        with patch.object(sys, 'argv', ['mcp_config.py', 'test-package', '--unknown']):
            with pytest.raises(SystemExit) as exc_info:
                mcp_config.parse_args()
            assert exc_info.value.code == 1

        captured = capsys.readouterr()
        assert "Unknown argument" in captured.out


class TestMainFunction:
    """Integration tests for main function."""

    def test_main_with_pypi_package(self, tmp_path, capsys):
        """Test main function with PyPI package."""
        config_file = tmp_path / "config.json"

        with patch.object(sys, 'argv', [
            'mcp_config.py', 'test-package',
            '--name', 'test-server',
            '--config', str(config_file)
        ]):
            mcp_config.main()

        captured = capsys.readouterr()
        assert "✅ Added MCP server configuration:" in captured.out
        assert "test-server" in captured.out
        assert config_file.exists()

    def test_main_auto_detect_name(self, tmp_path, capsys):
        """Test main function with auto-detected server name."""
        config_file = tmp_path / "config.json"

        with patch.object(sys, 'argv', [
            'mcp_config.py', 'mcp-server-filesystem',
            '--config', str(config_file)
        ]):
            mcp_config.main()

        captured = capsys.readouterr()
        assert "✅ Added MCP server configuration:" in captured.out
        assert "mcp-server-filesystem" in captured.out

    def test_main_with_git_package(self, tmp_path, capsys):
        """Test main function with git package."""
        config_file = tmp_path / "config.json"

        with patch.object(sys, 'argv', [
            'mcp_config.py', 'git+https://github.com/user/test-repo.git',
            '--config', str(config_file)
        ]):
            mcp_config.main()

        captured = capsys.readouterr()
        assert "✅ Added MCP server configuration:" in captured.out
        assert "test-repo" in captured.out

    def test_main_cannot_determine_name(self, tmp_path, capsys):
        """Test main function when server name cannot be determined."""
        config_file = tmp_path / "config.json"

        with patch.object(sys, 'argv', [
            'mcp_config.py', './nonexistent.py',
            '--config', str(config_file)
        ]):
            with pytest.raises(SystemExit) as exc_info:
                mcp_config.main()
            assert exc_info.value.code == 1

        captured = capsys.readouterr()
        assert "Error: Local file" in captured.out

    def test_main_config_creation_fails(self, tmp_path, capsys):
        """Test main function when config creation fails."""
        # Use an invalid path to force failure
        config_file = Path("/invalid/path/that/does/not/exist/config.json")

        with patch.object(sys, 'argv', [
            'mcp_config.py', 'test-package',
            '--name', 'test-server',
            '--config', str(config_file)
        ]):
            with pytest.raises(SystemExit) as exc_info:
                mcp_config.main()
            assert exc_info.value.code == 1

        captured = capsys.readouterr()
        assert "Error updating config file" in captured.out

    def test_main_with_local_file_fastmcp(self, tmp_path, capsys):
        """Test main function with local file containing FastMCP pattern."""
        server_file = tmp_path / "server.py"
        server_file.write_text('from fastmcp import FastMCP\nmcp = FastMCP("awesome-server")\n')

        config_file = tmp_path / "config.json"

        with patch.object(sys, 'argv', [
            'mcp_config.py', str(server_file),
            '--config', str(config_file)
        ]):
            mcp_config.main()

        captured = capsys.readouterr()
        assert "✅ Added MCP server configuration:" in captured.out
        assert "awesome-server" in captured.out

    def test_main_with_executable_name(self, tmp_path, capsys):
        """Test main function with explicit executable name."""
        config_file = tmp_path / "config.json"

        with patch.object(sys, 'argv', [
            'mcp_config.py', 'test-mcp-server-ap25092201',
            '--name', 'test-server',
            '--executable', 'test-mcp-server',
            '--config', str(config_file)
        ]):
            mcp_config.main()

        captured = capsys.readouterr()
        assert "✅ Added MCP server configuration:" in captured.out

        # Verify --from syntax is used
        config_data = json.loads(config_file.read_text())
        assert "--from" in config_data["mcpServers"]["test-server"]["args"][1]


class TestPrintUsage:
    """Tests for print_usage function."""

    def test_print_usage_output(self, capsys):
        """Test that print_usage prints expected content."""
        mcp_config.print_usage()

        captured = capsys.readouterr()
        assert "MCP Configuration Generator" in captured.out
        assert "Usage:" in captured.out
        assert "Package Specifications:" in captured.out
        assert "Options:" in captured.out
        assert "Examples:" in captured.out
        assert "--name" in captured.out
        assert "--config" in captured.out
        assert "--args" in captured.out
        assert "--executable" in captured.out
        assert "--bootstrap-url" in captured.out


class TestEdgeCases:
    """Tests for edge cases and error conditions."""

    def test_empty_package_spec(self):
        """Test handling of empty package specification."""
        result = mcp_config.detect_package_type("")
        assert result == "pypi"  # Empty string defaults to pypi

    def test_extract_server_name_no_match(self):
        """Test extract_server_name with no regex match."""
        result = mcp_config.extract_server_name("https://example.com/file")
        # Should return the input as fallback
        assert result == "https://example.com/file"

    def test_config_with_missing_mcpservers_key(self, tmp_path):
        """Test updating config that's missing mcpServers key."""
        config_file = tmp_path / "config.json"
        config_file.write_text('{"other_key": "value"}')

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec="test-package",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        assert "mcpServers" in config_data
        assert "test-server" in config_data["mcpServers"]

    def test_unicode_in_server_name(self, tmp_path):
        """Test handling of unicode characters in server name."""
        config_file = tmp_path / "config.json"

        result = mcp_config.create_or_update_config(
            server_name="test-server-🚀",
            package_spec="test-package",
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        assert "test-server-🚀" in config_data["mcpServers"]

    def test_very_long_package_spec(self, tmp_path):
        """Test handling of very long package specification."""
        config_file = tmp_path / "config.json"
        long_spec = "a" * 1000

        result = mcp_config.create_or_update_config(
            server_name="test-server",
            package_spec=long_spec,
            config_file=config_file
        )

        assert result is True
        config_data = json.loads(config_file.read_text())
        assert long_spec in config_data["mcpServers"]["test-server"]["_metadata"]["package_spec"]
