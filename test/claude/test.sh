#!/bin/bash
#
# Default-options test for the 'claude' feature.
#
# The real install path needs the container's git auth and a running VS Code server (the `code`
# CLI), neither of which exists in the features test harness. So this verifies the build-time
# artifacts (helper scripts on PATH, config written) and that the runtime helpers no-op cleanly
# when there is no `code` CLI and no host-home mount.

set -e

source dev-container-features-test-lib

check "install-settings-bridge on PATH" bash -c "command -v install-settings-bridge"
check "link-host-claude on PATH" bash -c "command -v link-host-claude"
check "config.env written" test -f /usr/local/lib/features/claude/config.env

# With no `code` CLI present, the extension installer must exit 0 (never fail the attach).
check "install-settings-bridge no-ops without code CLI" bash -c "command -v code >/dev/null 2>&1 || install-settings-bridge"

# With no host-home mount, the linker must skip cleanly and not create ~/.claude.
check "link-host-claude skips when host home absent" bash -c "link-host-claude && test ! -e \"\$HOME/.claude\""

reportResults
