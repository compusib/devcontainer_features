# DevContainer Features

This repository contains custom DevContainer features for Compusib projects.

## Features

### setup-git-hooks

Installs and configures a modular git hooks system with argbash-enhanced setup script.

**Key capabilities:**
- 🔧 System-wide installation of `setup-git-hooks` command
- 📝 Argbash-based argument parsing with regeneration support
- 🎯 Configurable git hooks directory and setup options
- 🔒 Git safe directory configuration
- 🤖 Automatic or manual setup modes
- 📊 Verbose output for debugging

See [src/git-hooks/README.md](src/git-hooks/README.md) for detailed documentation.

## Quick Start

Add to your `.devcontainer/devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/compusib/devcontainer_features/setup-git-hooks:1": {}
    }
}
```

For more examples, see the [examples/](examples/) directory.

## Testing

To test features locally:

```bash
# Clone this repository
git clone https://github.com/compusib/devcontainer_features.git
cd devcontainer_features

# Build and test with DevContainer CLI
devcontainer build --workspace-folder .
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . ./test-feature.sh
```

## Contributing

When adding new features:

1. Follow the [Dev Container Feature specification](https://containers.dev/implementors/features/)
2. Add comprehensive tests
3. Update documentation
4. Ensure CI/CD passes

### Feature Structure

```
src/
  feature-name/
    devcontainer-feature.json
    install.sh
    README.md
    scripts/           # Optional: source scripts
    test/             # Optional: feature-specific tests
```
