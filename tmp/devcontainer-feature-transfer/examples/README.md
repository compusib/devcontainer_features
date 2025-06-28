# DevContainer Feature Examples

This directory contains examples of how to use the setup-git-hooks feature in different scenarios.

## Basic Usage

### Minimal Configuration

```json
{
    "features": {
        "ghcr.io/compusib/devcontainer_features/setup-git-hooks:1": {}
    }
}
```

### Custom Configuration

```json
{
    "features": {
        "ghcr.io/compusib/devcontainer_features/setup-git-hooks:1": {
            "hooksDir": "custom/hooks/path",
            "autoSetup": true,
            "verbose": true,
            "gitSafeDirectory": "/workspaces/*"
        }
    }
}
```

### Manual Setup Only

```json
{
    "features": {
        "ghcr.io/compusib/devcontainer_features/setup-git-hooks:1": {
            "autoSetup": false
        }
    },
    "postCreateCommand": "setup-git-hooks --hooks-dir my-hooks --verbose"
}
```

## Advanced Examples

### Multi-Repository Setup

For workspaces with multiple repositories:

```json
{
    "features": {
        "ghcr.io/compusib/devcontainer_features/setup-git-hooks:1": {
            "autoSetup": false,
            "gitSafeDirectory": "/workspaces/*"
        }
    },
    "postCreateCommand": [
        "setup-git-hooks --hooks-dir shared-hooks --verbose",
        "cd /workspaces/repo1 && setup-git-hooks --hooks-dir ../shared-hooks",
        "cd /workspaces/repo2 && setup-git-hooks --hooks-dir ../shared-hooks"
    ]
}
```

### With Custom Environment Variables

```json
{
    "features": {
        "ghcr.io/compusib/devcontainer_features/setup-git-hooks:1": {
            "hooksDir": "tools/git-hooks",
            "verbose": true
        }
    },
    "containerEnv": {
        "GIT_HOOKS_CUSTOM_VAR": "value"
    }
}
```
