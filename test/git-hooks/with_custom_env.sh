#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib

# Test custom environment variables scenario
check "setup-git-hooks command is available" which setup-git-hooks

check "custom hooks directory is configured" bash -c "
    test '\$SETUP_GIT_HOOKS_DIR' = 'tools/git-hooks'
"

check "verbose mode is enabled" bash -c "
    test '\$SETUP_GIT_HOOKS_VERBOSE' = 'true'
"

check "custom environment variable is available" bash -c "
    test '\$GIT_HOOKS_CUSTOM_VAR' = 'value'
"

# Test functionality with custom environment
check "can use custom hooks directory with environment" bash -c "
    mkdir -p /tmp/test-custom-env && 
    cd /tmp/test-custom-env && 
    git init && 
    mkdir -p tools/git-hooks && 
    echo '#!/bin/bash' > tools/git-hooks/pre-commit && 
    echo 'echo \"Custom env hook with var: \$GIT_HOOKS_CUSTOM_VAR\"' >> tools/git-hooks/pre-commit &&
    chmod +x tools/git-hooks/pre-commit &&
    setup-git-hooks --hooks-dir tools/git-hooks --verbose
"

reportResults
