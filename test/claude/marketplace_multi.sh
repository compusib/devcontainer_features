#!/bin/bash
#
# Scenario: pluginMarketplaces lists two marketplaces — compusib (with a mounted
# local override) and partner (online git, no override). Proves install.sh threads
# the list into config.env and that ensure-marketplace-recursively-installed
# registers BOTH: compusib as a local `directory` source (override present) and
# partner from its git source, then installs each plugin against its own @suffix.

set -e

source dev-container-features-test-lib

check "config.env records the pluginMarketplaces list" \
    grep -q 'PLUGIN_MARKETPLACES="compusib|git@github.com:compusib/ai.git|/tmp/compusib-multi partner|git@github.com:partner/plugins.git"' \
    /usr/local/lib/features/claude/config.env

# Materialise only the compusib override -> compusib registers local, partner online.
check "registers both marketplaces, override-aware, per-suffix installs" bash -c '
    o="/tmp/compusib-multi"
    mkdir -p "$o/.claude-plugin"
    printf "{\"name\":\"compusib\",\"plugins\":[]}" > "$o/.claude-plugin/marketplace.json"
    bin="$(mktemp -d)"; export CLAUDE_LOG="$(mktemp)"
    printf "#!/bin/bash\necho \"claude \$*\" >> \"\$CLAUDE_LOG\"\nexit 0\n" > "$bin/claude"
    chmod +x "$bin/claude"
    PATH="$bin:$PATH" ensure-marketplace-recursively-installed >/dev/null 2>&1
    grep -q "plugin marketplace add $o" "$CLAUDE_LOG" &&
    grep -q "plugin marketplace add git@github.com:partner/plugins.git" "$CLAUDE_LOG" &&
    grep -q "plugin install base-stack@compusib" "$CLAUDE_LOG" &&
    grep -q "plugin install widget@partner" "$CLAUDE_LOG"
'

reportResults
