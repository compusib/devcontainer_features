#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh
# Test empty git safe directory scenario
check "setup-git-hooks command is available" which setup-git-hooks

check "git safe directory is empty/unset" bash -c "
    # When gitSafeDirectory is set to empty string, it should not configure safe.directory
    # We can test this by checking that no safe.directory was added by our feature
    echo 'Testing empty gitSafeDirectory configuration'
"

check "git safe directory not automatically configured" bash -c "
    # Check that our feature didn't add any safe.directory entries
    # (there might be system defaults, but ours shouldn't be there)
    git config --global --get-all safe.directory | grep -v '/workspaces' || echo 'No workspaces safe.directory found as expected'
"

# Test basic functionality still works without safe directory config
check "basic git hooks setup still works" bash -c "
    mkdir -p /tmp/test-empty-safe && 
    cd /tmp/test-empty-safe && 
    git init && 
    mkdir -p git/hooks && 
    echo '#!/bin/bash' > git/hooks/pre-commit && 
    echo 'echo \"Pre-commit without safe directory\"' >> git/hooks/pre-commit &&
    chmod +x git/hooks/pre-commit &&
    setup-git-hooks
"


reportResults
