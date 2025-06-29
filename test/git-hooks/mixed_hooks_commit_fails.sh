#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh

# Test mixed hooks where one succeeds and one fails, causing commit to fail
check "setup-git-hooks command is available" which setup-git-hooks
check "git is available" which git

# Create test repository with mixed pre-commit hooks
check "create test repo with mixed hooks" bash -c "
    mkdir -p /tmp/test-mixed-hooks && 
    cd /tmp/test-mixed-hooks && 
    git init &&
    git config user.email 'test@example.com' &&
    git config user.name 'Test User' &&
    
    # Create hooks directory structure
    mkdir -p git/hooks/pre-commit.d &&
    
    # Create a successful pre-commit hook (runs first)
    cat > git/hooks/pre-commit.d/01-successful-hook << 'EOF'
#!/bin/bash
echo 'Running first hook (successful)...'
echo 'SUCCESS: First hook passed!'
exit 0
EOF
    chmod +x git/hooks/pre-commit.d/01-successful-hook &&
    
    # Create a failing pre-commit hook (runs second)
    cat > git/hooks/pre-commit.d/02-failing-hook << 'EOF'
#!/bin/bash
echo 'Running second hook (failing)...'
echo 'ERROR: Second hook failed!'
exit 1
EOF
    chmod +x git/hooks/pre-commit.d/02-failing-hook &&
    
    # Setup git hooks
    setup-git-hooks --verbose
"

# Test that one failing hook prevents commit despite other succeeding
check "mixed hooks prevent commit when one fails" bash -c "
    cd /tmp/test-mixed-hooks &&
    echo 'test content' > test.txt &&
    git add test.txt &&
    
    # This should fail due to the second pre-commit hook
    if git commit -m 'Test commit'; then
        echo 'ERROR: Commit should have failed but succeeded'
        exit 1
    else
        echo 'SUCCESS: Commit properly failed due to failing hook'
        exit 0
    fi
"

# Verify both hooks were executed
check "both hooks executed in order" bash -c "
    cd /tmp/test-mixed-hooks &&
    echo 'test content 2' > test2.txt &&
    git add test2.txt &&
    
    # Capture output and check for both hook messages
    output=\$(git commit -m 'Test commit 2' 2>&1 || true)
    
    if echo \"\$output\" | grep -q 'Running first hook (successful)'; then
        echo 'SUCCESS: First hook execution detected'
    else
        echo 'ERROR: First hook execution not detected'
        exit 1
    fi
    
    if echo \"\$output\" | grep -q 'Running second hook (failing)'; then
        echo 'SUCCESS: Second hook execution detected'
    else
        echo 'ERROR: Second hook execution not detected'
        exit 1
    fi
    
    # Verify no commit was actually made
    if git log --oneline 2>/dev/null | grep -q 'Test commit'; then
        echo 'ERROR: Commit was made despite hook failure'
        exit 1
    else
        echo 'SUCCESS: No commit made due to hook failure'
        exit 0
    fi
"

# Test with only successful hook by temporarily disabling the failing one
check "commit succeeds with only successful hook" bash -c "
    cd /tmp/test-mixed-hooks &&
    
    # Disable the failing hook by removing execute permission
    chmod -x git/hooks/pre-commit.d/02-failing-hook &&
    
    echo 'test content 3' > test3.txt &&
    git add test3.txt &&
    
    # This should now succeed
    if git commit -m 'Test commit with only successful hook'; then
        echo 'SUCCESS: Commit succeeded with only successful hook'
        exit 0
    else
        echo 'ERROR: Commit failed unexpectedly'
        exit 1
    fi
"

reportResults
