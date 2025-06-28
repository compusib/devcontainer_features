#!/bin/bash
# Test script for the setup-git-hooks devcontainer feature
# This script can be used to test the feature after it's been transferred to the devcontainer_features repository

set -euo pipefail

echo "🧪 Testing setup-git-hooks devcontainer feature"

# Test 1: Check if setup-git-hooks is available system-wide
echo "📋 Test 1: Checking if setup-git-hooks is available system-wide..."
if command -v setup-git-hooks >/dev/null 2>&1; then
    echo "✅ setup-git-hooks command is available"
    setup-git-hooks --version || echo "ℹ️ No version info available"
else
    echo "❌ setup-git-hooks command not found"
    exit 1
fi

# Test 2: Check argbash library installation
echo "📋 Test 2: Checking argbash library installation..."
if [ -d "/usr/local/lib/argbash" ]; then
    echo "✅ argbash library directory exists"
    if [ -f "/usr/local/lib/argbash/setup-git-hooks-parsing.sh" ]; then
        echo "✅ argbash parsing script is available"
    else
        echo "❌ argbash parsing script not found"
        exit 1
    fi
    if [ -f "/usr/local/lib/argbash/Makefile" ]; then
        echo "✅ argbash Makefile is available"
    else
        echo "❌ argbash Makefile not found"
        exit 1
    fi
else
    echo "❌ argbash library directory not found"
    exit 1
fi

# Test 3: Check help functionality
echo "📋 Test 3: Testing help functionality..."
if setup-git-hooks --help | grep -q "Setup git hooks"; then
    echo "✅ Help functionality works"
else
    echo "❌ Help functionality failed"
    exit 1
fi

# Test 4: Create a temporary git repository and test the script
echo "📋 Test 4: Testing in a temporary git repository..."
TEMP_REPO="/tmp/test-git-hooks-$$"
mkdir -p "${TEMP_REPO}"
cd "${TEMP_REPO}"

# Initialize git repo
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create a simple git hooks directory
mkdir -p git/hooks
cat > git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Test pre-commit hook executed"
EOF
chmod +x git/hooks/pre-commit

# Test the setup-git-hooks script
echo "📋 Running setup-git-hooks in test repository..."
if setup-git-hooks --hooks-dir git/hooks --verbose; then
    echo "✅ setup-git-hooks executed successfully"
else
    echo "❌ setup-git-hooks failed"
    cd /
    rm -rf "${TEMP_REPO}"
    exit 1
fi

# Check if the hook was installed
if [ -f ".git/hooks/pre-commit" ]; then
    echo "✅ Pre-commit hook was installed"
else
    echo "❌ Pre-commit hook was not installed"
    cd /
    rm -rf "${TEMP_REPO}"
    exit 1
fi

# Test the hook
echo "📋 Testing installed git hook..."
echo "test" > test.txt
git add test.txt
if git commit -m "Test commit" 2>&1 | grep -q "Test pre-commit hook executed"; then
    echo "✅ Git hook executed successfully"
else
    echo "❌ Git hook did not execute"
    cd /
    rm -rf "${TEMP_REPO}"
    exit 1
fi

# Clean up
cd /
rm -rf "${TEMP_REPO}"

# Test 5: Test argbash regeneration
echo "📋 Test 5: Testing argbash script regeneration..."
cd /usr/local/lib/argbash
if make; then
    echo "✅ argbash Makefile executed successfully"
else
    echo "❌ argbash Makefile failed"
    exit 1
fi

echo ""
echo "🎉 All tests passed! The setup-git-hooks feature is working correctly."
echo ""
echo "📝 Feature capabilities verified:"
echo "   ✅ System-wide installation of setup-git-hooks script"
echo "   ✅ argbash library and parsing scripts installed"
echo "   ✅ Help and argument parsing functionality"
echo "   ✅ Git hooks installation and execution"
echo "   ✅ argbash script regeneration via Makefile"
