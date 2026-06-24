#!/bin/bash
set -e

echo "Activating feature 'claude'"

# Directory this script (and its lib/) live in.
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_LIB_TARGET_DIR="${FEATURE_LIB_DIR:-"/usr/local/lib/features"}/claude"
CONFIG_FILE="${FEATURE_LIB_TARGET_DIR}/config.env"

# Feature options (passed as environment variables by the devcontainer CLI).
INSTALL_SETTINGS_BRIDGE="${INSTALLSETTINGSBRIDGE:-true}"
SKIP_INSTALL_SYSTEM_PACKAGES="${SKIPINSTALLSYSTEMPACKAGES:-false}"
SETTINGS_BRIDGE_REPO_PATH="${SETTINGSBRIDGEREPOPATH:-/workspace/compusib/ai}"
SETTINGS_BRIDGE_REPO="${SETTINGSBRIDGEREPO:-git@github.com:compusib/ai.git}"
SETTINGS_BRIDGE_REF="${SETTINGSBRIDGEREF:-main}"
SETTINGS_BRIDGE_VSIX_DIR="${SETTINGSBRIDGEVSIXDIR:-vscode/settings-bridge/dist}"
CLAUDE_PLUGINS="${CLAUDEPLUGINS:-base-stack@compusib agent-skills@addy-agent-skills}"
DEFAULT_PLUGIN_CONFIGS="${DEFAULTPLUGINCONFIGS:-true}"
PLUGIN_MARKETPLACES="${PLUGINMARKETPLACES:-compusib|git@github.com:compusib/ai.git|/workspace/compusib/ai addy-agent-skills|git@github.com:paulbalomiri/agent-skills.git|/workspace/paulbalomiri/agent-skills}"
BOOTSTRAP_CLAUDE_SYNC="${BOOTSTRAPCLAUDESYNC:-true}"

# Implementation lives in lib/, split by concern; this script just orchestrates.
source "${FEATURE_DIR}/lib/ensure-dependency.sh"
source "${FEATURE_DIR}/lib/ensure-rclone.sh"
source "${FEATURE_DIR}/lib/install-scripts.sh"
source "${FEATURE_DIR}/lib/write-config.sh"

# 1. Ensure the runtime dependencies (rclone >= 1.66 and gh) are available.
if [[ "${SKIP_INSTALL_SYSTEM_PACKAGES}" == "true" ]]; then
    echo "⏭️  skipInstallSystemPackages=true — skipping rclone/gh dependency check."
else
    ensure_rclone
    # GitHub CLI is not in Debian's default repos — register GitHub's apt repo.
    ensure_dependency "gh" "gh" \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "https://cli.github.com/packages stable main"
fi

# 2. Install the runtime helper scripts to /usr/local/bin.
#
# This feature installs no `claude` CLI of its own. Plugin setup runs at session
# launch via claude-process-wrapper, set as the `claudeCode.claudeProcessWrapper`
# VS Code setting (see customizations.vscode.settings): the extension spawns the
# wrapper with its own bundled binary, the wrapper installs the plugin closure
# with that same binary (no jq, no version skew) and then execs the real session.
install_runtime_scripts "${FEATURE_DIR}/scripts"

# 2b. Install the sourced runtime libs (e.g. plugin-install.sh) next to config.env
# so the runtime helpers can source them.
install_runtime_libs "${FEATURE_DIR}/scripts" "${FEATURE_LIB_TARGET_DIR}"

# 3. Persist the resolved options so the runtime helpers can read them.
write_feature_config "${CONFIG_FILE}"

echo "✅ claude feature installed successfully!"
echo "   'claude-process-wrapper' is set as claudeCode.claudeProcessWrapper — it runs"
echo "   'ensure-marketplace-recursively-installed' at each session launch;"
echo "   'install-settings-bridge' ensures the extension vsix exists in place on onCreate"
echo "   (VS Code installs it via customizations.vscode.extensions); 'bootstrap-claude-sync' on postAttach."
