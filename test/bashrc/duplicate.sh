#!/bin/bash

#Read the hello and color tests for documentation here

set -e
source dev-container-features-test-lib
#check grep grep 'start CONTAINER FEATURE' cat /home/vscode/.bashrc | grep 'start CONTAINER FEATURE' || echo before first
#bash || echo exit interactive && echo exit interactive
#bash
if [ -e /home/vscode/.bashrc ]; then
    check "bashrc does not write twice to ~/.bashrc" bash -c "cat /home/vscode/.bashrc | grep 'start CONTAINER FEATURE' | wc -l | grep 1"
fi

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults

