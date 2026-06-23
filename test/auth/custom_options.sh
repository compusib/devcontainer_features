#!/bin/bash
# Scenario test: non-default options must be threaded through install.sh into
# config.env so provision-auth reads them on create.
set -e

source dev-container-features-test-lib

check "sshJwtVersion override persisted" \
    bash -c 'grep -Fq "SSH_JWT_VERSION=\"latest\"" /usr/local/lib/features/auth/config.env'

check "keepGoToolchain override persisted" \
    bash -c 'grep -Fq "KEEP_GO_TOOLCHAIN=\"false\"" /usr/local/lib/features/auth/config.env'

check "pythonVersion override persisted" \
    bash -c 'grep -Fq "PYTHON_VERSION=\"3.13\"" /usr/local/lib/features/auth/config.env'

reportResults
