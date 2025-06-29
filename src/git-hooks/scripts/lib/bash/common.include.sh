# Function to find git root directory (same as in setup-git-hooks)
get_git_root() {
    local current_dir="${1:-$(pwd)}"
    local search_dir="$current_dir"
    
    # If we're inside a .git directory, move up until we're outside it
    while [[ "$search_dir" == *"/.git"* ]] && [ "$search_dir" != "/" ]; do
        search_dir="$(realpath "$search_dir"/..)"
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
    
    # Fallback: search for .git directory in parent paths
    while [ -n "$search_dir" ] && [ "$search_dir" != "/" ]; do
        if [ -d "$search_dir/.git" ] || [ -f "$search_dir/.git" ]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(realpath "$search_dir"/..)"
    done
    
    # No git repository found
    return 1
}
