#!/bin/bash
#
# Scenario: pluginMarketplaceLocalOverride names a mounted checkout (a directory holding
# .claude-plugin/marketplace.json) -> the feature registers a local `directory` source.
#
# Like marketplace_online.sh, this proves install.sh threads the option into the real on-disk
# config.env; here it drives the mounted branch end to end against that config.

set -e

source dev-container-features-test-lib

OVERRIDE="/tmp/compusib-marketplace"

check "config.env records the mounted local-override path" \
    grep -q "PLUGIN_MARKETPLACE_LOCAL_OVERRIDE=\"$OVERRIDE\"" /usr/local/lib/features/claude/config.env

# Materialise a checkout at the override path -> directory source, no git url remnant.
check "ensure-compusib-marketplace writes a local directory source when mounted" bash -c '
    o="/tmp/compusib-marketplace"
    mkdir -p "$o/.claude-plugin"
    printf "{\"name\":\"compusib\",\"plugins\":[]}" > "$o/.claude-plugin/marketplace.json"
    s="$HOME/.claude/settings.json"; rm -f "$s"
    ensure-compusib-marketplace
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.source" "$s")" = "directory" ] &&
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.path" "$s")" = "$o" ] &&
    [ "$(jq -r ".extraKnownMarketplaces.compusib.source.url // \"absent\"" "$s")" = "absent" ]
'

reportResults
