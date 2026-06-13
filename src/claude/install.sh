#!/bin/bash
set -e

echo "Activating feature 'claude'"

FEATURE_LIB_TARGET_DIR="${FEATURE_LIB_DIR:-"/usr/local/lib/features"}/claude"
CONFIG_FILE="${FEATURE_LIB_TARGET_DIR}/config.env"

# Feature options (passed as environment variables by the devcontainer CLI).
INSTALL_SETTINGS_BRIDGE="${INSTALLSETTINGSBRIDGE:-true}"
SKIP_INSTALL_SYSTEM_PACKAGES="${SKIPINSTALLSYSTEMPACKAGES:-false}"
SETTINGS_BRIDGE_REPO_PATH="${SETTINGSBRIDGEREPOPATH:-/workspace/compusib/ai}"
SETTINGS_BRIDGE_REPO="${SETTINGSBRIDGEREPO:-git@github.com:compusib/ai.git}"
SETTINGS_BRIDGE_REF="${SETTINGSBRIDGEREF:-main}"
SETTINGS_BRIDGE_VSIX_DIR="${SETTINGSBRIDGEVSIXDIR:-vscode/settings-bridge/dist}"
EXTENSION_ID="${EXTENSIONID:-compusib.settings-bridge}"
HOST_HOME_MOUNTPOINT="${HOSTHOMEMOUNTPOINT:-~/host-home}"

# Ensure the runtime dependencies are available.
#
# These are best installed in the devcontainer's Dockerfile (baked into the
# image) so they don't need re-installing on every rebuild and so the build is
# reproducible. If they are missing we install them here as a fallback and warn.

# Path of the keyring a third-party repo's packages are verified against.
apt_repo_keyring() { echo "/etc/apt/keyrings/${1}.gpg"; }

# register_apt_repo <name> <key-url> <repo-spec>
# Register a third-party apt repository (modern signed-by style) so apt can
# install from it. <repo-spec> is the source line minus its [signed-by] options,
# as "<url> <suite> <component>" (e.g. "https://cli.github.com/packages stable main").
register_apt_repo() {
    local name="$1" key_url="$2" repo_spec="$3"
    local keyring; keyring="$(apt_repo_keyring "$name")"

    apt-get update -y
    apt-get install -y --no-install-recommends curl ca-certificates
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "$key_url" -o "$keyring"
    chmod go+r "$keyring"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=${keyring}] ${repo_spec}" \
        > "/etc/apt/sources.list.d/${name}.list"
}

# print_dockerfile_hint <command> <apt-package> [key-url] [repo-spec]
# Print the Dockerfile RUN line that reproduces this dependency's install,
# prepending the repo-registration steps when a third-party repo is supplied.
print_dockerfile_hint() {
    local cmd="$1" apt_pkg="$2" key_url="${3:-}" repo_spec="${4:-}"
    local keyring; keyring="$(apt_repo_keyring "$cmd")"
    local -a steps=()
    if [[ -n "$key_url" ]]; then
        steps+=(
            "install -m 0755 -d /etc/apt/keyrings"
            "curl -fsSL ${key_url} -o ${keyring}"
            "chmod go+r ${keyring}"
            "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=${keyring}] ${repo_spec}\" > /etc/apt/sources.list.d/${cmd}.list"
        )
    fi
    steps+=(
        "apt-get update"
        "apt-get install -y --no-install-recommends ${apt_pkg}"
        "rm -rf /var/lib/apt/lists/*"
    )

    local i
    for i in "${!steps[@]}"; do
        if [[ "$i" -eq 0 ]]; then
            printf '         RUN %s' "${steps[i]}"
        else
            printf ' \\\n          && %s' "${steps[i]}"
        fi
    done
    printf '\n'
}

# ensure_dependency <command> <apt-package> [key-url] [repo-spec]
# Orchestrates the helpers: no-op when <command> is present; otherwise warn,
# print the Dockerfile hint, then install (registering a third-party repo first
# when [key-url]/[repo-spec] are given — neither can be derived from the other).
ensure_dependency() {
    local cmd="$1" apt_pkg="$2" key_url="${3:-}" repo_spec="${4:-}"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ '${cmd}' already present, nothing to do."
        return 0
    fi

    echo "⚠️  '${cmd}' not found — installing it now as a fallback."
    echo "    👉 Better to bake it into your devcontainer's Dockerfile so it is"
    echo "       part of the image. Add the following to your Dockerfile:"
    echo ""
    print_dockerfile_hint "$cmd" "$apt_pkg" "$key_url" "$repo_spec"
    echo ""

    if ! command -v apt-get >/dev/null 2>&1; then
        echo "❌ apt-get not available; cannot auto-install '${cmd}'. Please install it manually."
        return 1
    fi

    [[ -n "$key_url" ]] && register_apt_repo "$cmd" "$key_url" "$repo_spec"
    apt-get update -y
    apt-get install -y --no-install-recommends "${apt_pkg}"
    rm -rf /var/lib/apt/lists/*
}

if [[ "${SKIP_INSTALL_SYSTEM_PACKAGES}" == "true" ]]; then
    echo "⏭️  skipInstallSystemPackages=true — skipping rclone/jq/gh dependency check."
else
    ensure_dependency "rclone" "rclone"
    ensure_dependency "jq" "jq"
    # GitHub CLI is not in Debian's default repos — register GitHub's apt repo.
    ensure_dependency "gh" "gh" \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "https://cli.github.com/packages stable main"
fi

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
