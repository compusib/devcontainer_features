#!/bin/bash
#
# TAG: remote — network/identity dependent, EXCLUDED from CI (see .github/workflows/test.yaml).
#
# Scenario: no local working tree is on disk (settingsBridgeRepoPath points at an absent dir), so
# install-settings-bridge clones the prebuilt *.vsix from the real settingsBridgeRepo over
# git-SSH (git@github.com:compusib/ai.git) and installs the downloaded copy from the home cache.
#
# This exercises the actual production download path, so it needs a github.com SSH identity:
#   - host key: install-settings-bridge clones with StrictHostKeyChecking=accept-new, so the
#     missing known_hosts entry in a fresh container is auto-trusted instead of prompting.
#   - auth: relies on the container's forwarded SSH agent. CI build containers have no such
#     identity, hence this scenario is excluded there and is meant to be run locally.
#
# A recording fake `code` stands in for the VS Code CLI so the install assertion is deterministic.

set -e

source dev-container-features-test-lib

ABSENT="/tmp/sb-no-local-tree"

check "config.env records the absent repo path and the github remote" bash -c "
    grep -q 'SETTINGS_BRIDGE_REPO_PATH=\"$ABSENT\"' /usr/local/lib/features/claude/config.env &&
    grep -q 'SETTINGS_BRIDGE_REPO=\"git@github.com:compusib/ai.git\"' /usr/local/lib/features/claude/config.env
"

check "install-settings-bridge clones from the github remote and installs the downloaded copy" bash -c '
    absent="/tmp/sb-no-local-tree"; cache="$HOME/.cache/claude-feature/settings-bridge"
    rm -rf "$absent" "$cache" # no local tree -> force the remote clone path
    # Recording fake VS Code CLI: nothing installed yet, log every --install-extension target.
    fake="$(mktemp -d)"; log="$(mktemp)"
    cat > "$fake/code" <<EOF
#!/bin/bash
case "\$1" in
  --list-extensions) exit 0 ;;
  --install-extension) echo "\$2" >> "$log" ;;
esac
exit 0
EOF
    chmod +x "$fake/code"
    PATH="$fake:$PATH" install-settings-bridge
    # The vsix was cloned from the remote into the download cache and installed from there.
    grep -q "^$cache/.*\.vsix$" "$log"
'

reportResults
