#!/bin/bash
#
# Scenario: a pluginMarketplaces entry whose local override names a mounted checkout (a
# directory holding .claude-plugin/marketplace.json) -> the feature registers a local
# `directory` source.
#
# Like marketplace_online.sh, this proves install.sh threads the option into the real on-disk
# config.env; here it drives the mounted branch against that config with `claude` stubbed.

set -e

source dev-container-features-test-lib

OVERRIDE="/tmp/compusib-marketplace"

check "config.env records the marketplace entry with the mounted local-override path" \
    grep -q "PLUGIN_MARKETPLACES=\"compusib|git@github.com:compusib/ai.git|$OVERRIDE\"" /usr/local/lib/features/claude/config.env

# Materialise a checkout at the override path -> a local directory source is registered.
check "registers a local directory marketplace source when mounted" bash -c '
    o="/tmp/compusib-marketplace"
    mkdir -p "$o/.claude-plugin"
    printf "{\"name\":\"compusib\",\"plugins\":[]}" > "$o/.claude-plugin/marketplace.json"
    bin="$(mktemp -d)"; export CLAUDE_LOG="$(mktemp)"
    printf "#!/bin/bash\necho \"claude \$*\" >> \"\$CLAUDE_LOG\"\nexit 0\n" > "$bin/claude"
    chmod +x "$bin/claude"
    PATH="$bin:$PATH" ensure-marketplace-recursively-installed >/dev/null 2>&1
    grep -q "plugin marketplace add $o" "$CLAUDE_LOG" &&
    grep -q "plugin install base-stack@compusib" "$CLAUDE_LOG"
'

reportResults
