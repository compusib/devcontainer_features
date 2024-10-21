#!/bin/bash

#Read the hello and color tests for documentation here

set -e
source dev-container-features-test-lib
check "~/.bashrc.d/CONTAINER_WORKSPACE_FOLDER_env.sh exists" ls ~/.bashrc.d/CONTAINER_WORKSPACE_FOLDER_env.sh
check "~/.bashrc.d/CONTAINER_WORKSPACE_FOLDER_env.sh contains the variable CONTAINER_WORKSPACE_FOLDER" cat ~/.bashrc.d/CONTAINER_WORKSPACE_FOLDER_env.sh | grep CONTAINER_WORKSPACE_FOLDER=
# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults