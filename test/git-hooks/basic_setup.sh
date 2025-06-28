#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh
# Test basic setup scenario with default values
check "setup-git-hooks command is available" which setup-git-hooks

check "git is available" which git

check "default environment variables are set" bash -c "
    test '$SETUP_GIT_HOOKS_DIR' = 'git/hooks' &&
    test '$SETUP_GIT_HOOKS_VERBOSE' = 'false'
"

# Test basic functionality
check "basic git hooks setup works" bash -c "
    mkdir -p /tmp/test-basic && 
    cd /tmp/test-basic && 
    git init && 
    mkdir -p git/hooks && 
    echo '#!/bin/bash' > git/hooks/pre-commit && 
    chmod +x git/hooks/pre-commit &&
    setup-git-hooks
"

reportResults
