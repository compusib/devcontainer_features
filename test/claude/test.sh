#!/bin/bash
#
# Default-options test for the 'claude' feature.
#
# The real install path needs the container's git auth, a running VS Code server (the `code`
# CLI), and the native `claude` CLI (installed at postCreate, which the features test harness
# does not run) — none of which exist here. So this verifies the build-time artifacts (helper
# scripts on PATH, config written) and the runtime behaviour of ensure-marketplace-recursively-installed by
# STUBBING `claude` and asserting the marketplace/plugin commands it is driven with.

set -e

source dev-container-features-test-lib

# Build a throwaway FEATURE_LIB_DIR (config.env) so a check can drive
# ensure-marketplace-recursively-installed with a chosen local-override path, fully hermetically — no writes
# to /usr/local or /workspace, regardless of the test user. Echoes the temp lib dir.
mk_lib() {
    local override="$1" lib
    lib="$(mktemp -d)"
    mkdir -p "$lib/claude"
    cat > "$lib/claude/config.env" <<EOF
CLAUDE_PLUGINS="base-stack@compusib"
PLUGIN_MARKETPLACES="compusib|git@github.com:compusib/ai.git|$override"
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
# Drop a `claude` stub on PATH that records every invocation to <bindir>/claude.log and prints
# nothing for `plugin list` (so the dependency loop sees no installed plugins and exits at once).
# Echoes the bin dir; the caller prepends it to PATH and reads "$bin/claude.log".
mk_claude_stub() {
    local bin; bin="$(mktemp -d)"
    printf '#!/bin/bash\necho "claude $*" >> "$(dirname "$0")/claude.log"\nexit 0\n' > "$bin/claude"
    chmod +x "$bin/claude"
    printf '%s' "$bin"
}
export -f mk_lib mk_local_marketplace mk_claude_stub

# --- build-time artifacts ---------------------------------------------------

check "claude-process-wrapper on PATH" bash -c "command -v claude-process-wrapper"
check "install-settings-bridge on PATH" bash -c "command -v install-settings-bridge"
check "bootstrap-claude-sync on PATH" bash -c "command -v bootstrap-claude-sync"
check "ensure-marketplace-recursively-installed on PATH" bash -c "command -v ensure-marketplace-recursively-installed"
check "no jq transform left behind" bash -c "! test -f /usr/local/lib/features/claude/ensure-marketplace-recursively-installed.jq"
check "config.env written" test -f /usr/local/lib/features/claude/config.env
check "config.env records claudePlugins default" bash -c "grep -q 'CLAUDE_PLUGINS=\"base-stack@compusib agent-skills@addy-agent-skills\"' /usr/local/lib/features/claude/config.env"
check "config.env records pluginMarketplaces default (compusib + addy-agent-skills)" bash -c "grep -q 'compusib|git@github.com:compusib/ai.git|/workspace/compusib/ai' /usr/local/lib/features/claude/config.env && grep -q 'addy-agent-skills|git@github.com:paulbalomiri/agent-skills.git|/workspace/paulbalomiri/agent-skills' /usr/local/lib/features/claude/config.env"

# With no `code` CLI present, the extension installer must exit 0 (never fail the attach).
check "install-settings-bridge no-ops without code CLI" bash -c "command -v code >/dev/null 2>&1 || install-settings-bridge"

# --- ensure-marketplace-recursively-installed: claude CLI driver --------------------------

# With no `claude` resolvable (none on PATH, none at ~/.local/bin), it must exit 0 — the
# postStart hook never fails just because the native install was skipped/failed.
check "marketplace: no-ops gracefully when claude is absent" bash -c '
    command -v claude >/dev/null 2>&1 && skip "claude present in test env" || true
    [ -x "$HOME/.local/bin/claude" ] && rm -f "$HOME/.local/bin/claude"
    FEATURE_LIB_DIR="$(mk_lib "")" ensure-marketplace-recursively-installed
'

# No local mount → registers the online git source and installs the configured roots via the CLI.
check "marketplace: registers online git source + installs roots" bash -c '
    bin="$(mk_claude_stub)"
    PATH="$bin:$PATH" FEATURE_LIB_DIR="$(mk_lib "")" ensure-marketplace-recursively-installed >/dev/null 2>&1
    grep -q "plugin marketplace add git@github.com:compusib/ai.git" "$bin/claude.log" &&
    grep -q "plugin install base-stack@compusib" "$bin/claude.log"
'

# A mounted local checkout → registers a directory source pointing at it.
check "marketplace: registers local directory source when mounted" bash -c '
    bin="$(mk_claude_stub)"; mkt="$(mk_local_marketplace)"
    PATH="$bin:$PATH" FEATURE_LIB_DIR="$(mk_lib "$mkt")" ensure-marketplace-recursively-installed >/dev/null 2>&1
    grep -q "plugin marketplace add $mkt" "$bin/claude.log" &&
    grep -q "plugin install base-stack@compusib" "$bin/claude.log"
'

# Nothing configured (empty CLAUDE_PLUGINS) → no claude calls at all.
check "marketplace: no-ops when no plugins configured" bash -c '
    bin="$(mk_claude_stub)"; lib="$(mktemp -d)"; mkdir -p "$lib/claude"
    printf "CLAUDE_PLUGINS=\"\"\n" > "$lib/claude/config.env"
    PATH="$bin:$PATH" FEATURE_LIB_DIR="$lib" ensure-marketplace-recursively-installed >/dev/null 2>&1
    [ ! -s "$bin/claude.log" ]
'

# --- claude-process-wrapper --------------------------------------------------

# The wrapper (set as claudeCode.claudeProcessWrapper) is spawned as
# `claude-process-wrapper <binary> [args...]`. It must publish the binary dir to
# ~/.bashrc.d, install plugins with that same binary, then exec the real session.
check "process wrapper: publishes path fragment, installs via the binary, then execs it" bash -c '
    export HOME="$(mktemp -d)"; mkdir -p "$HOME/.claude" "$HOME/.bashrc.d"
    export CLAUDE_LOG="$(mktemp)"
    bindir="$(mktemp -d)"
    printf "#!/bin/bash\necho \"claude \$*\" >> \"\$CLAUDE_LOG\"\nexit 0\n" > "$bindir/claude"
    chmod +x "$bindir/claude"
    claude-process-wrapper "$bindir/claude" --session-flag >/dev/null 2>&1
    # (1) path fragment written with the binary dir (no globbing needed elsewhere)
    grep -qF "$bindir" "$HOME/.bashrc.d/107_claude_bin_path.sh" &&
    # (2) plugins installed using that same binary
    grep -q "plugin install base-stack@compusib" "$CLAUDE_LOG" &&
    # (3) the real session was exec-launched (the binary saw the session args)
    grep -q "claude --session-flag" "$CLAUDE_LOG"
'

# --- bootstrap-claude-sync ---------------------------------------------------

# With neither `claude` nor `rcloneops` on PATH, the data-sync helper must exit 0 (never fail
# the attach) and must NOT install any plugin SessionStart hook (that mechanism is gone).
check "bootstrap-claude-sync exits 0 without claude/rcloneops" bash -c "bootstrap-claude-sync"
check "bootstrap-claude-sync installs no plugin SessionStart hook" bash -c '
    s="$HOME/.claude/settings.json"
    [ ! -f "$s" ] || ! jq -e ".hooks.SessionStart[]?.hooks[]? | select((.command // \"\") | test(\"ensure-marketplace-recursively-installed\"))" "$s" >/dev/null 2>&1
'

reportResults
