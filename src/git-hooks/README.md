
# Git Hooks Setup (git-hooks)

Installs and configures modular git hooks system with argbash-enhanced setup script

## Example Usage

```json
"features": {
    "ghcr.io/compusib/devcontainer_features/git-hooks:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| hooksDir | Directory containing git hooks relative to workspace root | string | git/hooks |
| autoSetup | Space-separated list of paths containing git repositories for automatic hook setup. Set to empty string to disable auto-setup. | string | /workspaces |
| verbose | Enable verbose output during setup | boolean | false |
| gitSafeDirectory | Git safe.directory pattern to configure (supports wildcards). Set to empty string to skip configuration. | string | /workspaces/* |

# Setup Git Hooks Feature

This devcontainer feature installs the `setup-git-hooks` script system-wide, making it available from any directory in the container.

## What it installs

- **Main script**: `/usr/local/bin/setup-git-hooks` - The main executable script
- **Library**: `/usr/local/lib/features/git-hooks` - Contains a common bash include library, argument parsing logic and its templates
- **Git configuration**: Configures git safe.directory to prevent "unsafe repository" warnings

## Configuration Options

### `hooksDir` (string, default: "git/hooks")
Directory containing git hooks relative to workspace root.

### `autoSetup` (string, default: "/workspaces")
Space-separated list of paths containing git repositories for automatic hook setup. Set to empty string to disable auto-setup. Each path should point to a directory containing a git repository where hooks should be installed automatically after container creation.

### `verbose` (boolean, default: false)
Enable verbose output during setup.

### `gitSafeDirectory` (string, default: "/workspaces/*")
Git safe.directory pattern to configure (supports wildcards). Set to empty string to skip configuration.

Example configuration in `devcontainer.json`:
```json
"features": {
  "./features/git-hooks": {
    "hooksDir": "git/hooks",
    "autoSetup": "/workspaces/myproject /data/another-repo",
    "verbose": false,
    "gitSafeDirectory": "/data/workspace/ansible"
  }
}
```

## Usage

Once the feature is installed, you can use the `setup-git-hooks` command from anywhere:

```bash
# Show help and all available options
setup-git-hooks --help

# List available hook types in the current git repository
setup-git-hooks --list

# Install git hooks (dry run first to see what would happen)
setup-git-hooks --dry-run --verbose

# Actually install the hooks
setup-git-hooks

# Force reinstall hooks (overwrite existing)
setup-git-hooks --force

# Clean installed hooks
setup-git-hooks --clean
```

## Features

- **System-wide availability**: Available from any directory
- **Full CLI**: Complete argument parsing with help, dry-run, verbose modes
- **Robust error handling**: Graceful handling of missing directories and git
- **Modular design**: Uses argbash for argument parsing
- **Container-optimized**: Works in both git repositories and non-git environments

## Development

The feature source files are located in:
- `scripts/setup-git-hooks` - Main script
- `scripts/args/` - Argbash templates and generated parsing code

To modify the feature, edit the files in the `scripts/` directory and reinstall the feature.

## Installation

This feature is automatically installed when the devcontainer is built, as it's included in the `devcontainer.json` features list.

Manual installation:
```bash
.devcontainer/features/git-hooks/install.sh
```


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/compusib/devcontainer_features/blob/main/src/git-hooks/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
