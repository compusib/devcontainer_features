#!/bin/bash

set -e

echo "Installing setup-git-hooks feature..."

# Get feature options (passed as environment variables by devcontainer)
GIT_SAFE_DIRECTORY="${GITSAFEDIRECTORY:-/workspaces/*}"

# Configure git safe directory if specified
if [[ -n "$GIT_SAFE_DIRECTORY" ]]; then
    echo "🔧 Configuring git safe directory: $GIT_SAFE_DIRECTORY"
    git config --global --add safe.directory "$GIT_SAFE_DIRECTORY"
else
    echo "⚠️  Skipping git safe directory configuration (empty value provided)"
fi

# Get the directory where this script is located
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install the main script to /usr/local/bin
echo "📦 Installing setup-git-hooks to /usr/local/bin/"
cp "${FEATURE_DIR}/scripts/setup-git-hooks" /usr/local/bin/
chmod +x /usr/local/bin/setup-git-hooks

# Install argbash library to /usr/local/lib/argbash
echo "📦 Installing argbash library to /usr/local/lib/argbash/"
mkdir -p /usr/local/lib/argbash
cp -r "${FEATURE_DIR}/scripts/args/"* /usr/local/lib/argbash/

# Make the parsing script executable
chmod +x /usr/local/lib/argbash/setup-git-hooks-parsing.sh

echo "✅ setup-git-hooks feature installed successfully!"
echo ""
echo "Usage:"
echo "  setup-git-hooks --help    # Show help"
echo "  setup-git-hooks --list    # List available hooks"
echo "  setup-git-hooks           # Install git hooks"
echo ""
echo "The script is now available system-wide and can be run from any directory."
