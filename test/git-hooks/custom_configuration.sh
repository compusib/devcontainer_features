#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
# Test custom configuration scenario
check "setup-git-hooks command is available" which setup-git-hooks


# Test that custom hooks directory can be used
check "can use custom hooks directory" bash -c "
    mkdir -p /tmp/test-custom && 
    cd /tmp/test-custom &&
    unset GIT_ROOT && 
    git init && 
    mkdir -p custom/hooks/path && 
    echo '#!/bin/bash' > custom/hooks/path/pre-commit && 
    setup-git-hooks --hooks-dir custom/hooks/path --verbose
"

reportResults
