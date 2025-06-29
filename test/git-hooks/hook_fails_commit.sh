#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh

# Test hook that fails and prevents commit
check "setup-git-hooks command is available" which setup-git-hooks
check "git is available" which git

# Create test repository with failing pre-commit hook
check "create test repo with failing hook" bash -c "
    mkdir -p /tmp/test-failing-hook && 
    cd /tmp/test-failing-hook && 
    git init &&
    git config user.email 'test@example.com' &&
    git config user.name 'Test User' &&
    
    # Create hooks directory structure
    mkdir -p git/hooks/pre-commit.d &&
    
    # Create a failing pre-commit hook
    cat > git/hooks/pre-commit.d/01-failing-hook << 'EOF'
#!/bin/bash
echo 'Running failing pre-commit hook...'
echo 'ERROR: This hook always fails!'
exit 1
EOF
    chmod +x git/hooks/pre-commit.d/01-failing-hook &&
    
    # Setup git hooks
    setup-git-hooks --verbose
"

# Test that the hook prevents commit
check "failing hook prevents commit" bash -c "
    cd /tmp/test-failing-hook &&
    echo 'test content' > test.txt &&
    git add test.txt &&
    
    # This should fail due to the pre-commit hook
    if git commit -m 'Test commit'; then
        echo 'ERROR: Commit should have failed but succeeded'
        exit 1
    else
        echo 'SUCCESS: Commit properly failed due to pre-commit hook'
        exit 0
    fi
"

# Verify hook was actually executed
check "hook execution logged" bash -c "
    cd /tmp/test-failing-hook &&
    echo 'test content 2' > test2.txt &&
    git add test2.txt &&
    
    # Capture output and check for our hook message
    if git commit -m 'Test commit 2' 2>&1 | grep -q 'Running failing pre-commit hook'; then
        echo 'SUCCESS: Hook execution detected in output'
        exit 0
    else
        echo 'ERROR: Hook execution not detected'
        exit 1
    fi
"

reportResults
