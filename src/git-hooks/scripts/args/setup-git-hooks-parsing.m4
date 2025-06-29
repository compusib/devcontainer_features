#!/bin/bash

get_git_root() {
    local current_dir="${1:-$(pwd)}"
    local search_dir="$current_dir"
    
    # If we're inside a .git directory, move up until we're outside it
    while [[ "$search_dir" == *"/.git"* ]] && [ "$search_dir" != "/" ]; do
        search_dir="$(dirname "$search_dir")"
    done
    
    # First try git rev-parse --show-toplevel if git is available and we're not in .git
    if command -v git >/dev/null 2>&1; then
        local git_root
        git_root=$(cd "$search_dir" && git rev-parse --show-toplevel 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$git_root" ]; then
            echo "$git_root"
            return 0
        fi
    fi

    # No git repository found
    return 1
}

# ARG_OPTIONAL_SINGLE([hooks-dir],[d],[Custom source directory for hooks],[git/hooks])
# ARG_OPTIONAL_SINGLE([target-dir],[t],[Custom target directory for git hooks],[.git/hooks])
# ARG_OPTIONAL_SINGLE([repo-dir],[r],[Custom git repository directory],[$(get_git_root .)])
# ARG_OPTIONAL_BOOLEAN([dry-run],[n],[Show what would be done without making changes])
# ARG_OPTIONAL_BOOLEAN([force],[f],[Force overwrite existing hooks without prompting])
# ARG_OPTIONAL_BOOLEAN([list],[l],[List available hook types and exit])
# ARG_OPTIONAL_BOOLEAN([verbose],[v],[Enable verbose output])
# ARG_OPTIONAL_BOOLEAN([clean],[c],[Remove all installed hook symlinks])
# ARG_HELP([Git hooks setup script with argbash - installs project git hooks])
# ARGBASH_GO

