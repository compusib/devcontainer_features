#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh

# Test hook that succeeds and allows commit
check "setup-git-hooks command is available" which setup-git-hooks
check "git is available" which git

# Create test repository with successful pre-commit hook
check "create test repo with successful hook" bash -c "
    mkdir -p /tmp/test-successful-hook && 
    cd /tmp/test-successful-hook && 
    git init &&
    git config user.email 'test@example.com' &&
    git config user.name 'Test User' &&
    
    # Create hooks directory structure
    mkdir -p git/hooks/pre-commit.d &&
    
    # Create a successful pre-commit hook
    cat > git/hooks/pre-commit.d/01-successful-hook << 'EOF'
#!/bin/bash
echo 'Running successful pre-commit hook...'
echo 'SUCCESS: All checks passed!'
exit 0
EOF
    chmod +x git/hooks/pre-commit.d/01-successful-hook &&
    
    # Setup git hooks
    setup-git-hooks --verbose
"

# Test that the hook allows commit
check "successful hook allows commit" bash -c "
    cd /tmp/test-successful-hook &&
    echo 'test content' > test.txt &&
    git add test.txt &&
    
    # This should succeed
    if git commit -m 'Test commit'; then
        echo 'SUCCESS: Commit succeeded with hook'
        exit 0
    else
        echo 'ERROR: Commit failed unexpectedly'
        exit 1
    fi
"

# Verify hook was actually executed
check "hook execution logged and commit exists" bash -c "
    cd /tmp/test-successful-hook &&
    
    # Check that commit exists
    if git log --oneline | grep -q 'Test commit'; then
        echo 'SUCCESS: Commit found in git log'
    else
        echo 'ERROR: Commit not found in git log'
        exit 1
    fi
    
    # Test another commit to verify hook still runs
    echo 'test content 2' > test2.txt &&
    git add test2.txt &&
    
    # Capture output and check for our hook message
    if git commit -m 'Test commit 2' 2>&1 | grep -q 'Running successful pre-commit hook'; then
        echo 'SUCCESS: Hook execution detected in output'
        exit 0
    else
        echo 'ERROR: Hook execution not detected'
        exit 1
    fi
"

reportResults
