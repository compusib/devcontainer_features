#!/bin/bash
set -e

echo "Activating feature 'claude'"

FEATURE_LIB_TARGET_DIR="${FEATURE_LIB_DIR:-"/usr/local/lib/features"}/claude"
CONFIG_FILE="${FEATURE_LIB_TARGET_DIR}/config.env"

# Feature options (passed as environment variables by the devcontainer CLI).
INSTALL_SETTINGS_BRIDGE="${INSTALLSETTINGSBRIDGE:-true}"
SETTINGS_BRIDGE_REPO_PATH="${SETTINGSBRIDGEREPOPATH:-/workspace/compusib/ai}"
SETTINGS_BRIDGE_REPO="${SETTINGSBRIDGEREPO:-git@github.com:compusib/ai.git}"
SETTINGS_BRIDGE_REF="${SETTINGSBRIDGEREF:-main}"
SETTINGS_BRIDGE_VSIX_DIR="${SETTINGSBRIDGEVSIXDIR:-vscode/settings-bridge/dist}"
EXTENSION_ID="${EXTENSIONID:-compusib.settings-bridge}"
HOST_HOME_MOUNTPOINT="${HOSTHOMEMOUNTPOINT:-~/host-home}"

# Get the directory where this script is located.
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install the runtime helper scripts to /usr/local/bin.
scripts_to_install=(
    "install-settings-bridge"
    "link-host-claude"
)
for script in "${scripts_to_install[@]}"; do
    if [[ -f "${FEATURE_DIR}/scripts/${script}" ]]; then
        echo "📦 Installing ${script} to /usr/local/bin/"
        cp "${FEATURE_DIR}/scripts/${script}" /usr/local/bin/
        chmod +x "/usr/local/bin/${script}"
    else
        echo "⚠️  Script ${script} not found in ${FEATURE_DIR}/scripts/"
    fi
done

# Persist the resolved options so the runtime (postAttach) helpers can read them.
# No secrets are stored here, only configuration.
echo "🔧 Writing feature config to ${CONFIG_FILE}"
mkdir -p "${FEATURE_LIB_TARGET_DIR}"
cat > "${CONFIG_FILE}" <<EOF
INSTALL_SETTINGS_BRIDGE="${INSTALL_SETTINGS_BRIDGE}"
SETTINGS_BRIDGE_REPO_PATH="${SETTINGS_BRIDGE_REPO_PATH}"
SETTINGS_BRIDGE_REPO="${SETTINGS_BRIDGE_REPO}"
SETTINGS_BRIDGE_REF="${SETTINGS_BRIDGE_REF}"
SETTINGS_BRIDGE_VSIX_DIR="${SETTINGS_BRIDGE_VSIX_DIR}"
EXTENSION_ID="${EXTENSION_ID}"
HOST_HOME_MOUNTPOINT="${HOST_HOME_MOUNTPOINT}"
EOF

echo "✅ claude feature installed successfully!"
echo "   Helpers 'link-host-claude' and 'install-settings-bridge' run on postAttach."
