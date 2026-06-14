# ensure-compusib-marketplace.jq
#
# Transform ~/.claude/settings.json to register exactly one marketplace ($m,
# e.g. "compusib") with the chosen source ($src = "git" | "directory") and to
# enable each configured plugin. Loaded by ensure-compusib-marketplace via
# `jq -f`, with these --arg variables:
#
#   $m       marketplace name (e.g. "compusib")
#   $src     "git" | "directory"
#   $url     git URL          (used when $src == "git")
#   $path    local directory  (used when $src == "directory")
#   $plugins newline-joined "<name>@<marketplace>" enabledPlugins keys

# The marketplace entry for the chosen source kind. The source object is nested
# (.source.source is the kind string), matching the known_marketplaces.json schema.
def mkt_entry:
    if $src == "directory"
    then { "source": { "source": "directory", "path": $path } }
    else { "source": { "source": "git", "url": $url }, "autoUpdate": true }
    end;

# enabledPlugins keys parsed from the newline-joined $plugins arg.
def plugin_keys:
    ($plugins | split("\n") | map(select(length > 0)));

# Replace (not merge) the marketplace entry so a stale online url/autoUpdate
# cannot leak into a directory entry; preserve every other marketplace and key.
(.extraKnownMarketplaces = (.extraKnownMarketplaces // {}))
| .extraKnownMarketplaces[$m] = mkt_entry
# Enable each configured plugin additively (preserves user-enabled plugins).
| .enabledPlugins = (reduce plugin_keys[] as $k
      ((.enabledPlugins // {}); .[$k] = true))
