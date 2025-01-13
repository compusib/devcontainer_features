#!/bin/bash
set -e
source dev-container-features-test-lib
#check "~/.bashrc.d/00_CONTAINER_WORKSPACE_FOLDER_env.sh exists" ls ~/.bashrc.d/00_CONTAINER_WORKSPACE_FOLDER_env.sh
check "~/.bashrc.d/01_GIT_ROOT_env.sh contains the value " cat ~/.bashrc.d/01_GIT_ROOT_env.sh | grep "export GIT_ROOT=/test/some/path"
