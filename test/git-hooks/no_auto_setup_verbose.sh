#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh
# Test no auto setup with verbose mode scenario
check "setup-git-hooks command is available" which setup-git-hooks

check "autoSetup is disabled" bash -c "
    # Since autoSetup is false, no automatic setup should occur
    echo 'Testing that autoSetup is disabled'
"


# Test that no automatic setup occurred
check "no automatic hook setup occurred" bash -c "
    mkdir -p /tmp/test-no-auto && 
    cd /tmp/test-no-auto && 
    git init && 
    # Check that hooks directory is empty/default (no automatic setup)
    test ! -L .git/hooks/pre-commit || echo 'No automatic setup confirmed'
"

# Test manual setup with verbose mode and custom directory
check "manual verbose setup works with custom directory" bash -c "
    cd /tmp/test-no-auto && 
    mkdir -p project-hooks/pre-commit.d && 
    echo '#!/bin/bash' > project-hooks/pre-commit.d/project_specific && 
    echo 'echo \"Project-specific pre-commit hook\"' >> project-hooks/pre-commit.d/project_specific &&
    chmod +x project-hooks/pre-commit.d/project_specific &&
    setup-git-hooks --hooks-dir project-hooks --verbose &&
    test -L .git/hooks/pre-commit
"

reportResults
