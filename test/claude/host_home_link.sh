#!/bin/bash
#
# Verifies that link-host-claude symlinks ~/.claude to the configured host-home mount when that
# mount contains a .claude directory, and that it refuses to clobber a real ~/.claude.

set -e

source dev-container-features-test-lib

check "link-host-claude on PATH" bash -c "command -v link-host-claude"

# Simulate the host home mount that the feature was configured with (hostHomeMountpoint).
check "create fake host home" bash -c "mkdir -p /tmp/fake-host-home/.claude"

# Link is created and points at the mount.
check "links ~/.claude to host home" bash -c "
    rm -rf \"\$HOME/.claude\" &&
    link-host-claude &&
    test -L \"\$HOME/.claude\" &&
    test \"\$(readlink \"\$HOME/.claude\")\" = /tmp/fake-host-home/.claude
"

# Re-running is idempotent.
check "re-run is idempotent" bash -c "
    link-host-claude &&
    test -L \"\$HOME/.claude\" &&
    test \"\$(readlink \"\$HOME/.claude\")\" = /tmp/fake-host-home/.claude
"

# With ~/.claude now a symlink into the host-home mount, bootstrap-claude-sync must
# treat it as an external mount and skip rcloneops (the host owns syncing).
check "bootstrap-claude-sync detects external mount and skips rcloneops" bash -c "
    bootstrap-claude-sync 2>&1 | grep -q 'external (host) mount'
"

# A real ~/.claude directory must not be clobbered.
check "does not clobber a real ~/.claude" bash -c "
    rm -rf \"\$HOME/.claude\" &&
    mkdir -p \"\$HOME/.claude\" &&
    touch \"\$HOME/.claude/keep-me\" &&
    link-host-claude &&
    test ! -L \"\$HOME/.claude\" &&
    test -f \"\$HOME/.claude/keep-me\"
"

reportResults
