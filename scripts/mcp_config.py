#!/usr/bin/env python3
"""
MCP Configuration Generator with Bootstrap Integration
Generates MCP server configuration using the universal bootstrap system.
Supports PyPI packages, Git repositories, and local development.
"""

import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import (
    Any,
    Dict,
    List,
    Optional,
)


def detect_package_type(package_spec: str) -> str:
    """Detect the type of package specification."""
    if package_spec.startswith("git+"):
        return "git"
    elif package_spec.startswith(("https://github.com/", "http://github.com/", "https://gitlab.com/", "https://bitbucket.org/")):
        return "github_raw"
    elif package_spec.startswith(("/", "./", "../")) or package_spec.startswith("-e"):
        return "local"
    else:
        return "pypi"


def extract_server_name(package_spec: str, filepath: Optional[Path] = None) -> Optional[str]:
    """Extract server name from package spec or FastMCP() pattern in file."""
    # For local files, try to extract from FastMCP pattern
    if filepath and filepath.exists():
        try:
            content = filepath.read_text(encoding="utf-8")
            # Look for FastMCP("servername") pattern
            pattern = r'FastMCP\(["\']([^"\']*)["\']'
            match = re.search(pattern, content)
            if match:
                return match.group(1)
        except Exception as e:
            print(f"Warning: Could not read file {filepath}: {e}")

    # Fallback: derive from package spec
    package_type = detect_package_type(package_spec)

    if package_type == "pypi":
        # Extract package name from PyPI spec (remove version constraints)
        name = re.split(r'[><=!~]', package_spec.split('[')[0])[0]
        return name.replace('-', '_').replace('_', '-')
    elif package_type == "git":
        # Extract from git URL
        match = re.search(r'/([^/]+?)(?:\.git)?(?:#.*)?$', package_spec)
        if match:
            return match.group(1)
    elif package_type == "github_raw":
        # Extract from GitHub raw URL (e.g., filename without .py)
        match = re.search(r'/([^/]+?)\.py$', package_spec)
        if match:
            return match.group(1).replace('_', '-')
        # Fallback: extract repository name
        match = re.search(r'/([^/]+?)/[^/]+?/[^/]+?/', package_spec)
        if match:
            return match.group(1)
    elif "/" in package_spec:
        # Local path - use directory name
        return Path(package_spec).stem

    return package_spec


def get_bootstrap_script_path() -> Path:
    """Get the path to the universal bootstrap script."""
    # Look for bootstrap script relative to this script
    script_dir = Path(__file__).parent
    bootstrap_path = script_dir / "universal-bootstrap.sh"

    if bootstrap_path.exists():
        return bootstrap_path

    # Fallback: look in common locations
    for path in [
        Path.home() / ".mcp" / "bootstrap" / "universal-bootstrap.sh",
        Path("/usr/local/bin/universal-bootstrap.sh"),
        script_dir.parent / "scripts" / "universal-bootstrap.sh"
    ]:
        if path.exists():
            return path

    # Return the expected path even if it doesn't exist
    return bootstrap_path


def create_or_update_config(
    server_name: str,
    package_spec: str,
    config_file: Path,
    server_args: Optional[List[str]] = None,
    bootstrap_url: str = "https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh"
) -> bool:
    """Create or update the MCP configuration file using bootstrap script."""
    try:
        # Create default config if file doesn't exist
        if not config_file.exists():
            default_config: Dict[str, Any] = {"mcpServers": {}}
            config_file.parent.mkdir(parents=True, exist_ok=True)
            config_file.write_text(json.dumps(default_config, indent=2))

        # Load existing config
        config_data = json.loads(config_file.read_text(encoding="utf-8"))

        # Ensure mcpServers exists
        if "mcpServers" not in config_data:
            config_data["mcpServers"] = {}

        # Build configuration based on package type
        package_type = detect_package_type(package_spec)

        if package_type == "github_raw":
            # For GitHub raw URLs, convert to proper format and use remote bootstrap
            # Convert GitHub blob URLs to raw URLs if needed
            if "/blob/" in package_spec:
                # Convert github.com/user/repo/blob/branch/file to raw.githubusercontent.com/user/repo/branch/file
                raw_url = package_spec.replace("github.com/", "raw.githubusercontent.com/").replace("/blob/", "/")
            else:
                raw_url = package_spec

            # Create remote bootstrap configuration
            bootstrap_cmd = f"curl -sSL {bootstrap_url} | sh -s --"
            if server_args:
                server_args_str = " " + " ".join(f'"{arg}"' for arg in server_args)
            else:
                server_args_str = ""

            config_data["mcpServers"][server_name] = {
                "command": "sh",
                "args": [
                    "-c",
                    f'{bootstrap_cmd} "{raw_url}"{server_args_str}'
                ]
            }
        else:
            # For local/PyPI/git packages, use local bootstrap script
            bootstrap_script = get_bootstrap_script_path()
            args = [str(bootstrap_script), package_spec]
            if server_args:
                args.extend(server_args)

            config_data["mcpServers"][server_name] = {
                "command": "bash",
                "args": args
            }

        # Add comment/metadata for better understanding
        if server_name not in config_data["mcpServers"] or "_metadata" not in config_data["mcpServers"][server_name]:
            config_data["mcpServers"][server_name]["_metadata"] = {
                "package_type": detect_package_type(package_spec),
                "package_spec": package_spec,
                "generated_by": "mcp_config.py",
                "bootstrap_version": "1.2.0"
            }

        # Write updated config using a temporary file for atomic operation
        with tempfile.NamedTemporaryFile(mode="w", dir=config_file.parent, delete=False) as tmp:
            json.dump(config_data, tmp, indent=2)
            tmp_path = Path(tmp.name)

        # Atomically replace the original file
        tmp_path.replace(config_file)

        return True
    except Exception as e:
        print(f"Error updating config file {config_file}: {e}")
        return False


def print_usage():
    """Print usage information."""
    print("MCP Configuration Generator with Bootstrap Integration")
    print("")
    print("Usage:")
    print("  python3 mcp_config.py <package_spec> [options]")
    print("")
    print("Package Specifications:")
    print("  PyPI package:        mcp-server-filesystem")
    print("  With version:        mcp-server-database==1.2.0")
    print("  Git repository:      git+https://github.com/user/mcp-server.git")
    print("  Local development:   ./src/my_server.py")
    print("  Editable install:    -e ./my-package")
    print("")
    print("Options:")
    print("  --name NAME         Server name (auto-detected if not provided)")
    print("  --config FILE       Config file path (default: Claude desktop config)")
    print("  --args ARGS         Additional server arguments (comma-separated)")
    print("  --bootstrap-url URL Bootstrap script URL (default: apisani1/mcp-python-bootstrap)")
    print("  --help, -h          Show this help message")
    print("")
    print("Examples:")
    print("  python3 mcp_config.py mcp-server-filesystem")
    print("  python3 mcp_config.py ./src/my_server.py --name my-server")
    print("  python3 mcp_config.py mcp-server-database==1.2.0 --args '--db-path,/tmp/db.sqlite'")
    print("  python3 mcp_config.py https://github.com/user/repo/blob/main/server.py --bootstrap-url https://example.com/bootstrap.sh")


def parse_args():
    """Parse command line arguments."""
    args = sys.argv[1:]
    if not args or "--help" in args or "-h" in args:
        print_usage()
        sys.exit(0 if args else 1)

    package_spec = args[0]
    server_name = None
    config_file_name = None
    server_args = []
    bootstrap_url = "https://raw.githubusercontent.com/apisani1/mcp-python-bootstrap/main/scripts/universal-bootstrap.sh"

    i = 1
    while i < len(args):
        if args[i] == "--name" and i + 1 < len(args):
            server_name = args[i + 1]
            i += 2
        elif args[i] == "--config" and i + 1 < len(args):
            config_file_name = args[i + 1]
            i += 2
        elif args[i] == "--args" and i + 1 < len(args):
            server_args = args[i + 1].split(',')
            i += 2
        elif args[i] == "--bootstrap-url" and i + 1 < len(args):
            bootstrap_url = args[i + 1]
            i += 2
        else:
            print(f"Unknown argument: {args[i]}")
            sys.exit(1)

    # Default config file
    if not config_file_name:
        config_file_name = os.path.expanduser(
            "~/Library/Application Support/Claude/claude_desktop_config.json"
        )

    return package_spec, server_name, config_file_name, server_args, bootstrap_url


def main() -> None:
    """Main function to handle command line arguments and execute the script."""
    package_spec, server_name, config_file_name, server_args, bootstrap_url = parse_args()

    # Auto-detect server name if not provided
    if not server_name:
        # For local files, check if it exists and try to extract from FastMCP pattern
        if detect_package_type(package_spec) == "local":
            filepath = Path(package_spec)
            if not filepath.exists():
                # Try relative to common source locations
                for base_path in [
                    Path("src/mcp_masterclass"),
                    Path("src"),
                    Path(".")
                ]:
                    test_path = base_path / package_spec
                    if test_path.exists():
                        filepath = test_path
                        break
                else:
                    print(f"Error: Local file {package_spec} not found")
                    sys.exit(1)

            server_name = extract_server_name(package_spec, filepath)
        else:
            server_name = extract_server_name(package_spec)

        if not server_name:
            print(f"Error: Could not determine server name. Use --name to specify it.")
            sys.exit(1)

    # Validate bootstrap script exists
    bootstrap_script = get_bootstrap_script_path()
    if not bootstrap_script.exists():
        print(f"Warning: Bootstrap script not found at {bootstrap_script}")
        print("Make sure the universal-bootstrap.sh script is available.")

    # Create or update config file
    config_file = Path(config_file_name)
    if create_or_update_config(server_name, package_spec, config_file, server_args, bootstrap_url):
        package_type = detect_package_type(package_spec)
        print(f"✅ Added MCP server configuration:")
        print(f"   Name: {server_name}")
        print(f"   Type: {package_type}")
        print(f"   Package: {package_spec}")
        if server_args:
            print(f"   Args: {', '.join(server_args)}")
        print(f"   Config: {config_file}")
        if package_type == "github_raw":
            print(f"   Bootstrap: {bootstrap_url}")
        else:
            print(f"   Bootstrap: {bootstrap_script}")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
