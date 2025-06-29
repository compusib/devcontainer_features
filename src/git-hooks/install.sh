#!/bin/bash

main_scripts_to_install=(
    "setup-git-hooks"
    "run-git-client-hooks"
)
FEATURE_LIB_TARGET_DIR="${FEATURE_LIB_DIR:-"/usr/local/lib/features"}"
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

# Install the main scripts to /usr/local/bin

for script in "${main_scripts_to_install[@]}"; do
    if [[ -f "${FEATURE_DIR}/scripts/${script}" ]]; then
        echo "📦 Installing ${script} to /usr/local/bin/"
        cp "${FEATURE_DIR}/scripts/${script}" /usr/local/bin/
        chmod +x "/usr/local/bin/${script}"
    else
        echo "⚠️  Script ${script} not found in ${FEATURE_DIR}/scripts/"
    fi
done
# Install argbash library to FEATURE_LIB_TARGET_DIR
echo "📦 Installing argbash library to ${FEATURE_LIB_TARGET_DIR}"
mkdir -p "${FEATURE_LIB_TARGET_DIR}"
cp -r ${FEATURE_DIR}/scripts/lib "${FEATURE_LIB_TARGET_DIR}/git-hooks"

# Make the parsing script executable
chmod +x ${FEATURE_LIB_TARGET_DIR}/git-hooks/bash/args/*.sh

echo "✅ setup-git-hooks feature installed successfully!"
echo ""
echo "Usage:"
echo "  setup-git-hooks --help    # Show help"
echo "  setup-git-hooks --list    # List available hooks"
echo "  setup-git-hooks           # Install git hooks"
echo ""
echo "The script is now available system-wide and can be run from any directory."
