#!/bin/bash
# auth feature — build-time staging only.
#
# Runs as root during image build, when /workspace (compy + bash) is NOT yet
# mounted and the user-level mise is unavailable. So the real provisioning is
# deferred to onCreateCommand (provision-auth, runs at create time as the remote
# user). Here we only: install the provision-auth helper and persist the resolved
# feature options for it to read. And we install pgtoken, which needs neither.
set -e

echo "Activating feature 'auth'"

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_LIB_TARGET_DIR="${FEATURE_LIB_DIR:-/usr/local/lib/features}/auth"
CONFIG_FILE="${FEATURE_LIB_TARGET_DIR}/config.env"

# Feature options (uppercased env vars from the devcontainer CLI).
COMPY_REPO_PATH="${COMPYREPOPATH:-/workspace/compusib/compy}"
SSH_JWT_VERSION="${SSHJWTVERSION:-latest}"
PYTHON_VERSION="${PYTHONVERSION:-}"
KEEP_GO_TOOLCHAIN="${KEEPGOTOOLCHAIN:-true}"

# 1. Install the runtime provisioning helper.
install -d /usr/local/bin
install -m 0755 "${FEATURE_DIR}/scripts/provision-auth" /usr/local/bin/provision-auth

# 2. Persist resolved options so provision-auth can read them on create.
install -d "${FEATURE_LIB_TARGET_DIR}"
cat > "${CONFIG_FILE}" <<EOF
COMPY_REPO_PATH="${COMPY_REPO_PATH}"
SSH_JWT_VERSION="${SSH_JWT_VERSION}"
PYTHON_VERSION="${PYTHON_VERSION}"
KEEP_GO_TOOLCHAIN="${KEEP_GO_TOOLCHAIN}"
EOF

# 3. pgtoken: the three libraries built for this machine's architecture (pgtoken/,
#    `make dist`: amd64 and arm64), installed by pgtoken's own script. libpq 19
#    finds the module on the linker's path by itself; where libpq is an 18, the
#    remote user's ~/.bashrc.d (the bashrc feature's) preloads the loader (NOTES.md).
case "$(uname -m)" in
    x86_64) PGTOKEN_ARCH=amd64 ;;
    aarch64) PGTOKEN_ARCH=arm64 ;;
    *) PGTOKEN_ARCH="$(uname -m)" ;;
esac
PGTOKEN_BUILT="${FEATURE_DIR}/pgtoken/dist/linux_${PGTOKEN_ARCH}"
if [ ! -f "${PGTOKEN_BUILT}/libpq-oauth.so" ]; then
    echo "auth: pgtoken is not built for linux/${PGTOKEN_ARCH} (${PGTOKEN_BUILT}): run 'make -C src/auth/pgtoken dist' first" >&2
    exit 1
fi
bash "${FEATURE_DIR}/pgtoken/install-pgtoken.sh" "${PGTOKEN_BUILT}" "${_REMOTE_USER_HOME}"

echo "✅ auth feature staged. Provisioning runs on create via 'provision-auth'."
echo "✅ pgtoken (linux/${PGTOKEN_ARCH}) installed in /usr/local/lib/pgtoken."
