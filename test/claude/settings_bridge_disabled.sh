#!/bin/bash
#
# Verifies that install-settings-bridge no-ops cleanly when installSettingsBridge is false.

set -e

source dev-container-features-test-lib

check "install-settings-bridge on PATH" bash -c "command -v install-settings-bridge"

# Disabled via the feature option -> must exit 0 without attempting any install/download.
check "install-settings-bridge exits 0 when disabled" install-settings-bridge

reportResults
