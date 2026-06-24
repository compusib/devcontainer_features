#!/bin/bash
#
# Scenario: a pluginMarketplaces entry whose local override directory EXISTS but does
# NOT contain .claude-plugin/marketplace.json -> the override does NOT win; the feature
# falls back to the ONLINE (git) source.
#
# Complements marketplace_online (which covers the absent-directory case): here the
# directory is present but is not a marketplace checkout, so it must be ignored — the
# manifest guard, not mere directory existence, decides whether a local source wins.

set -e

source dev-container-features-test-lib

OVERRIDE="/tmp/compusib-override-no-manifest"

check "config.env records the marketplace entry with the no-manifest override path" \
    grep -q "PLUGIN_MARKETPLACES=\"compusib|git@github.com:compusib/ai.git|$OVERRIDE\"" /usr/local/lib/features/claude/config.env

# Override dir exists but holds no marketplace.json -> the online git source is registered,
# and the local directory is NOT.
check "override without a marketplace.json does not win; online git source used" bash -c '
    o="/tmp/compusib-override-no-manifest"
    mkdir -p "$o"; rm -rf "$o/.claude-plugin"   # exists, but NOT a marketplace checkout
    bin="$(mktemp -d)"; export CLAUDE_LOG="$(mktemp)"
    printf "#!/bin/bash\necho \"claude \$*\" >> \"\$CLAUDE_LOG\"\nexit 0\n" > "$bin/claude"
    chmod +x "$bin/claude"
    PATH="$bin:$PATH" ensure-marketplace-recursively-installed >/dev/null 2>&1
    grep -q "plugin marketplace add git@github.com:compusib/ai.git" "$CLAUDE_LOG" &&
    ! grep -q "plugin marketplace add $o" "$CLAUDE_LOG" &&
    grep -q "plugin install base-stack@compusib" "$CLAUDE_LOG"
'

reportResults
