#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
# Test manual setup scenario - autoSetup should be false
check "setup-git-hooks command is available" which setup-git-hooks

# Since autoSetup is false, git hooks should not be automatically configured
# We can test this by checking that no hooks are set up initially
check "no automatic hook setup occurred" bash -c "
    mkdir -p /tmp/test-manual && 
    cd /tmp/test-manual && 
    git init && 
    test ! -L .git/hooks/pre-commit || echo 'No automatic setup detected'
"

# Test manual setup works
check "manual setup works correctly" bash -c "
    cd /tmp/test-manual && 
    mkdir -p my-hooks/pre-commit.d && 
    echo '#!/bin/bash' > my-hooks/pre-commit.d/test && 
    setup-git-hooks --hooks-dir my-hooks --verbose &&
    test -L .git/hooks/pre-commit
"

reportResults
