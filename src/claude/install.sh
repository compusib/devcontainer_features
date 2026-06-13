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
CLAUDE_PLUGINS="${CLAUDEPLUGINS:-base-stack@compusib}"
PLUGIN_MARKETPLACE="${PLUGINMARKETPLACE:-git@github.com:compusib/ai.git}"
BOOTSTRAP_CLAUDE_SYNC="${BOOTSTRAPCLAUDESYNC:-true}"

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

# rclone needs special handling: rcloneops drives `rclone bisync` with flags
# (--conflict-resolve, --resilient, --recover, --max-lock) that only exist in
# rclone >= 1.66, but Debian's apt build lags far behind (e.g. 1.60). So for
# rclone we check the *version*, not just presence, and fall back to rclone's
# official installer (which always fetches the latest) when it is missing or
# too old. jq and gh just need to be present, so they stay on ensure_dependency.
RCLONE_MIN_VERSION="1.66.0"

# Installed rclone version (e.g. "1.60.1"), or empty if rclone is absent.
rclone_installed_version() {
    command -v rclone >/dev/null 2>&1 || return 0
    rclone version 2>/dev/null | sed -n '1s/^rclone v//p'
}

# version_ge A B → succeeds when version A >= version B.
version_ge() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# Ensure a recent-enough rclone is installed, upgrading via the official script
# when the present one is missing or older than RCLONE_MIN_VERSION.
ensure_rclone() {
    local have; have="$(rclone_installed_version)"
    if [[ -n "$have" ]] && version_ge "$have" "$RCLONE_MIN_VERSION"; then
        echo "✅ 'rclone' ${have} present (>= ${RCLONE_MIN_VERSION}), nothing to do."
        return 0
    fi

    if [[ -n "$have" ]]; then
        echo "⚠️  'rclone' ${have} is older than ${RCLONE_MIN_VERSION} that rcloneops' bisync needs — upgrading via the official installer."
    else
        echo "⚠️  'rclone' not found — installing the latest via the official installer."
    fi
    echo "    👉 Better to bake the latest rclone into your devcontainer's Dockerfile:"
    echo "         RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates \\"
    echo "          && curl -fsSL https://rclone.org/install.sh | bash"
    echo ""

    # The official installer unpacks a zip and uses curl, so make sure both exist.
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y --no-install-recommends curl unzip ca-certificates
    fi
    curl -fsSL https://rclone.org/install.sh | bash
}

if [[ "${SKIP_INSTALL_SYSTEM_PACKAGES}" == "true" ]]; then
    echo "⏭️  skipInstallSystemPackages=true — skipping rclone/jq/gh dependency check."
else
    ensure_rclone
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
    "bootstrap-claude-sync"
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

# Put the VS Code extension's bundled `claude` binary on PATH via a ~/.bashrc.d
# fragment. The extension installs at attach time under a version/arch-specific
# directory, so the fragment resolves the binary dynamically when sourced (see
# scripts/claude-path.sh). This is what lets bootstrap-claude-sync find `claude`
# and actually install the configured plugins. Mirror the bashrc.d-vs-.bashrc
# fallback the other features use.
CLAUDE_PATH_FRAGMENT="190_claude_path.sh"
if [[ -f "${FEATURE_DIR}/scripts/claude-path.sh" ]]; then
    if [[ -d "${_REMOTE_USER_HOME}/.bashrc.d" ]]; then
        echo "🔧 Installing ${CLAUDE_PATH_FRAGMENT} to ${_REMOTE_USER_HOME}/.bashrc.d/"
        cp "${FEATURE_DIR}/scripts/claude-path.sh" "${_REMOTE_USER_HOME}/.bashrc.d/${CLAUDE_PATH_FRAGMENT}"
        chown "${_REMOTE_USER}" "${_REMOTE_USER_HOME}/.bashrc.d/${CLAUDE_PATH_FRAGMENT}"
    else
        echo "🔧 ${_REMOTE_USER_HOME}/.bashrc.d not found — appending claude PATH setup to ${_REMOTE_USER_HOME}/.bashrc"
        cat "${FEATURE_DIR}/scripts/claude-path.sh" >> "${_REMOTE_USER_HOME}/.bashrc"
    fi
else
    echo "⚠️  scripts/claude-path.sh not found in ${FEATURE_DIR}/scripts/ — 'claude' will not be added to PATH."
fi

# Persist the resolved options so the runtime (postStart/postAttach) helpers can read them.
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
CLAUDE_PLUGINS="${CLAUDE_PLUGINS}"
PLUGIN_MARKETPLACE="${PLUGIN_MARKETPLACE}"
BOOTSTRAP_CLAUDE_SYNC="${BOOTSTRAP_CLAUDE_SYNC}"
EOF

echo "✅ claude feature installed successfully!"
echo "   'install-settings-bridge' runs on postStart; 'bootstrap-claude-sync' runs on postAttach."
