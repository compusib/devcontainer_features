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
