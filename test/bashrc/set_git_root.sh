#!/bin/bash
set -e
source dev-container-features-test-lib
#check "~/.bashrc.d/000_CONTAINER_WORKSPACE_FOLDER_env.sh exists" ls ~/.bashrc.d/000_CONTAINER_WORKSPACE_FOLDER_env.sh
check "~/.bashrc.d/010_GIT_ROOT_env.sh contains the value " cat ~/.bashrc.d/010_GIT_ROOT_env.sh | grep "export GIT_ROOT=/test/some/path"
