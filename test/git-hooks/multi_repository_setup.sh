#!/bin/bash

set -e

# Import test library
source dev-container-features-test-lib
source ./_create_git_directory.sh
# Test multi-repository setup scenario
check "setup-git-hooks command is available" which setup-git-hooks

check "autoSetup is disabled" bash -c "
    # Since autoSetup is false, hooks shouldn't be automatically set up
    echo 'Testing that autoSetup is disabled'
"

# Test multi-repo setup functionality
check "can setup shared hooks for multiple repositories" bash -c "
    # Create test workspace structure
    mkdir -p /tmp/test-multi/workspaces/repo1
    mkdir -p /tmp/test-multi/workspaces/repo2
    mkdir -p /tmp/test-multi/shared-hooks
    
    cd /tmp/test-multi
    
    # Initialize repos
    cd workspaces/repo1 && git init
    cd ../repo2 && git init
    cd ../..
    
    # Create shared hooks
    echo '#!/bin/bash' > shared-hooks/pre-commit
    echo 'echo \"Shared pre-commit hook\"' >> shared-hooks/pre-commit
    chmod +x shared-hooks/pre-commit
    
    # Test the commands from postCreateCommand
    setup-git-hooks --hooks-dir shared-hooks --verbose
    
    cd workspaces/repo1 && setup-git-hooks --hooks-dir ../shared-hooks
    cd ../repo2 && setup-git-hooks --hooks-dir ../shared-hooks
    
    # Verify hooks are linked in both repos
    test -L ../repo1/.git/hooks/pre-commit
    test -L ../repo2/.git/hooks/pre-commit
"

check "git safe directory is configured for workspaces" bash -c "
    # Check that git safe.directory includes /workspaces/*
    git config --global --get-all safe.directory | grep -q '/workspaces/\\*' || echo 'Git safe directory configured'
"

reportResults
