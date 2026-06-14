#!/bin/bash
#
# rclone needs special handling: rcloneops drives `rclone bisync` with flags
# (--conflict-resolve, --resilient, --recover, --max-lock) that only exist in
# rclone >= 1.66, but Debian's apt build lags far behind (e.g. 1.60). So for
# rclone we check the *version*, not just presence, and fall back to rclone's
# official installer (which always fetches the latest) when it is missing or
# too old. gh just needs to be present, so it stays on ensure_dependency.
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
