#!/bin/bash

#Read the hello and color tests for documentation here

set -e
source dev-container-features-test-lib
check "~/.bashrc.d/00_CONTAINER_WORKSPACE_FOLDER_env.sh exists" ls ~/.bashrc.d/00_CONTAINER_WORKSPACE_FOLDER_env.sh
check "~/.bashrc.d/00_CONTAINER_WORKSPACE_FOLDER_env.sh contains the variable CONTAINER_WORKSPACE_FOLDER" cat ~/.bashrc.d/00_CONTAINER_WORKSPACE_FOLDER_env.sh | grep "export CONTAINER_WORKSPACE_FOLDER="
check "~/.bashrc.d/10_bash_path_append.sh exists" ls ~/.bashrc.d/10_bash_path_append.sh
check "~/.bashrc.d/10_bash_path_append.sh contains PATH=" cat ~/.bashrc.d/10_bash_path_append.sh | grep "export PATH=" 
check "~/.bashrc.d/10_bash_path_append.sh contains \$CONTAINER_WORKSPACE_FOLDER reference" cat ~/.bashrc.d/10_bash_path_append.sh | grep "CONTAINER_WORKSPACE_FOLDER"
check "~/.bashrc.d/01_GIT_ROOT_env.sh contains export GIT_ROOT=" cat ~/.bashrc.d/01_GIT_ROOT_env.sh | grep "export GIT_ROOT=" 
check "~/.bashrc.d/01_GIT_ROOT_env.sh contains \$CONTAINER_WORKSPACE_FOLDER reference" cat ~/.bashrc.d/01_GIT_ROOT_env.sh | grep "CONTAINER_WORKSPACE_FOLDER"
# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults

