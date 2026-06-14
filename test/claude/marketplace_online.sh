#!/bin/bash
#
# Scenario: pluginMarketplaceLocalOverride names a directory that does not exist
# -> the feature falls back to the ONLINE (git) marketplace source.
#
# Unlike test.sh (which drives ensure-compusib-marketplace with a synthetic config.env via
# mk_lib), this builds a real container with the option set, so it proves install.sh threads
# pluginMarketplaceLocalOverride into the on-disk config.env that ensure-compusib-marketplace reads.

set -e

source dev-container-features-test-lib

OVERRIDE="/tmp/compusib-no-marketplace"
rm -rf "$OVERRIDE" # guarantee the override dir is absent -> the online branch is taken

check "config.env records the (absent) local-override path" \
    grep -q "PLUGIN_MARKETPLACE_LOCAL_OVERRIDE=\"$OVERRIDE\"" /usr/local/lib/features/claude/config.env

# No mounted checkout at the override path -> online git source + enabledPlugins written.
check "ensure-compusib-marketplace writes the online git source + enabledPlugins" bash -c '
    s="$HOME/.claude/settings.json"; rm -f "$s"
    ensure-compusib-marketplace
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.source" "$s")" = "git" ] &&
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.url" "$s")" = "git@github.com:compusib/ai.git" ] &&
    [ "$(jq -r ".enabledPlugins[\"base-stack@compusib\"]" "$s")" = "true" ]
'

reportResults
