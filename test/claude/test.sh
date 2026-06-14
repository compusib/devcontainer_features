#!/bin/bash
#
# Default-options test for the 'claude' feature.
#
# The real install path needs the container's git auth and a running VS Code server (the `code`
# CLI), neither of which exists in the features test harness. So this verifies the build-time
# artifacts (helper scripts on PATH, config written) and the runtime behaviour of
# ensure-compusib-marketplace (declarative settings.json writes via jq — no `claude` needed).

set -e

source dev-container-features-test-lib

# Build a throwaway FEATURE_LIB_DIR (config.env + the jq transform) so a check can drive
# ensure-compusib-marketplace with a chosen local-override path, fully hermetically — no writes
# to /usr/local or /workspace, regardless of the test user. Echoes the temp lib dir.
mk_lib() {
    local override="$1" lib
    lib="$(mktemp -d)"
    mkdir -p "$lib/claude"
    cp /usr/local/lib/features/claude/ensure-compusib-marketplace.jq "$lib/claude/"
    cat > "$lib/claude/config.env" <<EOF
CLAUDE_PLUGINS="base-stack@compusib"
PLUGIN_MARKETPLACE="git@github.com:compusib/ai.git"
PLUGIN_MARKETPLACE_LOCAL_OVERRIDE="$override"
EOF
    printf '%s' "$lib"
}
# A directory that looks like a mounted marketplace checkout. Echoes its path.
mk_local_marketplace() {
    local d; d="$(mktemp -d)"
    mkdir -p "$d/.claude-plugin"
    printf '{"name":"compusib","plugins":[]}' > "$d/.claude-plugin/marketplace.json"
    printf '%s' "$d"
}
export -f mk_lib mk_local_marketplace

# --- build-time artifacts ---------------------------------------------------

check "install-settings-bridge on PATH" bash -c "command -v install-settings-bridge"
check "bootstrap-claude-sync on PATH" bash -c "command -v bootstrap-claude-sync"
check "ensure-compusib-marketplace on PATH" bash -c "command -v ensure-compusib-marketplace"
check "jq transform installed in lib dir" test -f /usr/local/lib/features/claude/ensure-compusib-marketplace.jq
check "config.env written" test -f /usr/local/lib/features/claude/config.env
check "config.env records claudePlugins default" bash -c "grep -q 'CLAUDE_PLUGINS=\"base-stack@compusib\"' /usr/local/lib/features/claude/config.env"
check "config.env records pluginMarketplaceLocalOverride default" bash -c "grep -q 'PLUGIN_MARKETPLACE_LOCAL_OVERRIDE=\"/workspace/compusib/ai\"' /usr/local/lib/features/claude/config.env"

# With no `code` CLI present, the extension installer must exit 0 (never fail the attach).
check "install-settings-bridge no-ops without code CLI" bash -c "command -v code >/dev/null 2>&1 || install-settings-bridge"

# --- ensure-compusib-marketplace: declarative settings.json writes -----------

# No local mount → the online git source + enabledPlugins are written, no `claude` needed.
check "marketplace: online git source + enabledPlugins" bash -c '
    s="$HOME/.claude/settings.json"; rm -f "$s"
    lib="$(mk_lib "")"
    FEATURE_LIB_DIR="$lib" ensure-compusib-marketplace
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.source" "$s")" = "git" ] &&
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.url" "$s")" = "git@github.com:compusib/ai.git" ] &&
    [ "$(jq -r ".enabledPlugins[\"base-stack@compusib\"]" "$s")" = "true" ]
'

# A mounted local checkout (dir with .claude-plugin/marketplace.json) → a directory source,
# and no git url remnant.
check "marketplace: local directory source when mounted" bash -c '
    s="$HOME/.claude/settings.json"; rm -f "$s"
    mkt="$(mk_local_marketplace)"
    lib="$(mk_lib "$mkt")"
    FEATURE_LIB_DIR="$lib" ensure-compusib-marketplace
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.source" "$s")" = "directory" ] &&
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.path" "$s")" = "$mkt" ] &&
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.url // \"absent\"" "$s")" = "absent" ]
'

# A git→directory flip prunes the stale compusib-scoped plugin cache so Claude re-resolves.
check "marketplace: source flip prunes stale compusib cache" bash -c '
    s="$HOME/.claude/settings.json"; rm -f "$s"
    plugins="$HOME/.claude/plugins"; rm -rf "$plugins"
    # Start online (git).
    FEATURE_LIB_DIR="$(mk_lib "")" ensure-compusib-marketplace
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.source" "$s")" = "git" ] || exit 1
    # Seed a stale cache as if Claude had resolved the git marketplace.
    mkdir -p "$plugins/marketplaces/compusib"
    printf "{\"compusib\":{\"source\":{\"source\":\"git\",\"url\":\"x\"}}}" > "$plugins/known_marketplaces.json"
    # Mount a local checkout and re-run → flip → prune.
    mkt="$(mk_local_marketplace)"
    FEATURE_LIB_DIR="$(mk_lib "$mkt")" ensure-compusib-marketplace
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.source" "$s")" = "directory" ] &&
    [ ! -d "$plugins/marketplaces/compusib" ] &&
    [ "$(jq -r ".compusib // \"gone\"" "$plugins/known_marketplaces.json")" = "gone" ]
'

# Re-running with the same source is idempotent: one compusib entry, enabledPlugins unchanged.
check "marketplace: write is idempotent" bash -c '
    s="$HOME/.claude/settings.json"; rm -f "$s"
    lib="$(mk_lib "")"
    FEATURE_LIB_DIR="$lib" ensure-compusib-marketplace
    FEATURE_LIB_DIR="$lib" ensure-compusib-marketplace
    [ "$(jq "[.extraKnownMarketplaces | keys[]] | length" "$s")" = "1" ] &&
    [ "$(jq "[.enabledPlugins | keys[]] | length" "$s")" = "1" ]
'

# Foreign marketplaces and user-enabled plugins are preserved.
check "marketplace: preserves other marketplaces and enabled plugins" bash -c '
    s="$HOME/.claude/settings.json"; mkdir -p "$HOME/.claude"
    printf "%s" "{\"extraKnownMarketplaces\":{\"other\":{\"source\":{\"source\":\"git\",\"url\":\"u\"}}},\"enabledPlugins\":{\"x@other\":true}}" > "$s"
    FEATURE_LIB_DIR="$(mk_lib "")" ensure-compusib-marketplace
    [ "$(jq -r ".extraKnownMarketplaces.other.source.url" "$s")" = "u" ] &&
    [ "$(jq -r ".enabledPlugins[\"x@other\"]" "$s")" = "true" ] &&
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.source" "$s")" = "git" ]
'

# --- bootstrap-claude-sync ---------------------------------------------------

# With neither `claude` nor `rcloneops` on PATH, the data-sync helper must exit 0 (never fail
# the attach) and must NOT install any plugin SessionStart hook (that mechanism is gone).
check "bootstrap-claude-sync exits 0 without claude/rcloneops" bash -c "bootstrap-claude-sync"
check "bootstrap-claude-sync installs no plugin SessionStart hook" bash -c '
    s="$HOME/.claude/settings.json"
    [ ! -f "$s" ] || ! jq -e ".hooks.SessionStart[]?.hooks[]? | select((.command // \"\") | test(\"ensure-(compusib-marketplace|claude-plugins)\"))" "$s" >/dev/null
'

# --- claude on PATH ----------------------------------------------------------

# The build step installs the claude PATH fragment (to ~/.bashrc.d when the
# bashrc feature created it, otherwise appended to ~/.bashrc).
check "claude PATH setup installed" bash -c '
    test -f "$HOME/.bashrc.d/190_claude_path.sh" || grep -q "anthropic.claude-code" "$HOME/.bashrc"
'

# Functional: a bundled VS Code extension binary on the expected path is resolved
# onto PATH by the fragment (newest version wins, no real CLI needed).
check "claude-path fragment resolves the bundled extension binary" bash -c '
    frag="$HOME/.bashrc.d/190_claude_path.sh"
    [ -f "$frag" ] || { echo "no bashrc.d fragment present; skipping functional check"; exit 0; }
    fakedir="$HOME/.vscode-server/extensions/anthropic.claude-code-9.9.9-test/resources/native-binary"
    mkdir -p "$fakedir"
    printf "#!/bin/sh\necho fake-claude\n" > "$fakedir/claude"
    chmod +x "$fakedir/claude"
    ( PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      . "$frag"
      command -v claude | grep -q "anthropic.claude-code-9.9.9-test/resources/native-binary/claude" )
'

reportResults
