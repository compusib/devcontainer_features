#!/bin/bash

set -e
source dev-container-features-test-lib


GATEWAY_IP=$(ip route show default | cut -d ' ' -f 3)
check 'alias ip is found in /etc/hosts' grep "\$GATEWAY_IP " /etc/hosts

reportResults
