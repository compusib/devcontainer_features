#!/bin/bash
#
# Persists the feature's resolved options for the runtime helpers to read.

# write_feature_config <config-file>
# Write the resolved option globals to <config-file> so the runtime
# (session-launch/postStart/postAttach) helpers can read them. No secrets are
# stored here, only configuration.
write_feature_config() {
    local config_file="$1"
    echo "🔧 Writing feature config to ${config_file}"
    mkdir -p "$(dirname "${config_file}")"
    cat > "${config_file}" <<EOF
INSTALL_SETTINGS_BRIDGE="${INSTALL_SETTINGS_BRIDGE}"
SETTINGS_BRIDGE_REPO_PATH="${SETTINGS_BRIDGE_REPO_PATH}"
SETTINGS_BRIDGE_REPO="${SETTINGS_BRIDGE_REPO}"
SETTINGS_BRIDGE_REF="${SETTINGS_BRIDGE_REF}"
SETTINGS_BRIDGE_VSIX_DIR="${SETTINGS_BRIDGE_VSIX_DIR}"
EXTENSION_ID="${EXTENSION_ID}"
CLAUDE_PLUGINS="${CLAUDE_PLUGINS}"
PLUGIN_MARKETPLACE="${PLUGIN_MARKETPLACE}"
PLUGIN_MARKETPLACE_LOCAL_OVERRIDE="${PLUGIN_MARKETPLACE_LOCAL_OVERRIDE}"
BOOTSTRAP_CLAUDE_SYNC="${BOOTSTRAP_CLAUDE_SYNC}"
EOF
}
