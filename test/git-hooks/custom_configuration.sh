#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh
# Test custom configuration scenario
check "setup-git-hooks command is available" which setup-git-hooks

check "environment variables reflect custom config" bash -c "
    echo 'SETUP_GIT_HOOKS_DIR: $SETUP_GIT_HOOKS_DIR'
    test '$SETUP_GIT_HOOKS_DIR' = 'custom/hooks/path'
"

check "verbose mode is enabled" bash -c "
    echo 'SETUP_GIT_HOOKS_VERBOSE: $SETUP_GIT_HOOKS_VERBOSE'
    test '$SETUP_GIT_HOOKS_VERBOSE' = 'true'
"

# Test that custom hooks directory can be used
check "can use custom hooks directory" bash -c "
    mkdir -p /tmp/test-custom && 
    cd /tmp/test-custom && 
    git init && 
    mkdir -p custom/hooks/path && 
    echo '#!/bin/bash' > custom/hooks/path/pre-commit && 
    setup-git-hooks --hooks-dir custom/hooks/path --verbose
"

reportResults
