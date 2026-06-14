#!/bin/bash
#
# Installs the feature's runtime helper scripts onto PATH.

# install_runtime_scripts <scripts-dir>
# Copy each runtime helper from <scripts-dir> to /usr/local/bin and make it
# executable. These run later — at session launch (claude-process-wrapper),
# postStart (install-settings-bridge, ensure-marketplace-recursively-installed)
# and postAttach (bootstrap-claude-sync).
install_runtime_scripts() {
    local scripts_dir="$1"
    local scripts_to_install=(
        "claude-process-wrapper"
        "install-settings-bridge"
        "bootstrap-claude-sync"
        "ensure-marketplace-recursively-installed"
    )
    local script
    for script in "${scripts_to_install[@]}"; do
        if [[ -f "${scripts_dir}/${script}" ]]; then
            echo "📦 Installing ${script} to /usr/local/bin/"
            cp "${scripts_dir}/${script}" /usr/local/bin/
            chmod +x "/usr/local/bin/${script}"
        else
            echo "⚠️  Script ${script} not found in ${scripts_dir}/"
        fi
    done
}
