#!/bin/bash
#
# Scenario: no local working tree is on disk (settingsBridgeRepoPath points at an absent dir), so
# install-settings-bridge clones the prebuilt *.vsix from settingsBridgeRepo and installs the
# downloaded copy from the home cache. A present local tree is preferred, so pointing the local
# path at a nonexistent dir is what forces this clone branch.
#
# The repo is a LOCAL seed git repo, NOT github. Two distinct repos must not be conflated:
#   - the real settings-bridge source is the PRIVATE github repo (git@github.com:compusib/ai.git);
#   - the "seed" here is a brand-new empty repo this test fabricates at runtime with `git init`,
#     holding a 0-byte placeholder *.vsix. It is created from nothing, never fetched.
# Why not clone the real repo? The features test harness runs the clone inside a throwaway build
# container with no SSH identity, so a real git@github.com clone can never succeed here (in CI or
# locally — CI has no access to the private repo, and SSH-agent forwarding does not reach the
# harness's build container). The local seed exercises the exact clone -> cache -> install code
# path fully offline, so this scenario stays green everywhere without any github credentials.
# Scope: this verifies install-settings-bridge's PLUMBING (fall back to clone, cache the vsix,
# invoke `code --install-extension` on it), not that a real, functional extension was installed.
# A recording fake `code` stands in for the VS Code CLI the harness lacks.

set -e

source dev-container-features-test-lib

ABSENT="/tmp/sb-no-local-tree"
SEED="/tmp/sb-seed-repo"

check "config.env records the absent repo path and the seed repo url" bash -c "
    grep -q 'SETTINGS_BRIDGE_REPO_PATH=\"$ABSENT\"' /usr/local/lib/features/claude/config.env &&
    grep -q 'SETTINGS_BRIDGE_REPO=\"$SEED\"' /usr/local/lib/features/claude/config.env
"

check "install-settings-bridge clones from the repo and installs the downloaded copy" bash -c '
    absent="/tmp/sb-no-local-tree"; seed="/tmp/sb-seed-repo"
    cache="$HOME/.cache/claude-feature/settings-bridge"
    rm -rf "$absent" "$seed" "$cache"
    # A local seed repo holding the vsix at the expected path, on branch main.
    git init -q "$seed"
    git -C "$seed" config user.email t@t; git -C "$seed" config user.name t
    mkdir -p "$seed/vscode/settings-bridge/dist"
    : > "$seed/vscode/settings-bridge/dist/settings-bridge-2.0.0.vsix"
    git -C "$seed" add -A; git -C "$seed" commit -qm seed; git -C "$seed" branch -M main
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
    # The installed vsix came from the download cache, not from any local tree.
    grep -q "^$cache/" "$log"
'

reportResults
