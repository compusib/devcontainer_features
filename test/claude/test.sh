#!/bin/bash
#
# Default-options test for the 'claude' feature.
#
# The real install path needs the container's git auth and a running VS Code server (the `code`
# CLI), neither of which exists in the features test harness. So this verifies the build-time
# artifacts (helper scripts on PATH, config written) and that the runtime helpers no-op cleanly
# when there is no `code` CLI.

set -e

source dev-container-features-test-lib

check "install-settings-bridge on PATH" bash -c "command -v install-settings-bridge"
check "bootstrap-claude-sync on PATH" bash -c "command -v bootstrap-claude-sync"
check "config.env written" test -f /usr/local/lib/features/claude/config.env
check "config.env records claudePlugins default" bash -c "grep -q 'CLAUDE_PLUGINS=\"base-stack@compusib\"' /usr/local/lib/features/claude/config.env"

# With no `code` CLI present, the extension installer must exit 0 (never fail the attach).
check "install-settings-bridge no-ops without code CLI" bash -c "command -v code >/dev/null 2>&1 || install-settings-bridge"

# With neither `claude` nor `rcloneops` on PATH, the bootstrap helper must no-op
# and exit 0 (never fail the attach), creating no ~/.claude. (Runs before the
# fake-binary test below so no `claude` is resolvable yet.)
check "bootstrap-claude-sync no-ops without claude/rcloneops" bash -c "bootstrap-claude-sync && test ! -e \"\$HOME/.claude\""

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
