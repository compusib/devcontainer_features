#!/bin/bash
# Runtime lib (sourced, not executed) for ensure-marketplace-recursively-installed.
# Holds the single-plugin install operation: seed the plugin's userConfig defaults,
# then install it. Factored out as prepwork for relocating the feature's runtime
# scripts into the bash repo (the move itself is a later step).
#
# Sourced into a `set -uo pipefail` script; keep every function best-effort so a
# failure here never blocks a session launch.

# default_plugin_config <plugin_id> <marketplace>
# Seed <plugin_id>'s manifest userConfig defaults into the user settings.json,
# using the bash-repo helper. Gated by DEFAULT_PLUGIN_CONFIGS (default on).
#
# The helper is source-agnostic and already idempotent: it reads the *cached*
# manifest (written by `claude plugin install`, not by `marketplace add`), merges
# fill-only by default (never clobbers a value the user set), and leaves the file
# untouched when the plugin declares no defaults. So a cold-cache root plugin is a
# silent no-op here; a dependency-with-defaults (e.g. companion-link) is already
# cached by its parent's install by the time we seed it. All output is logged.
default_plugin_config() {
    local plugin_id="$1" marketplace="$2"
    [[ "${DEFAULT_PLUGIN_CONFIGS:-true}" == "true" ]] || return 0

    local helper="${BASH_REPO_ROOT:-/workspace/compusib/bash}/bin/claude/manifest-to-default-user-config"
    [[ -x "$helper" ]] || helper="$(command -v manifest-to-default-user-config 2>/dev/null)"
    [[ -n "$helper" && -x "$helper" ]] || return 0

    "$helper" --plugin "${plugin_id%@*}" --marketplace "$marketplace" \
        --settings "${HOME}/.claude/settings.json" 2>&1 | sed 's/^/    /'
}

# install_plugin <claude_bin> <plugin_id> <marketplace>
# Seed the plugin's userConfig defaults (best-effort), then install it. Returns the
# install's exit status so callers can react (log a warning / ignore).
install_plugin() {
    local claude_bin="$1" plugin_id="$2" marketplace="$3"
    default_plugin_config "$plugin_id" "$marketplace"
    "$claude_bin" plugin install "$plugin_id" >/dev/null 2>&1
}
