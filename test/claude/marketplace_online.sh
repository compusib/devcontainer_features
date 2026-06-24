#!/bin/bash
#
# Scenario: a pluginMarketplaces entry whose local override names a directory that does
# not exist -> the feature falls back to the ONLINE (git) marketplace source.
#
# Builds a real container with the option set, proving install.sh threads
# pluginMarketplaces into the on-disk config.env that
# ensure-marketplace-recursively-installed reads. `claude` is stubbed (the native CLI installs
# at postCreate, which the features test harness does not run), so we assert the marketplace
# command the script is driven with rather than a real plugin install.

set -e

source dev-container-features-test-lib

OVERRIDE="/tmp/compusib-no-marketplace"
rm -rf "$OVERRIDE" # guarantee the override dir is absent -> the online branch is taken

check "config.env records the marketplace entry with the (absent) local-override path" \
    grep -q "PLUGIN_MARKETPLACES=\"compusib|git@github.com:compusib/ai.git|$OVERRIDE\"" /usr/local/lib/features/claude/config.env

# No mounted checkout at the override path -> the online git source is registered.
check "registers the online git marketplace source" bash -c '
    bin="$(mktemp -d)"; export CLAUDE_LOG="$(mktemp)"
    printf "#!/bin/bash\necho \"claude \$*\" >> \"\$CLAUDE_LOG\"\nexit 0\n" > "$bin/claude"
    chmod +x "$bin/claude"
    PATH="$bin:$PATH" ensure-marketplace-recursively-installed >/dev/null 2>&1
    grep -q "plugin marketplace add git@github.com:compusib/ai.git" "$CLAUDE_LOG" &&
    grep -q "plugin install base-stack@compusib" "$CLAUDE_LOG"
'

reportResults
