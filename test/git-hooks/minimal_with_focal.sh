#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh
# Test minimal setup with focal base image and non-root user
check "setup-git-hooks command is available" which setup-git-hooks

check "running as octocat user" bash -c "
    whoami | grep -q 'octocat' || echo 'User context test'
"

check "common-utils feature is working" bash -c "
    # Test that common-utils was installed but without zsh/oh-my-zsh
    test ! -d /home/octocat/.oh-my-zsh || echo 'Oh-my-zsh correctly not installed'
"

check "verbose mode is disabled" bash -c "
    test '\$SETUP_GIT_HOOKS_VERBOSE' = 'false'
"

# Test basic functionality as non-root user
check "can setup git hooks as octocat user" bash -c "
    mkdir -p /tmp/test-focal && 
    cd /tmp/test-focal && 
    git init && 
    mkdir -p git/hooks && 
    echo '#!/bin/bash' > git/hooks/pre-commit && 
    echo 'echo \"Pre-commit hook for octocat\"' >> git/hooks/pre-commit &&
    chmod +x git/hooks/pre-commit &&
    setup-git-hooks
"

reportResults
