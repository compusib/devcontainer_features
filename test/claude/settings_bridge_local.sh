#!/bin/bash
#
# Scenario: a local working tree of the settings-bridge repo (settingsBridgeRepoPath) is on disk
# and holds a built *.vsix. Because a present local tree is PREFERRED over cloning,
# install-settings-bridge must install from it and drop any stale downloaded home cache.
#
# The features test harness has no `code` CLI, so a recording fake stands in for it, letting the
# source-selection logic run end to end.

set -e

source dev-container-features-test-lib

TREE="/tmp/sb-local-tree"

check "config.env records the local settingsBridgeRepoPath" \
    grep -q "SETTINGS_BRIDGE_REPO_PATH=\"$TREE\"" /usr/local/lib/features/claude/config.env

check "install-settings-bridge installs from the local tree and clears stale cache" bash -c '
    tree="/tmp/sb-local-tree"; cache="$HOME/.cache/claude-feature/settings-bridge"
    # A local working tree holding a built vsix (the preferred source).
    mkdir -p "$tree/vscode/settings-bridge/dist"
    : > "$tree/vscode/settings-bridge/dist/settings-bridge-1.0.0.vsix"
    # A stale download that must be removed once the local tree wins.
    mkdir -p "$cache"; : > "$cache/old.vsix"
    # Recording fake VS Code CLI: log every --install-extension target.
    fake="$(mktemp -d)"; log="$(mktemp)"
    cat > "$fake/code" <<EOF
#!/bin/bash
[ "\$1" = "--install-extension" ] && echo "\$2" >> "$log"
exit 0
EOF
    chmod +x "$fake/code"
    PATH="$fake:$PATH" install-settings-bridge
    # Installed exactly the local vsix, and the stale cache is gone.
    [ "$(cat "$log")" = "$tree/vscode/settings-bridge/dist/settings-bridge-1.0.0.vsix" ] &&
    [ ! -d "$cache" ]
'

reportResults
